"""set_config.py — Admin CLI for the remote client control-plane config.

Reads/writes the single ``app_config`` row (key ``client_config``, migration
032) that ``GET /config`` serves to the desktop client: the minimum-supported
version floor, the recommended-version nudge, and feature flags / kill
switches. Changing a value here takes effect on the NEXT client request — no
client release and no backend redeploy (remote control plane / deploy !=
release).

Subcommands
-----------
  show
      Print the current effective config (defaults if no row exists).

  set [--min-version X] [--recommended-version X]
      [--flag key=value ...] [--unset-flag key ...] [--dry-run]
      Merge the given changes into the config document and upsert it. Flag
      values parse as true/false, JSON, else a bare string. --dry-run prints
      the before/after diff without writing.

Run modes (mirrors scripts/grant_tester.py)
--------------------------------------------
  Production one-off ECS task::

      aws ecs run-task --cluster psitta-cluster \\
          --task-definition psitta-api --profile psitta-prod \\
          --region us-east-1 \\
          --overrides '{"containerOverrides":[{"name":"psitta-api",
            "command":["python","scripts/set_config.py","set",
                       "--min-version","1.1.0","--dry-run"]}]}'

  Local (POSTGRES_* env vars or APP_SECRETS point at the target DB)::

      python scripts/set_config.py show
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import os
import sys
from typing import Any

logging.basicConfig(
    format="%(asctime)s  %(levelname)-7s  %(message)s",
    level=logging.INFO,
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("set_config")

CONFIG_KEY = "client_config"
DEFAULTS: dict[str, Any] = {
    "minimum_supported_version": "0.0.0",
    "recommended_version": "0.0.0",
    "flags": {},
}


# ── Postgres config resolution (matches grant_tester.py / list_accounts.py) ──
def _resolve_pg_config() -> dict[str, Any]:
    secrets: dict[str, Any] = {}
    raw = os.environ.get("APP_SECRETS")
    if raw:
        try:
            secrets = json.loads(raw)
        except json.JSONDecodeError:
            log.warning("app_secrets_invalid_json  ignoring")

    def cfg(key: str, default: Any = None) -> Any:
        return os.environ.get(key) or secrets.get(key) or default

    host = cfg("POSTGRES_HOST")
    if not host:
        raise SystemExit("ERROR: no Postgres host -- set POSTGRES_HOST or APP_SECRETS")
    return {
        "host": host,
        "port": int(cfg("POSTGRES_PORT", 5432)),
        "user": cfg("POSTGRES_USER"),
        "password": cfg("POSTGRES_PASSWORD"),
        "database": cfg("POSTGRES_DB"),
    }


def _parse_flag_value(raw: str) -> Any:
    low = raw.strip().lower()
    if low == "true":
        return True
    if low == "false":
        return False
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return raw


async def _read_config(conn: Any) -> dict[str, Any]:
    """Current config document merged over defaults. Empty/missing → defaults."""
    merged = {**DEFAULTS, "flags": dict(DEFAULTS["flags"])}
    try:
        row = await conn.fetchval(
            "SELECT value FROM app_config WHERE key = $1", CONFIG_KEY
        )
    except Exception as exc:  # table missing before migration 032
        log.warning("app_config_unavailable  error=%s", str(exc).splitlines()[0])
        return merged
    if row:
        val = json.loads(row) if isinstance(row, str) else row
        if isinstance(val, dict):
            merged.update({k: val[k] for k in DEFAULTS if k in val})
            if isinstance(val.get("flags"), dict):
                merged["flags"] = val["flags"]
    return merged


async def run(args: argparse.Namespace) -> int:
    import asyncpg  # noqa: PLC0415 -- lazy import keeps --help fast

    cfg = _resolve_pg_config()
    log.info("pg_connect  host=%s db=%s", cfg["host"], cfg["database"])
    conn = await asyncpg.connect(**cfg)
    try:
        current = await _read_config(conn)

        if args.command == "show":
            print(json.dumps(current, indent=2, sort_keys=True))  # noqa: T201
            return 0

        # command == "set": build the new document from the current one.
        new = {**current, "flags": dict(current["flags"])}
        if args.min_version is not None:
            new["minimum_supported_version"] = args.min_version
        if args.recommended_version is not None:
            new["recommended_version"] = args.recommended_version
        for pair in args.flag or []:
            if "=" not in pair:
                raise SystemExit(f"ERROR: --flag expects key=value, got {pair!r}")
            k, v = pair.split("=", 1)
            new["flags"][k.strip()] = _parse_flag_value(v)
        for k in args.unset_flag or []:
            new["flags"].pop(k.strip(), None)

        print("current:", json.dumps(current, sort_keys=True))  # noqa: T201
        print("new:    ", json.dumps(new, sort_keys=True))  # noqa: T201

        if new == current:
            log.info("no_change")
            return 0
        if args.dry_run:
            log.info("dry_run  no write performed")
            return 0

        await conn.execute(
            "INSERT INTO app_config (key, value, updated_at) "
            "VALUES ($1, $2::jsonb, NOW()) "
            "ON CONFLICT (key) DO UPDATE SET value = $2::jsonb, updated_at = NOW()",
            CONFIG_KEY,
            json.dumps(new),
        )
        log.info("config_updated  key=%s", CONFIG_KEY)
        return 0
    finally:
        await conn.close()


def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Manage the client control-plane config.")
    sub = p.add_subparsers(dest="command", required=True)
    sub.add_parser("show", help="Print the current effective config.")
    s = sub.add_parser("set", help="Update version floor / recommended / flags.")
    s.add_argument("--min-version", dest="min_version")
    s.add_argument("--recommended-version", dest="recommended_version")
    s.add_argument("--flag", action="append", metavar="KEY=VALUE")
    s.add_argument("--unset-flag", action="append", metavar="KEY")
    s.add_argument("--dry-run", action="store_true")
    return p


if __name__ == "__main__":
    _args = _build_parser().parse_args(sys.argv[1:])
    if not hasattr(_args, "min_version"):
        _args.min_version = None
        _args.recommended_version = None
        _args.flag = None
        _args.unset_flag = None
        _args.dry_run = False
    sys.exit(asyncio.run(run(_args)))
