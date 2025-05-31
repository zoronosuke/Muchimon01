from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import Optional
import asyncio
from ..services.tts_service import tts_service
from ..api.auth import get_current_user
from pydantic import BaseModel

router = APIRouter(prefix="/tts", tags=["Text-to-Speech"])

class TTSRequest(BaseModel):
    text: str
    speaker_id: int = 1

class TTSResponse(BaseModel):
    url: Optional[str]
    cacheKey: str
    createdAt: str
    expiresAt: Optional[str] = None
    cached: bool
    error: Optional[str] = None

@router.post("/synthesize", response_model=TTSResponse)
async def synthesize_speech(
    request: TTSRequest,
    user_data: dict = Depends(get_current_user)
):
    """
    テキストを音声に変換し、その音声データのURLを返します。
    既に同じテキストの音声が存在する場合は、それを再利用します。
    
    - キャッシュ処理: sha256("$speakerId-$text") をキーとして重複生成を回避
    - 格納先: Cloud Storage (TTSサービスが自動的に処理)
    - キャッシュ: Firestoreにメタデータを保存し、クライアントはまずFirestoreを参照
    """
    try:
        result = await tts_service.get_audio(request.text, request.speaker_id)
        return result
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"音声合成に失敗しました: {str(e)}"
        )

@router.get("/audio", response_model=TTSResponse)
async def get_speech_audio(
    text: str = Query(..., description="音声合成するテキスト"),
    speaker_id: int = Query(1, description="話者ID（VOICEVOXの話者ID）"),
    user_data: dict = Depends(get_current_user)
):
    """
    テキストを音声に変換し、その音声データのURLを返します。
    既に同じテキストの音声が存在する場合は、それを再利用します。
    """
    try:
        result = await tts_service.get_audio(text, speaker_id)
        return result
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"音声合成に失敗しました: {str(e)}"
        )
