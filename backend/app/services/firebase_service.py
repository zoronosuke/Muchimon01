import firebase_admin
from firebase_admin import credentials, auth, firestore, storage
from fastapi import HTTPException, status
from ..core.config import settings

cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
# バケット名を追加して初期化
firebase_app = firebase_admin.initialize_app(cred, {
    'storageBucket': settings.STORAGE_BUCKET_NAME
})
db = firestore.client()
# Firebase Storageのバケット参照を取得
bucket = storage.bucket()

async def verify_token(token: str):
    try:
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid authentication credentials: {e}",
        )

def get_user_by_id(user_id: str):
    try:
        user = auth.get_user(user_id)
        return user
    except auth.UserNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User not found: {user_id}",
        )
