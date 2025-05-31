from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .core.config import settings
from .api import auth, study, mochimon, chat, tts

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.PROJECT_VERSION
)

# CORSミドルウェアの設定
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 本番環境では特定のオリジンのみを許可
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ルーターの登録
app.include_router(auth.router)
app.include_router(study.router)
app.include_router(mochimon.router)
app.include_router(chat.router)
app.include_router(tts.router)

@app.get("/")
async def root():
    return {
        "message": "ムチモン学習アプリ API",
        "version": settings.PROJECT_VERSION
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
