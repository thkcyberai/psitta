"""Psitta - Edge TTS Provider (Free Microsoft Neural Voices).

Uses the edge-tts library to access Microsoft's Neural TTS voices
without requiring an Azure subscription or API key.

Same voice quality as Azure Neural voices. Zero cost.
"""

from __future__ import annotations

import edge_tts
import structlog

logger = structlog.get_logger(__name__)

# Verified available en-US Edge TTS voices:
# Female: AvaNeural, EmmaNeural, AnaNeural, AriaNeural, JennyNeural, MichelleNeural
# Male: AndrewNeural, BrianNeural, ChristopherNeural, EricNeural, GuyNeural, RogerNeural, SteffanNeural

EDGE_VOICES: dict[str, str] = {
    # Female voices
    "21m00Tcm4TlvDq8ikWAM": "en-US-JennyNeural",       # Rachel
    "AZnzlk1XvdvUeBnXmlld": "en-US-AriaNeural",         # Domi
    "EXAVITQu4vr4xnSDxMaL": "en-US-MichelleNeural",     # Bella
    "MF3mGyEYCl7XYWbV9V6O": "en-US-EmmaNeural",         # Elli
    "jBpfuIE2acCO8z3wKNLl": "en-US-AvaNeural",          # Gigi
    # Male voices
    "29vD33N1CtxCmqQRPOHJ": "en-US-GuyNeural",          # Drew
    "2EiwWnXFnvU5JabPnv8n": "en-US-BrianNeural",        # Clyde
    "ErXwobaYiN019PkySvjV": "en-US-AndrewNeural",       # Antoni
    "TxGEqnHWrfWFTfGW9XjX": "en-US-RogerNeural",        # Josh
    "VR6AewLTigWG4xSOukaG": "en-US-SteffanNeural",      # Arnold
    "pNInz6obpgDQGcFmaJgB": "en-US-ChristopherNeural",  # Adam
    "yoZ06aMxZJJ28mfd3POQ": "en-US-EricNeural",         # Sam
}

EDGE_DEFAULT_VOICE = "en-US-JennyNeural"

# Hard lock. We do not allow per-voice or per-request synthesis speed drift.
EDGE_RATE = "+0%"


class EdgeTTSProvider:
    """Free Microsoft Neural TTS via edge-tts library."""

    def _get_voice(self, elevenlabs_voice_id: str) -> str:
        return EDGE_VOICES.get(elevenlabs_voice_id, EDGE_DEFAULT_VOICE)

    async def synthesize(
        self,
        text: str,
        voice_id: str,
        speed: float = 1.0,  # kept for interface compatibility, ignored
        output_format: str = "mp3_44100_128",
    ) -> bytes:
        edge_voice = self._get_voice(voice_id)

        logger.info(
            "tts.edge.synthesize",
            voice=edge_voice,
            original_voice_id=voice_id,
            text_length=len(text),
            rate=EDGE_RATE,
        )

        communicate = edge_tts.Communicate(
            text=text[:5000],
            voice=edge_voice,
            rate=EDGE_RATE,
        )

        audio_chunks: list[bytes] = []
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                audio_chunks.append(chunk["data"])

        if not audio_chunks:
            raise RuntimeError(f"Edge TTS returned no audio for voice {edge_voice}")

        audio_bytes = b"".join(audio_chunks)

        logger.info(
            "tts.edge.synthesize.ok",
            voice=edge_voice,
            size=len(audio_bytes),
        )
        return audio_bytes

    async def health_check(self) -> bool:
        try:
            voices = await edge_tts.list_voices()
            return len(voices) > 0
        except Exception:
            return False
