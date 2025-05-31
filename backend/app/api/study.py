from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import uuid
from datetime import datetime
from ..services.firebase_service import verify_token, db
from ..models.schemas import (
    StudySessionStart, 
    StudySessionResponse, 
    LessonResponse, 
    TeachRequest, 
    TeachResponse,
    EndSessionResponse
)
from ..api.auth import get_current_user

router = APIRouter(prefix="/study", tags=["Study"])
security = HTTPBearer()

@router.post("/session/start", response_model=StudySessionResponse)
async def start_study_session(
    request: StudySessionStart,
    user_data: dict = Depends(get_current_user)
):
    try:
        user_id = user_data["uid"]
        session_id = str(uuid.uuid4())
        start_time = datetime.now()
        
        # セッションデータをFirestoreに保存
        session_ref = db.collection("study_sessions").document(session_id)
        session_ref.set({
            "userId": user_id,
            "subject": request.subject,
            "startTime": start_time,
            "status": "active"
        })
        
        # 初期授業データを作成
        lesson_id = f"L{uuid.uuid4().hex[:6]}"
        lesson_ref = db.collection("lessons").document(lesson_id)
        lesson_data = {
            "lessonId": lesson_id,
            "sessionId": session_id,
            "title": f"{request.subject}の基本概念の確認",
            "content": f"{request.subject}についての基本概念を確認していきましょう。",
            "order": 1,
            "nextAction": "teach"
        }
        lesson_ref.set(lesson_data)
        
        return {
            "sessionId": session_id,
            "startTime": start_time,
            "initialLesson": {
                "lessonId": lesson_id,
                "title": lesson_data["title"],
                "content": lesson_data["content"],
                "nextAction": lesson_data["nextAction"]
            }
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"セッション開始に失敗しました: {str(e)}"
        )
    
# @router.post("/session/start")
# async def start_study_session(request: StudySessionStart):
#     # ユーザーIDを取得
#     user_id = "dummy_user_id"
    
#     # 新しいセッションIDを生成
#     session_id = "dummy_session_id"
    
#     # 現在の日時をセッションの開始時間として記録
#     start_time = datetime.now()
    
#     # キャメルケースのフィールド名を使用してレスポンスを返す
#     return {
#         "sessionId": session_id,  # session_id → sessionId
#         "startTime": start_time,  # start_time → startTime
#         "initialLesson": {        # initial_lesson → initialLesson
#             "lessonId": "dummy_lesson_id",  # lesson_id → lessonId
#             "content": "This is a dummy lesson content."
#         }
#     }

@router.get("/session/{session_id}/lesson", response_model=LessonResponse)
async def get_lesson(
    session_id: str,
    user_data: dict = Depends(get_current_user)
):
    user_id = user_data["uid"]
    
    # セッションが存在するか確認
    session_ref = db.collection("study_sessions").document(session_id)
    session = session_ref.get()
    
    if not session.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found"
        )
    
    session_data = session.to_dict()
    
    # セッションの所有者を確認
    if session_data["userId"] != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have permission to access this session"
        )
    
    # 最新の授業を取得
    lessons = db.collection("lessons").where("sessionId", "==", session_id).order_by("order", direction="DESCENDING").limit(1).stream()
    
    lesson_data = None
    for lesson in lessons:
        lesson_data = lesson.to_dict()
        break
    
    if not lesson_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No lessons found for this session"
        )
    
    return {
        "lessonId": lesson_data["lessonId"],
        "title": lesson_data["title"],
        "content": lesson_data["content"],
        "nextAction": lesson_data.get("nextAction")
    }

@router.post("/session/{session_id}/teach", response_model=TeachResponse)
async def teach_mochimon(
    session_id: str,
    request: TeachRequest,
    user_data: dict = Depends(get_current_user)
):
    user_id = user_data["uid"]
    
    # セッションの存在とアクセス権を確認
    session_ref = db.collection("study_sessions").document(session_id)
    session = session_ref.get()
    
    if not session.exists or session.to_dict()["userId"] != user_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found or access denied"
        )
    
    # 教授記録を保存
    record_id = f"TR{uuid.uuid4().hex[:6]}"
    record_ref = db.collection("teaching_records").document(record_id)
    
    # AIフィードバックを生成（実際にはLangChainなどを使用）
    feedback = "とても良い説明でした！具体例を使って概念を説明できています。"
    progress = 85  # 実際には計算ロジックが必要
    
    record_data = {
        "recordId": record_id,
        "sessionId": session_id,
        "teachingContent": request.teachingContent,
        "feedback": feedback,
        "updatedProgress": progress,
        "timestamp": datetime.now()
    }
    record_ref.set(record_data)
    
    return {
        "status": "success",
        "message": "授業内容がムチモンに伝えられました。",
        "feedback": feedback,
        "updatedProgress": progress
    }

@router.post("/session/{session_id}/end", response_model=EndSessionResponse)
async def end_study_session(
    session_id: str,
    user_data: dict = Depends(get_current_user)
):
    user_id = user_data["uid"]
    
    # セッションの存在とアクセス権を確認
    session_ref = db.collection("study_sessions").document(session_id)
    session = session_ref.get()
    
    if not session.exists or session.to_dict()["userId"] != user_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found or access denied"
        )
    
    # セッションを終了状態に更新
    session_ref.update({
        "status": "ended",
        "endTime": datetime.now()
    })
    
    # セッションサマリーを生成（実際にはもっと詳細なロジックが必要）
    # 例: 教授記録から内容を要約、スコアを計算など
    summary = "本日の学習内容：基本概念の確認、授業の振り返りを実施。"
    final_score = 90
    
    return {
        "status": "ended",
        "summary": summary,
        "finalScore": final_score
    }

@router.get("/units", response_model=dict)
async def get_available_units(
    user_data: dict = Depends(get_current_user)
):
    """
    Firestoreから利用可能な学習単元（学年、科目、章、節）を取得します
    """
    try:
        # Firestoreから単元情報を取得
        units_ref = db.collection("study_units").document("available_units")
        units_doc = units_ref.get()
        
        if not units_doc.exists:
            # デフォルトのユニットデータを返す（初期データがない場合）
            return {
                "grades": ["中1", "中2", "中3"],
                "subjectsByGrade": {
                    "中1": ["数学"],
                    "中2": [],
                    "中3": []
                },
                "chaptersBySubject": {
                    "数学": ["1章"]
                },
                "sectionsByChapter": {
                    "数学_1章": ["1節①", "1節②"]
                }
            }
        
        # Firestoreから取得したユニットデータを返す
        return units_doc.to_dict()
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"学習単元の取得に失敗しました: {str(e)}"
        )

@router.get("/test/firebase")
async def test_firebase():
    """
    Firebase接続テスト用エンドポイント
    Firestoreに「Firebaseのテスト」というデータを保存します
    """
    try:
        # テスト用ドキュメントの作成
        test_id = str(uuid.uuid4())
        test_ref = db.collection("test_data").document(test_id)
        
        # テストデータをFirestoreに保存
        test_ref.set({
            "message": "Firebaseのテスト",
            "timestamp": datetime.now()
        })
        
        return {
            "status": "success",
            "message": "Firebaseへのテストデータ書き込みに成功しました",
            "documentId": test_id
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Firebaseテストに失敗しました: {str(e)}"
        )
