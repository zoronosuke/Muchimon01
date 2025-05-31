from fastapi import APIRouter, Depends
from ..api.auth import get_current_user
from ..models.schemas import MochimonImagesResponse, MochimonImage

router = APIRouter(prefix="/mochimon", tags=["Mochimon"])

@router.get("/images", response_model=MochimonImagesResponse)
async def get_mochimon_images(user_data: dict = Depends(get_current_user)):
    # 実際のアプリではFirestoreから画像データを取得
    # デモ用のサンプルデータ
    images = [
        {
            "id": "img001",
            "imageUrl": "https://storage.example.com/mochimon/img001.png",
            "description": "元気なムチモン",
            "metadata": {
                "createdAt": "2025-02-20T08:00:00Z"
            }
        },
        {
            "id": "img002",
            "imageUrl": "https://storage.example.com/mochimon/img002.png",
            "description": "考えるムチモン",
            "metadata": {
                "createdAt": "2025-02-20T08:00:00Z"
            }
        }
    ]
    
    return {"images": images}

@router.get("/images/{image_id}", response_model=MochimonImage)
async def get_mochimon_image_detail(
    image_id: str,
    user_data: dict = Depends(get_current_user)
):
    # 実際のアプリではFirestoreから特定の画像データを取得
    # デモ用のサンプルデータ
    if image_id == "img001":
        return {
            "id": "img001",
            "imageUrl": "https://storage.example.com/mochimon/img001.png",
            "description": "元気なムチモン",
            "metadata": {
                "createdAt": "2025-02-20T08:00:00Z"
            }
        }
    else:
        return {
            "id": "img002",
            "imageUrl": "https://storage.example.com/mochimon/img002.png",
            "description": "考えるムチモン",
            "metadata": {
                "createdAt": "2025-02-20T08:00:00Z"
            }
        }