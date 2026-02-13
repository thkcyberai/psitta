"""
Psitta — Provider Interface Contracts.

Protocol classes defining the boundaries between Psitta's core logic
and external services (TTS engines, object storage, vision APIs, etc.).

Using Python Protocols (structural subtyping) so implementations
don't need to inherit from a base class — they just need to match
the method signatures. This enables clean plugin boundaries for
the open-core extension model.

Design:
  - All methods are async (non-blocking I/O)
  - All methods include explicit error handling contracts
  - Return types are domain objects, not provider-specific types
  - Providers are stateless — configuration via __init__
"""

from __future__ import annotations

from typing import Protocol, runtime_checkable

from psitta.models.domain import ToneCategory, VoiceProfile


# ── Text-to-Speech ─────────────────────────────────────────────────────

@runtime_checkable
class TTSProvider(Protocol):
    """Contract for text-to-speech synthesis providers.

    Implementations: Azure Cognitive TTS (core), ElevenLabs (extension),
    Google Cloud TTS (extension), Amazon Polly (extension).
    """

    async def synthesize(
        self,
        text: str,
        voice_id: str,
        speed: float = 1.0,
        tone: ToneCategory = ToneCategory.NEUTRAL,
        output_format: str = "mp3",
    ) -> bytes:
        """Synthesize text into audio bytes.

        Args:
            text: Plain text to synthesize (max 5000 characters).
            voice_id: Provider-specific voice identifier.
            speed: Playback speed multiplier (0.5 to 3.0).
            tone: Prosody tone hint for expressive synthesis.
            output_format: Audio format ('mp3', 'opus', 'wav').

        Returns:
            Raw audio bytes in the requested format.

        Raises:
            ProviderError: On API failure, rate limit, or timeout.
            ValueError: If text exceeds max length or voice_id invalid.
        """
        ...

    async def get_supported_voices(self) -> list[str]:
        """Return list of voice IDs supported by this provider."""
        ...

    async def health_check(self) -> bool:
        """Return True if the provider is reachable and functional."""
        ...


# ── Object Storage ─────────────────────────────────────────────────────

@runtime_checkable
class StorageProvider(Protocol):
    """Contract for object storage providers.

    Implementations: S3/MinIO (core), Azure Blob (extension).
    """

    async def put_object(
        self,
        bucket: str,
        key: str,
        body: bytes,
        content_type: str = "application/octet-stream",
    ) -> str:
        """Store an object and return its storage key.

        Args:
            bucket: Target bucket name.
            key: Object key (path within bucket).
            body: Raw bytes to store.
            content_type: MIME type for the object.

        Returns:
            The storage key for later retrieval.

        Raises:
            ProviderError: On storage failure.
        """
        ...

    async def get_object(self, bucket: str, key: str) -> bytes:
        """Retrieve an object's bytes by key.

        Raises:
            ProviderError: If object not found or storage unavailable.
        """
        ...

    async def delete_object(self, bucket: str, key: str) -> bool:
        """Delete an object by key. Returns True if deleted."""
        ...

    async def generate_presigned_url(
        self,
        bucket: str,
        key: str,
        expires_in: int = 900,
    ) -> str:
        """Generate a time-limited URL for direct client access.

        Args:
            bucket: Bucket containing the object.
            key: Object key.
            expires_in: URL validity in seconds (default 15 min).

        Returns:
            Pre-signed URL string.
        """
        ...

    async def health_check(self) -> bool:
        """Return True if storage is reachable."""
        ...


# ── Vision Description ─────────────────────────────────────────────────

@runtime_checkable
class VisionDescriptionProvider(Protocol):
    """Contract for image-to-text description providers.

    Used to generate alt-text descriptions for images embedded
    in documents, which are then narrated as part of the audio.

    Implementations: Anthropic Claude (core), OpenAI GPT-4V (extension).
    """

    async def describe_image(
        self,
        image_bytes: bytes,
        context: str = "",
        max_words: int = 100,
    ) -> str:
        """Generate a natural language description of an image.

        Args:
            image_bytes: Raw image data (PNG, JPEG, WebP).
            context: Surrounding document text for better descriptions.
            max_words: Approximate maximum words in description.

        Returns:
            Natural language description suitable for narration.
        """
        ...

    async def health_check(self) -> bool:
        """Return True if the vision API is reachable."""
        ...


# ── Voice Catalog ──────────────────────────────────────────────────────

@runtime_checkable
class VoiceCatalogProvider(Protocol):
    """Contract for voice catalog providers.

    Manages the list of available voices, their metadata,
    and preview audio samples.

    Implementations: Static JSON (core), Dynamic API (extension).
    """

    async def list_voices(
        self,
        language: str | None = None,
        tier: str | None = None,
    ) -> list[VoiceProfile]:
        """Return available voices, optionally filtered."""
        ...

    async def get_voice(self, voice_id: str) -> VoiceProfile | None:
        """Get a specific voice by ID. Returns None if not found."""
        ...

    async def get_preview_url(self, voice_id: str) -> str | None:
        """Return a URL to a preview audio sample for the voice."""
        ...


# ── Tone Classification ───────────────────────────────────────────────

@runtime_checkable
class ToneClassifier(Protocol):
    """Contract for text tone classification.

    Analyzes text chunks to determine appropriate prosody
    for more expressive TTS synthesis.

    Implementations: Rule-based (core), LLM-based (extension).
    """

    async def classify(self, text: str) -> ToneCategory:
        """Classify the tone of a text passage.

        Args:
            text: Text to analyze.

        Returns:
            ToneCategory enum value.
        """
        ...
