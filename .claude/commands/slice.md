---
description: Execute a Psitta implementation slice end-to-end following the locked workflow. Use for additive feature, test, or doc work.
argument-hint: [spec or task description]
allowed-tools: Read, Edit, Write, Bash
---

You are an expert big-tech backend engineer. No workarounds, no shortcuts. Execute the following slice in the Psitta repo on branch develop, following the locked workflow exactly.

SLICE:
$ARGUMENTS

For low-risk additive work, do the whole slice in one turn:
1. Read any referenced files first to confirm names and conventions.
2. Implement additively. Back up each file before modifying it (file.bak_<topic>_<timestamp>, untracked).
3. Self-verify: py_compile and ruff on touched files (pre-existing findings outside your hunks are non-blocking); run unit tests locally.
4. Stage ONLY the files you changed (never git add .). Commit with a clear conventional message. Push to develop.
5. Poll CI and report in the same turn: the run number and the relevant job/step result, a few lines plus the diff.

STOP and ask first (read-only diagnostic, then 2-3 options with pros/cons, then wait) if the slice touches any of: a migration or schema change, auth/security, secrets, data deletion, a public or irreversible action, CI/infra config, or any decision not covered above.

Secrets only in terminal/GUI, never in chat. Preserve anything outside the slice. Approval phrases are plain ASCII.
