"""Tester Digest Lambda — daily 8am MT summary of new tester installs.

Triggered by EventBridge Scheduler (cron: 0 8 * * ? * in America/Denver,
all 7 days). Reads RDS Postgres via psycopg2 + IAM auth (no DB password),
runs the two canonical Item 9 queries against users JOIN tester_allowlist,
renders Psitta-branded HTML + text email, and POSTs to Resend with the
explicit User-Agent header required by KL 2026-05-10.

Sends every day, including 0-install days ("no new installs today" +
7-day trend). Re-raises on any failure (RDS connect, RDS query, Secrets
Manager, Resend HTTP) so the failed async invocation lands in the SQS
DLQ for forensics. EventBridge Scheduler does not retry by default;
the DLQ is the authoritative failure trail.

Runtime: python3.12 (psycopg2-binary packaged via Terraform build step
or Lambda Layer — see lambda_tester_digest.tf).
Egress: api.resend.com (TLS), RDS (in-VPC private subnet, port 5432).
Secrets: psitta/prod/resend-api-key (shared with welcome_email Lambda).
Auth to RDS: IAM via rds-db:connect — DB user must hold the rds_iam role.
"""
from __future__ import annotations

import html
import json
import logging
import os
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

import boto3
import botocore.exceptions
import psycopg2

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

# ── Module-scope state (cached across warm invocations) ──────────────────
_SECRETS_CLIENT = boto3.client("secretsmanager")
_RDS_CLIENT = boto3.client("rds")
_RESEND_API_KEY: Optional[str] = None  # populated lazily, cached
_RESEND_ENDPOINT = "https://api.resend.com/emails"
_HTTP_TIMEOUT_SECONDS = 8

_MODULE_DIR = Path(__file__).resolve().parent
_TEMPLATE_HTML = (_MODULE_DIR / "template_digest.html").read_text(encoding="utf-8")
_TEMPLATE_TEXT = (_MODULE_DIR / "template_digest.txt").read_text(encoding="utf-8")

# ── Canonical SQL (Phase B architecture decision, locked) ────────────────
# Both queries gate on tester_allowlist active rows (NOT revoked, NOT expired)
# so a revoked tester does not appear in today's count even if their
# users.created_at falls inside the window.
_TODAY_TESTERS_SQL = """
SELECT u.email, u.display_name, u.created_at, t.granted_at
FROM users u
JOIN tester_allowlist t ON lower(u.email) = t.email
WHERE u.created_at > NOW() - INTERVAL '24 hours'
  AND t.revoked_at IS NULL
  AND t.expires_at > NOW()
ORDER BY u.created_at DESC
"""

_SEVEN_DAY_TREND_SQL = """
SELECT date_trunc('day', u.created_at)::date AS day, COUNT(*) AS install_count
FROM users u
JOIN tester_allowlist t ON lower(u.email) = t.email
WHERE u.created_at > NOW() - INTERVAL '7 days'
  AND t.revoked_at IS NULL
  AND t.expires_at > NOW()
GROUP BY 1
ORDER BY day DESC
"""


# ── PII-safe logging helper (matches welcome_email pattern) ──────────────
def _mask_email(email: str) -> str:
    """Forensics-safe rendering: first char + @domain. CloudWatch logs only.

    The email body itself (sent to luis@psitta.ai) contains full
    addresses by design — this digest's whole purpose is to surface who
    just installed.
    """
    if not email or "@" not in email:
        return "<invalid>"
    local, _, domain = email.partition("@")
    head = local[0] if local else "?"
    return f"{head}***@{domain}"


# ── Secrets / RDS / Resend wiring ────────────────────────────────────────
def _load_api_key() -> str:
    """Fetch Resend API key from Secrets Manager. Cached at module scope."""
    global _RESEND_API_KEY
    if _RESEND_API_KEY is not None:
        return _RESEND_API_KEY

    secret_name = os.environ["RESEND_SECRET_NAME"]
    response = _SECRETS_CLIENT.get_secret_value(SecretId=secret_name)
    _RESEND_API_KEY = response["SecretString"].strip()
    return _RESEND_API_KEY


def _connect_rds():
    """Open a Postgres connection using RDS IAM auth.

    The auth token replaces the password — no DB password is read from
    Secrets Manager or env. The Lambda's execution role must hold
    rds-db:connect on the resource ARN
    arn:aws:rds-db:<region>:<account>:dbuser:<resource-id>/<rds-user>,
    AND the DB user must have the rds_iam role granted.

    sslmode='require' is sufficient inside the VPC private network path
    (RDS is in a private subnet, not internet-reachable). Upgrade to
    'verify-full' with explicit sslrootcert if SOC 2 evidence demands
    full chain verification — out of scope for the alpha digest.
    """
    host = os.environ["RDS_HOST"]
    port = int(os.environ.get("RDS_PORT", "5432"))
    db_name = os.environ["RDS_DB_NAME"]
    user = os.environ["RDS_USER"]
    region = (
        os.environ.get("AWS_REGION")
        or os.environ.get("AWS_DEFAULT_REGION")
        or "us-east-1"
    )

    token = _RDS_CLIENT.generate_db_auth_token(
        DBHostname=host, Port=port, DBUsername=user, Region=region
    )
    return psycopg2.connect(
        host=host,
        port=port,
        dbname=db_name,
        user=user,
        password=token,
        sslmode="require",
        connect_timeout=10,
    )


def _post_resend(api_key: str, payload: dict) -> dict:
    """POST the rendered email to Resend. Raises on HTTP 4xx/5xx or network error."""
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(  # noqa: S310 — fixed https URL, not user-supplied
        _RESEND_ENDPOINT,
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            # Cloudflare in front of api.resend.com 403s the default
            # "Python-urllib/3.x" UA as a banned bot signature (KL 2026-05-10).
            "User-Agent": "psitta-tester-digest/1.0 (+https://psitta.ai)",
        },
    )
    with urllib.request.urlopen(req, timeout=_HTTP_TIMEOUT_SECONDS) as resp:  # noqa: S310
        raw = resp.read().decode("utf-8")
        return json.loads(raw)


# ── Query execution ──────────────────────────────────────────────────────
def _fetch_today_testers(conn) -> list[dict]:
    with conn.cursor() as cur:
        cur.execute(_TODAY_TESTERS_SQL)
        rows = cur.fetchall()
    return [
        {
            "email": r[0],
            "display_name": r[1] or "",
            "created_at": r[2],
            "granted_at": r[3],
        }
        for r in rows
    ]


def _fetch_seven_day_trend(conn) -> list[dict]:
    with conn.cursor() as cur:
        cur.execute(_SEVEN_DAY_TREND_SQL)
        rows = cur.fetchall()
    return [{"day": r[0], "count": r[1]} for r in rows]


# ── Template rendering ──────────────────────────────────────────────────
def _subject_line(today_count: int) -> str:
    if today_count == 0:
        return "Psitta tester digest — no new installs in last 24h"
    if today_count == 1:
        return "Psitta tester digest — 1 new install in last 24h"
    return f"Psitta tester digest — {today_count} new installs in last 24h"


def _summary_line(today_count: int, seven_day_total: int) -> str:
    if today_count == 0:
        return (
            "No new testers installed Psitta in the last 24 hours. "
            f"(7-day total: {seven_day_total})"
        )
    word = "install" if today_count == 1 else "installs"
    return (
        f"{today_count} new {word} in the last 24 hours. "
        f"(7-day total: {seven_day_total})"
    )


def _render_today_html(testers: list[dict]) -> str:
    if not testers:
        return (
            '<p style="margin: 0; color: #555;">'
            "<em>No new installs in the last 24 hours.</em></p>"
        )
    rows = "\n".join(
        "<tr>"
        f'<td style="padding: 6px 12px; border: 1px solid #e5e5e5;">{html.escape(t["email"])}</td>'
        f'<td style="padding: 6px 12px; border: 1px solid #e5e5e5;">{html.escape(t["display_name"])}</td>'
        f'<td style="padding: 6px 12px; border: 1px solid #e5e5e5;">{t["created_at"].strftime("%Y-%m-%d %H:%M UTC")}</td>'
        "</tr>"
        for t in testers
    )
    return (
        '<table style="border-collapse: collapse; width: 100%; font-size: 14px;">'
        "<thead><tr>"
        '<th style="padding: 6px 12px; border: 1px solid #e5e5e5; background: #f7f7f7; text-align: left;">Email</th>'
        '<th style="padding: 6px 12px; border: 1px solid #e5e5e5; background: #f7f7f7; text-align: left;">Display name</th>'
        '<th style="padding: 6px 12px; border: 1px solid #e5e5e5; background: #f7f7f7; text-align: left;">First launch (UTC)</th>'
        "</tr></thead>"
        f"<tbody>{rows}</tbody>"
        "</table>"
    )


def _render_today_text(testers: list[dict]) -> str:
    if not testers:
        return "No new installs in the last 24 hours."
    lines = [
        f"{'Email':<40} {'Display name':<25} {'First launch (UTC)':<20}"
    ]
    for t in testers:
        ts = t["created_at"].strftime("%Y-%m-%d %H:%M UTC")
        lines.append(f"{t['email']:<40} {t['display_name']:<25} {ts:<20}")
    return "\n".join(lines)


def _render_trend_html(trend: list[dict]) -> str:
    if not trend:
        return (
            '<p style="margin: 0; color: #555;">'
            "<em>No installs in the last 7 days.</em></p>"
        )
    rows = "\n".join(
        "<tr>"
        f'<td style="padding: 6px 12px; border: 1px solid #e5e5e5;">{r["day"].isoformat()}</td>'
        f'<td style="padding: 6px 12px; border: 1px solid #e5e5e5; text-align: right;">{r["count"]}</td>'
        "</tr>"
        for r in trend
    )
    return (
        '<table style="border-collapse: collapse; font-size: 14px;">'
        "<thead><tr>"
        '<th style="padding: 6px 12px; border: 1px solid #e5e5e5; background: #f7f7f7; text-align: left;">Day</th>'
        '<th style="padding: 6px 12px; border: 1px solid #e5e5e5; background: #f7f7f7; text-align: right;">Installs</th>'
        "</tr></thead>"
        f"<tbody>{rows}</tbody>"
        "</table>"
    )


def _render_trend_text(trend: list[dict]) -> str:
    if not trend:
        return "No installs in the last 7 days."
    lines = [f"{'Day':<12}  {'Installs':>8}"]
    for r in trend:
        lines.append(f"{r['day'].isoformat():<12}  {r['count']:>8}")
    return "\n".join(lines)


def _render(template: str, replacements: dict[str, str]) -> str:
    out = template
    for k, v in replacements.items():
        out = out.replace("{{" + k + "}}", v)
    return out


# ── Entry point ──────────────────────────────────────────────────────────
def lambda_handler(event: dict, context: object) -> dict:
    """EventBridge Scheduler invocation. Sends the daily tester digest.

    Always sends — even on 0-install days. The event arg is unused
    (Scheduler invocations carry no actionable payload here); accepting
    it preserves the canonical Lambda handler signature.
    """
    logger.info("tester_digest.start")

    # 1) RDS — query both result sets in a single connection.
    try:
        conn = _connect_rds()
    except (psycopg2.Error, KeyError) as exc:
        logger.error("tester_digest.failed reason=rds_connect err=%s", exc)
        raise

    try:
        try:
            today = _fetch_today_testers(conn)
            trend = _fetch_seven_day_trend(conn)
        except psycopg2.Error as exc:
            logger.error("tester_digest.failed reason=rds_query err=%s", exc)
            raise
    finally:
        conn.close()

    today_count = len(today)
    seven_day_total = sum(r["count"] for r in trend)
    logger.info(
        "tester_digest.queried today=%d seven_day_total=%d",
        today_count, seven_day_total,
    )

    # 2) Render templates.
    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    html_replacements = {
        "summary_line": _summary_line(today_count, seven_day_total),
        "today_section": _render_today_html(today),
        "trend_section": _render_trend_html(trend),
        "generated_at_utc": generated_at,
    }
    text_replacements = {
        "summary_line": _summary_line(today_count, seven_day_total),
        "today_section": _render_today_text(today),
        "trend_section": _render_trend_text(trend),
        "generated_at_utc": generated_at,
    }
    html_body = _render(_TEMPLATE_HTML, html_replacements)
    text_body = _render(_TEMPLATE_TEXT, text_replacements)

    # 3) Resend POST.
    payload = {
        "from": os.environ["FROM_ADDRESS"],
        "to": [os.environ["TO_ADDRESS"]],
        "subject": _subject_line(today_count),
        "html": html_body,
        "text": text_body,
    }

    try:
        api_key = _load_api_key()
        result = _post_resend(api_key, payload)
    except urllib.error.HTTPError as exc:
        try:
            err_body = exc.read().decode("utf-8", errors="replace")[:500]
        except (OSError, AttributeError):
            err_body = "<no body>"
        logger.error(
            "tester_digest.failed reason=resend_http status=%s body=%s",
            exc.code, err_body,
        )
        raise
    except urllib.error.URLError as exc:
        logger.error(
            "tester_digest.failed reason=resend_network err=%s", exc.reason,
        )
        raise
    except json.JSONDecodeError as exc:
        logger.error(
            "tester_digest.failed reason=resend_bad_json err=%s", exc.msg,
        )
        raise
    except botocore.exceptions.ClientError as exc:
        code = exc.response.get("Error", {}).get("Code", "Unknown")
        logger.error(
            "tester_digest.failed reason=secrets err=%s", code,
        )
        raise

    message_id = result.get("id", "<no-id>")
    masked_recipients = ",".join(_mask_email(t) for t in payload["to"])
    logger.info(
        "tester_digest.ok today=%d seven_day_total=%d to=%s message_id=%s",
        today_count, seven_day_total, masked_recipients, message_id,
    )
    return {
        "today_count": today_count,
        "seven_day_total": seven_day_total,
        "message_id": message_id,
    }
