"""Build helper for the psitta-db-bootstrap one-time Lambda zip.

Mirrors build_tester_digest.py exactly with two path swaps. Invoked by
null_resource.db_bootstrap_build in lambda_db_bootstrap.tf via
`python` so the build step is portable across Windows/macOS/Linux
without depending on a bash interpreter being on PATH.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SRC_DIR = HERE.parent / "lambda" / "db_bootstrap"
BUILD_DIR = HERE / ".build" / "db_bootstrap_pkg"

SOURCE_FILES = ("handler.py",)

PSYCOPG2_PIN = "psycopg2-binary==2.9.9"


def main() -> int:
    if BUILD_DIR.exists():
        shutil.rmtree(BUILD_DIR)
    BUILD_DIR.mkdir(parents=True)

    for fname in SOURCE_FILES:
        src = SRC_DIR / fname
        if not src.is_file():
            print(f"build_db_bootstrap: missing source file {src}", file=sys.stderr)
            return 1
        shutil.copy(src, BUILD_DIR / fname)

    cmd = [
        sys.executable, "-m", "pip", "install",
        "--platform", "manylinux2014_x86_64",
        "--python-version", "3.12",
        "--target", str(BUILD_DIR),
        "--only-binary=:all:",
        "--no-deps",
        PSYCOPG2_PIN,
    ]
    print("build_db_bootstrap: " + " ".join(cmd))
    return subprocess.call(cmd)


if __name__ == "__main__":
    sys.exit(main())
