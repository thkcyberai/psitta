"""
Provider interfaces — the architectural contracts.

All external dependencies are abstracted behind these protocols.
Core code depends ONLY on these interfaces, never on concrete implementations.
Extensions provide implementations; core provides defaults.

This is the open-core boundary enforcement layer.
"""

from __future__ import annotations

import uuid
from abc import abstractmethod
from dataclasses import dataclass, field
from enum import StrEnum
from typing import AsyncIterator, Protocol, runtime_checkable


# ══════════════════════════════════════════════════════════════════════
# Shared Value Objects
# ══════════════════════════════════════════════════════════════════════


class AudioFormat(StrEnum):
    MP3 = "mp3"
    WAV = "wav"
    OGG = "ogg"
    OPUS = "opus"


@dataclass(frozen=True, slots=True)
class AudioChunk:
    """A single chunk of synthesized audio."""

    data: bytes
    format: AudioFormat
    duration_ms: int
    sequence_num: int
    is_last: bool = False


@dataclass(frozen=True, slots=True)
class TTSOptions:
    """Options for text-to-speech synthesis."""

    speed: float = 1.0
    pitch: float = 0.0
    volume: float = 1.0
    emotion: str = "neutral"
    ssml_enabled: bool = True
    output_format: AudioFormat = AudioFormat.MP3


@dataclass(frozen=True, slots=True)
class VoiceFilter:
    """Filters for voice catalog queries."""

    language: str | None = None
    gender: str | None = None
    style: str | None = None
    provider: str | None = None
    is_premium: bool | None = None


@dataclass(frozen=True, slots=True)
class VoiceMeta:
    """Metadata for a single voice in the catalog."""

    id: str
    name: str
    language: str
    gender: str
    style: str
    provider: str
    preview_url: str
    is_premium: bool
    quality_score: float
    description: str = ""
    supported_emotions: list[str] = field(default_factory=lambda: ["neutral"])


@dataclass(frozen=True, slots=True)
class CostEstimate:
    """Estimated cost for a TTS synthesis job."""

    character_count: int
    estimated_cost_usd: float
    provider: str
    voice_id: str


@dataclass(frozen=True, slots=True)
class ParsedDocument:
    """Result of parsing a document."""

    title: str
    text_blocks: list[TextBlock]
    visual_elements: list[DetectedVisual]
    page_count: int
    metadata: dict[str, str]


@dataclass(frozen=True, slots=True)
class TextBlock:
    """A semantic block of text extracted from a document."""

    content: str
    block_type: str  # heading, paragraph, list_item, table_cell, etc.
    page_number: int
    sequence_num: int
    metadata: dict[str, str] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class DetectedVisual:
    """A visual element detected in a document."""

    element_type: str  # image, chart, table, diagram
    page_number: int
    bounding_box: dict[str, float] | None = None
    image_data: bytes | None = None
    image_format: str = "png"


@dataclass(frozen=True, slots=True)
class VisualDescription:
    """Generated description of a visual element."""

    element_id: str
    description: str
    confidence: float
    alt_text: str


@dataclass(frozen=True, slots=True)
class ToneClassification:
    """Result of tone classification for a text chunk."""

    tone: str  # neutral, formal, conversational, somber, excited
    confidence: float
    suggested_ssml_params: dict[str, float]  # rate, pitch, volume adjustments


# ══════════════════════════════════════════════════════════════════════
# Provider Protocols
# ══════════════════════════════════════════════════════════════════════


@runtime_checkable
class TTSProvider(Protocol):
    """Contract for text-to-speech synthesis providers."""

    @abstractmethod
    async def synthesize(
        self, text: str, voice_id: str, options: TTSOptions
    ) -> AsyncIterator[AudioChunk]:
        """Synthesize text to audio, yielding chunks for progressive streaming."""
        ...

    @abstractmethod
    async def synthesize_ssml(
        self, ssml: str, voice_id: str, options: TTSOptions
    ) -> AsyncIterator[AudioChunk]:
        """Synthesize SSML-formatted text to audio."""
        ...

    @abstractmethod
    async def estimate_cost(self, char_count: int, voice_id: str) -> CostEstimate:
        """Estimate synthesis cost before committing."""
        ...

    @abstractmethod
    async def health_check(self) -> bool:
        """Verify provider is reachable and operational."""
        ...


@runtime_checkable
class VoiceCatalogProvider(Protocol):
    """Contract for voice catalog management."""

    @abstractmethod
    async def list_voices(self, filters: VoiceFilter) -> list[VoiceMeta]:
        """List available voices with optional filtering."""
        ...

    @abstractmethod
    async def get_voice(self, voice_id: str) -> VoiceMeta | None:
        """Get metadata for a specific voice."""
        ...

    @abstractmethod
    async def get_preview_audio(self, voice_id: str) -> bytes:
        """Get a preview audio sample for a voice."""
        ...


@runtime_checkable
class DocumentSourceProvider(Protocol):
    """Contract for document source ingestion."""

    @abstractmethod
    async def fetch(self, source: str) -> tuple[bytes, str]:
        """Fetch document content. Returns (bytes, detected_mime_type)."""
        ...

    @abstractmethod
    def supports(self, source_type: str) -> bool:
        """Check if this provider handles the given source type."""
        ...


@runtime_checkable
class DocumentParser(Protocol):
    """Contract for document parsing and text extraction."""

    @abstractmethod
    async def parse(self, content: bytes, mime_type: str) -> ParsedDocument:
        """Parse a document and extract structured text + visual elements."""
        ...

    @abstractmethod
    def supported_types(self) -> list[str]:
        """List of MIME types this parser can handle."""
        ...


@runtime_checkable
class OCRProvider(Protocol):
    """Contract for optical character recognition."""

    @abstractmethod
    async def extract_text(self, image_data: bytes, language: str = "eng") -> str:
        """Extract text from a single image."""
        ...

    @abstractmethod
    async def extract_text_with_positions(
        self, image_data: bytes, language: str = "eng"
    ) -> list[dict[str, object]]:
        """Extract text with bounding box positions."""
        ...


@runtime_checkable
class VisionDescriptionProvider(Protocol):
    """Contract for generating descriptions of visual elements."""

    @abstractmethod
    async def describe(
        self, image_data: bytes, context: str = ""
    ) -> VisualDescription:
        """Generate a natural-language description of a visual element."""
        ...

    @abstractmethod
    async def describe_chart(
        self, image_data: bytes, context: str = ""
    ) -> VisualDescription:
        """Generate a description specifically for charts and graphs."""
        ...

    @abstractmethod
    async def describe_table(
        self, image_data: bytes, context: str = ""
    ) -> VisualDescription:
        """Generate a structured description of a table."""
        ...


@runtime_checkable
class ToneClassifier(Protocol):
    """Contract for emotional tone classification."""

    @abstractmethod
    async def classify(self, text: str, document_type: str = "") -> ToneClassification:
        """Classify the emotional tone of a text passage."""
        ...


@runtime_checkable
class StorageProvider(Protocol):
    """Contract for object storage operations."""

    @abstractmethod
    async def upload(
        self, key: str, data: bytes, content_type: str = "application/octet-stream"
    ) -> str:
        """Upload data and return the storage key."""
        ...

    @abstractmethod
    async def upload_stream(
        self, key: str, stream: AsyncIterator[bytes], content_type: str = "application/octet-stream"
    ) -> str:
        """Upload from a stream for large files."""
        ...

    @abstractmethod
    async def download(self, key: str) -> bytes:
        """Download data by key."""
        ...

    @abstractmethod
    async def download_stream(self, key: str) -> AsyncIterator[bytes]:
        """Download as a stream for large files."""
        ...

    @abstractmethod
    async def delete(self, key: str) -> None:
        """Delete an object by key."""
        ...

    @abstractmethod
    async def delete_prefix(self, prefix: str) -> int:
        """Delete all objects with the given prefix. Returns count deleted."""
        ...

    @abstractmethod
    async def exists(self, key: str) -> bool:
        """Check if an object exists."""
        ...

    @abstractmethod
    async def generate_presigned_url(self, key: str, expires_in: int = 3600) -> str:
        """Generate a time-limited download URL."""
        ...


@runtime_checkable
class AuthProvider(Protocol):
    """Contract for authentication and token verification."""

    @abstractmethod
    async def verify_token(self, token: str) -> dict[str, object]:
        """Verify a JWT and return decoded claims."""
        ...

    @abstractmethod
    async def get_user_info(self, token: str) -> dict[str, str]:
        """Get user profile info from the auth provider."""
        ...


# ══════════════════════════════════════════════════════════════════════
# Provider Registry
# ══════════════════════════════════════════════════════════════════════


class ProviderRegistry:
    """
    Central registry for all provider implementations.

    Enforces single-responsibility: each provider type has exactly one active
    implementation at runtime. Extensions register their implementations at startup.
    """

    def __init__(self) -> None:
        self._tts: TTSProvider | None = None
        self._voice_catalog: VoiceCatalogProvider | None = None
        self._document_parsers: dict[str, DocumentParser] = {}
        self._ocr: OCRProvider | None = None
        self._vision: VisionDescriptionProvider | None = None
        self._tone_classifier: ToneClassifier | None = None
        self._storage: StorageProvider | None = None
        self._auth: AuthProvider | None = None

    # ── Registration ─────────────────────────────────────────────

    def register_tts(self, provider: TTSProvider) -> None:
        self._tts = provider

    def register_voice_catalog(self, provider: VoiceCatalogProvider) -> None:
        self._voice_catalog = provider

    def register_document_parser(self, mime_type: str, parser: DocumentParser) -> None:
        self._document_parsers[mime_type] = parser

    def register_ocr(self, provider: OCRProvider) -> None:
        self._ocr = provider

    def register_vision(self, provider: VisionDescriptionProvider) -> None:
        self._vision = provider

    def register_tone_classifier(self, provider: ToneClassifier) -> None:
        self._tone_classifier = provider

    def register_storage(self, provider: StorageProvider) -> None:
        self._storage = provider

    def register_auth(self, provider: AuthProvider) -> None:
        self._auth = provider

    # ── Access ───────────────────────────────────────────────────

    @property
    def tts(self) -> TTSProvider:
        if self._tts is None:
            raise RuntimeError("No TTSProvider registered")
        return self._tts

    @property
    def voice_catalog(self) -> VoiceCatalogProvider:
        if self._voice_catalog is None:
            raise RuntimeError("No VoiceCatalogProvider registered")
        return self._voice_catalog

    def document_parser(self, mime_type: str) -> DocumentParser:
        parser = self._document_parsers.get(mime_type)
        if parser is None:
            raise ValueError(f"No DocumentParser registered for MIME type: {mime_type}")
        return parser

    @property
    def ocr(self) -> OCRProvider:
        if self._ocr is None:
            raise RuntimeError("No OCRProvider registered")
        return self._ocr

    @property
    def vision(self) -> VisionDescriptionProvider:
        if self._vision is None:
            raise RuntimeError("No VisionDescriptionProvider registered")
        return self._vision

    @property
    def tone_classifier(self) -> ToneClassifier:
        if self._tone_classifier is None:
            raise RuntimeError("No ToneClassifier registered")
        return self._tone_classifier

    @property
    def storage(self) -> StorageProvider:
        if self._storage is None:
            raise RuntimeError("No StorageProvider registered")
        return self._storage

    @property
    def auth(self) -> AuthProvider:
        if self._auth is None:
            raise RuntimeError("No AuthProvider registered")
        return self._auth


# Singleton registry
registry = ProviderRegistry()
