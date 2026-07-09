"""Voice ID mapping between TTS providers.

When a request must fall back from ElevenLabs to the Edge/Azure path, the
ElevenLabs voice id is translated to a Microsoft Neural voice. The previous map
sent every non-English voice to ``en-US-JennyNeural`` — so a Brazilian /
Spanish / French premium voice fell back to a US-English FEMALE voice (wrong
language AND wrong gender; this is why "Matheus" was heard as an American woman).

This version resolves a non-English fallback from the STATIC CATALOG's own Azure
voices, so it can only ever return a voice that is already verified in
production. Resolution: exact (language, gender) → same language family + gender
→ same language family (any gender) → English. A language with no native Azure
voice in the catalog (e.g. European Portuguese) therefore falls back to the
nearest verified voice of the same family (pt-PT → pt-BR) instead of a guessed,
possibly-invalid id.
"""

import re
from functools import lru_cache

_MICROSOFT_NEURAL_PATTERN = re.compile(r"^[a-z]{2}-[A-Z]{2}-\w+Neural$")

# Explicit English ElevenLabs → Azure map (keeps per-voice variety for en-US).
# Pre-existing; unchanged. Only fires when an English EL voice falls back.
ELEVENLABS_TO_AZURE: dict[str, str] = {
    "21m00Tcm4TlvDq8ikWAM": "en-US-JennyNeural",       # Rachel
    "AZnzlk1XvdvUeBnXmlld": "en-US-AriaNeural",         # Domi
    "EXAVITQu4vr4xnSDxMaL": "en-US-MichelleNeural",     # Bella
    "MF3mGyEYCl7XYWbV9V6O": "en-US-EmmaNeural",         # Elli
    "jBpfuIE2acCO8z3wKNLl": "en-US-AvaNeural",          # Gigi
    "29vD33N1CtxCmqQRPOHJ": "en-US-GuyNeural",          # Drew
    "2EiwWnXFnvU5JabPnv8n": "en-US-BrianNeural",        # Clyde
    "ErXwobaYiN019PkySvjV": "en-US-AndrewNeural",       # Antoni
    "TxGEqnHWrfWFTfGW9XjX": "en-US-RogerNeural",        # Josh
    "VR6AewLTigWG4xSOukaG": "en-US-SteffanNeural",      # Arnold
    "pNInz6obpgDQGcFmaJgB": "en-US-ChristopherNeural",  # Adam
    "yoZ06aMxZJJ28mfd3POQ": "en-US-EricNeural",         # Sam
}

_FALLBACK_DEFAULT = "en-US-JennyNeural"  # last-resort; always a real voice


@lru_cache(maxsize=1)
def _azure_index() -> dict[tuple[str, str], str]:
    """(language, gender) → Azure voice id, built from the static catalog's
    provider='azure' voices. Only verified, in-catalog ids can be produced.
    Cached once (catalog is static)."""
    from psitta.providers.voice_catalog_static import VOICE_CATALOG
    idx: dict[tuple[str, str], str] = {}
    for v in VOICE_CATALOG:
        if v.get("provider") == "azure":
            idx.setdefault((v.get("language", ""), v.get("gender", "")), v["id"])
    return idx


@lru_cache(maxsize=None)
def _catalog_lang_gender(voice_id: str) -> tuple[str, str]:
    """(language, gender) for any catalog voice id; ('', 'female') if unknown."""
    from psitta.providers.voice_catalog_static import VOICE_CATALOG
    for v in VOICE_CATALOG:
        if v["id"] == voice_id:
            return v.get("language", ""), v.get("gender", "female")
    return "", "female"


def _resolve_azure(lang: str, gender: str) -> str:
    idx = _azure_index()
    if (lang, gender) in idx:                      # exact language + gender
        return idx[(lang, gender)]
    family = lang.split("-")[0] if lang else "en"
    for (l, g), aid in idx.items():                # same family, same gender
        if l.split("-")[0] == family and g == gender:
            return aid
    for (l, g), aid in idx.items():                # same family, any gender
        if l.split("-")[0] == family:
            return aid
    # English of the requested gender, else the hard default.
    return idx.get(("en-US", gender)) or idx.get(("en-US", "female")) or _FALLBACK_DEFAULT


def elevenlabs_to_azure(voice_id: str) -> str:
    """Translate a voice id to a native Microsoft Neural voice for the
    Edge/Azure fallback path, preserving language and gender and only ever
    returning a catalog-verified voice.

    Order:
      1. Already a native Microsoft id  → pass through unchanged.
      2. Known English ElevenLabs voice → its mapped en-US voice (variety).
      3. Otherwise                      → catalog language + gender resolved
         against the catalog's Azure voices (family fallback for languages with
         no native Azure voice, e.g. pt-PT → pt-BR).
    """
    if _MICROSOFT_NEURAL_PATTERN.match(voice_id):
        return voice_id
    if voice_id in ELEVENLABS_TO_AZURE:
        return ELEVENLABS_TO_AZURE[voice_id]
    lang, gender = _catalog_lang_gender(voice_id)
    gender = gender if gender in ("male", "female") else "female"
    return _resolve_azure(lang, gender)
