"""Static voice catalog — ElevenLabs (20) + Azure Neural (12)."""

VOICE_CATALOG = [
    # ── ElevenLabs ───────────────────────────────────────────────────────
    {"id": "21m00Tcm4TlvDq8ikWAM", "name": "Rachel",  "display_name": "Rachel",  "language": "en-US", "gender": "female", "provider": "elevenlabs", "tier": "premium"},
    {"id": "EXAVITQu4vr4xnSDxMaL", "name": "Bella",   "display_name": "Bella",   "language": "en-US", "gender": "female", "provider": "elevenlabs", "tier": "premium"},
    {"id": "AZnzlk1XvdvUeBnXmlld", "name": "Domi",    "display_name": "Domi",    "language": "en-US", "gender": "female", "provider": "elevenlabs", "tier": "premium"},
    {"id": "MF3mGyEYCl7XYWbV9V6O", "name": "Elli",    "display_name": "Elli",    "language": "en-US", "gender": "female", "provider": "elevenlabs", "tier": "premium"},
    {"id": "XB0fDUnXU5powFXDhCwa", "name": "Glinda",  "display_name": "Glinda",  "language": "en-US", "gender": "female", "provider": "elevenlabs", "tier": "premium"},
    {"id": "pNInz6obpgDQGcFmaJgB", "name": "Adam",    "display_name": "Adam",    "language": "en-US", "gender": "male",   "provider": "elevenlabs", "tier": "premium"},
    {"id": "29vD33N1CtxCmqQRPOHJ", "name": "Drew",    "display_name": "Drew",    "language": "en-US", "gender": "male",   "provider": "elevenlabs", "tier": "premium"},
    {"id": "ErXwobaYiN019PkySvjV", "name": "Antoni",  "display_name": "Antoni",  "language": "en-US", "gender": "male",   "provider": "elevenlabs", "tier": "premium"},
    {"id": "2EiwWnXFnvU5JabPnv8n", "name": "Clyde",   "display_name": "Clyde",   "language": "en-US", "gender": "male",   "provider": "elevenlabs", "tier": "premium"},
    {"id": "TxGEqnHWrfWFTfGW9XjX", "name": "Josh",    "display_name": "Josh",    "language": "en-US", "gender": "male",   "provider": "elevenlabs", "tier": "premium"},
    {"id": "VR6AewLTigWG4xSOukaG", "name": "Arnold",  "display_name": "Arnold",  "language": "en-US", "gender": "male",   "provider": "elevenlabs", "tier": "premium"},
    {"id": "yoZ06aMxZJJ28mfd3POQ", "name": "Sam",     "display_name": "Sam",     "language": "en-US", "gender": "male",   "provider": "elevenlabs", "tier": "premium"},
    # ── Azure Neural ─────────────────────────────────────────────────────
    {"id": "en-US-AriaNeural",     "name": "Aria",    "display_name": "Aria",    "language": "en-US", "gender": "female", "provider": "azure",       "tier": "standard"},
    {"id": "en-US-JennyNeural",    "name": "Jenny",   "display_name": "Jenny",   "language": "en-US", "gender": "female", "provider": "azure",       "tier": "standard"},
    {"id": "en-GB-SoniaNeural",    "name": "Sonia",   "display_name": "Sonia",   "language": "en-GB", "gender": "female", "provider": "azure",       "tier": "standard"},
    {"id": "en-US-GuyNeural",      "name": "Guy",     "display_name": "Guy",     "language": "en-US", "gender": "male",   "provider": "azure",       "tier": "standard"},
    {"id": "en-US-DavisNeural",    "name": "Davis",   "display_name": "Davis",   "language": "en-US", "gender": "male",   "provider": "azure",       "tier": "standard"},
    {"id": "en-GB-RyanNeural",     "name": "Ryan",    "display_name": "Ryan",    "language": "en-GB", "gender": "male",   "provider": "azure",       "tier": "standard"},
    # ── Azure Neural — Portuguese / Spanish / French (native, standard) ──
    {"id": "pt-BR-FranciscaNeural", "name": "Francisca", "display_name": "Francisca", "language": "pt-BR", "gender": "female", "provider": "azure",       "tier": "standard"},
    {"id": "pt-BR-AntonioNeural",   "name": "Antonio",   "display_name": "Ant\u00f4nio",   "language": "pt-BR", "gender": "male",   "provider": "azure",       "tier": "standard"},
    {"id": "es-ES-ElviraNeural",    "name": "Elvira",    "display_name": "Elvira",    "language": "es-ES", "gender": "female", "provider": "azure",       "tier": "standard"},
    {"id": "es-ES-AlvaroNeural",    "name": "Alvaro",    "display_name": "\u00c1lvaro",    "language": "es-ES", "gender": "male",   "provider": "azure",       "tier": "standard"},
    {"id": "fr-FR-DeniseNeural",    "name": "Denise",    "display_name": "Denise",    "language": "fr-FR", "gender": "female", "provider": "azure",       "tier": "standard"},
    {"id": "fr-FR-HenriNeural",     "name": "Henri",     "display_name": "Henri",     "language": "fr-FR", "gender": "male",   "provider": "azure",       "tier": "standard"},
    # ── ElevenLabs — native premium: Portuguese (BR) / Spanish (ES) / French (FR) ──
    {"id": "oArP4WehPe3qjqvCwHNo", "name": "Matheus",  "display_name": "Matheus",  "language": "pt-BR", "gender": "male",   "provider": "elevenlabs", "tier": "premium"},
    {"id": "sXSV9RZ095VZyL64w3ap", "name": "Alexa",    "display_name": "Alexa",    "language": "pt-BR", "gender": "female", "provider": "elevenlabs", "tier": "premium"},
    {"id": "Cmqnney5svFebDMl5Y9L", "name": "Gael",     "display_name": "Gael",     "language": "es-ES", "gender": "male",   "provider": "elevenlabs", "tier": "premium"},
    {"id": "AxFLn9byyiDbMn5fmyqu", "name": "Aitana",   "display_name": "Aitana",   "language": "es-ES", "gender": "female", "provider": "elevenlabs", "tier": "premium"},
    {"id": "UBXZKOKbt62aLQHhc1Jm", "name": "Francois", "display_name": "Fran\u00e7ois", "language": "fr-FR", "gender": "male",   "provider": "elevenlabs", "tier": "premium"},
    {"id": "cuo3D4C6LVenyV7b2Kpd", "name": "Anna",     "display_name": "Anna",     "language": "fr-FR", "gender": "female", "provider": "elevenlabs", "tier": "premium"},
    # ── ElevenLabs — native premium: European Portuguese (pt-PT) ──────────
    {"id": "hOLl3246BMBsdy0qtYLb", "name": "Nelson",   "display_name": "Nelson",   "language": "pt-PT", "gender": "male",   "provider": "elevenlabs", "tier": "premium"},
    {"id": "nJ5NFqyKb8kn9JBPmo6i", "name": "Joana",    "display_name": "Joana",    "language": "pt-PT", "gender": "female", "provider": "elevenlabs", "tier": "premium"},
]
