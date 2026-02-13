"""
S3-compatible storage provider implementation.

Works with AWS S3, MinIO (local dev), and any S3-compatible service.
"""

from __future__ import annotations

from typing import AsyncIterator

import aioboto3
import structlog

from psitta.providers.interfaces.contracts import StorageProvider

logger = structlog.get_logger()


class S3StorageProvider:
    """S3-compatible object storage implementation."""

    def __init__(
        self,
        bucket_name: str,
        region: str = "us-east-1",
        endpoint_url: str | None = None,
        access_key_id: str = "",
        secret_access_key: str = "",
    ) -> None:
        self._bucket_name = bucket_name
        self._session = aioboto3.Session(
            aws_access_key_id=access_key_id or None,
            aws_secret_access_key=secret_access_key or None,
            region_name=region,
        )
        self._endpoint_url = endpoint_url

    def _client_kwargs(self) -> dict[str, str]:
        kwargs: dict[str, str] = {}
        if self._endpoint_url:
            kwargs["endpoint_url"] = self._endpoint_url
        return kwargs

    async def upload(
        self, key: str, data: bytes, content_type: str = "application/octet-stream"
    ) -> str:
        async with self._session.client("s3", **self._client_kwargs()) as s3:
            await s3.put_object(
                Bucket=self._bucket_name,
                Key=key,
                Body=data,
                ContentType=content_type,
            )
        logger.debug("s3_upload", key=key, size=len(data))
        return key

    async def upload_stream(
        self, key: str, stream: AsyncIterator[bytes], content_type: str = "application/octet-stream"
    ) -> str:
        # For streaming uploads, collect and upload (or use multipart for large files)
        chunks: list[bytes] = []
        async for chunk in stream:
            chunks.append(chunk)
        data = b"".join(chunks)
        return await self.upload(key, data, content_type)

    async def download(self, key: str) -> bytes:
        async with self._session.client("s3", **self._client_kwargs()) as s3:
            response = await s3.get_object(Bucket=self._bucket_name, Key=key)
            data = await response["Body"].read()
        return data

    async def download_stream(self, key: str) -> AsyncIterator[bytes]:
        async with self._session.client("s3", **self._client_kwargs()) as s3:
            response = await s3.get_object(Bucket=self._bucket_name, Key=key)
            async for chunk in response["Body"].iter_chunks(chunk_size=64 * 1024):
                yield chunk

    async def delete(self, key: str) -> None:
        async with self._session.client("s3", **self._client_kwargs()) as s3:
            await s3.delete_object(Bucket=self._bucket_name, Key=key)
        logger.debug("s3_delete", key=key)

    async def delete_prefix(self, prefix: str) -> int:
        count = 0
        async with self._session.client("s3", **self._client_kwargs()) as s3:
            paginator = s3.get_paginator("list_objects_v2")
            async for page in paginator.paginate(Bucket=self._bucket_name, Prefix=prefix):
                objects = page.get("Contents", [])
                if objects:
                    await s3.delete_objects(
                        Bucket=self._bucket_name,
                        Delete={"Objects": [{"Key": obj["Key"]} for obj in objects]},
                    )
                    count += len(objects)
        logger.debug("s3_delete_prefix", prefix=prefix, count=count)
        return count

    async def exists(self, key: str) -> bool:
        try:
            async with self._session.client("s3", **self._client_kwargs()) as s3:
                await s3.head_object(Bucket=self._bucket_name, Key=key)
            return True
        except Exception:
            return False

    async def generate_presigned_url(self, key: str, expires_in: int = 3600) -> str:
        async with self._session.client("s3", **self._client_kwargs()) as s3:
            url = await s3.generate_presigned_url(
                "get_object",
                Params={"Bucket": self._bucket_name, "Key": key},
                ExpiresIn=expires_in,
            )
        return url
