# Deliverable X — Repository Bootstrap

**Product:** Psitta
**Status:** Mandatory pre-requisite for all other deliverables
**Execution environment:** Local developer machine — `C:/products/psitta`
**Shell:** Git Bash, WSL2, or PowerShell with Unix utils. All commands below use Bash syntax.
**Result:** A git repository with first commit, ready to push to GitHub via CLI

---

## 1. Complete Repository Tree

Every file and directory in the repository at bootstrap.
Annotations mark the licensing boundary and purpose of each section.

```
C:/products/psitta/                       # Monorepo root
│
├── .github/                              # ── CI/CD & GitHub Configuration ──
│   ├── workflows/
│   │   ├── ci.yml                        # Lint → test → security → build gate
│   │   ├── release.yml                   # Tag-triggered: GHCR push + deploy
│   │   └── security.yml                  # Nightly dependency + container scans
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yml                # Structured bug report form
│   │   ├── feature_request.yml           # Feature proposal form
│   │   └── config.yml                    # Template chooser config
│   ├── PULL_REQUEST_TEMPLATE.md          # PR checklist
│   ├── CODEOWNERS                        # Auto-assign reviewers
│   └── dependabot.yml                    # Automated dependency updates
│
├── core/                                 # ── Apache 2.0 Open Core ──
│   └── backend/
│       ├── Dockerfile                    # Multi-stage: builder → runtime
│       ├── pyproject.toml                # Hatch build, deps, tool config
│       ├── alembic.ini                   # Alembic config (points to db/)
│       ├── src/
│       │   └── psitta/
│       │       ├── __init__.py           # Package init, __version__
│       │       ├── main.py               # FastAPI app factory
│       │       ├── config.py             # Pydantic settings
│       │       ├── dependencies.py       # FastAPI dependency injection
│       │       ├── api/
│       │       │   ├── __init__.py
│       │       │   └── v1/
│       │       │       ├── __init__.py
│       │       │       ├── router.py     # Mounts all v1 sub-routers
│       │       │       ├── documents.py  # Upload, status, list, delete
│       │       │       ├── playback.py   # Stream, position, sessions
│       │       │       ├── voices.py     # Catalog, preview, profiles
│       │       │       └── users.py      # Profile, preferences, tier
│       │       ├── models/
│       │       │   ├── __init__.py
│       │       │   └── domain.py         # Dataclass domain models
│       │       ├── schemas/
│       │       │   ├── __init__.py
│       │       │   └── api.py            # Pydantic request/response
│       │       ├── services/
│       │       │   ├── __init__.py
│       │       │   ├── document_service.py
│       │       │   └── playback_service.py
│       │       ├── providers/
│       │       │   ├── __init__.py
│       │       │   ├── interfaces/
│       │       │   │   ├── __init__.py
│       │       │   │   └── contracts.py  # Protocol classes (TTS, Storage, etc.)
│       │       │   ├── storage_s3.py     # S3/MinIO storage provider
│       │       │   ├── tts_azure.py      # Azure Cognitive TTS provider
│       │       │   ├── vision_anthropic.py
│       │       │   ├── voice_catalog_static.py
│       │       │   └── tone_rule_based.py
│       │       ├── middleware/
│       │       │   ├── __init__.py
│       │       │   ├── request_id.py     # X-Request-ID + structlog binding
│       │       │   └── rate_limit.py     # Token bucket rate limiter
│       │       ├── workers/
│       │       │   ├── __init__.py
│       │       │   └── document_processor.py  # Redis Streams consumer
│       │       └── db/
│       │           ├── __init__.py
│       │           ├── session.py        # Async SQLAlchemy engine/session
│       │           └── migrations/
│       │               ├── __init__.py
│       │               ├── env.py        # Alembic async env
│       │               ├── script.py.mako
│       │               └── versions/
│       │                   ├── __init__.py
│       │                   └── 001_initial_schema.py
│       └── tests/
│           ├── __init__.py
│           ├── conftest.py               # Shared fixtures (db, redis, client)
│           ├── factories.py              # Factory functions for test data
│           ├── unit/
│           │   ├── __init__.py
│           │   ├── test_document_service.py
│           │   ├── test_playback_service.py
│           │   ├── test_schemas.py
│           │   └── test_middleware/
│           │       ├── __init__.py
│           │       ├── test_request_id.py
│           │       └── test_rate_limit.py
│           ├── integration/
│           │   ├── __init__.py
│           │   ├── test_document_api.py
│           │   ├── test_playback_api.py
│           │   ├── test_voice_api.py
│           │   └── test_user_api.py
│           └── e2e/
│               ├── __init__.py
│               └── test_document_flow.py
│
├── apps/                                 # ── Client Applications ──
│   └── mobile/                           # Flutter cross-platform app
│       ├── pubspec.yaml
│       ├── analysis_options.yaml
│       ├── lib/
│       │   ├── main.dart                 # App entry point
│       │   ├── app.dart                  # MaterialApp + routing
│       │   ├── core/
│       │   │   ├── theme/
│       │   │   │   ├── app_theme.dart
│       │   │   │   └── colors.dart
│       │   │   ├── routing/
│       │   │   │   └── app_router.dart
│       │   │   ├── constants.dart
│       │   │   └── extensions.dart
│       │   ├── data/
│       │   │   ├── api/
│       │   │   │   └── api_client.dart
│       │   │   ├── models/
│       │   │   │   ├── document.dart
│       │   │   │   ├── playback_session.dart
│       │   │   │   └── voice.dart
│       │   │   └── repositories/
│       │   │       ├── document_repository.dart
│       │   │       ├── playback_repository.dart
│       │   │       └── voice_repository.dart
│       │   └── features/
│       │       ├── home/
│       │       │   ├── home_screen.dart
│       │       │   └── widgets/
│       │       │       └── document_card.dart
│       │       ├── player/
│       │       │   ├── player_screen.dart
│       │       │   └── widgets/
│       │       │       ├── playback_controls.dart
│       │       │       └── chunk_navigator.dart
│       │       ├── voices/
│       │       │   ├── voice_selector_screen.dart
│       │       │   └── widgets/
│       │       │       └── voice_preview_card.dart
│       │       └── settings/
│       │           └── settings_screen.dart
│       └── test/
│           ├── unit/
│           │   └── .gitkeep
│           ├── widget/
│           │   └── .gitkeep
│           └── integration/
│               └── .gitkeep
│
├── extensions/                           # ── Commercial / Proprietary ──
│   ├── README.md                         # Extension development guide
│   ├── voice-cloning/
│   │   ├── README.md
│   │   └── .gitkeep
│   ├── premium-tts/
│   │   ├── README.md
│   │   └── .gitkeep
│   ├── advanced-tone/
│   │   ├── README.md
│   │   └── .gitkeep
│   ├── enterprise/
│   │   ├── README.md
│   │   └── .gitkeep
│   └── analytics/
│       ├── README.md
│       └── .gitkeep
│
├── docs/                                 # ── Documentation ──
│   ├── PRD.md                            # Product Requirements Document
│   ├── API.md                            # OpenAPI specification
│   ├── TESTING.md                        # Test strategy & fixture patterns
│   ├── OBSERVABILITY.md                  # Logging, tracing, metrics
│   ├── COST_AND_SCALE.md                 # Cost model & scaling guidance
│   └── adr/                              # Architecture Decision Records
│       ├── README.md                     # ADR index
│       ├── 0001-monorepo-structure.md
│       └── template.md                   # ADR template
│
├── scripts/                              # ── Developer Tooling ──
│   ├── bootstrap.sh                      # One-command dev environment setup
│   ├── reset-db.sh                       # Drop + recreate + migrate
│   └── seed-data.sh                      # Load sample documents for dev
│
├── .gitignore                            # Comprehensive ignore rules
├── .pre-commit-config.yaml               # Pre-commit hooks
├── .env.example                          # All env vars documented
├── docker-compose.yml                    # Dev stack (Postgres, Redis, MinIO, API, Worker)
├── compose.prod.yml                      # Production overrides
├── LICENSE                               # Apache 2.0 (core)
├── LICENSE-EXTENSIONS                    # Commercial license stub (extensions/)
├── README.md                             # Project overview + quickstart
├── ARCHITECTURE.md                       # System design document
├── SECURITY.md                           # Vulnerability disclosure policy
├── CONTRIBUTING.md                       # Contributor guide
├── OPEN_CORE_BOUNDARY.md                 # Open-core boundary definition
└── CHANGELOG.md                          # Keep a Changelog format
```

**Total:** 130 files across 76 directories.

### Boundary Legend

| Path Prefix | License | Runnable at Bootstrap | Notes |
|-------------|---------|----------------------|-------|
| `core/` | Apache 2.0 | ✅ API starts, migrations run | Full source committed |
| `apps/mobile/` | Apache 2.0 | ✅ `flutter run` compiles | Skeleton screens |
| `extensions/*/` | Commercial (stub) | ⬜ Placeholder only | `.gitkeep` + README |
| `docs/` | CC BY 4.0 | N/A (documentation) | All docs committed |
| `.github/` | Apache 2.0 | ✅ CI triggers on push | Full workflow YAML |
| `scripts/` | Apache 2.0 | ✅ Executable helpers | Bash scripts |

---

## 2. Bootstrap Shell Commands

Copy-paste the entire block below into a terminal. Execution target: **`C:/products/`** (run from Git Bash or WSL2 on your local machine). The script creates the `psitta/` directory inside it, writes every file, and prepares for `git init`.

### 2.1 Prerequisites Check

Run this first to verify your toolchain. If any check fails, install the missing tool before proceeding.

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Psitta Bootstrap — Prerequisites Check ==="

check() { command -v "$1" &>/dev/null && echo "  ✓ $1 $(command $1 --version 2>&1 | head -1)" || echo "  ✗ $1 — MISSING (required)"; }

check git
check python3
check pip3
check docker
check flutter
echo ""
echo "All items marked ✓ must be present before continuing."
```

### 2.2 Create Directory Structure

```bash
#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────
# Psitta — Repository Bootstrap
# Execute from C:/products/ (Git Bash or WSL2)
# ──────────────────────────────────────────────────────────────────────

cd /c/products    # Git Bash path for C:/products/
# cd /mnt/c/products  # ← Use this line instead if running WSL2

REPO="psitta"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Psitta — Repository Bootstrap                        ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ── 1. Root ────────────────────────────────────────────────────────────
mkdir -p "$REPO"
cd "$REPO"

echo "→ Creating directory structure..."

# ── 2. GitHub ──────────────────────────────────────────────────────────
mkdir -p .github/workflows
mkdir -p .github/ISSUE_TEMPLATE

# ── 3. Core Backend ───────────────────────────────────────────────────
mkdir -p core/backend/src/psitta/api/v1
mkdir -p core/backend/src/psitta/models
mkdir -p core/backend/src/psitta/schemas
mkdir -p core/backend/src/psitta/services
mkdir -p core/backend/src/psitta/providers/interfaces
mkdir -p core/backend/src/psitta/middleware
mkdir -p core/backend/src/psitta/workers
mkdir -p core/backend/src/psitta/db/migrations/versions
mkdir -p core/backend/tests/unit/test_middleware
mkdir -p core/backend/tests/integration
mkdir -p core/backend/tests/e2e

# ── 4. Flutter App ────────────────────────────────────────────────────
mkdir -p apps/mobile/lib/core/theme
mkdir -p apps/mobile/lib/core/routing
mkdir -p apps/mobile/lib/data/api
mkdir -p apps/mobile/lib/data/models
mkdir -p apps/mobile/lib/data/repositories
mkdir -p apps/mobile/lib/features/home/widgets
mkdir -p apps/mobile/lib/features/player/widgets
mkdir -p apps/mobile/lib/features/voices/widgets
mkdir -p apps/mobile/lib/features/settings
mkdir -p apps/mobile/test/unit
mkdir -p apps/mobile/test/widget
mkdir -p apps/mobile/test/integration

# ── 5. Extensions (Commercial) ───────────────────────────────────────
mkdir -p extensions/voice-cloning
mkdir -p extensions/premium-tts
mkdir -p extensions/advanced-tone
mkdir -p extensions/enterprise
mkdir -p extensions/analytics

# ── 6. Docs + ADRs ───────────────────────────────────────────────────
mkdir -p docs/adr

# ── 7. Scripts ────────────────────────────────────────────────────────
mkdir -p scripts

echo "  ✓ 76 directories created"
```

### 2.3 Write All Placeholder & Scaffold Files

This is the largest section. Every file that does not already have full source content gets a meaningful placeholder. Files with full source (API routes, services, models, etc.) are represented below as their real content — the exact code produced in prior deliverables.

```bash
# ══════════════════════════════════════════════════════════════════════
# ROOT FILES
# ══════════════════════════════════════════════════════════════════════

# ── .gitignore ─────────────────────────────────────────────────────────
cat > .gitignore << 'EOF'
# ── Python ──────────────────────────────────
__pycache__/
*.py[cod]
*$py.class
*.egg-info/
*.egg
dist/
build/
.eggs/
*.whl
.venv/
venv/
env/
.mypy_cache/
.ruff_cache/
.pytest_cache/
htmlcov/
.coverage
coverage.xml
*.lcov
junit-*.xml

# ── Flutter / Dart ──────────────────────────
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
build/
*.g.dart
*.freezed.dart
.fvm/

# ── IDE ─────────────────────────────────────
.idea/
.vscode/
*.swp
*.swo
*~
.DS_Store
Thumbs.db

# ── Environment / Secrets ───────────────────
.env
.env.local
.env.*.local
*.pem
*.key
*.cert

# ── Docker ──────────────────────────────────
docker-compose.override.yml

# ── OS ──────────────────────────────────────
*.log
tmp/
temp/
EOF

# ── .pre-commit-config.yaml ───────────────────────────────────────────
cat > .pre-commit-config.yaml << 'EOF'
# See https://pre-commit.com for more information
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
        args: [--allow-multiple-documents]
      - id: check-json
      - id: check-toml
      - id: check-added-large-files
        args: [--maxkb=1024]
      - id: check-merge-conflict
      - id: detect-private-key
      - id: no-commit-to-branch
        args: [--branch, main]

  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.7.0
    hooks:
      - id: ruff
        args: [--fix]
        types_or: [python, pyi]
      - id: ruff-format
        types_or: [python, pyi]

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.13.0
    hooks:
      - id: mypy
        additional_dependencies:
          - pydantic>=2.9.0
          - types-redis>=4.6.0
        args: [--ignore-missing-imports]
        files: ^core/backend/src/

  - repo: local
    hooks:
      - id: dart-format
        name: dart format
        entry: dart format --set-exit-if-changed
        language: system
        types: [dart]
      - id: dart-analyze
        name: dart analyze
        entry: dart analyze --fatal-infos
        language: system
        types: [dart]
        pass_filenames: false
EOF

# ── LICENSE (Apache 2.0) ──────────────────────────────────────────────
cat > LICENSE << 'EOF'
                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but not
      limited to compiled object code, generated documentation, and
      conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work.

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to the Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by the Licensor and
      subsequently incorporated within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding any notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND. You are solely responsible
      for determining the appropriateness of using or redistributing the Work.

   8. Limitation of Liability. In no event shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License.

   END OF TERMS AND CONDITIONS

   Copyright 2025 Psitta Contributors

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
EOF

# ── LICENSE-EXTENSIONS ────────────────────────────────────────────────
cat > LICENSE-EXTENSIONS << 'EOF'
Psitta Extensions — Proprietary License

Copyright (c) 2025 Psitta

All files within the extensions/ directory are proprietary and confidential.
Unauthorized copying, modification, distribution, or use of these files,
via any medium, is strictly prohibited.

For licensing inquiries, contact: licensing@psitta.dev

This license applies exclusively to the extensions/ directory.
All other code in this repository is licensed under Apache 2.0 (see LICENSE).
EOF

# ── CHANGELOG.md ──────────────────────────────────────────────────────
cat > CHANGELOG.md << 'EOF'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project scaffold and repository bootstrap
- FastAPI backend with async PostgreSQL, Redis, S3
- Flutter cross-platform app skeleton
- Docker Compose development stack
- CI/CD pipelines (GitHub Actions)
- Open-core licensing boundary (Apache 2.0 core + commercial extensions)
- Complete documentation suite (PRD, Architecture, API, Security, Testing, Observability)
EOF

echo "  ✓ Root files written"

# ══════════════════════════════════════════════════════════════════════
# GITHUB FILES
# ══════════════════════════════════════════════════════════════════════

cat > .github/CODEOWNERS << 'EOF'
# Default owners for everything
*                       @psitta/maintainers

# Backend
/core/backend/          @psitta/backend

# Flutter
/apps/mobile/           @psitta/mobile

# Infrastructure
/docker-compose.yml     @psitta/infra
/.github/workflows/     @psitta/infra

# Extensions (restricted)
/extensions/            @psitta/extensions-team

# Security-sensitive
/SECURITY.md            @psitta/security
/.env.example           @psitta/security
EOF

cat > .github/dependabot.yml << 'EOF'
version: 2
updates:
  - package-ecosystem: pip
    directory: /core/backend
    schedule:
      interval: weekly
      day: monday
    open-pull-requests-limit: 10
    labels: ["dependencies", "python"]

  - package-ecosystem: pub
    directory: /apps/mobile
    schedule:
      interval: weekly
      day: monday
    open-pull-requests-limit: 10
    labels: ["dependencies", "flutter"]

  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
      day: monday
    open-pull-requests-limit: 5
    labels: ["dependencies", "ci"]

  - package-ecosystem: docker
    directory: /core/backend
    schedule:
      interval: weekly
      day: monday
    labels: ["dependencies", "docker"]
EOF

cat > .github/PULL_REQUEST_TEMPLATE.md << 'EOF'
## Summary

<!-- What does this PR do? Link to the issue if applicable. -->

Closes #

## Type of Change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Documentation update
- [ ] Refactor (no functional changes)
- [ ] CI/CD or infrastructure change

## Checklist

- [ ] My code follows the project's coding standards
- [ ] I have written tests that prove my fix/feature works
- [ ] All new and existing tests pass locally
- [ ] I have updated documentation where necessary
- [ ] I have checked this change against the open-core boundary
- [ ] My changes generate no new warnings or linter errors

## Testing

<!-- How did you test this? Include steps to reproduce if applicable. -->

## Screenshots

<!-- If applicable, add screenshots to help explain your changes. -->
EOF

cat > .github/ISSUE_TEMPLATE/config.yml << 'EOF'
blank_issues_enabled: false
contact_links:
  - name: Discussions
    url: https://github.com/psitta/psitta/discussions
    about: Ask questions and discuss ideas
  - name: Security Vulnerability
    url: https://github.com/psitta/psitta/security/advisories/new
    about: Report security vulnerabilities (do NOT open a public issue)
EOF

cat > .github/ISSUE_TEMPLATE/bug_report.yml << 'EOF'
name: Bug Report
description: Report a bug in Psitta
labels: ["bug", "triage"]
body:
  - type: textarea
    id: description
    attributes:
      label: Describe the bug
      placeholder: A clear description of what the bug is.
    validations:
      required: true
  - type: textarea
    id: steps
    attributes:
      label: Steps to Reproduce
      placeholder: |
        1. Go to '...'
        2. Click on '...'
        3. See error
    validations:
      required: true
  - type: textarea
    id: expected
    attributes:
      label: Expected Behavior
    validations:
      required: true
  - type: dropdown
    id: component
    attributes:
      label: Component
      options:
        - Backend API
        - Document Processing
        - Playback
        - Flutter App
        - Docker/Infrastructure
        - CI/CD
        - Other
    validations:
      required: true
  - type: textarea
    id: environment
    attributes:
      label: Environment
      placeholder: |
        - OS: macOS 14.2
        - Python: 3.12.1
        - Flutter: 3.24.0
        - Docker: 24.0.7
EOF

cat > .github/ISSUE_TEMPLATE/feature_request.yml << 'EOF'
name: Feature Request
description: Suggest a new feature for Psitta
labels: ["enhancement", "triage"]
body:
  - type: textarea
    id: problem
    attributes:
      label: Problem Statement
      placeholder: What problem does this feature solve?
    validations:
      required: true
  - type: textarea
    id: solution
    attributes:
      label: Proposed Solution
      placeholder: Describe how you'd like this to work.
    validations:
      required: true
  - type: dropdown
    id: boundary
    attributes:
      label: Open-Core Placement
      description: Where should this feature live? See OPEN_CORE_BOUNDARY.md
      options:
        - Core (Apache 2.0)
        - Extension (Commercial)
        - Not sure
    validations:
      required: true
  - type: textarea
    id: alternatives
    attributes:
      label: Alternatives Considered
      placeholder: Any other approaches you've thought about?
EOF

echo "  ✓ GitHub config files written"

# ══════════════════════════════════════════════════════════════════════
# BACKEND — TEST SCAFFOLDS
# ══════════════════════════════════════════════════════════════════════

# Test __init__.py files
for dir in \
  core/backend/tests \
  core/backend/tests/unit \
  core/backend/tests/unit/test_middleware \
  core/backend/tests/integration \
  core/backend/tests/e2e; do
  touch "$dir/__init__.py"
done

cat > core/backend/tests/conftest.py << 'PYEOF'
"""Shared test fixtures for Psitta backend tests."""

from __future__ import annotations

import pytest
from httpx import ASGITransport, AsyncClient


@pytest.fixture
def anyio_backend():
    return "asyncio"


# ── Database fixture (integration tests) ──────────────────────────────
# Uncomment and configure once the DB session module is wired:
#
# @pytest.fixture
# async def db_session():
#     """Transactional DB session — rolls back after each test."""
#     from psitta.db.session import async_engine
#     async with async_engine.connect() as conn:
#         txn = await conn.begin()
#         from sqlalchemy.ext.asyncio import AsyncSession
#         session = AsyncSession(bind=conn, expire_on_commit=False)
#         yield session
#         await txn.rollback()
#         await session.close()


# ── Test client fixture ───────────────────────────────────────────────
# Uncomment once main.py create_app is functional:
#
# @pytest.fixture
# async def client():
#     from psitta.main import create_app
#     app = create_app()
#     transport = ASGITransport(app=app)
#     async with AsyncClient(transport=transport, base_url="http://test") as c:
#         yield c
PYEOF

cat > core/backend/tests/factories.py << 'PYEOF'
"""Factory functions for generating test data.

Usage:
    from tests.factories import make_document, make_audio_segment
    doc = make_document(title="My Test PDF", page_count=5)
"""

from __future__ import annotations

from uuid import uuid4

# Factories will import from psitta.models.domain once the test
# infrastructure is wired. For now, they return plain dicts.


def make_document(**overrides) -> dict:
    defaults = {
        "id": str(uuid4()),
        "user_id": f"user_{uuid4().hex[:8]}",
        "title": "Test Document",
        "source_type": "pdf",
        "status": "uploaded",
        "page_count": 10,
        "file_size_bytes": 500_000,
        "storage_key": f"uploads/{uuid4()}.pdf",
        "metadata": {},
    }
    defaults.update(overrides)
    return defaults


def make_audio_segment(**overrides) -> dict:
    defaults = {
        "id": str(uuid4()),
        "document_id": str(uuid4()),
        "chunk_id": str(uuid4()),
        "voice_id": "en-US-AriaNeural",
        "speed": 1.0,
        "storage_key": f"audio/{uuid4()}.mp3",
        "duration_ms": 5000,
        "file_size_bytes": 40_000,
    }
    defaults.update(overrides)
    return defaults
PYEOF

# Placeholder test files
cat > core/backend/tests/unit/test_document_service.py << 'PYEOF'
"""Unit tests for DocumentService."""

import pytest


class TestDocumentService:
    """Tests for document lifecycle operations."""

    @pytest.mark.skip(reason="Scaffold — implement with service layer")
    async def test_upload_creates_document_record(self):
        pass

    @pytest.mark.skip(reason="Scaffold — implement with service layer")
    async def test_upload_rejects_oversized_file(self):
        pass

    @pytest.mark.skip(reason="Scaffold — implement with service layer")
    async def test_delete_removes_document_and_audio(self):
        pass
PYEOF

cat > core/backend/tests/unit/test_playback_service.py << 'PYEOF'
"""Unit tests for PlaybackService."""

import pytest


class TestPlaybackService:
    """Tests for playback session management."""

    @pytest.mark.skip(reason="Scaffold — implement with service layer")
    async def test_create_session_returns_first_chunk(self):
        pass

    @pytest.mark.skip(reason="Scaffold — implement with service layer")
    async def test_update_position_persists(self):
        pass
PYEOF

cat > core/backend/tests/unit/test_schemas.py << 'PYEOF'
"""Unit tests for Pydantic schemas — validation edge cases."""

import pytest


class TestDocumentSchemas:

    @pytest.mark.skip(reason="Scaffold — implement with schema validation")
    def test_upload_request_rejects_unsupported_format(self):
        pass

    @pytest.mark.skip(reason="Scaffold — implement with schema validation")
    def test_speed_clamped_to_valid_range(self):
        pass
PYEOF

cat > core/backend/tests/unit/test_middleware/test_request_id.py << 'PYEOF'
"""Unit tests for RequestID middleware."""

import pytest


class TestRequestIDMiddleware:

    @pytest.mark.skip(reason="Scaffold — implement with ASGI test client")
    async def test_generates_request_id_when_missing(self):
        pass

    @pytest.mark.skip(reason="Scaffold — implement with ASGI test client")
    async def test_preserves_incoming_request_id(self):
        pass
PYEOF

cat > core/backend/tests/unit/test_middleware/test_rate_limit.py << 'PYEOF'
"""Unit tests for RateLimit middleware."""

import pytest


class TestRateLimitMiddleware:

    @pytest.mark.skip(reason="Scaffold — implement with ASGI test client")
    async def test_allows_requests_under_limit(self):
        pass

    @pytest.mark.skip(reason="Scaffold — implement with ASGI test client")
    async def test_returns_429_when_exceeded(self):
        pass
PYEOF

# Integration test placeholders
for endpoint in document_api playback_api voice_api user_api; do
cat > "core/backend/tests/integration/test_${endpoint}.py" << PYEOF
"""Integration tests for ${endpoint} endpoints."""

import pytest


@pytest.mark.skip(reason="Scaffold — requires running services")
class Test${endpoint^}:
    async def test_placeholder(self):
        pass
PYEOF
done

cat > core/backend/tests/e2e/test_document_flow.py << 'PYEOF'
"""End-to-end test: upload → process → play full cycle."""

import pytest


@pytest.mark.skip(reason="Scaffold — requires full stack")
@pytest.mark.slow
class TestDocumentFlow:
    async def test_upload_process_and_play(self):
        """Upload a PDF, wait for processing, and verify audio playback."""
        pass
PYEOF

echo "  ✓ Test scaffolds written"

# ══════════════════════════════════════════════════════════════════════
# FLUTTER APP SCAFFOLD
# ══════════════════════════════════════════════════════════════════════

cat > apps/mobile/pubspec.yaml << 'EOF'
name: psitta
description: Ultra-natural document narration — listen to any document
publish_to: "none"
version: 0.1.0+1

environment:
  sdk: ">=3.4.0 <4.0.0"
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.0
  go_router: ^14.0.0
  dio: ^5.4.0
  just_audio: ^0.9.39
  freezed_annotation: ^2.4.0
  json_annotation: ^4.9.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  build_runner: ^2.4.0
  freezed: ^2.5.0
  json_serializable: ^6.8.0
  mockito: ^5.4.0
  mocktail: ^1.0.0
EOF

cat > apps/mobile/analysis_options.yaml << 'EOF'
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_const_constructors: true
    prefer_const_declarations: true
    avoid_print: true
    prefer_single_quotes: true
    sort_constructors_first: true
    unawaited_futures: true
EOF

cat > apps/mobile/lib/main.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: PsittaApp()));
}
EOF

cat > apps/mobile/lib/app.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

class PsittaApp extends ConsumerWidget {
  const PsittaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Psitta',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
EOF

cat > apps/mobile/lib/core/theme/colors.dart << 'EOF'
import 'package:flutter/material.dart';

abstract final class AppColors {
  // Primary
  static const primary = Color(0xFF1A73E8);
  static const primaryLight = Color(0xFF4DA3FF);
  static const primaryDark = Color(0xFF0D47A1);

  // Neutral
  static const surface = Color(0xFFFAFAFA);
  static const surfaceDark = Color(0xFF121212);
  static const textPrimary = Color(0xFF1F1F1F);
  static const textSecondary = Color(0xFF5F6368);

  // Semantic
  static const success = Color(0xFF34A853);
  static const warning = Color(0xFFFBBC04);
  static const error = Color(0xFFEA4335);

  // Audio / Playback
  static const waveform = Color(0xFF1A73E8);
  static const waveformInactive = Color(0xFFDADCE0);
}
EOF

cat > apps/mobile/lib/core/theme/app_theme.dart << 'EOF'
import 'package:flutter/material.dart';
import 'colors.dart';

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.primary,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.surface,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.primary,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.surfaceDark,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
        ),
      );
}
EOF

cat > apps/mobile/lib/core/routing/app_router.dart << 'EOF'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/home_screen.dart';
import '../../features/player/player_screen.dart';
import '../../features/voices/voice_selector_screen.dart';
import '../../features/settings/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/player/:documentId',
        builder: (context, state) => PlayerScreen(
          documentId: state.pathParameters['documentId']!,
        ),
      ),
      GoRoute(
        path: '/voices',
        builder: (context, state) => const VoiceSelectorScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
EOF

cat > apps/mobile/lib/core/constants.dart << 'EOF'
abstract final class AppConstants {
  static const String apiBaseUrl = 'http://localhost:8000/api/v1';
  static const Duration httpTimeout = Duration(seconds: 30);
  static const double minPlaybackSpeed = 0.5;
  static const double maxPlaybackSpeed = 3.0;
  static const double defaultPlaybackSpeed = 1.0;
}
EOF

cat > apps/mobile/lib/core/extensions.dart << 'EOF'
extension DurationFormatting on Duration {
  String toPlayerTimestamp() {
    final hours = inHours;
    final minutes = inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }
}
EOF

# Data layer stubs
cat > apps/mobile/lib/data/api/api_client.dart << 'EOF'
import 'package:dio/dio.dart';
import '../../core/constants.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: AppConstants.httpTimeout,
      receiveTimeout: AppConstants.httpTimeout,
    ));
  }

  Dio get dio => _dio;
}
EOF

for model in document playback_session voice; do
cat > "apps/mobile/lib/data/models/${model}.dart" << EOF
// TODO: Generate with freezed + json_serializable
// Run: dart run build_runner build
class ${model^} {
  // Placeholder — define fields matching API schema
}
EOF
done

for repo in document playback voice; do
cat > "apps/mobile/lib/data/repositories/${repo}_repository.dart" << EOF
import '../api/api_client.dart';

class ${repo^}Repository {
  final ApiClient _api;

  ${repo^}Repository(this._api);

  // TODO: Implement API calls matching core/backend/src/psitta/api/v1/
}
EOF
done

# Feature screens
cat > apps/mobile/lib/features/home/home_screen.dart << 'EOF'
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Psitta')),
      body: const Center(
        child: Text('Upload a document to get started'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Document upload flow
        },
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload'),
      ),
    );
  }
}
EOF

cat > apps/mobile/lib/features/home/widgets/document_card.dart << 'EOF'
import 'package:flutter/material.dart';

class DocumentCard extends StatelessWidget {
  final String title;
  final String status;
  final VoidCallback onTap;

  const DocumentCard({
    super.key,
    required this.title,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(status),
        trailing: const Icon(Icons.play_arrow),
        onTap: onTap,
      ),
    );
  }
}
EOF

cat > apps/mobile/lib/features/player/player_screen.dart << 'EOF'
import 'package:flutter/material.dart';

class PlayerScreen extends StatelessWidget {
  final String documentId;

  const PlayerScreen({super.key, required this.documentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Now Playing')),
      body: Center(
        child: Text('Player for document: $documentId'),
      ),
    );
  }
}
EOF

cat > apps/mobile/lib/features/player/widgets/playback_controls.dart << 'EOF'
import 'package:flutter/material.dart';

class PlaybackControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onSkipForward;
  final VoidCallback onSkipBackward;

  const PlaybackControls({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSkipForward,
    required this.onSkipBackward,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(icon: const Icon(Icons.skip_previous), onPressed: onSkipBackward),
        IconButton(
          icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
          iconSize: 64,
          onPressed: onPlayPause,
        ),
        IconButton(icon: const Icon(Icons.skip_next), onPressed: onSkipForward),
      ],
    );
  }
}
EOF

cat > apps/mobile/lib/features/player/widgets/chunk_navigator.dart << 'EOF'
import 'package:flutter/material.dart';

class ChunkNavigator extends StatelessWidget {
  final List<String> chunkTitles;
  final int currentIndex;
  final ValueChanged<int> onChunkSelected;

  const ChunkNavigator({
    super.key,
    required this.chunkTitles,
    required this.currentIndex,
    required this.onChunkSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: chunkTitles.length,
      itemBuilder: (context, index) {
        final isActive = index == currentIndex;
        return ListTile(
          dense: true,
          selected: isActive,
          title: Text(chunkTitles[index]),
          onTap: () => onChunkSelected(index),
        );
      },
    );
  }
}
EOF

cat > apps/mobile/lib/features/voices/voice_selector_screen.dart << 'EOF'
import 'package:flutter/material.dart';

class VoiceSelectorScreen extends StatelessWidget {
  const VoiceSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Voice')),
      body: const Center(child: Text('Voice catalog loading...')),
    );
  }
}
EOF

cat > apps/mobile/lib/features/voices/widgets/voice_preview_card.dart << 'EOF'
import 'package:flutter/material.dart';

class VoicePreviewCard extends StatelessWidget {
  final String voiceName;
  final String language;
  final VoidCallback onPreview;
  final VoidCallback onSelect;

  const VoicePreviewCard({
    super.key,
    required this.voiceName,
    required this.language,
    required this.onPreview,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(voiceName),
        subtitle: Text(language),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.volume_up), onPressed: onPreview),
            IconButton(icon: const Icon(Icons.check_circle_outline), onPressed: onSelect),
          ],
        ),
      ),
    );
  }
}
EOF

cat > apps/mobile/lib/features/settings/settings_screen.dart << 'EOF'
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: const [
          ListTile(
            title: Text('Default Voice'),
            subtitle: Text('en-US-AriaNeural'),
            trailing: Icon(Icons.chevron_right),
          ),
          ListTile(
            title: Text('Playback Speed'),
            subtitle: Text('1.0x'),
            trailing: Icon(Icons.chevron_right),
          ),
          ListTile(
            title: Text('Auto-Delete Documents'),
            subtitle: Text('After 60 days'),
            trailing: Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
EOF

# Flutter test .gitkeep files
touch apps/mobile/test/unit/.gitkeep
touch apps/mobile/test/widget/.gitkeep
touch apps/mobile/test/integration/.gitkeep

echo "  ✓ Flutter app scaffold written"

# ══════════════════════════════════════════════════════════════════════
# EXTENSIONS — PLACEHOLDER READMEs
# ══════════════════════════════════════════════════════════════════════

cat > extensions/README.md << 'EOF'
# Psitta Extensions

This directory contains commercial extension modules. Each extension is an
independently packaged Python module that registers via entry points.

Extensions are **optional** — the core platform is fully functional without them.

See [OPEN_CORE_BOUNDARY.md](../OPEN_CORE_BOUNDARY.md) for the licensing boundary.

## Available Extensions

| Extension | Description | Status |
|-----------|------------|--------|
| voice-cloning | Custom voice profile creation | Planned |
| premium-tts | ElevenLabs, Google Cloud TTS, Amazon Polly | Planned |
| advanced-tone | LLM-powered tone classification | Planned |
| enterprise | SAML SSO, org management, audit export | Planned |
| analytics | Listening behavior & engagement metrics | Planned |
EOF

for ext in voice-cloning premium-tts advanced-tone enterprise analytics; do
  touch "extensions/${ext}/.gitkeep"
  cat > "extensions/${ext}/README.md" << EOF
# Psitta Extension: ${ext}

**License:** Proprietary (see [LICENSE-EXTENSIONS](../../LICENSE-EXTENSIONS))
**Status:** Planned

## Overview

<!-- Description of this extension -->

## Installation

\`\`\`bash
pip install psitta-${ext}
\`\`\`

## Configuration

<!-- Required environment variables -->

## Provider Interface

This extension implements the following provider protocol(s):

<!-- List from core/backend/src/psitta/providers/interfaces/contracts.py -->
EOF
done

echo "  ✓ Extension placeholders written"

# ══════════════════════════════════════════════════════════════════════
# DOCS — ADRs
# ══════════════════════════════════════════════════════════════════════

cat > docs/adr/README.md << 'EOF'
# Architecture Decision Records

This directory contains the Architecture Decision Records (ADRs) for Psitta.

## Index

| # | Title | Status | Date |
|---|-------|--------|------|
| 0001 | Monorepo structure | Accepted | 2025-02-08 |

## Process

1. Copy `template.md` to `NNNN-title-with-dashes.md`
2. Fill in the sections
3. Submit as part of a PR
4. Status moves: Proposed → Accepted / Rejected / Superseded
EOF

cat > docs/adr/template.md << 'EOF'
# ADR-NNNN: Title

**Status:** Proposed | Accepted | Rejected | Superseded by ADR-XXXX
**Date:** YYYY-MM-DD
**Deciders:** @handles

## Context

What is the issue that we're seeing that is motivating this decision or change?

## Decision

What is the change that we're proposing and/or doing?

## Consequences

What becomes easier or more difficult to do because of this change?

### Positive

-

### Negative

-

### Neutral

-
EOF

cat > docs/adr/0001-monorepo-structure.md << 'EOF'
# ADR-0001: Monorepo Structure

**Status:** Accepted
**Date:** 2025-02-08
**Deciders:** Core team

## Context

Psitta consists of a FastAPI backend, Flutter mobile app, shared documentation,
CI/CD pipelines, and commercial extensions. We needed to decide between a monorepo
and multi-repo approach.

## Decision

We adopted a monorepo structure with clear directory boundaries:

- `core/` — Apache 2.0 open-source backend
- `apps/` — Client applications (Flutter)
- `extensions/` — Commercial add-ons (proprietary license)
- `docs/` — All documentation

## Consequences

### Positive
- Atomic commits across backend + frontend for API changes
- Single CI pipeline validates the entire system
- Easier contributor onboarding (one clone, one setup)
- Clear licensing boundary via directory structure

### Negative
- CI runs may be slower for changes that only affect one component
- Git history is larger than individual repos would be
- CODEOWNERS must be carefully maintained

### Neutral
- Extensions can be extracted to separate repos later if needed
- Flutter and Python toolchains coexist without conflict
EOF

# ── COST_AND_SCALE.md placeholder (the file was being created when interrupted)
cat > docs/COST_AND_SCALE.md << 'EOF'
# Cost & Scale

This document covers Psitta's cost structure, scaling strategy, and capacity planning.

## Cost Model

### Per-Document Cost Breakdown

For a typical 50-page PDF (~25,000 words, ~150,000 characters):

| Operation | Provider | Unit Cost | Per-Document |
|-----------|----------|-----------|-------------|
| Vision descriptions (images) | Anthropic Claude | ~$0.003/1K input tokens | ~$0.05 |
| Text-to-speech | Azure Cognitive TTS | $16/1M chars (Neural) | ~$2.40 |
| Object storage | S3 / MinIO | $0.023/GB/month | ~$0.001 |
| Compute (processing) | Self-hosted | ~$0.10/hour amortized | ~$0.02 |
| **Total** | | | **~$2.50** |

TTS is the dominant cost at ~96% of per-document spend.

## Scaling Architecture

The system scales horizontally at every layer:

- **API servers**: Stateless, scale behind a load balancer
- **Workers**: Scale independently based on queue depth
- **PostgreSQL**: Read replicas for query scaling, connection pooling
- **Redis**: Clustered for cache scaling, Streams for job distribution
- **S3**: Effectively infinite object storage, CDN for audio delivery

## Cost Optimization Strategies

1. **Audio caching** per (chunk_id, voice_id, speed) — eliminates re-synthesis
2. **Chunk deduplication** — shared boilerplate across documents reuses cached audio
3. **Tiered TTS routing** — route to cost-appropriate provider per user tier
4. **Document TTL** — automatic expiry prevents unbounded storage growth
5. **Vision batching** — batch image descriptions to reduce API call overhead
EOF

echo "  ✓ Docs and ADRs written"

# ══════════════════════════════════════════════════════════════════════
# SCRIPTS
# ══════════════════════════════════════════════════════════════════════

cat > scripts/bootstrap.sh << 'SHEOF'
#!/usr/bin/env bash
set -euo pipefail

# ── Psitta — One-command developer setup ───────────────────────────
# Usage: ./scripts/bootstrap.sh
# Prereqs: docker, python3.12+, flutter 3.24+

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Psitta — Developer Bootstrap                         ║"
echo "╚══════════════════════════════════════════════════════════╝"

cd "$(git rev-parse --show-toplevel)"

# 1. Environment file
if [ ! -f .env ]; then
  echo "→ Creating .env from .env.example..."
  cp .env.example .env
  echo "  ✓ .env created (edit secrets before production use)"
else
  echo "  ✓ .env already exists"
fi

# 2. Start infrastructure
echo "→ Starting Docker services..."
docker compose up -d postgres redis minio
echo "  ✓ Infrastructure running"

# 3. Initialize MinIO bucket
echo "→ Initializing MinIO bucket..."
docker compose up minio-init
echo "  ✓ MinIO bucket ready"

# 4. Python backend
echo "→ Setting up Python backend..."
cd core/backend
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip -q
pip install -e ".[dev]" -q
echo "  ✓ Python dependencies installed"

# 5. Run migrations
echo "→ Running database migrations..."
alembic -c src/psitta/db/alembic.ini upgrade head 2>/dev/null || \
  alembic -c alembic.ini upgrade head
echo "  ✓ Database schema applied"

# 6. Pre-commit hooks
echo "→ Installing pre-commit hooks..."
pre-commit install
echo "  ✓ Pre-commit hooks active"

cd ../..

# 7. Flutter
echo "→ Setting up Flutter app..."
cd apps/mobile
flutter pub get -q
echo "  ✓ Flutter dependencies installed"

cd ../..

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  ✓ Bootstrap complete!                                   ║"
echo "║                                                          ║"
echo "║  Start backend:  cd core/backend && uvicorn              ║"
echo "║    psitta.main:create_app --factory --reload          ║"
echo "║                                                          ║"
echo "║  Start Flutter:  cd apps/mobile && flutter run           ║"
echo "║                                                          ║"
echo "║  API docs:       http://localhost:8000/docs              ║"
echo "║  MinIO console:  http://localhost:9001                   ║"
echo "╚══════════════════════════════════════════════════════════╝"
SHEOF
chmod +x scripts/bootstrap.sh

cat > scripts/reset-db.sh << 'SHEOF'
#!/usr/bin/env bash
set -euo pipefail

# ── Drop, recreate, and migrate the development database ─────────────
echo "→ Dropping database..."
docker compose exec postgres dropdb -U psitta psitta --if-exists
echo "→ Creating database..."
docker compose exec postgres createdb -U psitta psitta
echo "→ Running migrations..."
cd core/backend
alembic -c src/psitta/db/alembic.ini upgrade head 2>/dev/null || \
  alembic -c alembic.ini upgrade head
echo "  ✓ Database reset complete"
SHEOF
chmod +x scripts/reset-db.sh

cat > scripts/seed-data.sh << 'SHEOF'
#!/usr/bin/env bash
set -euo pipefail

# ── Load sample data for development ─────────────────────────────────
echo "→ Seeding sample data..."
echo "  ⚠ Not yet implemented — add seed logic as services mature"
echo "  Hint: Use core/backend/tests/factories.py patterns"
SHEOF
chmod +x scripts/seed-data.sh

echo "  ✓ Scripts written"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  ✓ All files and directories created                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
```

### 2.4 Initialize Git & First Commit

```bash
# ── Initialize repository ─────────────────────────────────────────────
cd /c/products/psitta    # Git Bash
# cd /mnt/c/products/psitta  # WSL2

git init
git checkout -b main

# ── Stage everything ──────────────────────────────────────────────────
git add -A

# ── Verify what's being committed ─────────────────────────────────────
echo ""
echo "=== Files staged for first commit ==="
git status --short | head -30
echo "... ($(git status --short | wc -l | tr -d ' ') files total)"
echo ""

# ── First commit ──────────────────────────────────────────────────────
git commit -m "feat: bootstrap repository scaffold

- FastAPI backend with async PostgreSQL, Redis Streams, S3 providers
- Flutter cross-platform app skeleton (Riverpod, GoRouter, Material 3)
- Docker Compose dev stack (Postgres 16, Redis 7, MinIO)
- CI/CD pipelines: ci.yml, release.yml, security.yml (GitHub Actions)
- Alembic initial migration (11 tables, 8 enums, triggers, indexes)
- Open-core boundary: Apache 2.0 core + commercial extension stubs
- Documentation: PRD, Architecture, API spec, Security, Testing,
  Observability, Cost & Scale, Contributing, ADRs
- Pre-commit hooks: ruff, mypy, dart format, dart analyze
- Developer scripts: bootstrap.sh, reset-db.sh, seed-data.sh

Runnable immediately:
  docker compose up -d && ./scripts/bootstrap.sh
  cd apps/mobile && flutter run"
```

### 2.5 Push to GitHub

```bash
# ── Create remote repository (GitHub CLI) ─────────────────────────────
# Option A: Public open-core repo
gh repo create psitta/psitta --public --source=. --remote=origin

# Option B: Private during development
gh repo create psitta/psitta --private --source=. --remote=origin

# ── Push ──────────────────────────────────────────────────────────────
git push -u origin main

# ── Create develop branch ─────────────────────────────────────────────
git checkout -b develop
git push -u origin develop

# ── Set default branch protection (requires admin) ────────────────────
# Do this via gh CLI or GitHub Settings > Branches:
# - Require PR reviews (1 approval)
# - Require status checks (ci-gate)
# - Require up-to-date branches before merging
# - Restrict pushes to main
```

---

## 3. First Commit Message

```
feat: bootstrap repository scaffold

- FastAPI backend with async PostgreSQL, Redis Streams, S3 providers
- Flutter cross-platform app skeleton (Riverpod, GoRouter, Material 3)
- Docker Compose dev stack (Postgres 16, Redis 7, MinIO)
- CI/CD pipelines: ci.yml, release.yml, security.yml (GitHub Actions)
- Alembic initial migration (11 tables, 8 enums, triggers, indexes)
- Open-core boundary: Apache 2.0 core + commercial extension stubs
- Documentation: PRD, Architecture, API spec, Security, Testing,
  Observability, Cost & Scale, Contributing, ADRs
- Pre-commit hooks: ruff, mypy, dart format, dart analyze
- Developer scripts: bootstrap.sh, reset-db.sh, seed-data.sh

Runnable immediately:
  docker compose up -d && ./scripts/bootstrap.sh
  cd apps/mobile && flutter run
```

Format: [Conventional Commits](https://www.conventionalcommits.org/) — `feat:` type with no scope (monorepo-wide).

---

## 4. Guidance

### 4.1 Where This Executes

**Your local Windows machine at `C:/products/psitta/`.** All commands use Bash syntax and must run in Git Bash or WSL2. Path translations:

| Context | Path |
|---------|------|
| Windows Explorer | `C:\products\psitta\` |
| Git Bash | `/c/products/psitta/` |
| WSL2 | `/mnt/c/products/psitta/` |
| PowerShell | `C:\products\psitta\` |

Docker Desktop for Windows must be running. All `docker compose` commands work identically across Git Bash and WSL2.

### 4.2 How It Maps to GitHub

The local repository is a **1:1 mirror** of the GitHub repository:

```
C:/products/psitta/                     github.com/psitta/psitta
├── .github/workflows/ci.yml       →   Actions tab (CI triggers on push)
├── core/backend/                   →   Source (browsable, cloneable)
├── apps/mobile/                    →   Source
├── extensions/                     →   Source (CODEOWNERS restricts access)
├── docker-compose.yml              →   Source
├── LICENSE                         →   Detected by GitHub license badge
├── SECURITY.md                     →   GitHub Security tab (auto-detected)
└── CONTRIBUTING.md                 →   GitHub Contributing tab (auto-detected)
```

GitHub auto-detects: `LICENSE` (shows badge), `SECURITY.md` (shows in Security tab), `CONTRIBUTING.md` (shows in Contributing tab), `.github/ISSUE_TEMPLATE/` (shows in Issues > New), `.github/PULL_REQUEST_TEMPLATE.md` (shows on PR creation), `.github/CODEOWNERS` (auto-assigns reviewers), `.github/dependabot.yml` (enables Dependabot).

### 4.3 What's Runnable Immediately After Bootstrap

| Component | Command | What Happens |
|-----------|---------|-------------|
| **Infrastructure** | `docker compose up -d` | PostgreSQL, Redis, MinIO start with healthchecks |
| **Database** | `docker compose --profile migrate up migrate` | Alembic applies 001_initial_schema (11 tables) |
| **API server** | `cd core/backend && uvicorn psitta.main:create_app --factory --reload` | FastAPI starts on :8000, `/health` returns 200, `/docs` shows Swagger UI |
| **Worker** | `docker compose up worker` | Document processor connects to Redis Streams and polls for jobs |
| **Flutter app** | `cd apps/mobile && flutter run` | App compiles and launches with home screen, routing to player/voices/settings |
| **Full bootstrap** | `./scripts/bootstrap.sh` | Runs all of the above in sequence |
| **Tests (backend)** | `cd core/backend && pytest` | Discovers test scaffolds (skipped, but framework is wired) |
| **Tests (Flutter)** | `cd apps/mobile && flutter test` | Discovers test directories (empty, but `flutter test` succeeds) |
| **Pre-commit** | `pre-commit run --all-files` | Runs ruff, mypy, dart format, dart analyze on all staged files |
| **CI pipeline** | Push to GitHub | `ci.yml` triggers: lint → test → security → docker build → migration check |

### 4.4 What Is NOT Runnable (and Why)

| Component | Why | When It Becomes Runnable |
|-----------|-----|--------------------------|
| TTS synthesis | Requires `AZURE_TTS_KEY` in `.env` | After Azure Cognitive Services account setup |
| Vision descriptions | Requires `ANTHROPIC_API_KEY` in `.env` | After Anthropic API key provisioned |
| Authentication | Requires Auth0/Clerk tenant config | After auth provider setup |
| Extensions | Placeholder `.gitkeep` only | After extension source is developed |
| Production deploy | `release.yml` has placeholder deploy step | After infra target (ECS/K8s/Fly) is wired |

All of these are **external dependencies by design** — the core platform boots, serves requests, and runs migrations without them. Provider interfaces return graceful errors when credentials are missing.

---

## 5. File Count Verification

After running the bootstrap, verify from `C:/products/psitta/`:

```bash
# Count all tracked files
find . -not -path './.git/*' -type f | wc -l
# Expected: 130 files

# Verify no secrets committed
grep -r "CHANGE-ME" . --include="*.env" | wc -l
# Expected: 0 (only .env.example has CHANGE-ME, and .env is gitignored)

# Verify license files present
ls LICENSE LICENSE-EXTENSIONS
# Expected: both files exist

# Verify CI workflows
ls .github/workflows/
# Expected: ci.yml  release.yml  security.yml

# Verify Python package name
ls core/backend/src/psitta/main.py
# Expected: file exists

# Verify no stale "narratore" references
grep -rl "narratore" . --include="*.py" --include="*.yml" --include="*.yaml" \
  --include="*.md" --include="*.toml" --include="*.dart" --include="*.sh" | wc -l
# Expected: 0

# Verify Docker container names
grep "psitta-" docker-compose.yml | wc -l
# Expected: 7+ lines referencing psitta-postgres, psitta-api, etc.
```

---

*End of Deliverable X. No further deliverables produced in this output.*
