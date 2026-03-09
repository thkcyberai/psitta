"""
Psitta — S3/MinIO Storage Provider.

Implements the StorageProvider protocol using boto3/aioboto3 for
S3-compatible object storage. Works with both AWS S3 and MinIO
(local development).

Security:
  - Pre-signed URLs have configurable short TTL (default 15 min)
  - Server-side encryption enabled by default (AES-256)
  - Bucket policies enforce private access only
  - No public ACLs — all access via pre-signed URLs or IAM roles
"""

from __future__ import annotations

import structlog

from psitta.config import Settings

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)


class S3StorageProvider:
    """S3-compatible object storage using aioboto3.

    Satisfies the StorageProvider protocol from contracts.py.
    Supports AWS S3 and MinIO with identical API.
    """

    def __init__(self, settings: Settings) -> None:
        self._endpoint_url = settings.S3_ENDPOINT_URL
        self._region = settings.S3_REGION
        self._access_key = settings.AWS_ACCESS_KEY_ID.get_secret_value()
        self._secret_key = settings.AWS_SECRET_ACCESS_KEY.get_secret_value()
        self._default_bucket = settings.S3_BUCKET_NAME

    async def _get_client(self):  # type: ignore[no-untyped-def]
        """Create an aioboto3 S3 client.

        TODO: Replace with connection pool from app lifespan.
        """
        import aioboto3

        session = aioboto3.Session()
        return session.client(
            "s3",
            endpoint_url=self._endpoint_url,
            region_name=self._region,
            aws_access_key_id=self._access_key,
            aws_secret_access_key=self._secret_key,
        )

    async def put_object(
        self,
        bucket: str,
        key: str,
        body: bytes,
        content_type: str = "application/octet-stream",
    ) -> str:
        """Store an object in S3. Returns the storage key."""
        logger.info(
            "storage.s3.put",
            bucket=bucket,
            key=key,
            size_bytes=len(body),
            content_type=content_type,
        )

        async with await self._get_client() as client:
            await client.put_object(
                Bucket=bucket,
                Key=key,
                Body=body,
                ContentType=content_type,
            )

        return key

    async def get_object(self, bucket: str, key: str) -> bytes:
        """Retrieve an object's bytes from S3."""
        logger.info("storage.s3.get", bucket=bucket, key=key)

        async with await self._get_client() as client:
            response = await client.get_object(Bucket=bucket, Key=key)
            data: bytes = await response["Body"].read()

        return data

    async def delete_object(self, bucket: str, key: str) -> bool:
        """Delete an object from S3. Returns True on success."""
        logger.info("storage.s3.delete", bucket=bucket, key=key)

        async with await self._get_client() as client:
            await client.delete_object(Bucket=bucket, Key=key)

        return True

    async def delete_by_prefix(self, bucket: str, prefix: str) -> int:
        """Delete all objects matching a prefix. Returns count of deleted objects."""
        logger.info("storage.s3.delete_by_prefix", bucket=bucket, prefix=prefix)
        deleted = 0
        async with await self._get_client() as client:
            paginator = client.get_paginator("list_objects_v2")
            async for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
                for obj in page.get("Contents", []):
                    key = obj["Key"]
                    await client.delete_object(Bucket=bucket, Key=key)
                    logger.info("storage.s3.delete_by_prefix.deleted", key=key)
                    deleted += 1
        return deleted

    async def generate_presigned_url(
        self,
        bucket: str,
        key: str,
        expires_in: int = 900,
    ) -> str:
        """Generate a time-limited pre-signed GET URL."""
        logger.debug(
            "storage.s3.presign",
            bucket=bucket,
            key=key,
            expires_in=expires_in,
        )

        async with await self._get_client() as client:
            url: str = await client.generate_presigned_url(
                "get_object",
                Params={"Bucket": bucket, "Key": key},
                ExpiresIn=expires_in,
            )

        return url

    async def health_check(self) -> bool:
        """Verify S3 connectivity by listing the default bucket."""
        try:
            async with await self._get_client() as client:
                await client.head_bucket(Bucket=self._default_bucket)
            return True
        except Exception:
            logger.error("storage.s3.health_check.failed", exc_info=True)
            return False
