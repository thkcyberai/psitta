"""020 Stage 2 — backfill real emails + purge Auth0-era luisaao orphan.

Item 11.4 Stage 2 cleanup. Resolves two pieces of tech debt left over
from the Mar 23-24 Auth0 -> Cognito migration:

  1. Six users.email rows still hold synthetic <sub>@auth0.local
     placeholders, written by the auto-provisioning code path when the
     Cognito access token lacked an email claim (fixed in Stage 1 via
     the Pre-Token-Generation v2 Lambda).

  2. One pre-Cognito Auth0 row (auth0_user_id starts with
     ``google-oauth2|``) is unreachable post-migration: Cognito has no
     matching user, so the account can no longer be authenticated. Its
     43 documents are 5 days of dogfood test content (Mar 18-23,
     2026) — 39 already user-deleted, the remaining 4 are upload-retry
     duplicates of the same two test files. Zero meaningful content
     loss.

Five emails are backfilled from values returned by
``cognito-idp:AdminGetUser`` against each row's ``auth0_user_id``
(captured during the Stage 2 Phase 1 read-only diagnostic):

  google-oauth2|...    -> hard-deleted (no Cognito record)
  34c81458-...         -> luisaao@gmail.com
  d4686488-...         -> test1@facti.ai
  94b8f428-...         -> test2@facti.ai
  e478e4b8-...         -> test3@facti.ai
  14788448-...         -> luis@psitta.ai

All seven FK references to users.id are ``ON DELETE CASCADE``
(enumerated via information_schema in Phase 1), so a single DELETE
on the user row cleans up all owned records (documents,
playback_sessions, user_subscriptions, usage_counters, etc.).

This migration is one-way: ``downgrade()`` raises NotImplementedError
because the deleted Auth0 row + its dependent records cannot be
reconstructed.

Revision ID: 020
Revises: 019
Create Date: 2026-05-07
"""

from __future__ import annotations

from alembic import op
from sqlalchemy import text

# ── Revision identifiers ────────────────────────────────────────────────────
revision = "020"
down_revision = "019"
branch_labels = None
depends_on = None

# ── Constants ───────────────────────────────────────────────────────────────
ORPHAN_AUTH0_SUB = "google-oauth2|111631750180837297565"

BACKFILL_MAP: list[tuple[str, str]] = [
    # (auth0_user_id LIKE prefix, real email)
    ("34c81458-%", "luisaao@gmail.com"),
    ("d4686488-%", "test1@facti.ai"),
    ("94b8f428-%", "test2@facti.ai"),
    ("e478e4b8-%", "test3@facti.ai"),
    ("14788448-%", "luis@psitta.ai"),
]


def upgrade() -> None:
    bind = op.get_bind()

    # ── 0. Fresh / empty-DB guard ──────────────────────────────────────────
    # This migration backfills/purges specific production records captured in
    # the Stage 2 Phase 1 diagnostic (the Auth0-era orphan plus 5 synthetic
    # @auth0.local emails). A database that contains none of that target data,
    # such as fresh CI, a new environment, or a disaster-recovery rebuild, has
    # nothing to migrate. No-op gracefully so `alembic upgrade head` can run
    # from base. When ANY target data is present we fall through to the full
    # pre-flight assertions below, which still abort on partial/shifted state.
    targets_present = bind.execute(
        text(
            "SELECT COUNT(*) FROM users "
            "WHERE auth0_user_id = :sub "
            "   OR email LIKE '%@auth0.local'"
        ),
        {"sub": ORPHAN_AUTH0_SUB},
    ).scalar()
    if targets_present == 0:
        return

    # ── 1. Pre-flight assertions ───────────────────────────────────────────
    # Confirm orphan row exists with the expected auth0_user_id.
    orphan_count = bind.execute(
        text(
            "SELECT COUNT(*) FROM users WHERE auth0_user_id = :sub"
        ),
        {"sub": ORPHAN_AUTH0_SUB},
    ).scalar()
    if orphan_count != 1:
        raise RuntimeError(
            f"Pre-flight: expected exactly 1 user with auth0_user_id "
            f"'{ORPHAN_AUTH0_SUB}', found {orphan_count}. Aborting."
        )

    # Confirm orphan still has 43 documents (matches Phase 1 finding;
    # if mismatched, data shifted between diagnostic and apply -- abort
    # rather than silently destroy more or fewer rows than reviewed).
    orphan_doc_count = bind.execute(
        text(
            "SELECT COUNT(*) FROM documents WHERE user_id = "
            "(SELECT id FROM users WHERE auth0_user_id = :sub)"
        ),
        {"sub": ORPHAN_AUTH0_SUB},
    ).scalar()
    if orphan_doc_count != 43:
        raise RuntimeError(
            f"Pre-flight: expected 43 documents for orphan, found "
            f"{orphan_doc_count}. State changed since diagnostic. Aborting."
        )

    # Confirm all 5 backfill targets still have synthetic emails (idempotency
    # check -- if any were already backfilled out-of-band, abort to avoid
    # overwriting an unexpected real email).
    for prefix, _real_email in BACKFILL_MAP:
        synthetic_count = bind.execute(
            text(
                "SELECT COUNT(*) FROM users "
                "WHERE auth0_user_id LIKE :prefix "
                "  AND email LIKE '%@auth0.local'"
            ),
            {"prefix": prefix},
        ).scalar()
        if synthetic_count != 1:
            raise RuntimeError(
                f"Pre-flight: expected exactly 1 synthetic-email row for "
                f"auth0_user_id prefix '{prefix}', found {synthetic_count}. "
                f"Aborting."
            )

    # ── 2. Hard-delete the orphan ──────────────────────────────────────────
    # All 7 FKs to users.id are ON DELETE CASCADE (verified via
    # information_schema in Phase 1):
    #   documents, el_usage_counters, playback_sessions, stripe_customers,
    #   usage_counters, user_subscriptions, voice_profiles
    # Single DELETE handles the full dependency chain atomically.
    bind.execute(
        text("DELETE FROM users WHERE auth0_user_id = :sub"),
        {"sub": ORPHAN_AUTH0_SUB},
    )

    # ── 3. Backfill 5 real emails ──────────────────────────────────────────
    # Each UPDATE is guarded by the synthetic-email pattern so re-runs
    # against a partially-applied state become no-ops rather than
    # overwriting real values.
    for prefix, real_email in BACKFILL_MAP:
        bind.execute(
            text(
                "UPDATE users SET email = :email, updated_at = NOW() "
                "WHERE auth0_user_id LIKE :prefix "
                "  AND email LIKE '%@auth0.local'"
            ),
            {"email": real_email, "prefix": prefix},
        )

    # ── 4. Post-migration assertions ───────────────────────────────────────
    remaining_synthetic = bind.execute(
        text("SELECT COUNT(*) FROM users WHERE email LIKE '%@auth0.local'")
    ).scalar()
    if remaining_synthetic != 0:
        raise RuntimeError(
            f"Post-flight: {remaining_synthetic} rows still have "
            f"@auth0.local email. Aborting (transaction will roll back)."
        )

    remaining_orphan = bind.execute(
        text("SELECT COUNT(*) FROM users WHERE auth0_user_id = :sub"),
        {"sub": ORPHAN_AUTH0_SUB},
    ).scalar()
    if remaining_orphan != 0:
        raise RuntimeError(
            f"Post-flight: orphan row still present "
            f"({remaining_orphan} rows). Aborting."
        )

    expected_emails = {real for _prefix, real in BACKFILL_MAP}
    found = {
        row[0]
        for row in bind.execute(
            text(
                "SELECT email FROM users WHERE email = ANY(:emails)"
            ),
            {"emails": list(expected_emails)},
        ).fetchall()
    }
    missing = expected_emails - found
    if missing:
        raise RuntimeError(
            f"Post-flight: expected emails not present after backfill: "
            f"{sorted(missing)}. Aborting."
        )


def downgrade() -> None:
    raise NotImplementedError(
        "020 is one-way data destruction: the Auth0-era luisaao row and "
        "its 43 documents + 11 playback_sessions + 11 user_subscriptions + "
        "1 usage_counters dependents were hard-deleted via ON DELETE "
        "CASCADE. Reconstructing them is not possible from migration state. "
        "Restore from RDS point-in-time backup if a rollback is required."
    )
