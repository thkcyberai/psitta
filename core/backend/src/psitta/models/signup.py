"""SQLAlchemy ORM model for homepage signup-list entries (M8b.x).

Maps the ``signup_list`` table created in migration 014. Receives public
email submissions from the psitta.ai signup form — no foreign keys, no
auth context: the submitter may or may not have a Psitta account.

Status lifecycle is a CHECK-constrained string tag rather than a
PostgreSQL enum so the operator can adjust without a schema migration,
and the CHECK still guards against typos.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, String, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from psitta.db.base import Base


class SignupListEntry(Base):
    """A single email captured by the public homepage signup form."""

    __tablename__ = "signup_list"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    email: Mapped[str] = mapped_column(
        String(255), nullable=False, unique=True
    )
    first_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    source: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        server_default=text("'homepage_hero'"),
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=text("NOW()"),
        index=True,
    )
    status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        server_default=text("'pending'"),
    )

    def __repr__(self) -> str:
        return (
            f"<SignupListEntry id={self.id} email={self.email} "
            f"status={self.status}>"
        )
