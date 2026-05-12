"""ONE-TIME DB Bootstrap Lambda — creates the psitta_api_digest role.

Reads RDS master credentials from `psitta/prod/app-secrets` (the bundled
app-wide secret; this Lambda's IAM is scoped to that ARN only), connects
to the production RDS as the master user, and runs an idempotent SQL
bootstrap that creates the `psitta_api_digest` read-only role with the
exact grants required by the psitta-tester-digest Lambda (Item 9).

The Lambda is intended to be deployed, invoked exactly once via the
RequestResponse (synchronous) invocation type, and destroyed via
`terraform destroy -target` within ~10 minutes per the operator ops
checklist. If this Lambda is still deployed >24h after creation, that
is a bug — see the comment block at the top of lambda_db_bootstrap.tf.

Runtime: python3.12 (psycopg2-binary vendored via Terraform build step).
Egress: RDS (in-VPC private subnet, port 5432).
Secrets: psitta/prod/app-secrets (read once, cached at module scope).
Idempotent: re-running is a no-op. CREATE USER is guarded by
            IF NOT EXISTS; GRANTs are naturally idempotent.
"""
from __future__ import annotations

import json
import logging
import os
from typing import Optional

import boto3
import botocore.exceptions
import psycopg2

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

# ── Module-scope state (cached across warm invocations) ──────────────────
_SECRETS_CLIENT = boto3.client("secretsmanager")
_MASTER_CREDS: Optional[dict] = None  # populated lazily, never logged

# ── Bootstrap SQL (matches Item 9 ops checklist verbatim) ────────────────
_BOOTSTRAP_DO_BLOCK = """
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'psitta_api_digest') THEN
        CREATE USER psitta_api_digest;
    END IF;
END $$;
"""

# GRANTs are naturally idempotent in PostgreSQL — re-granting role
# membership or table privileges is a no-op. Each statement runs as a
# separate cursor.execute() call so a precise failure line surfaces in
# the CloudWatch error log if one of them rejects (rds_iam missing,
# table absent, etc.).
_GRANTS: tuple[str, ...] = (
    "GRANT rds_iam TO psitta_api_digest",
    "GRANT CONNECT ON DATABASE psitta TO psitta_api_digest",
    "GRANT USAGE ON SCHEMA public TO psitta_api_digest",
    "GRANT SELECT ON users TO psitta_api_digest",
    "GRANT SELECT ON tester_allowlist TO psitta_api_digest",
)

_VERIFY_SQL = (
    "SELECT rolname, rolinherit FROM pg_roles WHERE rolname = 'psitta_api_digest'"
)


def _load_master_creds() -> dict:
    """Fetch RDS master credentials from Secrets Manager. Cached.

    The app-secrets blob is JSON with many keys (Postgres + Cognito + S3
    + 3rd-party API keys). We pull exactly two — POSTGRES_USER and
    POSTGRES_PASSWORD — and never log the password.
    """
    global _MASTER_CREDS
    if _MASTER_CREDS is not None:
        return _MASTER_CREDS

    secret_name = os.environ["RDS_MASTER_SECRET_NAME"]
    response = _SECRETS_CLIENT.get_secret_value(SecretId=secret_name)
    payload = json.loads(response["SecretString"])
    try:
        _MASTER_CREDS = {
            "username": payload["POSTGRES_USER"],
            "password": payload["POSTGRES_PASSWORD"],
        }
    except KeyError as exc:
        raise RuntimeError(
            f"Master credentials secret {secret_name} missing key {exc}; "
            "expected POSTGRES_USER and POSTGRES_PASSWORD in the bundled "
            "app-secrets JSON."
        ) from exc
    return _MASTER_CREDS


def _connect_rds():
    """Open a Postgres connection using the master credentials.

    sslmode='require' is sufficient inside the VPC private network path
    (RDS is in a private subnet, not internet-reachable). The Lambda is
    short-lived and one-shot — no connection-pool concerns.
    """
    creds = _load_master_creds()
    return psycopg2.connect(
        host=os.environ["RDS_HOST"],
        port=int(os.environ.get("RDS_PORT", "5432")),
        dbname=os.environ["RDS_DB_NAME"],
        user=creds["username"],
        password=creds["password"],
        sslmode="require",
        connect_timeout=10,
    )


def lambda_handler(event: dict, context: object) -> dict:
    """Run the bootstrap SQL idempotently and return a verification result.

    Returns:
        {
          "statusCode": 200,
          "body": "<JSON-encoded verification + grants summary>"
        }

    Raises:
        Any exception during connect / SQL / verification re-raises so the
        synchronous caller sees the precise failure mode. No DLQ wiring;
        operator drives error handling manually.
    """
    logger.info("db_bootstrap.start")

    try:
        conn = _connect_rds()
    except (psycopg2.Error, KeyError, botocore.exceptions.ClientError) as exc:
        logger.error("db_bootstrap.failed reason=rds_connect err=%s", exc)
        raise

    try:
        with conn.cursor() as cur:
            cur.execute(_BOOTSTRAP_DO_BLOCK)
            logger.info("db_bootstrap.user_ensured")
            for stmt in _GRANTS:
                cur.execute(stmt)
                logger.info("db_bootstrap.granted stmt=%s", stmt)
            cur.execute(_VERIFY_SQL)
            verify_row = cur.fetchone()
        conn.commit()
    except psycopg2.Error as exc:
        conn.rollback()
        logger.error("db_bootstrap.failed reason=sql err=%s", exc)
        raise
    finally:
        conn.close()

    if verify_row is None:
        logger.error("db_bootstrap.failed reason=verify_empty")
        raise RuntimeError(
            "Bootstrap completed but verification SELECT returned no rows — "
            "psitta_api_digest role not visible in pg_roles."
        )

    rolname, rolinherit = verify_row[0], verify_row[1]
    logger.info(
        "db_bootstrap.ok rolname=%s rolinherit=%s",
        rolname, rolinherit,
    )
    return {
        "statusCode": 200,
        "body": json.dumps({
            "rolname": rolname,
            "rolinherit": rolinherit,
            "grants_applied": [
                "rds_iam (role membership)",
                "CONNECT ON DATABASE psitta",
                "USAGE ON SCHEMA public",
                "SELECT ON users",
                "SELECT ON tester_allowlist",
            ],
            "note": (
                "This Lambda is one-shot. Run `terraform destroy "
                "-target=aws_lambda_function.db_bootstrap ...` per the "
                "ops checklist to remove it now that the role exists."
            ),
        }),
    }
