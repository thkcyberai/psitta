"""api/v1/contact.py — Public contact-form endpoint (M8b.2).

Endpoints:
  POST /contact  — accept a contact-form submission from psitta.ai

Security:
  - Public — no JWT authentication required
  - Input bounded by Pydantic field constraints (length limits, EmailStr)
  - Inserted via parameterized SQL, never string-interpolated
  - DB errors logged server-side but not exposed to the client
  - Rate limiting handled upstream by RateLimitMiddleware (default bucket)
"""

from __future__ import annotations

from typing import Optional

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


class ContactRequest(BaseModel):
    """Payload submitted by the psitta.ai contact form."""

    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")

    first_name: str = Field(min_length=1, max_length=100)
    last_name: str = Field(min_length=1, max_length=100)
    email: EmailStr
    phone: Optional[str] = Field(default=None, max_length=30)
    message: str = Field(min_length=1, max_length=5000)


class ContactResponse(BaseModel):
    """Outcome of a contact submission attempt."""

    success: bool
    message: str


# ── POST /contact (public) ───────────────────────────────────────────────


@router.post(
    "/contact",
    response_model=ContactResponse,
    summary="Submit a message through the public contact form",
)
async def submit_contact(
    payload: ContactRequest,
    db: AsyncSession = Depends(get_db_session),
) -> ContactResponse | JSONResponse:
    """Store a contact-form submission for the founder to review.

    Public endpoint — no authentication required. On success returns
    ``{success: true, ...}``. On any database failure returns HTTP 500
    with a generic message that does not leak internal details.
    """
    try:
        await db.execute(
            text(
                """
                INSERT INTO contact_submissions
                    (first_name, last_name, email, phone, message)
                VALUES
                    (:first_name, :last_name, :email, :phone, :message)
                """
            ),
            {
                "first_name": payload.first_name,
                "last_name": payload.last_name,
                "email": payload.email,
                "phone": payload.phone,
                "message": payload.message,
            },
        )
        await db.commit()
    except SQLAlchemyError as exc:
        await db.rollback()
        logger.error(
            "contact.submit.db_error",
            error=str(exc),
            email=payload.email,
        )
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={
                "success": False,
                "message": (
                    "Something went wrong. Please try again or email "
                    "support@psitta.ai directly."
                ),
            },
        )

    logger.info(
        "contact.submit.ok",
        email=payload.email,
        first_name=payload.first_name,
        last_name=payload.last_name,
    )
    return ContactResponse(
        success=True,
        message="Thank you for reaching out. We will get back to you soon.",
    )
