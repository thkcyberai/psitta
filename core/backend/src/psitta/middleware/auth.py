"""
Psitta — Amazon Cognito JWT Authentication.

Validates Cognito-issued JWTs on protected routes using JWKS (RS256).
Provides a FastAPI dependency that extracts and validates the token,
returning the authenticated user's claims.

Security:
  - RS256 signature verification via Cognito's JWKS endpoint
  - Audience (client_id) and issuer validation
  - Token expiry enforcement (handled by python-jose)
  - JWKS keys cached with TTL to avoid per-request fetches
"""

from __future__ import annotations

import time
from dataclasses import dataclass, field
from typing import Any

import httpx
import structlog
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

from psitta.config import Settings, get_settings

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)

# ── JWKS Cache ────────────────────────────────────────────────────────

_jwks_cache: dict[str, Any] = {}
_jwks_cache_expiry: float = 0.0
_JWKS_CACHE_TTL: int = 3600  # 1 hour


async def _get_jwks(settings: Settings) -> dict[str, Any]:
    """Fetch and cache Cognito JWKS (JSON Web Key Set).

    Keys are cached for 1 hour to avoid hitting Cognito on every request.
    Cognito rotates keys infrequently; 1hr TTL is safe and efficient.
    """
    global _jwks_cache, _jwks_cache_expiry  # noqa: PLW0603

    now = time.monotonic()
    if _jwks_cache and now < _jwks_cache_expiry:
        return _jwks_cache

    jwks_url = settings.cognito_jwks_url
    logger.info("auth.jwks.fetch", url=jwks_url)

    async with httpx.AsyncClient() as client:
        resp = await client.get(jwks_url, timeout=10.0)
        resp.raise_for_status()
        _jwks_cache = resp.json()
        _jwks_cache_expiry = now + _JWKS_CACHE_TTL

    return _jwks_cache


def _find_rsa_key(jwks: dict[str, Any], token: str) -> dict[str, str]:
    """Extract the RSA public key matching the token's kid header."""
    try:
        unverified_header = jwt.get_unverified_header(token)
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token header",
        ) from exc

    kid = unverified_header.get("kid")
    if not kid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token missing key ID (kid)",
        )

    for key in jwks.get("keys", []):
        if key.get("kid") == kid:
            return {
                "kty": key["kty"],
                "kid": key["kid"],
                "use": key["use"],
                "n":   key["n"],
                "e":   key["e"],
            }

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Unable to find matching signing key",
    )


# ── Token Claims ──────────────────────────────────────────────────────


@dataclass(frozen=True)
class TokenClaims:
    """Validated claims extracted from a Cognito JWT."""

    sub: str            # Cognito user ID (UUID format)
    email: str = ""
    email_verified: bool = False
    permissions: list[str] = field(default_factory=list)
    roles: list[str] = field(default_factory=list)
    raw: dict[str, Any] = field(default_factory=dict, repr=False)


# ── FastAPI Dependencies ──────────────────────────────────────────────

_bearer_scheme = HTTPBearer(auto_error=True)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer_scheme),
    settings: Settings = Depends(get_settings),
) -> TokenClaims:
    """Validate the Cognito Bearer token and return claims.

    Raises 401 if the token is missing, expired, or invalid.

    Cognito access tokens use client_id as the audience.
    Cognito ID tokens use client_id as the audience too.
    We validate against COGNITO_CLIENT_ID.
    """
    token = credentials.credentials

    # Development bypass — local testing only, never reaches production
    if settings.ENVIRONMENT == "development" and token == "dev-bypass-token":
        logger.warning("auth.dev_bypass", msg="Using development bypass token")
        return TokenClaims(
            sub="00000000-0000-0000-0000-000000000001",
            email="dev@psitta.local",
            email_verified=True,
            permissions=["read:documents", "write:documents"],
            roles=["admin"],
        )

    jwks = await _get_jwks(settings)
    rsa_key = _find_rsa_key(jwks, token)

    # Extract unverified claims for diagnostic logging on failure
    try:
        unverified_payload = jwt.get_unverified_claims(token)
    except Exception:
        unverified_payload = {}

    # Cognito access tokens: audience is the user pool client_id
    # Cognito ID tokens: audience is also the client_id
    try:
        payload = jwt.decode(
            token,
            rsa_key,
            algorithms=["RS256"],
            audience=settings.COGNITO_CLIENT_ID,
            issuer=settings.cognito_issuer,
        )
    except jwt.ExpiredSignatureError as exc:
        logger.warning(
            "auth.token.expired",
            token_sub=unverified_payload.get("sub"),
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired",
        ) from exc
    except jwt.JWTClaimsError as exc:
        logger.warning(
            "auth.token.claims_error",
            error=str(exc),
            token_iss=unverified_payload.get("iss"),
            token_aud=unverified_payload.get("aud"),
            expected_iss=settings.cognito_issuer,
            expected_aud=settings.COGNITO_CLIENT_ID,
            jwks_url=settings.cognito_jwks_url,
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token claims (audience/issuer mismatch)",
        ) from exc
    except JWTError as exc:
        logger.warning(
            "auth.token.invalid",
            error_type=type(exc).__name__,
            error=str(exc),
            token_iss=unverified_payload.get("iss"),
            expected_iss=settings.cognito_issuer,
            jwks_url=settings.cognito_jwks_url,
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        ) from exc

    sub = payload.get("sub")
    if not sub:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token missing subject claim",
        )

    # Cognito standard claims
    email = payload.get("email", "")
    email_verified = payload.get("email_verified", False)

    # Cognito groups map to roles (set via User Pool groups)
    roles = payload.get("cognito:groups", [])

    # Permissions derived from roles for compatibility
    permissions: list[str] = []
    if "admin" in roles:
        permissions = ["read:documents", "write:documents", "delete:documents"]
    elif roles:
        permissions = ["read:documents", "write:documents"]

    logger.info("auth.validated", sub=sub, roles=roles)

    return TokenClaims(
        sub=sub,
        email=email,
        email_verified=email_verified,
        permissions=permissions,
        roles=roles,
        raw=payload,
    )


# ── Role / Permission Checkers ────────────────────────────────────────


def require_role(*allowed_roles: str):
    """FastAPI dependency that checks the user has one of the allowed roles."""

    async def _check(claims: TokenClaims = Depends(get_current_user)) -> TokenClaims:
        if not any(role in claims.roles for role in allowed_roles):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Requires one of roles: {', '.join(allowed_roles)}",
            )
        return claims

    return _check


def require_permission(*required_perms: str):
    """FastAPI dependency that checks the user has all required permissions."""

    async def _check(claims: TokenClaims = Depends(get_current_user)) -> TokenClaims:
        missing = [p for p in required_perms if p not in claims.permissions]
        if missing:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Missing permissions: {', '.join(missing)}",
            )
        return claims

    return _check
