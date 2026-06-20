---
name: psitta-deploy
description: Strict-protocol push-and-verify for the Psitta repo (github.com/thkcyberai/psitta). Runs a 6-phase bundle (stage → commit → push → watch CI → watch Release → verify ECR↔ECS digest match) with mandatory typed-approval gates between phases A->B and B->C. Use this whenever pushing a Psitta backend or desktop commit to develop, deploying to ECS Fargate, or running production push verification. Use this even when the user just says "push" or "deploy" or "ship" -- never bypass the strict protocol with ad-hoc git push commands.
---

# psitta-deploy

Codifies the strict-protocol push-and-verify flow used for production pushes to the Psitta repo. Runs six phases (A–F), stops at typed-approval gates between A→B and B→C, auto-flows D and E, reports at F.

## Inputs (from the caller)

The user must supply two inputs in the invoking prompt:

1. **`paths`** — explicit list of repo-relative paths to stage. Files must already be edited in the working tree; the skill stages them with `git add <named paths>`. **Never use `git add .`** — only the named paths.
2. **`message`** — commit message. Either inline as a heredoc body, or a path to a file containing the message. Passed verbatim to `git commit -F-`.

Optional:
- **`baseline_run_id`** — prior CI run id to compare rot signature against in Phase D. Default: auto-fetch the most-recent prior CI run on `develop` whose `head_sha` differs from our SHA.

If either required input is missing or ambiguous, STOP and ask. Don't guess.

## Invariants (must hold across every invocation)

- **Never `git add .`** — only the named path list.
- **Never auto-recover** from any failure (Phase A verify, lint/analyze, CI new-rot, Release failure, digest mismatch). STOP and report; wait for typed instruction.
- **Never modify staged content or commit message after Phase A.** If Phase A verification fails, run `git reset HEAD` to unstage and report.
- **Never amend, force-push, rebase, or revert** without explicit typed instruction.
- **Approval gates confirm intent, not punctuation.** Gate A unlocks commit; gate B unlocks push. Accept any clear affirmative that names the gate, plain ASCII only, case-insensitive, hyphens and spaces interchangeable. Examples that pass gate B: "approved B", "approve B push", "yes push B", "B approved", "go B". If the intent and the target gate are unambiguous, proceed. Never require an em-dash, smart quote, or any Unicode-specific character. Preferred single-word forms: "go A" / "go B".
- **Backups are caller responsibility.** This skill is push-and-verify only; the caller is expected to have edited files (with their own backup discipline) before invoking.

## Project-specific values (hardcoded)

| | |
|---|---|
| Repo | `github.com/thkcyberai/psitta` |
| Branch | `develop` |
| ECR | `psitta-api:latest` (account 808765744063, us-east-1) |
| ECS | cluster `psitta-cluster`, service `psitta-api` |
| AWS profile | `psitta-prod` |
| AWS region | `us-east-1` |
| Workflows | `ci.yml` (rot-prone, see Phase D), `release.yml` (deploys to ECR + ECS) |

## Phase A — Stage and verify

1. `cd` to repo root. Confirm `git branch --show-current == develop`. STOP if not.
2. Stage the named paths verbatim: `git add <path1> <path2> ...`. One `git add` per group is fine; never `.`.
3. Verify exact match: `git diff --cached --name-only | sort` MUST equal the caller's input set sorted. If any extra path appears or any expected path is missing, run `git reset HEAD` and STOP with a diff of expected vs actual.
4. For each touched `.py` file: run `python -m py_compile <file>` and `ruff check <file>`. If a corresponding `<file>.bak_*` exists in the same directory, also run `ruff check <bak>` and compare error-code distributions — STOP if new codes appear vs baseline. If no `.bak_*` is present, skip the comparison and report the current ruff count without blocking. (Honest comparison only when comparison is meaningful.)
5. For each touched `.dart` file: `cd apps/desktop && flutter analyze --no-fatal-infos <files>`. Required: zero errors. Warnings/infos OK.
6. Show `git diff --cached --stat` and `git status --short` confirming out-of-scope files (CLAUDE.md, untracked artifacts) remain unstaged.
7. **STOP. Wait for the user to give gate A approval** — any clear affirmative naming gate A (e.g., "go A", "approved A", "yes commit", "A ok"). Plain ASCII, case-insensitive.

## Phase B — Commit

1. Run `git commit -F- <<'EOF' ... EOF` with the caller's message verbatim. **Do not edit, abbreviate, or rewrap.**
2. Show `git log -1 --format="%H %s"` and `git log -1 --stat | head -50`.
3. Spot-check that the first and last paragraphs of the message landed (no truncation).
4. **STOP. Wait for the user to give gate B approval** — any clear affirmative naming gate B (e.g., "go B", "approved B", "yes push", "B ok"). Plain ASCII, case-insensitive.

## Phase C — Push (auto-flows into D)

1. Verify `git branch --show-current == develop` AND exactly 1 commit ahead of origin/develop. STOP if either check fails.
2. Capture `PUSH_T0=$(date -u +%s)` for wall-clock measurement.
3. `git push origin develop`.
4. Confirm `git rev-parse origin/develop` equals new SHA.
5. Auto-flow to Phase D.

## Phase D — Watch CI

`gh` CLI is unauthenticated on this host; use anonymous REST polling.

1. Find our run: `curl -s --ssl-no-revoke "https://api.github.com/repos/thkcyberai/psitta/actions/runs?branch=develop&per_page=8"` and pick the run whose `head_sha` matches our SHA and `name == "CI"`. Capture `CI_RUN_ID`.
2. `scripts/poll_workflow.sh $CI_RUN_ID` — polls every 30s until `status == completed`.
3. If `conclusion == success`: log and proceed to Phase E.
4. If `conclusion == failure`: run `scripts/compare_ci_signature.sh $CI_RUN_ID [$BASELINE_RUN_ID]`. The script auto-fetches the most-recent prior CI run on `develop` (with `head_sha != $OUR_SHA`) if no baseline is passed.
   - **Rot match** (failed-step set identical to baseline) → log "rot confirmed" and proceed to Phase E.
   - **NEW failed steps appear** → STOP, dump the diff, do not proceed.

## Phase E — Watch Release + verify digest convergence

1. Find Release run: same lookup, `name == "Release"`. Capture `RELEASE_RUN_ID`.
2. `scripts/poll_workflow.sh $RELEASE_RUN_ID`. If `conclusion != success`, STOP.
3. `scripts/verify_digest_match.sh` — fetches ECR `:latest` digest, polls ECS running task digest every 30s until match (max 10 polls = 5 min). Returns 0 on match, 1 on timeout.
4. `CONVERGE_ELAPSED=$(($(date -u +%s) - PUSH_T0))`.

## Phase F — Final report

Single table with:
- Commit SHA on develop
- Push T0 (UTC)
- CI conclusion + rot match (yes / new steps differ)
- Release conclusion
- ECR `:latest` digest (current)
- ECR digest from prior commit (for visibility)
- Running ECS task digest
- ECR == ECS (yes/no)
- Wall clock from push to digest match (seconds)
- Working-tree post-commit (confirm out-of-scope files still untouched)

STOP after Phase F. Caller handles any subsequent app-level visual smoke (e.g., MSIX rebuild + tester verification for desktop changes).

## Why these guardrails exist

- **Intent-based approval gates** — gates confirm the human's intent and target action, not a glyph. Plain ASCII only; no Unicode required. Accept any clear affirmative naming the gate (case-insensitive, hyphens/spaces interchangeable). The goal is preventing accidental pushes, not creating copy-paste friction.
- **No `git add .`** — sweeps unrelated changes (CLAUDE.md hook updates, voice-avatar WIP, untracked website assets) into the commit.
- **Rot baseline comparison** — CI has been red since Apr 25 due to pre-existing test rot (KL 2026-05-01). Without baseline diff, every push would falsely STOP. With diff, only NEW failures halt the deploy.
- **Digest verify** — task-definition revision is a meaningless signal because Psitta uses `:latest` tag with `--force-new-deployment` (KL 2026-04-25). Image digest is the only ground truth.
