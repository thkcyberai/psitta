"""api/v1/waitlist.py — Public Creativity Nook waitlist endpoint (Phase F).

Endpoints:
  POST /waitlist/creativity-nook  — capture an email for the launch waitlist

Security:
  - Public — no JWT authentication required
  - Input bounded by Pydantic (EmailStr)
  - Inserted via parameterized SQL; ON CONFLICT (email) DO NOTHING makes
    the endpoint idempotent without leaking list membership to attackers
    probing for known emails (anti-enumeration: same response for new +
    duplicate submissions)
  - Audit log entry written for SOC 2 traceability
  - DB errors logged server-side but never exposed to the client
  - Rate limiting handled upstream by RateLimitMiddleware (default bucket)
"""

from __future__ import annotations

import structlog
from fastapi import APIRouter, Depends, Request, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, EmailStr
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.dependencies import get_db_session
from psitta.services import audit_service

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)

router = APIRouter()


# ── Request / Response Schemas ───────────────────────────────────────────


class CreativityWaitlistRequest(BaseModel):
    """Email-only payload for the Creativity Nook launch waitlist."""

    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")

    email: EmailStr


class CreativityWaitlistResponse(BaseModel):
    """Outcome of a waitlist join attempt."""

    success: bool
    message: str


_SUCCESS_MESSAGE = (
    "You're on the list. We'll email you when Creativity Nook launches."
)


# ── POST /waitlist/creativity-nook (public) ─────────────────────────────


@router.post(
    "/waitlist/creativity-nook",
    response_model=CreativityWaitlistResponse,
    summary="Join the Creativity Nook launch waitlist",
)
async def join_creativity_waitlist(
    payload: CreativityWaitlistRequest,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
) -> CreativityWaitlistResponse | JSONResponse:
    """Capture an email for Creativity Nook launch notification.

    Public endpoint. ON CONFLICT (email) DO NOTHING makes duplicate
    submissions idempotent so the response does not reveal whether an
    email is already on the list.
    """
    try:
        await db.execute(
            text(
                """
                INSERT INTO signup_list
                    (email, first_name, source, status)
                VALUES
                    (:email, NULL, 'creativity_nook_waitlist', 'pending')
                ON CONFLICT (email) DO NOTHING
                """
            ),
            {"email": payload.email},
        )
        await audit_service.log_event(
            db,
            action="waitlist.creativity_nook.signup",
            resource_type="waitlist",
            details={"email": payload.email},
            ip_address=request.client.host if request.client else None,
        )
        await db.commit()
    except SQLAlchemyError as exc:
        await db.rollback()
        logger.error(
            "waitlist.creativity_nook.db_error",
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
        "waitlist.creativity_nook.signup",
        email=payload.email,
    )
    return CreativityWaitlistResponse(
        success=True, message=_SUCCESS_MESSAGE
    )
