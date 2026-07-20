# A4 Stripe Runbook — operator steps (Git Bash) · v4

All commands are for **Git Bash** on Windows. The cloud session cannot
reach api.stripe.com or AWS, so everything runs on your machine and
Claude reads the outputs from `core/backend/_a4_stripe/out/`.

**Key handling (v4):** interactive hidden prompts (`read -rsp`) proved
unreliable in Git Bash — pasted input can be silently dropped. The
scripts now read the key from a FILE you create with notepad: the key
never appears on screen, never enters shell history, and you delete
the file right after. On a bad key the scripts print a masked
diagnostic (first 8 chars + length only) so we can see what went wrong
without exposing anything. Make sure you use the **Secret key**
(`sk_test_…` / `sk_live_…`) from Stripe Dashboard → Developers → API
keys → Secret key → Reveal — NOT the publishable `pk_…` key.

## Gate 0 — one-time setup + backend unit suite  ✅ (passed 2026-07-20)

```bash
cd /c/products/psitta/core/backend
.venv/Scripts/python -m pip install -e ".[dev]"
.venv/Scripts/python -m pytest tests/unit -q --no-cov
```

`--no-cov`: the pyproject `--cov-fail-under=30` gate is calibrated for
the FULL suite in CI; a unit-only run measures partial coverage and
fails spuriously. Correctness locally, coverage in CI.

## Step 1 — READ-ONLY inventory, both modes (no changes made)

```bash
cd /c/products/psitta/core/backend

# TEST mode — notepad opens; paste the sk_test_ key, save, close:
notepad _a4_stripe/key.txt
.venv/Scripts/python _a4_stripe/stripe_audit.py --key-file _a4_stripe/key.txt

# LIVE mode — overwrite the same file with the sk_live_ key:
notepad _a4_stripe/key.txt
.venv/Scripts/python _a4_stripe/stripe_audit.py --key-file _a4_stripe/key.txt

# Delete the key file:
rm _a4_stripe/key.txt
```

Mode is detected from the key itself; outputs go to
`_a4_stripe/out/test/` and `_a4_stripe/out/live/` automatically.

## Step 2 — AWS discovery (read-only; finds the REAL resource names)

The first attempt failed because the guessed names (`psitta-api`,
`psitta/prod/app-secrets`) don't exist under your CLI's account/region.
Discover what actually exists:

```bash
mkdir -p _a4_stripe/out
aws sts get-caller-identity                                   > _a4_stripe/out/aws_identity.json
aws ecs list-clusters --region us-east-1                      > _a4_stripe/out/aws_clusters.json
aws ecs list-task-definition-families --status ACTIVE --region us-east-1 \
                                                              > _a4_stripe/out/aws_taskdef_families.json
aws secretsmanager list-secrets --region us-east-1 \
  --query "SecretList[].Name"                                 > _a4_stripe/out/aws_secret_names.json
```

(All read-only; the identity file contains your account id — no
credentials. Claude reads these, identifies the real task definition
and secret, and gives you the exact follow-up commands for the
environment check.)

→ STOP HERE. Tell Claude when Steps 1–2 are done.

## Step 3 — migration (ONLY after Claude presents the plan and you approve)

```bash
notepad _a4_stripe/key.txt        # sk_test_ key first
.venv/Scripts/python _a4_stripe/stripe_migrate.py --key-file _a4_stripe/key.txt            # dry run
.venv/Scripts/python _a4_stripe/stripe_migrate.py --key-file _a4_stripe/key.txt --apply    # execute

notepad _a4_stripe/key.txt        # then the sk_live_ key
.venv/Scripts/python _a4_stripe/stripe_migrate.py --key-file _a4_stripe/key.txt            # dry run
.venv/Scripts/python _a4_stripe/stripe_migrate.py --key-file _a4_stripe/key.txt --apply    # execute

rm _a4_stripe/key.txt
```

Then re-run Step 1 (both modes) so Claude can diff before/after.

## Rollback (any time)

The canonical rollback source is the TRACKED, sanitized record committed
to the repo (object IDs + default-price pointers only — no PII):

```bash
notepad _a4_stripe/key.txt        # sk_live_ key (record is live-mode; mode mismatch is refused)
.venv/Scripts/python _a4_stripe/stripe_rollback.py --key-file _a4_stripe/key.txt \
  --record _a4_stripe/rollback_records/live_catalog_migration_2026-07-20.json
rm _a4_stripe/key.txt
```

Without `--record`, the script falls back to the git-ignored runtime log
(`out/<mode>/migration_log.json`). Either source performs the complete
restore: re-activate products → re-activate prices → restore
default_price pointers. Archiving was the only mutation, so this is a
full catalog restoration.

## What the migration does and deliberately does NOT do

- Archives (active=false) Reading Nook AND Creative Nook products and
  prices. Writing Nook untouched (script hard-refuses otherwise, and
  aborts if no active Writing price exists).
- Deletes nothing. Touches no subscription, customer, or invoice.
- Existing Reading subscribers keep billing on their archived price
  (Stripe guarantee); their Writing Nook entitlement comes from the
  backend grandfathering aliases deployed with A4.
