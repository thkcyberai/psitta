"""Unit tests for the capability model + require_capability enforcement.

Guards the entitlement architecture: the plan→capability matrix is the single
source of truth, and require_capability fails CLOSED (denies) for any plan that
lacks the capability — server-authoritative, so a client leak can't bypass it.
"""

from __future__ import annotations

from types import SimpleNamespace
from uuid import uuid4

import pytest
from fastapi import HTTPException

from psitta.dependencies import require_capability
from psitta.services.capabilities import (
    CAP_BLUEPRINTS,
    CAP_PREMIUM_VOICES,
    CAP_READ_ALOUD,
    CAP_SWH,
    CAP_WRITING_DESK,
    capabilities_for,
    capability_response,
)

# ── Plan → capability matrix ────────────────────────────────────────────────

def test_free_has_only_read_aloud():
    caps = capabilities_for("free")
    assert caps == frozenset({CAP_READ_ALOUD})
    assert CAP_PREMIUM_VOICES not in caps
    assert CAP_SWH not in caps
    assert CAP_WRITING_DESK not in caps
    assert CAP_BLUEPRINTS not in caps


def test_reading_nook_grandfathers_to_writing_nook_capabilities():
    # A4 product consolidation: Reading Nook is discontinued and every
    # historical Reading entitlement is grandfathered UPWARD (DP-2) —
    # capabilities_for normalizes reading_nook_pro to writing_nook_pro,
    # so grandfathered customers receive the full studio.
    assert capabilities_for("reading_nook_pro") == capabilities_for(
        "writing_nook_pro"
    )
    caps = capabilities_for("reading_nook_pro")
    assert CAP_READ_ALOUD in caps
    assert CAP_PREMIUM_VOICES in caps
    assert CAP_SWH in caps
    assert CAP_WRITING_DESK in caps
    assert CAP_BLUEPRINTS in caps


def test_writing_nook_has_full_studio():
    caps = capabilities_for("writing_nook_pro")
    for cap in (
        CAP_READ_ALOUD, CAP_PREMIUM_VOICES, CAP_SWH, CAP_WRITING_DESK,
        CAP_BLUEPRINTS, "narrative", "structure_analysis", "ai_summary",
        "story_coach", "scribbles_whispers",
    ):
        assert cap in caps, cap


def test_creative_nook_is_superset_of_writing_nook():
    assert capabilities_for("creative_nook_pro") >= capabilities_for(
        "writing_nook_pro"
    )


def test_unknown_and_none_fail_closed_to_free():
    assert capabilities_for(None) == frozenset({CAP_READ_ALOUD})
    assert capabilities_for("") == frozenset({CAP_READ_ALOUD})
    assert capabilities_for("garbage_plan") == frozenset({CAP_READ_ALOUD})


def test_legacy_plan_ids_normalize():
    # pro_monthly / pro_annual are the stored Reading Nook shapes; A4
    # grandfathers both (and reading_nook_pro itself) onto Writing Nook.
    assert capabilities_for("pro_monthly") == capabilities_for(
        "writing_nook_pro"
    )
    assert capabilities_for("pro_annual") == capabilities_for(
        "writing_nook_pro"
    )
    # creativity_nook_pro (legacy Stripe prefix) → creative_nook_pro caps.
    assert capabilities_for("creativity_nook_pro") == capabilities_for(
        "creative_nook_pro"
    )


# ── capability_response payload ─────────────────────────────────────────────

def test_capability_response_shape():
    r = capability_response("writing_nook_pro")
    assert r["plan"] == "writing_nook_pro"
    assert CAP_BLUEPRINTS in r["capabilities"]
    assert r["capabilities"] == sorted(r["capabilities"])  # stable order
    assert r["limits"]["doc_cap"] == -1  # unlimited
    assert r["limits"]["max_playback_speed"] == 4.0


def test_capability_response_free_limits():
    r = capability_response("free")
    assert r["plan"] == "free"
    assert r["limits"]["doc_cap"] == 10
    assert r["limits"]["max_playback_speed"] == 2.0


# ── require_capability enforcement (server-authoritative) ────────────────────

@pytest.mark.asyncio
async def test_require_capability_allows_when_plan_grants_it(monkeypatch):
    async def fake_resolve(db, user_id, email=None):
        return SimpleNamespace(plan_id="writing_nook_pro")

    monkeypatch.setattr(
        "psitta.dependencies.get_effective_plan", fake_resolve
    )
    dep = require_capability(CAP_BLUEPRINTS)
    plan = await dep(
        claims=SimpleNamespace(email="a@b.com"), user_id=uuid4(), db=None
    )
    assert plan.plan_id == "writing_nook_pro"


@pytest.mark.asyncio
async def test_require_capability_denies_with_403_when_absent(monkeypatch):
    async def fake_resolve(db, user_id, email=None):
        return SimpleNamespace(plan_id="free")

    monkeypatch.setattr(
        "psitta.dependencies.get_effective_plan", fake_resolve
    )
    dep = require_capability(CAP_BLUEPRINTS)
    with pytest.raises(HTTPException) as exc:
        await dep(
            claims=SimpleNamespace(email=""), user_id=uuid4(), db=None
        )
    assert exc.value.status_code == 403
    assert exc.value.detail["error"] == "capability_required"
    assert exc.value.detail["capability"] == CAP_BLUEPRINTS
    assert exc.value.detail["plan"] == "free"


@pytest.mark.asyncio
async def test_require_capability_grandfathered_reading_reaches_blueprints(
    monkeypatch,
):
    """A4 consolidation: a grandfathered Reading Nook entitlement
    normalizes to Writing Nook, so the studio gates OPEN for it. (The
    gate-on-capability-not-on-paid-plan property is still proven by the
    free-plan denial test above.)"""
    async def fake_resolve(db, user_id, email=None):
        return SimpleNamespace(plan_id="reading_nook_pro")

    monkeypatch.setattr(
        "psitta.dependencies.get_effective_plan", fake_resolve
    )
    dep = require_capability(CAP_BLUEPRINTS)
    plan = await dep(
        claims=SimpleNamespace(email="a@b.com"), user_id=uuid4(), db=None
    )
    assert plan.plan_id == "reading_nook_pro"


# ── Server-gated Writing-Nook-only surfaces (leak closure) ───────────────────
# These four are enforced server-side with require_capability at the route /
# router level, so a client leak can't reach them:
#   scribbles_whispers -> notes router
#   ai_summary         -> POST /documents/{id}/summarize
#   story_coach        -> POST /projects/{id}/narrative/check
#   structure_analysis -> POST /projects/{id}/narrative/analyze
_WN_ONLY_GATED = [
    "scribbles_whispers",
    "ai_summary",
    "story_coach",
    "structure_analysis",
]


@pytest.mark.parametrize("capability", _WN_ONLY_GATED)
def test_wn_only_features_denied_to_free(capability):
    """Free must NOT hold these capabilities; Writing Nook and Creative
    Nook must — and (A4) grandfathered Reading Nook entitlements do too,
    because they normalize to Writing Nook. Guards the exact regression:
    if any of these leaked into Free's set, the server gate would wave
    the request through."""
    assert capability not in capabilities_for("free")
    assert capability in capabilities_for("writing_nook_pro")
    assert capability in capabilities_for("creative_nook_pro")
    # DP-2 grandfathering: reading-shaped ids receive the full studio.
    assert capability in capabilities_for("reading_nook_pro")
    assert capability in capabilities_for("pro_monthly")
