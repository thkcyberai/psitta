"""Pre-Token-Generation v2 Lambda — injects email claim into Cognito access token.

Cognito access tokens by default omit user-attribute claims. This Lambda
fires on every token-generation event and copies the verified email
attribute into the access token's claim set so the FastAPI resolver
(get_effective_plan -> tester_allowlist) can match by email without an
AdminGetUser round trip.

Fail-open: any error returns the event unchanged so login never breaks.
Cognito v2 schema requires returning the modified event verbatim.
"""
from __future__ import annotations

import logging
import os

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

# triggerSource values that fire on token-issuing flows we care about.
# All must be handled so refresh tokens also carry email.
_TOKEN_TRIGGERS = {
    "TokenGeneration_Authentication",
    "TokenGeneration_HostedAuth",
    "TokenGeneration_RefreshTokens",
    "TokenGeneration_AuthenticateDevice",
    "TokenGeneration_NewPasswordChallenge",
}


def lambda_handler(event: dict, context: object) -> dict:
    try:
        trigger = event.get("triggerSource", "")
        if trigger not in _TOKEN_TRIGGERS:
            return event

        attrs = event.get("request", {}).get("userAttributes", {}) or {}
        email = attrs.get("email")
        if not email:
            logger.warning(
                "pre_token_gen.no_email  sub=%s trigger=%s",
                event.get("userName"), trigger,
            )
            return event

        event.setdefault("response", {})
        event["response"]["claimsAndScopeOverrideDetails"] = {
            "accessTokenGeneration": {
                "claimsToAddOrOverride": {"email": email},
            },
            "idTokenGeneration": {
                "claimsToAddOrOverride": {"email": email},
            },
        }
        logger.info(
            "pre_token_gen.injected  sub=%s trigger=%s",
            event.get("userName"), trigger,
        )
        return event
    except Exception:
        logger.exception("pre_token_gen.error - returning event unchanged")
        return event
