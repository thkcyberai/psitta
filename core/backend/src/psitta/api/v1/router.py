"""
API v1 router — aggregates all endpoint modules.
"""

from __future__ import annotations

from fastapi import APIRouter

from psitta.api.v1.documents import router as documents_router
from psitta.api.v1.playback import router as playback_router
from psitta.api.v1.voices import router as voices_router
from psitta.api.v1.users import router as users_router

api_router = APIRouter()

api_router.include_router(documents_router, prefix="/documents", tags=["documents"])
api_router.include_router(playback_router, prefix="/playback", tags=["playback"])
api_router.include_router(voices_router, prefix="/voices", tags=["voices"])
api_router.include_router(users_router, prefix="/users", tags=["users"])
