"""Build helper for the psitta-tester-digest Lambda zip.

Invoked by null_resource.tester_digest_build in lambda_tester_digest.tf via
`python -m` so the build step is portable across Windows/macOS/Linux without
depending on a bash interpreter being on PATH.

Steps:
  1. Wipe `infra/terraform/.build/tester_digest_pkg/` (start clean).
  2. Copy the three source files from `infra/lambda/tester_digest/` into the
     build dir.
  3. pip-install psycopg2-binary==2.9.9 into the build dir with
     --platform manylinux2014_x86_64 --python-version 3.12 so the Linux
     wheel ships even when Terraform runs on Windows.

The build dir is then zipped by `data.archive_file.tester_digest` and
uploaded as the Lambda deployment package. requirements.txt is NOT copied
into the zip (it's documentation; the deps are already vendored).
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SRC_DIR = HERE.parent / "lambda" / "tester_digest"
BUILD_DIR = HERE / ".build" / "tester_digest_pkg"

SOURCE_FILES = (
    "handler.py",
    "template_digest.html",
    "template_digest.txt",
)

PSYCOPG2_PIN = "psycopg2-binary==2.9.9"


def main() -> int:
    if BUILD_DIR.exists():
        shutil.rmtree(BUILD_DIR)
    BUILD_DIR.mkdir(parents=True)

    for fname in SOURCE_FILES:
        src = SRC_DIR / fname
        if not src.is_file():
            print(f"build_tester_digest: missing source file {src}", file=sys.stderr)
            return 1
        shutil.copy(src, BUILD_DIR / fname)

    # --platform + --python-version + --only-binary forces pip to fetch the
    # manylinux2014 cp312 wheel rather than the host-platform wheel.
    # --no-deps because psycopg2-binary has no Python deps; bundling extras
    # would only bloat the zip.
    cmd = [
        sys.executable, "-m", "pip", "install",
        "--platform", "manylinux2014_x86_64",
        "--python-version", "3.12",
        "--target", str(BUILD_DIR),
        "--only-binary=:all:",
        "--no-deps",
        PSYCOPG2_PIN,
    ]
    print("build_tester_digest: " + " ".join(cmd))
    return subprocess.call(cmd)


if __name__ == "__main__":
    sys.exit(main())
