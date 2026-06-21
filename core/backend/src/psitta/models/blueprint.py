"""SQLAlchemy ORM models for the Blueprint feature (migration 021).

Maps the four additive tables created in migration 021:

  - ``Blueprint``         — reusable book architecture; system templates AND
                            user-owned blueprints
  - ``BlueprintPart``     — named, ordered, nesting slots inside a blueprint
  - ``ProjectBlueprint``  — a project's adoption of a blueprint (primary flag)
  - ``PartDocument``      — a document placed in a part, with a controlled role

These models coexist with the existing raw-SQL pattern (``users`` /
``documents`` / ``projects`` remain raw, FK-referenced only) and with the
billing ORM models — all on the same ``Base`` and the same ``AsyncSession``
from ``db.session`` (mirrors ``models/billing.py``).

The authoritative DDL lives in hand-written migration 021, like every Psitta
migration. These models are intentionally NOT wired into Alembic
``target_metadata`` — autogenerate stays disabled because most core tables
(``users``/``documents``/``projects``) have no ORM mapping and autogenerate
would propose dropping them.

Design notes:
  - Controlled lists (genre, status, role) are enforced with TEXT + CHECK so
    the lists can evolve without ``ALTER TYPE`` gymnastics.
  - ``sort_order`` is NUMERIC so a drag-reorder is always a single-row write
    via the midpoint of its neighbours (arbitrary precision never exhausts).
  - Progress / completion / readiness / has-content are computed on read and
    NEVER stored.
  - Same-blueprint nesting is guaranteed at the DB level by the composite FK
    ``(parent_part_id, blueprint_id) -> (id, blueprint_id)``. The ORM
    parent/children self-relationship is intentionally omitted (the shared
    ``blueprint_id`` column participates in two FKs); the part tree is walked
    with a recursive CTE / explicit queries in the service layer.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    ForeignKeyConstraint,
    Index,
    Numeric,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from psitta.db.base import Base


class Blueprint(Base):
    """A reusable book architecture — a system template or a user blueprint.

    ``user_id IS NULL`` ⇔ system template (read-only, owned by Psitta).
    ``user_id IS NOT NULL`` ⇔ user-owned, editable blueprint. The
    owner-coherence CHECK keeps the two kinds mutually exclusive.
    """

    __tablename__ = "blueprints"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    # NULL ⇔ system template; NOT NULL ⇔ user blueprint. Cross-boundary ref to
    # the unmapped ``users`` table: plain UUID column here; the DB-level FK
    # (ON DELETE CASCADE) is owned by migration 021.
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        nullable=True,
    )
    is_system: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    name: Mapped[str] = mapped_column(Text, nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    genre: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[str] = mapped_column(
        Text, nullable=False, server_default=text("'Draft'")
    )
    # Clone lineage for analytics only — no live coupling; SET NULL if the
    # source template is ever deleted so the independent clone survives.
    source_template_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("blueprints.id", ondelete="SET NULL"),
        nullable=True,
    )
    # Narrative origin — set when the blueprint was generated from the Narrative
    # Structure catalog (NULL for hand-built blueprints). Added in migration 028.
    narrative_structure_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    narrative_variant: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("now()")
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("now()")
    )

    parts: Mapped[list["BlueprintPart"]] = relationship(
        back_populates="blueprint",
        foreign_keys="BlueprintPart.blueprint_id",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )

    __table_args__ = (
        CheckConstraint(
            "genre IN ('Novel', 'Memoir', 'Non-Fiction', 'Biography', "
            "'Research Paper', 'Children''s Picture Book', 'Screenplay', "
            "'Workbook/How-To', 'Business Book', 'Short Story Collection')",
            name="ck_blueprints_genre",
        ),
        CheckConstraint(
            "status IN ('Draft', 'Completed', 'Archived')",
            name="ck_blueprints_status",
        ),
        CheckConstraint(
            "(is_system AND user_id IS NULL) "
            "OR (NOT is_system AND user_id IS NOT NULL)",
            name="ck_blueprints_owner_coherence",
        ),
        Index(
            "ix_blueprints_user_id",
            "user_id",
            postgresql_where=text("user_id IS NOT NULL"),
        ),
        Index(
            "ix_blueprints_is_system",
            "is_system",
            postgresql_where=text("is_system"),
        ),
        Index("ix_blueprints_source_template_id", "source_template_id"),
        Index(
            "ix_blueprints_user_status",
            "user_id",
            "status",
            postgresql_where=text("user_id IS NOT NULL"),
        ),
    )

    def __repr__(self) -> str:
        kind = "system" if self.is_system else "user"
        return f"<Blueprint {kind} name={self.name!r} genre={self.genre!r}>"


class BlueprintPart(Base):
    """An ordered, nestable slot inside a blueprint (Prologue, Act I, Chapter 3).

    Nesting is via ``parent_part_id``; the composite FK
    ``(parent_part_id, blueprint_id) -> (id, blueprint_id)`` guarantees a
    parent always belongs to the SAME blueprint. ``sort_order`` orders siblings.
    """

    __tablename__ = "blueprint_parts"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    blueprint_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("blueprints.id", ondelete="CASCADE"),
        nullable=False,
    )
    # NULL ⇔ root part. Same-blueprint integrity enforced by the composite FK
    # declared in __table_args__ (not an inline per-column FK).
    parent_part_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    name: Mapped[str] = mapped_column(Text, nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    sort_order: Mapped[Decimal] = mapped_column(Numeric, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("now()")
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("now()")
    )

    blueprint: Mapped["Blueprint"] = relationship(
        back_populates="parts",
        foreign_keys=[blueprint_id],
    )
    documents: Mapped[list["PartDocument"]] = relationship(
        back_populates="part",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )

    __table_args__ = (
        UniqueConstraint(
            "id", "blueprint_id", name="uq_blueprint_parts_id_blueprint"
        ),
        ForeignKeyConstraint(
            ["parent_part_id", "blueprint_id"],
            ["blueprint_parts.id", "blueprint_parts.blueprint_id"],
            ondelete="CASCADE",
            name="fk_blueprint_parts_parent",
        ),
        Index("ix_blueprint_parts_blueprint_id", "blueprint_id"),
        Index("ix_blueprint_parts_parent_part_id", "parent_part_id"),
        Index(
            "ix_blueprint_parts_tree",
            "blueprint_id",
            "parent_part_id",
            "sort_order",
        ),
    )

    def __repr__(self) -> str:
        return f"<BlueprintPart name={self.name!r} blueprint_id={self.blueprint_id}>"


class ProjectBlueprint(Base):
    """A project's adoption of a blueprint. Idempotent; at most one primary."""

    __tablename__ = "project_blueprints"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    # Cross-boundary ref to the unmapped ``projects`` table: plain UUID column
    # here; the DB-level FK (ON DELETE CASCADE) is owned by migration 021.
    project_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        nullable=False,
    )
    blueprint_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("blueprints.id", ondelete="CASCADE"),
        nullable=False,
    )
    is_primary: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("now()")
    )

    __table_args__ = (
        UniqueConstraint(
            "project_id",
            "blueprint_id",
            name="uq_project_blueprints_project_blueprint",
        ),
        # At most one primary blueprint per project.
        Index(
            "uq_project_blueprints_one_primary",
            "project_id",
            unique=True,
            postgresql_where=text("is_primary"),
        ),
        Index("ix_project_blueprints_blueprint_id", "blueprint_id"),
    )

    def __repr__(self) -> str:
        return (
            f"<ProjectBlueprint project_id={self.project_id} "
            f"blueprint_id={self.blueprint_id} primary={self.is_primary}>"
        )


class PartDocument(Base):
    """A document placed into a blueprint part, with a controlled role.

    A document is in AT MOST ONE part (UNIQUE on ``document_id``). The document
    itself is never duplicated or moved — only referenced here.
    """

    __tablename__ = "part_documents"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    part_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("blueprint_parts.id", ondelete="CASCADE"),
        nullable=False,
    )
    # Cross-boundary ref to the unmapped ``documents`` table: plain UUID column
    # here; the DB-level FK (ON DELETE CASCADE) is owned by migration 021.
    document_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        nullable=False,
        unique=True,
    )
    role: Mapped[str] = mapped_column(
        Text, nullable=False, server_default=text("'Main Content'")
    )
    sort_order: Mapped[Decimal] = mapped_column(Numeric, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("now()")
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("now()")
    )

    part: Mapped["BlueprintPart"] = relationship(back_populates="documents")

    __table_args__ = (
        CheckConstraint(
            "role IN ('Main Content', 'Supporting Content', 'Research', "
            "'Notes', 'Reference Material')",
            name="ck_part_documents_role",
        ),
        Index("ix_part_documents_part_id", "part_id"),
        Index("ix_part_documents_part_order", "part_id", "sort_order"),
    )

    def __repr__(self) -> str:
        return (
            f"<PartDocument part_id={self.part_id} "
            f"document_id={self.document_id} role={self.role!r}>"
        )
