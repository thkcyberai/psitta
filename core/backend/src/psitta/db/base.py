"""SQLAlchemy declarative base for ORM models.

All ORM model classes inherit from ``Base``. The ``metadata`` object is
available for Alembic autogenerate (wire via ``target_metadata`` in
``migrations/env.py`` when ready to switch from hand-written migrations).

Note: the existing codebase uses raw ``text()`` queries and hand-written
Alembic migrations. ORM models are introduced here for the Stripe billing
layer (M3) and will coexist with the raw-SQL pattern until a full migration.
"""

from __future__ import annotations

from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    """Base class for all ORM-mapped models."""

    pass
