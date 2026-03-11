"""Add cover_document_id to projects table

Revision ID: 006
Revises: 005
Create Date: 2026-03-09
"""
from alembic import op
import sqlalchemy as sa

revision = '006'
down_revision = '005'
branch_labels = None
depends_on = None

def upgrade():
    op.add_column('projects',
        sa.Column('cover_document_id', sa.dialects.postgresql.UUID(), nullable=True)
    )
    op.create_foreign_key(
        'fk_projects_cover_document_id',
        'projects', 'documents',
        ['cover_document_id'], ['id'],
        ondelete='SET NULL',
    )

def downgrade():
    op.drop_constraint('fk_projects_cover_document_id', 'projects', type_='foreignkey')
    op.drop_column('projects', 'cover_document_id')
