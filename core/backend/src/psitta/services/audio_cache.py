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
        return S3StorageProvider(get_settings())
    except Exception as e:
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


async def put_mp3(chunk_id: str, voice_id: str, audio_bytes: bytes) -> str:
    """Save mp3 to local + S3. Returns local path."""
    _ensure_dir()
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
