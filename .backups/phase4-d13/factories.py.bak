"""Factory functions for generating test data."""
from __future__ import annotations
from uuid import uuid4

def make_document(**overrides) -> dict:
    defaults = {"id": str(uuid4()), "user_id": f"user_{uuid4().hex[:8]}",
                "title": "Test Document", "source_type": "pdf", "status": "uploaded",
                "page_count": 10, "file_size_bytes": 500_000,
                "storage_key": f"uploads/{uuid4()}.pdf", "metadata": {}}
    defaults.update(overrides)
    return defaults

def make_audio_segment(**overrides) -> dict:
    defaults = {"id": str(uuid4()), "document_id": str(uuid4()),
                "chunk_id": str(uuid4()), "voice_id": "en-US-AriaNeural",
                "speed": 1.0, "storage_key": f"audio/{uuid4()}.mp3",
                "duration_ms": 5000, "file_size_bytes": 40_000}
    defaults.update(overrides)
    return defaults
