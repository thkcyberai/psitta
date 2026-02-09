"""
Psitta — API v1 Router.

Central router that mounts all v1 sub-routers. Each domain module
(documents, playback, voices, users) registers its own routes with
appropriate prefixes and tags for OpenAPI documentation.

Security: All routes except health checks require authentication
          (enforced per-router via dependencies).
"""

from __future__ import annotations

from fastapi import APIRouter

from psitta.api.v1.documents import router as documents_router
from psitta.api.v1.playback import router as playback_router
from psitta.api.v1.voices import router as voices_router
from psitta.api.v1.users import router as users_router

v1_router = APIRouter()

# ── Document Management ────────────────────────────────────────────────
# Upload, status, list, delete documents
v1_router.include_router(
    documents_router,
    prefix="/documents",
    tags=["documents"],
)

# ── Playback ───────────────────────────────────────────────────────────
# Stream audio, manage sessions, update position
v1_router.include_router(
    playback_router,
    prefix="/playback",
    tags=["playback"],
)

# ── Voice Catalog ──────────────────────────────────────────────────────
# List voices, preview, manage voice profiles
v1_router.include_router(
    voices_router,
    prefix="/voices",
    tags=["voices"],
)

# ── User Management ────────────────────────────────────────────────────
# Profile, preferences, tier information
v1_router.include_router(
    users_router,
    prefix="/users",
    tags=["users"],
)
