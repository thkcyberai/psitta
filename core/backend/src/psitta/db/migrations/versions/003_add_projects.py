"""add projects table and project_id to documents

Revision ID: 003
Revises: 002
Create Date: 2026-03-06
"""
from __future__ import annotations
from alembic import op

revision = '003'
down_revision = '002'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("""
        CREATE TABLE IF NOT EXISTS projects (
            id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id     TEXT        NOT NULL,
            name        TEXT        NOT NULL,
            created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
            updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
        )
    """)
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_projects_user_id ON projects(user_id)"
    )
    op.execute("""
        ALTER TABLE documents
        ADD COLUMN IF NOT EXISTS project_id UUID
            REFERENCES projects(id) ON DELETE SET NULL
    """)
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_documents_project_id ON documents(project_id)"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_documents_project_id")
    op.execute("ALTER TABLE documents DROP COLUMN IF EXISTS project_id")
    op.execute("DROP INDEX IF EXISTS ix_projects_user_id")
    op.execute("DROP TABLE IF EXISTS projects")
