import os
from dotenv import load_dotenv

# .envファイルから環境変数を読み込み
load_dotenv()

class Settings:
    PROJECT_NAME: str = "ムチモン学習アプリAPI"
    PROJECT_VERSION: str = "1.0.0"
    
    OPENAI_API_KEY: str = os.getenv("OPENAI_API_KEY")
    OPENAI_API_ASSISTANTS_KEY: str = os.getenv("OPENAI_API_ASSISTANTS_KEY")
    FIREBASE_CREDENTIALS_PATH: str = os.getenv("FIREBASE_CREDENTIALS_PATH")
    
    # TTS設定
    VOICEVOX_ENGINE_URL: str = os.getenv("VOICEVOX_ENGINE_URL", "http://127.0.0.1:50021")
    STORAGE_BUCKET_NAME: str = os.getenv("STORAGE_BUCKET_NAME")
    STORAGE_TTS_FOLDER: str = os.getenv("STORAGE_TTS_FOLDER", "tts")
    TTS_CACHE_EXPIRY_DAYS: int = int(os.getenv("TTS_CACHE_EXPIRY_DAYS", "30"))

settings = Settings()
