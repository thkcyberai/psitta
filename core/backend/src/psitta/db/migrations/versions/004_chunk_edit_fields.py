"""Add is_edited and edited_at columns to document_chunks

Revision ID: 004
Revises: 003
Create Date: 2026-03-08
"""
from alembic import op
import sqlalchemy as sa

revision = '004'
down_revision = '003'
branch_labels = None
depends_on = None

def upgrade():
    op.add_column('document_chunks',
        sa.Column('is_edited', sa.Boolean(), nullable=False, server_default='false')
    )
    op.add_column('document_chunks',
        sa.Column('edited_at', sa.DateTime(timezone=True), nullable=True)
    )
    op.add_column('document_chunks',
        sa.Column('original_text', sa.Text(), nullable=True)
    )

def downgrade():
    op.drop_column('document_chunks', 'is_edited')
    op.drop_column('document_chunks', 'edited_at')
    op.drop_column('document_chunks', 'original_text')
