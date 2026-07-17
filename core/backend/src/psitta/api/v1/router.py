"""
Psitta — API v1 Router.

Central router that mounts all v1 sub-routers. Each domain module
(documents, playback, voices, users) registers its own routes with
appropriate prefixes and tags for OpenAPI documentation.

Security: All routes except health checks require authentication
          (enforced per-router via dependencies).
"""

from __future__ import annotations

from fastapi import APIRouter, Depends

from psitta.api.v1.auth import router as auth_router
from psitta.api.v1.billing import router as billing_router
from psitta.api.v1.blueprints import placement_router
from psitta.api.v1.blueprints import router as blueprints_router
from psitta.api.v1.contact import router as contact_router
from psitta.api.v1.documents import router as documents_router
from psitta.api.v1.notes import router as notes_router
from psitta.api.v1.playback import router as playback_router
from psitta.api.v1.project_blueprints import router as project_blueprints_router
from psitta.api.v1.projects import router as projects_router
from psitta.api.v1.signup import router as signup_router
from psitta.api.v1.subscriptions import router as subscriptions_router
from psitta.api.v1.tts import router as tts_router
from psitta.api.v1.users import router as users_router
from psitta.api.v1.voices import router as voices_router
from psitta.api.v1.waitlist import router as waitlist_router
from psitta.dependencies import require_capability

v1_router = APIRouter()

# ── Authentication ────────────────────────────────────────────────────
v1_router.include_router(
    auth_router,
    prefix="/auth",
    tags=["auth"],
)

# ── Document Management ────────────────────────────────────────────────
v1_router.include_router(
    documents_router,
    prefix="/documents",
    tags=["documents"],
)

# ── Playback ───────────────────────────────────────────────────────────
v1_router.include_router(
    playback_router,
    prefix="/playback",
    tags=["playback"],
)

# ── Voice Catalog ──────────────────────────────────────────────────────
v1_router.include_router(
    voices_router,
    prefix="/voices",
    tags=["voices"],
)

# ── User Management ────────────────────────────────────────────────────
v1_router.include_router(
    users_router,
    prefix="/users",
    tags=["users"],
)

# ── Scribbles (notes) — Writing Nook auxiliary tool, server-enforced ──
# Scribbles are a Writing Nook feature; Free and Reading Nook have no
# auxiliary writer tools. Enforcing the capability at the router closes the
# leak for EVERY client (old field builds included) whose UI still exposes
# the Scribbles panel — the server refuses regardless of what the client shows.
v1_router.include_router(
    notes_router,
    prefix="/notes",
    tags=["notes"],
    dependencies=[Depends(require_capability("scribbles_whispers"))],
)

# ── Projects ──────────────────────────────────────────────────────────
v1_router.include_router(
    projects_router,
)

# ── Blueprints (Writing Nook studio — server-enforced capability) ─────
# Book structures are a Writing Nook feature end to end. Enforcing the
# capability at the router closes the leak for EVERY client, including old
# field builds whose UI still exposes the button — the server refuses.
v1_router.include_router(
    blueprints_router,
    dependencies=[Depends(require_capability("blueprints"))],
)

# ── Project ↔ Blueprint adoption (Writing Nook only) ──────────────────
v1_router.include_router(
    project_blueprints_router,
    dependencies=[Depends(require_capability("blueprints"))],
)

# ── Document placement (Blueprint feature — Writing Nook only) ─────────
v1_router.include_router(
    placement_router,
    dependencies=[Depends(require_capability("blueprints"))],
)

# ── Subscriptions ─────────────────────────────────────────────────────
v1_router.include_router(
    subscriptions_router,
)

# ── Billing (Stripe) ─────────────────────────────────────────────────
v1_router.include_router(
    billing_router,
    prefix="/billing",
    tags=["billing"],
)

# ── TTS Diagnostics ────────────────────────────────────────────────────
v1_router.include_router(
    tts_router,
    prefix="/tts",
    tags=["tts"],
)

# ── Contact form (public) ─────────────────────────────────────────────
v1_router.include_router(
    contact_router,
    tags=["contact"],
)

# ── Signup list (public) ──────────────────────────────────────────────
v1_router.include_router(
    signup_router,
    tags=["signup"],
)

# ── Waitlist (public) ─────────────────────────────────────────────────
v1_router.include_router(
    waitlist_router,
    tags=["waitlist"],
)
