"""Voice ID mapping between TTS providers.

Only uses verified available voices.
"""

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

def elevenlabs_to_azure(voice_id: str) -> str:
    return ELEVENLABS_TO_AZURE.get(voice_id, "en-US-JennyNeural")
