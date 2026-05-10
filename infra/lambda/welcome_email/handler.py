"""Welcome Email Lambda — Cognito Post-Confirmation trigger.

Fires exactly once per email-verified Cognito signup. Reads the Resend API
key from AWS Secrets Manager (cached at module scope so warm invocations
skip the round trip), renders Template D with a {{name}} merge field
derived from the email local-part, and POSTs to the Resend transactional
email API. On any Resend HTTP error or network exception the handler
re-raises so Cognito's async-trigger machinery routes the failed event to
the SQS DLQ for forensics. The handler always returns the original event
unchanged so the Cognito auth flow is never blocked by email-send failure.

Runtime: python3.12 (boto3 is bundled — no zip dependency).
Egress: api.resend.com (TLS, default urllib certificate validation).
Secrets: psitta/prod/resend-api-key (read-only via task IAM role).
"""
from __future__ import annotations

import json
import logging
import os
import urllib.error
import urllib.request
from pathlib import Path
from typing import Optional

import boto3
import botocore.exceptions

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

_SECRETS_CLIENT = boto3.client("secretsmanager")
_RESEND_API_KEY: Optional[str] = None  # populated lazily, cached across invocations
_RESEND_ENDPOINT = "https://api.resend.com/emails"
_HTTP_TIMEOUT_SECONDS = 8

_MODULE_DIR = Path(__file__).resolve().parent
_TEMPLATE_HTML = (_MODULE_DIR / "template_d.html").read_text(encoding="utf-8")
_TEMPLATE_TEXT = (_MODULE_DIR / "template_d.txt").read_text(encoding="utf-8")
_SUBJECT = "Welcome to Psitta — your alpha access is active"


def _mask_email(email: str) -> str:
    """Return a forensics-safe rendering of an email: first char + @domain."""
    if not email or "@" not in email:
        return "<invalid>"
    local, _, domain = email.partition("@")
    head = local[0] if local else "?"
    return f"{head}***@{domain}"


def _derive_name(email: str) -> str:
    """Title-case the first token of the email local-part for the greeting.

    "alice.smith@x.com"  -> "Alice"
    "alice_smith@x.com"  -> "Alice"
    "alice@x.com"        -> "Alice"
    Returns "" if the email is malformed; caller falls back to "Hey there,".
    """
    if not email or "@" not in email:
        return ""
    local = email.partition("@")[0]
    if not local:
        return ""
    # Split on the common name separators in email local-parts.
    first_token = local.replace("_", ".").replace("-", ".").split(".")[0]
    if not first_token:
        return ""
    return first_token[:1].upper() + first_token[1:].lower()


def _render(template: str, name: str) -> str:
    """Substitute the {{name}} merge field. Greeting is name-aware.

    With a name: replaces "Hey {{name}}," verbatim from the template.
    Without:     replaces the same line with "Hey there," (no name).
    """
    if name:
        greeting = f"Hey {name},"
    else:
        greeting = "Hey there,"
    return template.replace("Hey {{name}},", greeting)


def _load_api_key() -> str:
    """Fetch the Resend API key from Secrets Manager. Cached at module scope.

    The secret is stored as a plain string (not JSON) because it has only
    one value; AWS SecretString returns the literal key.
    """
    global _RESEND_API_KEY
    if _RESEND_API_KEY is not None:
        return _RESEND_API_KEY

    secret_name = os.environ["RESEND_SECRET_NAME"]
    response = _SECRETS_CLIENT.get_secret_value(SecretId=secret_name)
    _RESEND_API_KEY = response["SecretString"].strip()
    return _RESEND_API_KEY


def _post_resend(api_key: str, payload: dict) -> dict:
    """POST the rendered email to Resend. Raises on HTTP 4xx/5xx or network error.

    Returns the parsed JSON response on success (Resend includes a message id).
    """
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
            # "Python-urllib/3.x" UA as a banned bot signature (error 1010).
            "User-Agent": "psitta-welcome-email/1.0 (+https://psitta.ai)",
        },
    )
    with urllib.request.urlopen(req, timeout=_HTTP_TIMEOUT_SECONDS) as resp:  # noqa: S310
        raw = resp.read().decode("utf-8")
        return json.loads(raw)


def lambda_handler(event: dict, context: object) -> dict:
    """Cognito Post-Confirmation trigger. Sends the welcome email once per signup.

    On Resend success: logs welcome_email.send.ok with the message id.
    On Resend HTTP error / network exception / Secrets Manager error: logs
    welcome_email.send.failed and re-raises so the failed invocation lands
    in the SQS DLQ. Cognito's auth flow is unaffected because async
    Post-Confirmation failures do not block signup.
    """
    sub = event.get("userName", "<unknown>")
    attrs = (event.get("request") or {}).get("userAttributes") or {}

    try:
        email = attrs["email"]
    except KeyError:
        logger.error("welcome_email.send.failed reason=no_email sub=%s", sub)
        raise

    name = _derive_name(email)
    masked = _mask_email(email)
    logger.info("welcome_email.send.start sub=%s email=%s named=%s", sub, masked, bool(name))

    payload = {
        "from": os.environ["FROM_ADDRESS"],
        "to": [email],
        "subject": _SUBJECT,
        "html": _render(_TEMPLATE_HTML, name),
        "text": _render(_TEMPLATE_TEXT, name),
    }

    try:
        api_key = _load_api_key()
        result = _post_resend(api_key, payload)
    except urllib.error.HTTPError as exc:
        # 4xx and 5xx both land here. Read body once for forensics; never log api_key.
        try:
            err_body = exc.read().decode("utf-8", errors="replace")[:500]
        except (OSError, AttributeError):
            err_body = "<no body>"
        logger.error(
            "welcome_email.send.failed sub=%s email=%s status=%s body=%s",
            sub, masked, exc.code, err_body,
        )
        raise
    except urllib.error.URLError as exc:
        logger.error(
            "welcome_email.send.failed sub=%s email=%s reason=network err=%s",
            sub, masked, exc.reason,
        )
        raise
    except json.JSONDecodeError as exc:
        logger.error(
            "welcome_email.send.failed sub=%s email=%s reason=bad_json err=%s",
            sub, masked, exc.msg,
        )
        raise
    except botocore.exceptions.ClientError as exc:
        # Secrets Manager fetch failed (IAM, throttle, missing secret).
        code = exc.response.get("Error", {}).get("Code", "Unknown")
        logger.error(
            "welcome_email.send.failed sub=%s email=%s reason=secrets err=%s",
            sub, masked, code,
        )
        raise

    message_id = result.get("id", "<no-id>")
    logger.info(
        "welcome_email.send.ok sub=%s email=%s message_id=%s",
        sub, masked, message_id,
    )
    return event
