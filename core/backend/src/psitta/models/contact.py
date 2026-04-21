"""SQLAlchemy ORM model for contact-form submissions (M8b.2).

Maps the ``contact_submissions`` table created in migration 013.
Receives public submissions from the psitta.ai contact form — no
foreign keys, no auth context: the submitter may or may not have a
Psitta account.

Status lifecycle is a short string tag rather than a PostgreSQL enum so
the operator can adjust states (e.g. add ``spam``) without a migration.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, String, Text, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from psitta.db.base import Base


class ContactSubmission(Base):
    """A single message submitted through the public contact form."""

    __tablename__ = "contact_submissions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    first_name: Mapped[str] = mapped_column(String(100), nullable=False)
    last_name: Mapped[str] = mapped_column(String(100), nullable=False)
    email: Mapped[str] = mapped_column(String(255), nullable=False)
    phone: Mapped[str | None] = mapped_column(String(30), nullable=True)
    message: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=text("NOW()"),
        index=True,
    )
    status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        server_default=text("'new'"),
        index=True,
    )

    def __repr__(self) -> str:
        return (
            f"<ContactSubmission id={self.id} email={self.email} "
            f"status={self.status}>"
        )
