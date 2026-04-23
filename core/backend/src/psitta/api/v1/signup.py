"""api/v1/signup.py — Public homepage email-capture endpoint.

Endpoints:
  POST /signup  — capture an email + first name from psitta.ai/signup

Security:
  - Public — no JWT authentication required
  - Input bounded by Pydantic (EmailStr + length limits on first_name)
  - Inserted via parameterized SQL; ON CONFLICT (email) DO NOTHING
    makes the endpoint idempotent without leaking list membership to
    attackers probing for known emails
  - DB errors logged server-side but never exposed to the client
  - Rate limiting handled upstream by RateLimitMiddleware (default bucket)
"""

from __future__ import annotations

import structlog
from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, EmailStr, Field
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.dependencies import get_db_session

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)

router = APIRouter()


# ── Request / Response Schemas ───────────────────────────────────────────


class SignupRequest(BaseModel):
    """Payload submitted by the psitta.ai homepage signup form."""

    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")

    email: EmailStr
    first_name: str = Field(min_length=1, max_length=100)


class SignupResponse(BaseModel):
    """Outcome of a signup attempt."""

    success: bool
    message: str


_SUCCESS_MESSAGE = "Thanks! We'll let you know when Psitta is ready for you."


# ── POST /signup (public) ────────────────────────────────────────────────


@router.post(
    "/signup",
    response_model=SignupResponse,
    summary="Join the Psitta launch list (homepage email capture)",
)
async def submit_signup(
    payload: SignupRequest,
    db: AsyncSession = Depends(get_db_session),
) -> SignupResponse | JSONResponse:
    """Capture an email for launch notifications.

    Public endpoint — no authentication required. ``ON CONFLICT (email)
    DO NOTHING`` makes duplicate submissions idempotent so the response
    does not reveal whether an email is already on the list.
    """
    try:
        await db.execute(
            text(
                """
                INSERT INTO signup_list
                    (email, first_name, source, status)
                VALUES
                    (:email, :first_name, 'homepage_hero', 'pending')
                ON CONFLICT (email) DO NOTHING
                """
            ),
            {
                "email": payload.email,
                "first_name": payload.first_name,
            },
        )
        await db.commit()
    except SQLAlchemyError as exc:
        await db.rollback()
        logger.error(
            "signup.submit.db_error",
            error=str(exc),
            email=payload.email,
        )
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={
                "success": False,
                "message": "Something went wrong. Please try again.",
            },
        )

    logger.info(
        "signup.submit.ok",
        email=payload.email,
        first_name=payload.first_name,
    )
    return SignupResponse(success=True, message=_SUCCESS_MESSAGE)
