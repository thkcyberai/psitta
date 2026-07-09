"""
Psitta — Audio Cache Service.

Wraps S3/MinIO for persistent audio and alignment storage.
Local /tmp acts as a fast-serving layer; S3 is the durable store.

Cache key convention:
  audio/{chunk_id}_{voice_id}.mp3
  audio/{chunk_id}_{voice_id}.alignment.json
"""
from __future__ import annotations

import json
import os
import structlog

logger = structlog.get_logger(__name__)

AUDIO_DIR = "/tmp/psitta_audio"
S3_PREFIX = "audio"


def _local_mp3(chunk_id: str, voice_id: str) -> str:
    return f"{AUDIO_DIR}/{chunk_id}_{voice_id}.mp3"


def _local_align(chunk_id: str, voice_id: str) -> str:
    return f"{AUDIO_DIR}/{chunk_id}_{voice_id}.alignment.json"


def _s3_mp3(chunk_id: str, voice_id: str) -> str:
    return f"{S3_PREFIX}/{chunk_id}_{voice_id}.mp3"


def _s3_align(chunk_id: str, voice_id: str) -> str:
    return f"{S3_PREFIX}/{chunk_id}_{voice_id}.alignment.json"


def _ensure_dir() -> None:
    os.makedirs(AUDIO_DIR, exist_ok=True)


def _get_s3():
    """Return an S3StorageProvider instance, or None if unavailable."""
    try:
        from psitta.config import get_settings
        from psitta.providers.storage_s3 import S3StorageProvider
        logger.info("upload.trace.audio_cache.get_s3.begin")
        provider = S3StorageProvider(get_settings())
        logger.info(
            "upload.trace.audio_cache.get_s3.success",
            provider_class=type(provider).__name__,
        )
        return provider
    except Exception as e:
        logger.warning(
            "upload.trace.audio_cache.get_s3.failed",
            exception_type=type(e).__name__,
            exception_message=str(e),
        )
        logger.warning("audio_cache.s3_unavailable", error=str(e))
        return None


async def get_mp3(chunk_id: str, voice_id: str) -> str | None:
    """Return local path to mp3 if cached (local or S3). None on miss."""
    _ensure_dir()
    local = _local_mp3(chunk_id, voice_id)

    # 1. Local hit
    if os.path.exists(local) and os.path.getsize(local) > 0:
        return local

    # 2. S3 hit — download to local
    s3 = _get_s3()
    if s3:
        try:
            from psitta.config import get_settings
            bucket = get_settings().S3_BUCKET_NAME
            data = await s3.get_object(bucket, _s3_mp3(chunk_id, voice_id))
            with open(local, "wb") as f:
                f.write(data)
            logger.info("audio_cache.mp3.s3_hit", chunk_id=chunk_id)
            return local
        except Exception:
            pass  # S3 miss — fall through

    return None


async def put_mp3(
    chunk_id: str, voice_id: str, audio_bytes: bytes, *, normalize: bool = True
) -> str:
    """Save mp3 to local + S3. Returns local path.

    Audio is loudness-normalized (EBU R128) before persisting so every voice —
    any provider, any language — replays at a consistent perceived volume.
    Pass ``normalize=False`` when the caller has already normalized the bytes
    (e.g. the streaming endpoint, which normalizes once before sending) to avoid
    a redundant second pass. Fail-safe: normalization errors leave bytes as-is.
    """
    _ensure_dir()
    if normalize:
        from psitta.providers.audio_loudness import normalize_mp3
        audio_bytes = await normalize_mp3(audio_bytes)
    local = _local_mp3(chunk_id, voice_id)
    with open(local, "wb") as f:
        f.write(audio_bytes)

    s3 = _get_s3()
    if s3:
        try:
            from psitta.config import get_settings
            bucket = get_settings().S3_BUCKET_NAME
            await s3.put_object(bucket, _s3_mp3(chunk_id, voice_id), audio_bytes, "audio/mpeg")
            logger.info("audio_cache.mp3.saved_s3", chunk_id=chunk_id, size=len(audio_bytes))
        except Exception as e:
            logger.warning("audio_cache.mp3.s3_write_failed", error=str(e), chunk_id=chunk_id)

    return local


async def get_alignment(chunk_id: str, voice_id: str) -> dict | None:
    """Return alignment payload dict if cached. None on miss."""
    _ensure_dir()
    local = _local_align(chunk_id, voice_id)

    # 1. Local hit
    if os.path.exists(local):
        try:
            with open(local, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass

    # 2. S3 hit
    s3 = _get_s3()
    if s3:
        try:
            from psitta.config import get_settings
            bucket = get_settings().S3_BUCKET_NAME
            data = await s3.get_object(bucket, _s3_align(chunk_id, voice_id))
            payload = json.loads(data.decode("utf-8"))
            with open(local, "w", encoding="utf-8") as f:
                json.dump(payload, f)
            logger.info("audio_cache.alignment.s3_hit", chunk_id=chunk_id)
            return payload
        except Exception:
            pass

    return None


async def put_alignment(chunk_id: str, voice_id: str, payload: dict) -> None:
    """Save alignment JSON to local + S3."""
    _ensure_dir()
    local = _local_align(chunk_id, voice_id)
    with open(local, "w", encoding="utf-8") as f:
        json.dump(payload, f)

    s3 = _get_s3()
    if s3:
        try:
            from psitta.config import get_settings
            bucket = get_settings().S3_BUCKET_NAME
            data = json.dumps(payload).encode("utf-8")
            await s3.put_object(bucket, _s3_align(chunk_id, voice_id), data, "application/json")
            logger.info("audio_cache.alignment.saved_s3", chunk_id=chunk_id)
        except Exception as e:
            logger.warning("audio_cache.alignment.s3_write_failed", error=str(e), chunk_id=chunk_id)


def s3_key_mp3(chunk_id: str, voice_id: str) -> str:
    """Return the canonical S3 object key for an audio segment.
    Always use this for DB storage_key — never the local /tmp path.
    """
    return _s3_mp3(chunk_id, voice_id)


def _local_raw(doc_id: str, extension: str) -> str:
    return f"{AUDIO_DIR}/raw_{doc_id}{extension}"


def _s3_raw(doc_id: str, extension: str) -> str:
    return f"uploads/{doc_id}{extension}"


async def put_raw_file(doc_id: str, extension: str, file_bytes: bytes) -> str:
    """Save original uploaded file to local + S3. Returns local path."""
    _ensure_dir()
    local = _local_raw(doc_id, extension)
    object_key = _s3_raw(doc_id, extension)
    logger.info(
        "upload.trace.audio_cache.put_raw_file.begin",
        doc_id=doc_id,
        extension=extension,
        local_path=local,
        object_key=object_key,
        size_bytes=len(file_bytes),
    )
    with open(local, "wb") as f:
        f.write(file_bytes)

    s3 = _get_s3()
    logger.info(
        "upload.trace.audio_cache.put_raw_file.s3_provider",
        doc_id=doc_id,
        provider_exists=bool(s3),
        object_key=object_key,
    )
    if not s3:
        logger.error("audio_cache.raw.s3_unavailable", doc_id=doc_id)
        raise RuntimeError("Durable raw-file storage is unavailable")

    try:
        from psitta.config import get_settings

        bucket = get_settings().S3_BUCKET_NAME
        logger.info(
            "upload.trace.audio_cache.put_raw_file.put_object.begin",
            doc_id=doc_id,
            bucket=bucket,
            object_key=object_key,
            local_path=local,
            size_bytes=len(file_bytes),
        )
        await s3.put_object(
            bucket,
            object_key,
            file_bytes,
            "application/octet-stream",
        )
        logger.info(
            "upload.trace.audio_cache.put_raw_file.put_object.end",
            doc_id=doc_id,
            bucket=bucket,
            object_key=object_key,
            local_path=local,
            size_bytes=len(file_bytes),
        )
        logger.info("audio_cache.raw.saved_s3", doc_id=doc_id, size=len(file_bytes))
    except Exception as e:
        logger.error(
            "upload.trace.audio_cache.put_raw_file.put_object.failed",
            doc_id=doc_id,
            bucket=locals().get("bucket"),
            object_key=object_key,
            local_path=local,
            exception_type=type(e).__name__,
            exception_message=str(e),
        )
        logger.error("audio_cache.raw.s3_write_failed", error=str(e), doc_id=doc_id)
        raise RuntimeError("Durable raw-file storage failed") from e

    logger.info(
        "upload.trace.audio_cache.put_raw_file.complete",
        doc_id=doc_id,
        local_path=local,
        object_key=object_key,
    )
    return local


async def get_raw_file(storage_key: str) -> str | None:
    """Return local path to an original file using the stored storage key."""
    if not storage_key:
        return None

    _ensure_dir()
    local_name = os.path.basename(storage_key)
    if not local_name:
        return None
    local = os.path.join(AUDIO_DIR, local_name)

    if os.path.exists(local) and os.path.getsize(local) > 0:
        return local

    s3 = _get_s3()
    if s3:
        try:
            from psitta.config import get_settings
            bucket = get_settings().S3_BUCKET_NAME
            data = await s3.get_object(bucket, storage_key)
            with open(local, "wb") as f:
                f.write(data)
            logger.info("audio_cache.raw.s3_hit", storage_key=storage_key)
            return local
        except Exception:
            pass

    return None
