"""
Psitta — Role-Based Access Control (RBAC).

Defines tier-based permissions and limits for free, pro, and admin users.
Used by route handlers to enforce feature gates and usage quotas.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class TierLimits:
    """Usage limits for a subscription tier."""

    documents_per_month: int
    storage_mb: int
    max_document_pages: int
    tts_characters_per_month: int
    concurrent_sessions: int
    can_use_premium_voices: bool
    can_export_audio: bool
    can_manage_users: bool


# ── Tier Definitions ──────────────────────────────────────────────────

TIER_LIMITS: dict[str, TierLimits] = {
    "free": TierLimits(
        documents_per_month=10,
        storage_mb=500,
        max_document_pages=50,
        tts_characters_per_month=50_000,
        concurrent_sessions=1,
        can_use_premium_voices=False,
        can_export_audio=False,
        can_manage_users=False,
    ),
    "pro": TierLimits(
        documents_per_month=50,
        storage_mb=5_000,
        max_document_pages=500,
        tts_characters_per_month=500_000,
        concurrent_sessions=5,
        can_use_premium_voices=True,
        can_export_audio=True,
        can_manage_users=False,
    ),
    "admin": TierLimits(
        documents_per_month=999_999,
        storage_mb=50_000,
        max_document_pages=999,
        tts_characters_per_month=999_999_999,
        concurrent_sessions=99,
        can_use_premium_voices=True,
        can_export_audio=True,
        can_manage_users=True,
    ),
}


def get_tier_limits(tier: str) -> TierLimits:
    """Get limits for the given tier, defaulting to free."""
    return TIER_LIMITS.get(tier, TIER_LIMITS["free"])
