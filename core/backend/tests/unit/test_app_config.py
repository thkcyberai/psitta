"""Unit tests for the remote control-plane resolver (services/app_config).

Guards the reliability contract: the client control-plane config resolves DB
overrides over PERMISSIVE defaults, and every failure path (missing table
before migration 032, malformed row) returns those defaults — so a config
fault can never force an update or fire a kill switch that locks users out.
"""

from __future__ import annotations

from types import SimpleNamespace

import pytest

from psitta.services.app_config import DEFAULT_CLIENT_CONFIG, get_client_config


class _FakeResult:
    def __init__(self, row):
        self._row = row

    def first(self):
        return self._row


class _FakeNested:
    async def __aenter__(self):
        return self

    async def __aexit__(self, *_):
        return False


class _FakeDB:
    """Minimal async-session stand-in: supports begin_nested() + execute()."""

    def __init__(self, *, row=None, raise_on_execute=False):
        self._row = row
        self._raise = raise_on_execute

    def begin_nested(self):
        return _FakeNested()

    async def execute(self, *_a, **_k):
        if self._raise:
            raise RuntimeError('relation "app_config" does not exist')
        return _FakeResult(self._row)


@pytest.mark.asyncio
async def test_defaults_when_no_row():
    cfg = await get_client_config(_FakeDB(row=None))
    assert cfg["minimum_supported_version"] == "0.0.0"
    assert cfg["recommended_version"] == "0.0.0"
    assert cfg["flags"] == {}


@pytest.mark.asyncio
async def test_db_overrides_applied():
    row = SimpleNamespace(
        value={
            "minimum_supported_version": "1.1.0",
            "recommended_version": "1.2.0",
            "flags": {"reading_pipeline_v2": True, "legacy_player": False},
        }
    )
    cfg = await get_client_config(_FakeDB(row=row))
    assert cfg["minimum_supported_version"] == "1.1.0"
    assert cfg["recommended_version"] == "1.2.0"
    assert cfg["flags"] == {"reading_pipeline_v2": True, "legacy_player": False}


@pytest.mark.asyncio
async def test_partial_row_merges_over_defaults():
    # Only flags set → versions keep their safe defaults.
    row = SimpleNamespace(value={"flags": {"kill_switch": True}})
    cfg = await get_client_config(_FakeDB(row=row))
    assert cfg["minimum_supported_version"] == "0.0.0"
    assert cfg["recommended_version"] == "0.0.0"
    assert cfg["flags"] == {"kill_switch": True}


@pytest.mark.asyncio
async def test_malformed_fields_ignored():
    # Wrong types must be ignored, falling back to defaults (fail-safe).
    row = SimpleNamespace(
        value={"minimum_supported_version": 123, "flags": "not-a-dict"}
    )
    cfg = await get_client_config(_FakeDB(row=row))
    assert cfg["minimum_supported_version"] == "0.0.0"
    assert cfg["flags"] == {}


@pytest.mark.asyncio
async def test_failsafe_returns_defaults_on_db_error():
    # Missing table (code deployed before migration 032) must not raise.
    cfg = await get_client_config(_FakeDB(raise_on_execute=True))
    assert cfg == {
        "minimum_supported_version": "0.0.0",
        "recommended_version": "0.0.0",
        "flags": {},
    }


def test_defaults_are_permissive():
    # The defaults themselves must never force an update or kill a feature.
    assert DEFAULT_CLIENT_CONFIG["minimum_supported_version"] == "0.0.0"
    assert DEFAULT_CLIENT_CONFIG["flags"] == {}
