from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from ..services.firebase_service import verify_token, get_user_by_id
from ..models.schemas import UserProfile

router = APIRouter(prefix="/user", tags=["Authentication"])
security = HTTPBearer()

# backend/app/api/auth.py のget_current_user関数を修正
async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    try:
        print(f"Received token: {credentials.credentials[:10]}...") # トークンの先頭部分だけを表示
        token = credentials.credentials
        user_data = await verify_token(token)
        return user_data
    except Exception as e:
        print(f"Authentication error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"認証に失敗しました: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )

@router.get("/profile", response_model=UserProfile)
async def get_user_profile(user_data: dict = Depends(get_current_user)):
    user_id = user_data["uid"]
    user = get_user_by_id(user_id)
    
    return {
        "userId": user_id,
        "displayName": user.display_name or "",
        "email": user.email or ""
    }