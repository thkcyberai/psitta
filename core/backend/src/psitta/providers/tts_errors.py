"""Shared TTS provider error types."""

from __future__ import annotations


class TTSProviderError(RuntimeError):
    """Error raised by a concrete TTS provider."""

    def __init__(self, provider: str, message: str, status_code: int | None = None) -> None:
        super().__init__(message)
        self.provider = provider
        self.status_code = status_code
