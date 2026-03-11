"""Add cover_type and cover_value columns to documents

Revision ID: 005
Revises: 004
Create Date: 2026-03-09
"""
from alembic import op
import sqlalchemy as sa

revision = '005'
down_revision = '004'
branch_labels = None
depends_on = None

def upgrade():
    op.add_column('documents',
        sa.Column('cover_type', sa.VARCHAR(20), nullable=True)
    )
    op.add_column('documents',
        sa.Column('cover_value', sa.VARCHAR(500), nullable=True)
    )

def downgrade():
    op.drop_column('documents', 'cover_type')
    op.drop_column('documents', 'cover_value')
