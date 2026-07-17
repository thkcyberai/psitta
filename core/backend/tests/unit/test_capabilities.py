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


def test_reading_nook_has_premium_reading_but_no_studio():
    caps = capabilities_for("reading_nook_pro")
    # Premium reading tier: voices, SWH, languages, edit — but no studio.
    assert CAP_READ_ALOUD in caps
    assert CAP_PREMIUM_VOICES in caps
    assert CAP_SWH in caps
    assert "languages" in caps
    assert "edit_document" in caps
    assert CAP_WRITING_DESK not in caps
    assert CAP_BLUEPRINTS not in caps
    assert "structure_analysis" not in caps
    assert "ai_summary" not in caps


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
    # pro_monthly / pro_annual are the stored Reading Nook shapes.
    assert capabilities_for("pro_monthly") == capabilities_for(
        "reading_nook_pro"
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
async def test_require_capability_reading_nook_denied_blueprints(monkeypatch):
    """Reading Nook is Pro but must NOT reach blueprints — proves we gate on
    capability, not on 'is this a paid plan'."""
    async def fake_resolve(db, user_id, email=None):
        return SimpleNamespace(plan_id="reading_nook_pro")

    monkeypatch.setattr(
        "psitta.dependencies.get_effective_plan", fake_resolve
    )
    dep = require_capability(CAP_BLUEPRINTS)
    with pytest.raises(HTTPException) as exc:
        await dep(
            claims=SimpleNamespace(email="a@b.com"), user_id=uuid4(), db=None
        )
    assert exc.value.status_code == 403
