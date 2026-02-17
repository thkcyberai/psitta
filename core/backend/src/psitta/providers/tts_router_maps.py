"""Voice ID mapping between TTS providers."""

ELEVENLABS_TO_AZURE: dict[str, str] = {
    "21m00Tcm4TlvDq8ikWAM": "en-US-JennyNeural",
    "AZnzlk1XvdvUeBnXmlld": "en-US-AriaNeural",
    "EXAVITQu4vr4xnSDxMaL": "en-US-SaraNeural",
    "MF3mGyEYCl7XYWbV9V6O": "en-US-AmberNeural",
    "jBpfuIE2acCO8z3wKNLl": "en-US-AshleyNeural",
    "29vD33N1CtxCmqQRPOHJ": "en-US-GuyNeural",
    "2EiwWnXFnvU5JabPnv8n": "en-US-DavisNeural",
    "ErXwobaYiN019PkySvjV": "en-US-TonyNeural",
    "TxGEqnHWrfWFTfGW9XjX": "en-US-JasonNeural",
    "VR6AewLTigWG4xSOukaG": "en-US-BrandonNeural",
    "pNInz6obpgDQGcFmaJgB": "en-US-ChristopherNeural",
    "yoZ06aMxZJJ28mfd3POQ": "en-US-EricNeural",
}

def elevenlabs_to_azure(voice_id: str) -> str:
    return ELEVENLABS_TO_AZURE.get(voice_id, "en-US-JennyNeural")
