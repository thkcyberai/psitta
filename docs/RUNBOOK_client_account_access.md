# Runbook — Accessing & Administering Client Accounts (Production)

**Audience:** Psitta operators (currently: the founder).
**Scope:** How to safely inspect a client's account, see and change their plan/entitlement, run one-off admin tasks, and apply migrations against the **production** database.
**Last updated:** 2026-07-16.

> **What "access a client account" means here.** Psitta has **no account impersonation / no "log in as user"**. Operator access means: (1) *inspect* a user's resolved tier and entitlement state, and (2) *adjust* their entitlement through the admin tools below (tester allowlist, etc.). You never see a user's password, and you never log in as them.

---

## 0. Golden safety rules (read every time)

1. **Confirm the account first.** Every command runs with `--profile psitta-prod --region us-east-1`. Before anything, verify you're on the right AWS account:
   ```bash
   aws sts get-caller-identity --profile psitta-prod --region us-east-1 --query Account --output text
   ```
   It **must** print `808765744063`. If it prints anything else, **stop**.
2. **List first. Dry-run second. Apply only after you've read the dry-run.** Every write tool below has a `--dry-run`. Use it.
3. **Read-only until you mean to write.** `list_accounts.py` and any `show` subcommand only issue `SELECT`s — safe to run anytime.
4. **Never touch Stripe, `user_subscriptions` (dev override), or billing tables by hand.** Entitlement changes go through the sanctioned tools (tester allowlist / control-plane), never raw SQL against billing.
5. **Never print or paste secrets.** Don't echo `APP_SECRETS`, DB passwords, or API keys.
6. **One change at a time**, and verify each before the next.

---

## 1. The core mechanism: ECS one-off tasks

Production Postgres is private (no public access). The only sanctioned way to run admin code or SQL against it is a **one-off ECS Fargate task** that runs the app image with an overridden command. ECS Exec is **not** available (SSM egress gap), so always use `run-task`.

**Fixed infrastructure values** (don't change these):

| Thing | Value |
|---|---|
| Cluster | `psitta-cluster` |
| Task definition | `psitta-api` (`:latest` image, pulled automatically) |
| Subnets | `subnet-0a143e23d5e240aa9`, `subnet-0653bdf3529d8bbe8` |
| Security group | `sg-002cf129761af804f` |
| Public IP | `DISABLED` |
| Log group | `/ecs/psitta-api` (stream `ecs/psitta-api/<task-id>`) |
| AWS account | `808765744063` |

### 1.1 The reusable pattern

Every admin action is the same three-part block — only the `command` array changes. Fire the task, wait for it to stop, then read its stdout from CloudWatch:

```bash
TASK_ARN=$(aws ecs run-task \
  --cluster psitta-cluster --task-definition psitta-api --launch-type FARGATE \
  --network-configuration 'awsvpcConfiguration={subnets=[subnet-0a143e23d5e240aa9,subnet-0653bdf3529d8bbe8],securityGroups=[sg-002cf129761af804f],assignPublicIp=DISABLED}' \
  --overrides '{"containerOverrides":[{"name":"psitta-api","command":[ <COMMAND-ARRAY> ]}]}' \
  --profile psitta-prod --region us-east-1 --query 'tasks[0].taskArn' --output text)
echo "task: $TASK_ARN"; TASK_ID=${TASK_ARN##*/}
aws ecs wait tasks-stopped --cluster psitta-cluster --tasks "$TASK_ARN" --profile psitta-prod --region us-east-1
MSYS_NO_PATHCONV=1 aws logs get-log-events --log-group-name /ecs/psitta-api \
  --log-stream-name "ecs/psitta-api/$TASK_ID" \
  --profile psitta-prod --region us-east-1 --query 'events[].message' --output text
```

**Notes**
- `MSYS_NO_PATHCONV=1` is required on Windows Git Bash so it doesn't mangle the `/ecs/...` log-group path.
- If the log comes back empty, the task may not have logged yet — re-run the last `aws logs get-log-events` line, or check the exit code:
  ```bash
  aws ecs describe-tasks --cluster psitta-cluster --tasks "$TASK_ARN" \
    --profile psitta-prod --region us-east-1 \
    --query 'tasks[0].containers[0].{exitCode:exitCode,reason:reason}'
  ```
  `exitCode: 0` = success.

---

## 2. How a user's tier is resolved (know this before you change anything)

`services/subscription_service.get_effective_plan` resolves the plan in this **precedence order** (first match wins):

1. **Stripe subscription** — active `subscriptions` row (real paying customer). *Managed by Stripe webhooks only.*
2. **Dev/admin override** — active `user_subscriptions` row. *Set via internal override only; do not hand-edit.*
3. **Reverse-trial grant** — `trial_grants`, not revoked, not expired (new-signup Writing Nook trial).
4. **Tester allowlist** — `tester_allowlist` by email, not revoked, not expired (**this is the safe lever you control**).
5. **Free** — the default.

**Implication:** the sanctioned way to give someone Reading Nook (or refresh their access) *without* touching Stripe is the **tester allowlist** (§4). It sits below Stripe/override in precedence, so it never overrides a real paying subscription.

---

## 3. Inspect accounts (read-only, always safe)

List every account and its resolved tier + source:

```
COMMAND-ARRAY:  "python","scripts/list_accounts.py"
```

Filter to specific people (case-insensitive email match):

```
COMMAND-ARRAY:  "python","scripts/list_accounts.py","alice@example.com","bob@example.com"
```

Output columns: `email · tier · source · created`, then per-tier totals. `source` tells you *why* they have that tier (`stripe` / `dev_override` / `reverse_trial` / `tester_allowlist` / `free`) — which tells you the right lever to pull.

---

## 4. Grant / revoke entitlement via the tester allowlist

`scripts/grant_tester.py` manages `tester_allowlist`. An active row grants **30 days of Reading Nook Pro** keyed by lowercased email, independent of Stripe.

**Always dry-run first.**

Grant (dry-run → real):
```
COMMAND-ARRAY:  "python","scripts/grant_tester.py","add","user@example.com","--granted-by","luis@psitta.ai","--days","30","--dry-run"
COMMAND-ARRAY:  "python","scripts/grant_tester.py","add","user@example.com","--granted-by","luis@psitta.ai","--days","30"
```
Re-running `add` slides the expiry forward and un-revokes — safe to repeat to *extend* someone.

List active tester grants:
```
COMMAND-ARRAY:  "python","scripts/grant_tester.py","list","--active-only"
```

Revoke (soft — sets `revoked_at`, idempotent):
```
COMMAND-ARRAY:  "python","scripts/grant_tester.py","revoke","user@example.com","--dry-run"
COMMAND-ARRAY:  "python","scripts/grant_tester.py","revoke","user@example.com"
```

> The allowlist grants **Reading Nook Pro**. Writing Nook for testers is handled the same way with the WN allowlist entry (used to promote a tester to the full studio without a Stripe upgrade).

Every grant/revoke emits a structured CloudWatch log line (`tester.allowlist_granted` / `tester.allowlist_revoked`) and records `granted_by` on the row — that's your audit trail.

---

## 5. Remote control plane (client version floor + feature flags)

`scripts/set_config.py` manages the `app_config` row that `GET /config` serves to clients. Changes take effect on the **next client request — no redeploy**.

Show current config:
```
COMMAND-ARRAY:  "python","scripts/set_config.py","show"
```

Set the minimum client version (force-update floor) — dry-run first:
```
COMMAND-ARRAY:  "python","scripts/set_config.py","set","--min-version","1.1.0","--dry-run"
COMMAND-ARRAY:  "python","scripts/set_config.py","set","--min-version","1.1.0"
```

Flip a feature flag / kill switch (value parses as true/false/JSON/string):
```
COMMAND-ARRAY:  "python","scripts/set_config.py","set","--flag","reading_v2=false"
```

Defaults are permissive (`0.0.0` floor, no flags), so an unset/failed config never locks anyone out.

> ⚠️ Until the client actually reads `/config` and sends its version, these values are **inert** — safe to experiment with, but they don't affect users yet.

---

## 6. Apply a database migration

Migrations do **not** run on deploy (the container goes straight to `uvicorn`). Apply them as a one-off, and only **after** the image containing the migration has shipped (push → CI → Release green → ECR `:latest` updated).

Inspect current revision:
```
COMMAND-ARRAY:  "alembic","current"
```
Apply all pending:
```
COMMAND-ARRAY:  "alembic","upgrade","head"
```
Verify:
```
COMMAND-ARRAY:  "alembic","current"
```
The `upgrade` log prints `Running upgrade <from> -> <to>, <name>` when it applies. If `current` doesn't advance after `upgrade head`, the image didn't contain the migration yet — wait for Release to finish and retry.

---

## 7. Other diagnostic scripts (read-only)

Present in `core/backend/scripts/`, run with the same one-off pattern:

- `diagnose_subscription_details.py` / `diagnose_subscription_sources.py` — inspect a user's raw subscription/entitlement rows across all sources (useful when `source` in §3 is surprising).
- `check_blueprint_narrative.py` — inspect blueprint/narrative wiring for a project.
- Backfills (`backfill_*.py`) — idempotent data fixes; each has `--dry-run`. Treat as write operations: dry-run, read, then apply.

---

## 8. Escalation / when NOT to proceed

Stop and reconsider (or ask) if:
- The account guard (§0.1) prints anything other than `808765744063`.
- A dry-run shows a change to more rows than you expected.
- You're about to touch Stripe, `user_subscriptions`, or any billing table directly — **don't**; those are webhook/override-managed.
- A migration's `downgrade` is destructive (e.g. a data purge) — verify reversibility before `upgrade`.

---

### Appendix — quick command index

| Task | COMMAND-ARRAY |
|---|---|
| List all accounts | `"python","scripts/list_accounts.py"` |
| Inspect one user | `"python","scripts/list_accounts.py","email@x.com"` |
| Grant 30d Reading Nook | `"python","scripts/grant_tester.py","add","email@x.com","--granted-by","luis@psitta.ai","--days","30"` |
| Revoke tester | `"python","scripts/grant_tester.py","revoke","email@x.com"` |
| Show control-plane config | `"python","scripts/set_config.py","show"` |
| Set min client version | `"python","scripts/set_config.py","set","--min-version","X.Y.Z"` |
| Migration: current / apply | `"alembic","current"` / `"alembic","upgrade","head"` |

Always: **guard → dry-run → read → apply → verify.**
