"""SQLAlchemy ORM models for Stripe billing (M3).

Maps the three tables created in migration 012:

  - ``StripeCustomer``       — one-to-one with ``users``
  - ``Subscription``         — Stripe subscription lifecycle
  - ``SubscriptionEvent``    — raw webhook payloads (forensic trail)

Relationships:
  User (raw table) → StripeCustomer (one-to-one via user_id)
  StripeCustomer → Subscription (one-to-many via stripe_customer_id FK)

These models coexist with the existing raw-SQL query pattern. Services
can use either ORM queries or ``text()`` — both use the same
``AsyncSession`` from ``db.session``.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from psitta.db.base import Base


class StripeCustomer(Base):
    """Links a Psitta user to their Stripe customer ID (one-to-one)."""

    __tablename__ = "stripe_customers"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )
    stripe_customer_id: Mapped[str] = mapped_column(
        String(255), nullable=False, unique=True, index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("NOW()")
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("NOW()")
    )

    # Relationships
    subscriptions: Mapped[list[Subscription]] = relationship(
        back_populates="customer", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return (
            f"<StripeCustomer user_id={self.user_id} "
            f"stripe={self.stripe_customer_id}>"
        )


class Subscription(Base):
    """Stripe subscription lifecycle state."""

    __tablename__ = "subscriptions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    stripe_customer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("stripe_customers.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    stripe_subscription_id: Mapped[str] = mapped_column(
        String(255), nullable=False, unique=True, index=True
    )
    stripe_product_id: Mapped[str] = mapped_column(String(255), nullable=False)
    stripe_price_id: Mapped[str] = mapped_column(String(255), nullable=False)
    lookup_key: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    status: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    current_period_start: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    current_period_end: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    cancel_at_period_end: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    canceled_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("NOW()")
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("NOW()")
    )

    # Relationships
    customer: Mapped[StripeCustomer] = relationship(back_populates="subscriptions")

    def __repr__(self) -> str:
        return (
            f"<Subscription stripe_sub={self.stripe_subscription_id} "
            f"status={self.status} key={self.lookup_key}>"
        )


class SubscriptionEvent(Base):
    """Raw Stripe webhook event — append-only forensic trail.

    The ``stripe_event_id`` column is the idempotency key: webhook
    handlers check for its existence before processing to prevent
    duplicate side effects from Stripe retries.
    """

    __tablename__ = "subscription_events"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    stripe_event_id: Mapped[str] = mapped_column(
        String(255), nullable=False, unique=True, index=True
    )
    event_type: Mapped[str] = mapped_column(
        String(100), nullable=False, index=True
    )
    stripe_subscription_id: Mapped[str | None] = mapped_column(
        String(255), nullable=True, index=True
    )
    payload: Mapped[dict] = mapped_column(JSONB, nullable=False)
    processed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("NOW()")
    )

    def __repr__(self) -> str:
        return (
            f"<SubscriptionEvent type={self.event_type} "
            f"stripe_id={self.stripe_event_id}>"
        )
