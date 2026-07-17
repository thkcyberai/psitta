"""services/capabilities.py — Capability model (entitlement architecture).

SINGLE SOURCE OF TRUTH for *what a plan can do*. Every feature gate — client
and server — must check a **capability**, never a plan id. Plans map to a set
of capability strings here; moving a feature between plans is a one-line data
change in ``PLAN_CAPABILITIES``, not code scattered across the app.

Resolution flow:
    get_effective_plan (subscription_service) resolves the user's canonical
    plan  →  capabilities_for(plan_id)  →  the set the client renders from
    (via GET /users/me/capabilities) and the server enforces (via
    dependencies.require_capability).

Design rules (charter): server-authoritative, single source of truth,
capability-based (never ``if plan == X``). Fails closed to Free on anything
unknown.
"""

from __future__ import annotations

from psitta.services.plan_limits import _normalize_plan_id, get_plan_limits

# ── Capability vocabulary (the strings the whole app gates on) ─────────────
CAP_READ_ALOUD = "read_aloud"                 # listen to documents (all tiers)
CAP_EDIT_DOCUMENT = "edit_document"           # edit text (Free = listen/read only)
CAP_PREMIUM_VOICES = "premium_voices"         # ElevenLabs voices (vs Edge standard)
CAP_SWH = "swh"                               # sync word highlight
CAP_LANGUAGES = "languages"                   # EN/PT/ES/FR working-language switch
CAP_WRITING_DESK = "writing_desk"             # full Writing Nook studio surface
CAP_BLUEPRINTS = "blueprints"                 # book-structure blueprints
CAP_NARRATIVE = "narrative"                   # narrative structures
CAP_STRUCTURE_ANALYSIS = "structure_analysis"  # structure analyzer
CAP_AI_SUMMARY = "ai_summary"                 # Summarize-it (LLM)
CAP_STORY_COACH = "story_coach"               # Story-Coach (LLM)
CAP_SCRIBBLES_WHISPERS = "scribbles_whispers"  # auxiliary writer tools

ALL_CAPABILITIES: frozenset[str] = frozenset({
    CAP_READ_ALOUD,
    CAP_EDIT_DOCUMENT,
    CAP_PREMIUM_VOICES,
    CAP_SWH,
    CAP_LANGUAGES,
    CAP_WRITING_DESK,
    CAP_BLUEPRINTS,
    CAP_NARRATIVE,
    CAP_STRUCTURE_ANALYSIS,
    CAP_AI_SUMMARY,
    CAP_STORY_COACH,
    CAP_SCRIBBLES_WHISPERS,
})

# ── Plan → capabilities. THE source of truth. Edit here to move a feature. ──
_FREE: frozenset[str] = frozenset({
    CAP_READ_ALOUD,  # listen only, standard voices
})

_READING_NOOK: frozenset[str] = _FREE | {
    CAP_EDIT_DOCUMENT,   # Player has read + write
    CAP_PREMIUM_VOICES,
    CAP_SWH,
    CAP_LANGUAGES,
}

_WRITING_NOOK: frozenset[str] = _READING_NOOK | {
    CAP_WRITING_DESK,
    CAP_BLUEPRINTS,
    CAP_NARRATIVE,
    CAP_STRUCTURE_ANALYSIS,
    CAP_AI_SUMMARY,
    CAP_STORY_COACH,
    CAP_SCRIBBLES_WHISPERS,
}

# Creative Nook = Writing Nook + (creative extras, added when they ship).
_CREATIVE_NOOK: frozenset[str] = _WRITING_NOOK

PLAN_CAPABILITIES: dict[str, frozenset[str]] = {
    "free": _FREE,
    "reading_nook_pro": _READING_NOOK,
    "writing_nook_pro": _WRITING_NOOK,
    "creative_nook_pro": _CREATIVE_NOOK,
}


def capabilities_for(plan_id: str | None) -> frozenset[str]:
    """Capability set for a plan id. Unknown/None → Free (fail closed).

    Accepts canonical plan ids from ``get_effective_plan`` and normalizes
    legacy ids (pro_monthly, creativity_nook_pro, …) defensively via
    plan_limits._normalize_plan_id so one caller can't diverge.
    """
    canonical = _normalize_plan_id(plan_id or "free")
    return PLAN_CAPABILITIES.get(canonical, _FREE)


def capability_response(plan_id: str | None) -> dict:
    """Build the GET /users/me/capabilities payload.

    Returns the capability list plus the numeric limits the client needs to
    render (document ceiling, playback-speed cap). Limits are pulled from
    plan_limits so quotas stay single-sourced there, capabilities here.
    """
    canonical = _normalize_plan_id(plan_id or "free")
    caps = PLAN_CAPABILITIES.get(canonical, _FREE)
    limits = get_plan_limits(canonical)
    return {
        "plan": canonical,
        "capabilities": sorted(caps),
        "limits": {
            "doc_cap": limits.documents_per_month,     # -1 = unlimited
            "max_playback_speed": limits.max_playback_speed,
        },
    }
