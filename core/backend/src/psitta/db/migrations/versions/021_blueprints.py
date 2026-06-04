"""021 — Blueprint feature: blueprints, blueprint_parts, project_blueprints, part_documents.

Additive only. Creates the four Blueprint tables that let users organize
documents into reusable book architectures. Mirrors the ORM models in
``psitta.models.blueprint``.

ZERO changes to ``documents`` and ``projects``: this migration neither ALTERs
nor DROPs either table. The foreign keys that point at them
(``part_documents.document_id`` → ``documents(id)`` and
``project_blueprints.project_id`` → ``projects(id)``) are declared on the NEW
child tables; the referenced parent tables are not modified.

upgrade()   creates the four tables parent → child.
downgrade() drops them child → parent (indexes/constraints drop with the
            tables), leaving the database byte-for-byte as before 021.

Revision ID: 021
Revises: 020
Create Date: 2026-06-03
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# Revision identifiers
revision: str = "021"
down_revision: str | None = "020"
branch_labels: str | None = None
depends_on: str | None = None


def upgrade() -> None:
    """Create the four Blueprint tables (parent → child)."""

    # ── blueprints ──────────────────────────────────────────────────────
    op.create_table(
        "blueprints",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        # NULL ⇔ system template; NOT NULL ⇔ user blueprint.
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=True,
        ),
        sa.Column(
            "is_system", sa.Boolean(), nullable=False, server_default=sa.text("false")
        ),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("genre", sa.Text(), nullable=False),
        sa.Column(
            "status", sa.Text(), nullable=False, server_default=sa.text("'Draft'")
        ),
        # Clone lineage only (analytics); SET NULL if the source template goes.
        sa.Column(
            "source_template_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("blueprints.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.CheckConstraint(
            "genre IN ('Novel', 'Memoir', 'Non-Fiction', 'Biography', "
            "'Research Paper', 'Children''s Picture Book', 'Screenplay', "
            "'Workbook/How-To', 'Business Book', 'Short Story Collection')",
            name="ck_blueprints_genre",
        ),
        sa.CheckConstraint(
            "status IN ('Draft', 'Completed', 'Archived')",
            name="ck_blueprints_status",
        ),
        sa.CheckConstraint(
            "(is_system AND user_id IS NULL) "
            "OR (NOT is_system AND user_id IS NOT NULL)",
            name="ck_blueprints_owner_coherence",
        ),
    )
    op.create_index(
        "ix_blueprints_user_id",
        "blueprints",
        ["user_id"],
        postgresql_where=sa.text("user_id IS NOT NULL"),
    )
    op.create_index(
        "ix_blueprints_is_system",
        "blueprints",
        ["is_system"],
        postgresql_where=sa.text("is_system"),
    )
    op.create_index(
        "ix_blueprints_source_template_id", "blueprints", ["source_template_id"]
    )
    op.create_index(
        "ix_blueprints_user_status",
        "blueprints",
        ["user_id", "status"],
        postgresql_where=sa.text("user_id IS NOT NULL"),
    )

    # ── blueprint_parts ─────────────────────────────────────────────────
    op.create_table(
        "blueprint_parts",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "blueprint_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("blueprints.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("parent_part_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("sort_order", sa.Numeric(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        # Required so the composite self-FK below can reference (id, blueprint_id).
        sa.UniqueConstraint(
            "id", "blueprint_id", name="uq_blueprint_parts_id_blueprint"
        ),
        # Guarantees a part's parent lives in the SAME blueprint; cascades the
        # subtree on parent delete.
        sa.ForeignKeyConstraint(
            ["parent_part_id", "blueprint_id"],
            ["blueprint_parts.id", "blueprint_parts.blueprint_id"],
            ondelete="CASCADE",
            name="fk_blueprint_parts_parent",
        ),
    )
    op.create_index(
        "ix_blueprint_parts_blueprint_id", "blueprint_parts", ["blueprint_id"]
    )
    op.create_index(
        "ix_blueprint_parts_parent_part_id", "blueprint_parts", ["parent_part_id"]
    )
    op.create_index(
        "ix_blueprint_parts_tree",
        "blueprint_parts",
        ["blueprint_id", "parent_part_id", "sort_order"],
    )

    # ── project_blueprints ──────────────────────────────────────────────
    op.create_table(
        "project_blueprints",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "project_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("projects.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "blueprint_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("blueprints.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "is_primary", sa.Boolean(), nullable=False, server_default=sa.text("false")
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        # Idempotent adoption: a project adopts a given blueprint at most once.
        sa.UniqueConstraint(
            "project_id",
            "blueprint_id",
            name="uq_project_blueprints_project_blueprint",
        ),
    )
    # At most one primary blueprint per project.
    op.create_index(
        "uq_project_blueprints_one_primary",
        "project_blueprints",
        ["project_id"],
        unique=True,
        postgresql_where=sa.text("is_primary"),
    )
    op.create_index(
        "ix_project_blueprints_blueprint_id", "project_blueprints", ["blueprint_id"]
    )

    # ── part_documents ──────────────────────────────────────────────────
    op.create_table(
        "part_documents",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "part_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("blueprint_parts.id", ondelete="CASCADE"),
            nullable=False,
        ),
        # UNIQUE ⇒ a document is in at most one part. CASCADE so deleting a
        # document removes only this placement row (the document is never
        # touched by this table otherwise).
        sa.Column(
            "document_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("documents.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "role", sa.Text(), nullable=False, server_default=sa.text("'Main Content'")
        ),
        sa.Column("sort_order", sa.Numeric(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.UniqueConstraint("document_id", name="uq_part_documents_document"),
        sa.CheckConstraint(
            "role IN ('Main Content', 'Supporting Content', 'Research', "
            "'Notes', 'Reference Material')",
            name="ck_part_documents_role",
        ),
    )
    op.create_index("ix_part_documents_part_id", "part_documents", ["part_id"])
    op.create_index(
        "ix_part_documents_part_order", "part_documents", ["part_id", "sort_order"]
    )


def downgrade() -> None:
    """Drop the four Blueprint tables (child → parent).

    Each ``drop_table`` removes that table's own indexes, constraints, and the
    foreign keys declared on it, so explicit index drops are unnecessary. Order
    is child → parent so no FK ever dangles mid-downgrade.
    """
    op.drop_table("part_documents")
    op.drop_table("project_blueprints")
    op.drop_table("blueprint_parts")
    op.drop_table("blueprints")
