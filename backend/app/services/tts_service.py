import hashlib
import httpx
import asyncio
import os
import re
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from ..core.config import settings
from ..services.firebase_service import db, bucket

class TTSService:
    def __init__(self):
        self.voicevox_base_url = settings.VOICEVOX_ENGINE_URL
        self.collection_name = "tts_cache"  # Firestoreのコレクション名
        self.storage_folder = settings.STORAGE_TTS_FOLDER
        self.cache_expiry_days = settings.TTS_CACHE_EXPIRY_DAYS
        
    def _preprocess_text(self, text: str) -> str:
        """
        テキストを前処理し、数字が正しく読み上げられるように変換します。
        数字が"ポンド"と読まれる問題を修正するための処理です。
        
        Args:
            text: 前処理するテキスト
            
        Returns:
            str: 前処理後のテキスト
        """
        # 数字が#記号と誤解される場合があるため、その対策
        # 数字の後に日本語が続く場合は、数字を全角に変換して区別を明確にする
        # 半角→全角変換マッピング
        zen_digits = {
            '0': '０', '1': '１', '2': '２', '3': '３', '4': '４', 
            '5': '５', '6': '６', '7': '７', '8': '８', '9': '９'
        }
        
        # 数字を全角に変換する関数
        def to_zen(match):
            digit = match.group(1)
            jp_char = match.group(2)
            zen_digit = ''.join(zen_digits.get(c, c) for c in digit)
            return f"{zen_digit}{jp_char}"
        
        # 数字+日本語のパターンを見つけて変換
        text = re.sub(r'(\d+)([一-龯ぁ-んァ-ヶ])', to_zen, text)
        
        return text
    
    async def get_audio(self, text: str, speaker_id: int = 1) -> Dict[str, Any]:
        """
        テキストを音声に変換し、Cloud Storageに保存します。
        既に同じテキストの音声が存在する場合は再利用します。
        
        Args:
            text: 音声に変換するテキスト
            speaker_id: 話者ID (VOICEVOX Engineの話者ID)
            
        Returns:
            dict: 音声ファイルのURL、作成日時などを含む辞書
        """
        # キャッシュキーは元のテキストで生成（互換性を保つため）
        cache_key = self._generate_cache_key(speaker_id, text)
        
        # Firestoreでキャッシュを確認
        cached_audio = self._check_cache(cache_key)
        if cached_audio:
            return cached_audio
            
        # テキストの前処理（キャッシュになかった場合のみ実行）
        processed_text = self._preprocess_text(text)
        
        # 音声合成処理
        try:
            audio_data = await self._generate_voice(processed_text, speaker_id)
            
            # Cloud Storageに保存
            storage_path = f"{self.storage_folder}/{cache_key}.mp3"
            blob = bucket.blob(storage_path)
            
            # メタデータ設定（オプショナル）
            metadata = {
                "speakerId": str(speaker_id),
                "textHash": hashlib.sha256(text.encode()).hexdigest(),
                "createdAt": datetime.now().isoformat()
            }
            blob.metadata = metadata
            
            # アップロード（Content-Typeを明示的に指定）
            blob.upload_from_string(
                audio_data,
                content_type="audio/mpeg"
            )
            
            # アクセスURL生成（一時的なURLを生成、有効期限は最大7日）
            # 注意: Google Cloud Storageの署名付きURLは最大7日(604800秒)の有効期限しかサポートしていません
            # 7日より長い期間を指定すると「Max allowed expiration interval is seven days 604800」エラーが発生します
            url = blob.generate_signed_url(
                version="v4",
                expiration=timedelta(days=7),  # GCSの最大期限は7日(604800秒)
                method="GET"
            )
            
            # Firestoreにキャッシュ情報を保存
            cache_data = {
                "url": url,
                "storagePath": storage_path,
                "createdAt": datetime.now(),
                "speakerId": speaker_id,
                "textLength": len(text),
                "expiresAt": datetime.now() + timedelta(days=7),  # URL有効期限(7日)
                "cacheExpiresAt": datetime.now() + timedelta(days=self.cache_expiry_days)  # キャッシュ期限(設定値)
            }
            
            db.collection(self.collection_name).document(cache_key).set(cache_data)
            
            return {
                "url": url,
                "cacheKey": cache_key,
                "createdAt": cache_data["createdAt"].isoformat(),
                "expiresAt": cache_data["expiresAt"].isoformat(),
                "cached": False
            }
            
        except Exception as e:
            # エラーログ
            print(f"TTS生成エラー: {e}")
            # エラー時はURLなしで返す（必須フィールドを含める）
            return {
                "error": str(e),
                "url": None,
                "cacheKey": cache_key,
                "createdAt": datetime.now().isoformat(),  # 必須フィールド
                "expiresAt": (datetime.now() + timedelta(days=1)).isoformat(),  # オプションだが含めておく
                "cached": False
            }
    
    def _generate_cache_key(self, speaker_id: int, text: str) -> str:
        """話者IDとテキストからキャッシュキーを生成"""
        hash_input = f"{speaker_id}-{text}"
        return hashlib.sha256(hash_input.encode()).hexdigest()
    
    def _check_cache(self, cache_key: str) -> Optional[Dict[str, Any]]:
        """Firestoreでキャッシュを確認"""
        doc_ref = db.collection(self.collection_name).document(cache_key)
        doc = doc_ref.get()
        
        if doc.exists:
            cache_data = doc.to_dict()
            
            # URLが有効期限切れの場合は再生成
            if datetime.now() > cache_data.get("expiresAt").replace(tzinfo=None):
                storage_path = cache_data.get("storagePath")
                blob = bucket.blob(storage_path)
                
                # ファイルが存在するか確認
                if blob.exists():
                    # 新しいURLを生成 (最大7日)
                    url = blob.generate_signed_url(
                        version="v4",
                        expiration=timedelta(days=7),  # GCSの最大期限は7日(604800秒)
                        method="GET"
                    )
                    
                    # キャッシュ情報を更新 (URL有効期限は7日)
                    expires_at = datetime.now() + timedelta(days=7)
                    doc_ref.update({
                        "url": url,
                        "expiresAt": expires_at
                    })
                    
                    return {
                        "url": url,
                        "cacheKey": cache_key,
                        "createdAt": cache_data["createdAt"].isoformat(),
                        "expiresAt": expires_at.isoformat(),
                        "cached": True
                    }
                else:
                    # ファイルが存在しない場合はキャッシュエントリを削除
                    doc_ref.delete()
                    return None
            
            # 有効なキャッシュの場合
            return {
                "url": cache_data["url"],
                "cacheKey": cache_key,
                "createdAt": cache_data["createdAt"].isoformat(),
                "expiresAt": cache_data["expiresAt"].isoformat(),
                "cached": True
            }
        
        return None
    
    async def _generate_voice(self, text: str, speaker_id: int) -> bytes:
        """VOICEVOX Engineを使用して音声を生成"""
        async with httpx.AsyncClient() as client:
            # ステップ1: audio_query生成
            query_url = f"{self.voicevox_base_url}/audio_query?speaker={speaker_id}&text={text}"
            query_response = await client.post(query_url)
            
            if query_response.status_code != 200:
                raise Exception(f"audio_query生成失敗: {query_response.text}")
            
            query_data = query_response.json()
            
            # ステップ2: 音声合成
            synthesis_url = f"{self.voicevox_base_url}/synthesis?speaker={speaker_id}"
            synthesis_response = await client.post(
                synthesis_url,
                json=query_data,
                headers={"Content-Type": "application/json"}
            )
            
            if synthesis_response.status_code != 200:
                raise Exception(f"音声合成失敗: {synthesis_response.text}")
            
            return synthesis_response.content

# シングルトンインスタンス
tts_service = TTSService()
