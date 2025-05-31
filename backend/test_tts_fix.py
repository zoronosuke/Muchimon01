import asyncio
import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from app.services.tts_service import tts_service

async def test_tts_generation():
    """Test that TTS generation works with the fixed URL expiration interval"""
    try:
        result = await tts_service.get_audio("これはテスト音声です。", speaker_id=1)
        print("TTS生成成功!")
        print(f"URL: {result['url']}")
        print(f"作成日時: {result['createdAt']}")
        print(f"有効期限: {result['expiresAt']}")
        print(f"キャッシュ状態: {'キャッシュあり' if result['cached'] else '新規生成'}")
        return True
    except Exception as e:
        print(f"TTS生成エラー: {e}")
        return False

if __name__ == "__main__":
    success = asyncio.run(test_tts_generation())
    sys.exit(0 if success else 1)
