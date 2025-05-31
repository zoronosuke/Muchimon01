from fastapi import APIRouter, Depends, HTTPException, status
from datetime import datetime
import uuid
from typing import Optional, List, Dict, Any  # Optionalを追加
from ..api.auth import get_current_user
from ..services.ai_service import ai_service
from ..services.assistants_service import assistants_service
from ..services.firebase_service import db
from ..models.schemas import (
    ChatMessageRequest, 
    ChatMessageResponse, 
    ChatHistoryResponse, 
    ChatMessage,
    ChatRoomRequest,
    ChatRoomResponse,
    ChatRoomListResponse,
    ChatRoomDetail
)

router = APIRouter(prefix="/chat", tags=["Chat"])

@router.post("/rooms", response_model=ChatRoomResponse)
async def create_chat_room(
    request: ChatRoomRequest,
    user_data: dict = Depends(get_current_user)
):
    """新しいチャットルーム（AIとの会話）を作成"""
    user_id = user_data["uid"]
    user_name = user_data.get("name", "ユーザー")
    
    # チャットルームIDの生成
    room_id = f"room-{uuid.uuid4().hex[:10]}"
    now = datetime.now()
    
    # チャットルームデータの作成
    chat_room = {
        "id": room_id,
        "name": request.name or f"{user_name}のチャット",
        "topic": request.topic or "一般的な会話",
        "createdBy": user_id,
        "createdAt": now,
        "updatedAt": now,
        "participants": [
            {
                "userId": user_id,
                "joinedAt": now,
                "role": "admin"
            },
            {
                "userId": "ai-assistant",
                "joinedAt": now,
                "role": "member"
            }
        ],
        "isPrivate": True,
        "metadata": request.metadata or {}
    }
    
    # Firestoreにチャットルーム情報を保存
    room_ref = db.collection("chatRooms").document(room_id)
    room_ref.set(chat_room)
    
    # ユーザードキュメントを更新してチャットルームを追加
    user_ref = db.collection("users").document(user_id)
    user_doc = user_ref.get()
    
    if user_doc.exists:
        user_data = user_doc.to_dict()
        chat_rooms = user_data.get("chatRooms", [])
        if room_id not in chat_rooms:
            chat_rooms.append(room_id)
            user_ref.update({"chatRooms": chat_rooms})
    else:
        # ユーザードキュメントが存在しない場合は作成
        user_ref.set({
            "id": user_id,
            "username": user_name,
            "email": user_data.get("email", ""),
            "lastActive": now,
            "createdAt": now,
            "chatRooms": [room_id]
        })
    
    return {
        "roomId": room_id,
        "name": chat_room["name"],
        "topic": chat_room["topic"],
        "createdAt": chat_room["createdAt"]
    }

@router.get("/rooms", response_model=ChatRoomListResponse)
async def get_chat_rooms(user_data: dict = Depends(get_current_user)):
    """ユーザーのチャットルーム一覧を取得"""
    user_id = user_data["uid"]
    
    # ユーザーの参加しているチャットルームを取得
    rooms_query = db.collection("chatRooms").where("participants", "array_contains", {"userId": user_id})
    
    # 代替手法: ユーザードキュメントからチャットルーム一覧を取得
    user_ref = db.collection("users").document(user_id)
    user_doc = user_ref.get()
    
    rooms = []
    if user_doc.exists:
        user_data = user_doc.to_dict()
        room_ids = user_data.get("chatRooms", [])
        
        for room_id in room_ids:
            room_ref = db.collection("chatRooms").document(room_id)
            room_doc = room_ref.get()
            
            if room_doc.exists:
                room_data = room_doc.to_dict()
                
                # 最新メッセージを取得
                last_message = None
                messages_query = (
                    db.collection("messages")
                    .where("roomId", "==", room_id)
                    .order_by("timestamp", direction="DESCENDING")
                    .limit(1)
                )
                
                for msg in messages_query.stream():
                    msg_data = msg.to_dict()
                    last_message = {
                        "content": msg_data.get("content", ""),
                        "senderId": msg_data.get("senderId", ""),
                        "timestamp": msg_data.get("timestamp", datetime.now())
                    }
                    break
                
                rooms.append(
                    ChatRoomDetail(
                        id=room_data.get("id"),
                        name=room_data.get("name"),
                        topic=room_data.get("topic"),
                        createdAt=room_data.get("createdAt"),
                        updatedAt=room_data.get("updatedAt"),
                        lastMessage=last_message
                    )
                )
    
    return {"rooms": rooms}

@router.get("/rooms/{room_id}", response_model=ChatRoomDetail)
async def get_chat_room(
    room_id: str,
    user_data: dict = Depends(get_current_user)
):
    """特定のチャットルーム情報を取得"""
    user_id = user_data["uid"]
    
    # チャットルームの存在と参加権限を確認
    room_ref = db.collection("chatRooms").document(room_id)
    room_doc = room_ref.get()
    
    if not room_doc.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Chat room not found"
        )
    
    room_data = room_doc.to_dict()
    participants = room_data.get("participants", [])
    user_is_participant = False
    
    for participant in participants:
        if participant.get("userId") == user_id:
            user_is_participant = True
            break
    
    if not user_is_participant and room_data.get("isPrivate", True):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have access to this chat room"
        )
    
    # 最新メッセージを取得
    last_message = None
    messages_query = (
        db.collection("messages")
        .where("roomId", "==", room_id)
        .order_by("timestamp", direction="DESCENDING")
        .limit(1)
    )
    
    for msg in messages_query.stream():
        msg_data = msg.to_dict()
        last_message = {
            "content": msg_data.get("content", ""),
            "senderId": msg_data.get("senderId", ""),
            "timestamp": msg_data.get("timestamp", datetime.now())
        }
        break
    
    return ChatRoomDetail(
        id=room_data.get("id"),
        name=room_data.get("name"),
        topic=room_data.get("topic"),
        createdAt=room_data.get("createdAt"),
        updatedAt=room_data.get("updatedAt"),
        lastMessage=last_message,
        participants=room_data.get("participants")
    )

@router.post("/rooms/{room_id}/messages", response_model=ChatMessageResponse)
async def send_chat_message(
    room_id: str,
    request: ChatMessageRequest,
    use_assistant: bool = False,  # Assistants APIを使うかどうかのクエリパラメータ
    user_data: dict = Depends(get_current_user)
):
    """チャットルームにメッセージを送信"""
    user_id = user_data["uid"]
    
    # チャットルームの存在と参加権限を確認
    room_ref = db.collection("chatRooms").document(room_id)
    room_doc = room_ref.get()
    
    if not room_doc.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Chat room not found"
        )
    
    room_data = room_doc.to_dict()
    participants = room_data.get("participants", [])
    user_is_participant = False
    
    for participant in participants:
        if participant.get("userId") == user_id:
            user_is_participant = True
            break
    
    if not user_is_participant:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have access to this chat room"
        )
    
    now = datetime.now()
    
    # ユーザーメッセージをFirestoreに保存
    message_id = f"msg-{uuid.uuid4().hex[:10]}"
    message_ref = db.collection("messages").document(message_id)
    
    user_message = {
        "id": message_id,
        "roomId": room_id,
        "senderId": user_id,
        "content": request.message,
        "timestamp": now,
        "readBy": [{"userId": user_id, "readAt": now}],
        "isEdited": False
    }
    
    message_ref.set(user_message)
    
    # AIからの応答を取得
    ai_response = ""
    metadata = {}
    
    if use_assistant:
        # OpenAI Assistants APIを使用
        try:
            assistant_response = await assistants_service.send_message(room_id, request.message)
            ai_response = assistant_response["content"]
            metadata = {
                "openai_thread_id": assistant_response.get("thread_id", ""),
                "openai_message_id": assistant_response.get("message_id", ""),
                "using_assistants_api": True
            }
        except Exception as e:
            # エラー時はフォールバック
            print(f"Assistants API error: {e}")
            conversation_context = room_data.get("metadata", {}).get("conversation_context", room_id)
            ai_response = ai_service.process_message(conversation_context, request.message)
    else:
        # 通常のAIサービスを使用
        conversation_context = room_data.get("metadata", {}).get("conversation_context", room_id)
        ai_response = ai_service.process_message(conversation_context, request.message)
    
    # AIの応答をFirestoreに保存
    ai_message_id = f"msg-ai-{uuid.uuid4().hex[:10]}"
    ai_message_ref = db.collection("messages").document(ai_message_id)
    
    ai_message = {
        "id": ai_message_id,
        "roomId": room_id,
        "senderId": "ai-assistant",
        "content": ai_response,
        "timestamp": datetime.now(),
        "readBy": [{"userId": user_id, "readAt": datetime.now()}],
        "isEdited": False,
        "metadata": metadata
    }
    
    ai_message_ref.set(ai_message)
    
    # チャットルームの更新時間と最新メッセージを更新
    room_update = {
        "updatedAt": now,
        "lastMessage": {
            "content": ai_response,
            "senderId": "ai-assistant",
            "timestamp": now
        }
    }
    
    # Assistants APIを使用した場合はメタデータも更新
    if use_assistant and metadata:
        current_metadata = room_data.get("metadata", {})
        current_metadata.update({
            "using_assistants_api": True,
            "openai_thread_id": metadata.get("openai_thread_id", "")
        })
        room_update["metadata"] = current_metadata
    
    room_ref.update(room_update)
    
    return {
        "response": ai_response,
        "context": {
            "roomId": room_id,
            "messageId": ai_message_id,
            "usingAssistantsApi": use_assistant
        }
    }

@router.post("/rooms/{room_id}/assistant-messages", response_model=ChatMessageResponse)
async def send_assistant_message(
    room_id: str,
    request: ChatMessageRequest,
    grade: Optional[str] = None,
    subject: Optional[str] = None,
    chapter: Optional[str] = None,
    section: Optional[str] = None,
    user_data: dict = Depends(get_current_user)
):
    """OpenAI Assistants APIを使ってチャットルームにメッセージを送信"""
    user_id = user_data["uid"]
    
    # チャットルームの存在と参加権限を確認
    room_ref = db.collection("chatRooms").document(room_id)
    room_doc = room_ref.get()
    
    if not room_doc.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Chat room not found"
        )
    
    room_data = room_doc.to_dict()
    participants = room_data.get("participants", [])
    user_is_participant = False
    
    for participant in participants:
        if participant.get("userId") == user_id:
            user_is_participant = True
            break
    
    if not user_is_participant:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have access to this chat room"
        )
    
    now = datetime.now()
    
    # ユーザーメッセージをFirestoreに保存
    message_id = f"msg-{uuid.uuid4().hex[:10]}"
    message_ref = db.collection("messages").document(message_id)
    
    user_message = {
        "id": message_id,
        "roomId": room_id,
        "senderId": user_id,
        "content": request.message,
        "timestamp": now,
        "readBy": [{"userId": user_id, "readAt": now}],
        "isEdited": False
    }
    
    message_ref.set(user_message)
    
    # Assistants APIからの応答を取得
    try:
        # デバッグ情報をログに出力
        print(f"送信リクエスト: room_id={room_id}, message={request.message}")
        print(f"メタデータ: grade={grade}, subject={subject}, chapter={chapter}, section={section}")
        
        # チャットルームのメタデータ確認
        room_ref = db.collection("chatRooms").document(room_id)
        room_doc = room_ref.get()
        if room_doc.exists:
            room_data = room_doc.to_dict()
            metadata = room_data.get("metadata", {})
            print(f"ルームメタデータ: {metadata}")
            
            # メタデータに assistant キーがあるか確認
            room_assistant = metadata.get("assistant")
            if room_assistant:
                print(f"ルームのアシスタント名: {room_assistant}")
            
        # もし学年、科目などが指定されていれば、それを使用
        assistant_response = await assistants_service.send_message(
            room_id, 
            request.message,
            grade=grade,
            subject=subject,
            chapter=chapter,
            section=section
        )
        
        ai_response = assistant_response["content"]
        
        # AIの応答をFirestoreに保存
        ai_message_id = f"msg-ai-{uuid.uuid4().hex[:10]}"
        ai_message_ref = db.collection("messages").document(ai_message_id)
        
        # ルームの現在のアシスタント設定を取得
        assistant_settings = assistants_service.get_room_assistant_settings(room_id)
        
        ai_message = {
            "id": ai_message_id,
            "roomId": room_id,
            "senderId": "ai-assistant",
            "content": ai_response,
            "timestamp": datetime.now(),
            "readBy": [{"userId": user_id, "readAt": datetime.now()}],
            "isEdited": False,
            "metadata": {
                "openai_thread_id": assistant_response.get("thread_id", ""),
                "openai_message_id": assistant_response.get("message_id", ""),
                "using_assistants_api": True,
                "assistant_grade": assistant_settings["grade"],
                "assistant_subject": assistant_settings["subject"],
                "assistant_chapter": assistant_settings["chapter"],
                "assistant_section": assistant_settings["section"]
            }
        }
        
        ai_message_ref.set(ai_message)
        
        # チャットルームの更新時間と最新メッセージを更新
        current_metadata = room_data.get("metadata", {})
        current_metadata.update({
            "using_assistants_api": True,
            "openai_thread_id": assistant_response.get("thread_id", ""),
            "assistant_grade": assistant_settings["grade"],
            "assistant_subject": assistant_settings["subject"],
            "assistant_chapter": assistant_settings["chapter"],
            "assistant_section": assistant_settings["section"]
        })
        
        room_ref.update({
            "updatedAt": now,
            "lastMessage": {
                "content": ai_response,
                "senderId": "ai-assistant",
                "timestamp": now
            },
            "metadata": current_metadata
        })
        
        return {
            "response": ai_response,
            "context": {
                "roomId": room_id,
                "messageId": ai_message_id,
                "usingAssistantsApi": True,
                "threadId": assistant_response.get("thread_id", ""),
                "assistantSettings": assistant_settings
            }
        }
    except Exception as e:
        # エラー発生時は例外を返す
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error with Assistants API: {str(e)}"
        )

@router.get("/rooms/{room_id}/messages", response_model=ChatHistoryResponse)
async def get_room_messages(
    room_id: str,
    limit: int = 50,
    before_timestamp: Optional[datetime] = None,
    user_data: dict = Depends(get_current_user)
):
    """チャットルームのメッセージ履歴を取得"""
    user_id = user_data["uid"]
    
    # チャットルームの存在と参加権限を確認
    room_ref = db.collection("chatRooms").document(room_id)
    room_doc = room_ref.get()
    
    if not room_doc.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Chat room not found"
        )
    
    room_data = room_doc.to_dict()
    participants = room_data.get("participants", [])
    user_is_participant = False
    
    for participant in participants:
        if participant.get("userId") == user_id:
            user_is_participant = True
            break
    
    if not user_is_participant and room_data.get("isPrivate", True):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have access to this chat room"
        )
    
    # クエリ構築
    messages_query = (
        db.collection("messages")
        .where("roomId", "==", room_id)
        .order_by("timestamp", direction="DESCENDING")
        .limit(limit)
    )
    
    if before_timestamp:
        messages_query = messages_query.where("timestamp", "<", before_timestamp)
    
    # メッセージ取得
    messages = []
    for msg_doc in messages_query.stream():
        msg_data = msg_doc.to_dict()
        
        # 既読情報に自分を追加
        read_by = msg_data.get("readBy", [])
        user_has_read = False
        
        for read_info in read_by:
            if read_info.get("userId") == user_id:
                user_has_read = True
                break
        
        if not user_has_read:
            read_by.append({"userId": user_id, "readAt": datetime.now()})
            msg_doc.reference.update({"readBy": read_by})
        
        # リアクション情報の整形
        reactions = []
        for reaction in msg_data.get("reactions", []):
            reactions.append({
                "emoji": reaction.get("emoji", "👍"),
                "users": reaction.get("users", [])
            })
        
        # 添付ファイル情報の整形
        attachments = []
        for attachment in msg_data.get("attachments", []):
            attachments.append({
                "type": attachment.get("type", "file"),
                "url": attachment.get("url", ""),
                "name": attachment.get("name", ""),
                "size": attachment.get("size", 0)
            })
        
        messages.append(
            ChatMessage(
                id=msg_data.get("id"),
                roomId=msg_data.get("roomId"),
                senderId=msg_data.get("senderId"),
                content=msg_data.get("content"),
                timestamp=msg_data.get("timestamp"),
                readBy=msg_data.get("readBy", []),
                attachments=attachments,
                replyTo=msg_data.get("replyTo"),
                isEdited=msg_data.get("isEdited", False),
                reactions=reactions
            )
        )
    
    # 時系列順に並べ替え
    messages.sort(key=lambda x: x.timestamp)
    
    return {"messages": messages}

@router.delete("/rooms/{room_id}", status_code=status.HTTP_200_OK)
async def delete_chat_room(
    room_id: str,
    user_data: dict = Depends(get_current_user)
):
    """チャットルームを削除する"""
    user_id = user_data["uid"]
    
    # チャットルームの存在と権限を確認
    room_ref = db.collection("chatRooms").document(room_id)
    room_doc = room_ref.get()
    
    if not room_doc.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Chat room not found"
        )
    
    room_data = room_doc.to_dict()
    participants = room_data.get("participants", [])
    is_admin = False
    
    # ユーザーが管理者権限を持っているかチェック
    for participant in participants:
        if participant.get("userId") == user_id and participant.get("role") == "admin":
            is_admin = True
            break
    
    if not is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have permission to delete this chat room"
        )
    
    # チャットルームに関連するメッセージを削除
    messages_query = db.collection("messages").where("roomId", "==", room_id)
    batch = db.batch()
    
    # バッチ削除のサイズ制限があるため、複数のバッチに分ける
    all_messages = list(messages_query.stream())
    for i in range(0, len(all_messages), 500):  # Firestoreのバッチ上限は500
        batch = db.batch()
        batch_messages = all_messages[i:i+500]
        for msg in batch_messages:
            batch.delete(msg.reference)
        batch.commit()
    
    # チャットルーム自体を削除
    room_ref.delete()
    
    # ユーザードキュメントからチャットルームIDを削除
    user_ref = db.collection("users").document(user_id)
    user_doc = user_ref.get()
    
    if user_doc.exists:
        user_data = user_doc.to_dict()
        chat_rooms = user_data.get("chatRooms", [])
        if room_id in chat_rooms:
            chat_rooms.remove(room_id)
            user_ref.update({"chatRooms": chat_rooms})
    
    return {"status": "success", "message": "Chat room deleted successfully"}

# 以下は既存のAPIとの互換性のためのエンドポイント
@router.post("/message", response_model=ChatMessageResponse)
async def send_chat_message_legacy(
    request: ChatMessageRequest,
    user_data: dict = Depends(get_current_user)
):
    user_id = user_data["uid"]
    
    # 会話IDの取得または新規作成
    conversation_id = request.sessionId or f"conv-{uuid.uuid4().hex[:10]}"
    
    # AIからの応答を取得
    ai_response = ai_service.process_message(conversation_id, request.message)
    
    # メッセージをFirestoreに保存
    message_ref = db.collection("chat_messages").document()
    
    user_message = {
        "messageId": message_ref.id,
        "sessionId": request.sessionId,
        "conversationId": conversation_id,
        "sender": "user",
        "message": request.message,
        "timestamp": datetime.now()
    }
    
    ai_message = {
        "messageId": f"ai-{uuid.uuid4().hex[:10]}",
        "sessionId": request.sessionId,
        "conversationId": conversation_id,
        "sender": "AI",
        "message": ai_response,
        "timestamp": datetime.now()
    }
    
    # バッチ処理でメッセージを保存
    batch = db.batch()
    batch.set(message_ref, user_message)
    batch.set(db.collection("chat_messages").document(ai_message["messageId"]), ai_message)
    batch.commit()
    
    return {
        "response": ai_response,
        "context": {
            "conversationId": conversation_id
        }
    }

@router.get("/messages", response_model=ChatHistoryResponse)
async def get_chat_history(
    session_id: str = None,
    user_data: dict = Depends(get_current_user)
):
    user_id = user_data["uid"]
    
    # セッションIDが指定されている場合は、そのセッションのメッセージのみを取得
    if session_id:
        # セッションの所有者を確認
        session_ref = db.collection("study_sessions").document(session_id)
        session = session_ref.get()
        
        if not session.exists or session.to_dict()["userId"] != user_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Session not found or access denied"
            )
        
        messages_query = db.collection("chat_messages").where("sessionId", "==", session_id).order_by("timestamp")
    else:
        # ユーザーの全メッセージを取得
        messages_query = db.collection("chat_messages").where("userId", "==", user_id).order_by("timestamp")
    
    messages = []
    for msg in messages_query.stream():
        msg_data = msg.to_dict()
        messages.append(
            ChatMessage(
                sender=msg_data["sender"],
                message=msg_data["message"],
                timestamp=msg_data["timestamp"]
            )
        )
    
    return {"messages": messages}

# === Assistants API管理エンドポイント ===

@router.get("/assistants", status_code=status.HTTP_200_OK)
async def get_assistants(
    user_data: dict = Depends(get_current_user)
):
    """利用可能なアシスタント一覧を取得"""
    # Firestoreからアシスタント一覧を取得
    assistants_query = db.collection("assistants").order_by("grade").order_by("subject").order_by("chapter").order_by("section")
    assistants = []
    
    for doc in assistants_query.stream():
        assistants.append(doc.to_dict())
    
    return {"assistants": assistants}

@router.post("/assistants", status_code=status.HTTP_201_CREATED)
async def add_assistant(
    assistant_id: str,
    grade: str,
    subject: str,
    chapter: str,
    section: str,
    name: str,
    description: str = "",
    user_data: dict = Depends(get_current_user)
):
    """新しいアシスタントをFirestoreに追加（管理者向け）"""
    user_id = user_data["uid"]
    
    # 権限チェック (管理者のみアクセス可能)
    user_ref = db.collection("users").document(user_id)
    user_doc = user_ref.get()
    
    if not user_doc.exists or not user_doc.to_dict().get("isAdmin", False):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="このエンドポイントは管理者のみ利用可能です"
        )
    
    # 新しいアシスタント情報を作成
    assistant_data = {
        "id": assistant_id,
        "grade": grade,
        "subject": subject,
        "chapter": chapter,
        "section": section,
        "name": name,
        "description": description,
        "createdAt": datetime.now(),
        "createdBy": user_id
    }
    
    # Firestoreに保存
    try:
        assistant_ref = db.collection("assistants").document(assistant_id)
        assistant_ref.set(assistant_data)
        
        # サービスに再ロードを通知
        key = f"{grade}_{subject}_{chapter}_{section}"
        assistants_service.assistant_cache[key] = assistant_id
        
        return {
            "status": "success",
            "message": "アシスタントが正常に追加されました",
            "assistant": assistant_data
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"アシスタントの追加に失敗しました: {str(e)}"
        )

@router.put("/assistants/{assistant_id}", status_code=status.HTTP_200_OK)
async def update_assistant(
    assistant_id: str,
    grade: Optional[str] = None,
    subject: Optional[str] = None,
    chapter: Optional[str] = None,
    section: Optional[str] = None,
    name: Optional[str] = None,
    description: Optional[str] = None,
    user_data: dict = Depends(get_current_user)
):
    """既存のアシスタント情報を更新（管理者向け）"""
    user_id = user_data["uid"]
    
    # 権限チェック (管理者のみアクセス可能)
    user_ref = db.collection("users").document(user_id)
    user_doc = user_ref.get()
    
    if not user_doc.exists or not user_doc.to_dict().get("isAdmin", False):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="このエンドポイントは管理者のみ利用可能です"
        )
    
    # アシスタントの存在を確認
    assistant_ref = db.collection("assistants").document(assistant_id)
    assistant_doc = assistant_ref.get()
    
    if not assistant_doc.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="指定されたアシスタントが見つかりません"
        )
    
    assistant_data = assistant_doc.to_dict()
    
    # 更新データを準備
    update_data = {}
    if grade:
        update_data["grade"] = grade
    if subject:
        update_data["subject"] = subject
    if chapter:
        update_data["chapter"] = chapter
    if section:
        update_data["section"] = section
    if name:
        update_data["name"] = name
    if description:
        update_data["description"] = description
    
    update_data["updatedAt"] = datetime.now()
    update_data["updatedBy"] = user_id
    
    # Firestoreを更新
    try:
        assistant_ref.update(update_data)
        
        # 更新後のデータを取得
        updated_assistant = assistant_ref.get().to_dict()
        
        # キャッシュも更新
        if "grade" in update_data or "subject" in update_data or "chapter" in update_data or "section" in update_data:
            # 古いキーを削除
            old_key = f"{assistant_data['grade']}_{assistant_data['subject']}_{assistant_data['chapter']}_{assistant_data['section']}"
            if old_key in assistants_service.assistant_cache:
                del assistants_service.assistant_cache[old_key]
            
            # 新しいキーを追加
            new_key = f"{updated_assistant['grade']}_{updated_assistant['subject']}_{updated_assistant['chapter']}_{updated_assistant['section']}"
            assistants_service.assistant_cache[new_key] = assistant_id
        
        return {
            "status": "success",
            "message": "アシスタント情報が更新されました",
            "assistant": updated_assistant
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"アシスタント情報の更新に失敗しました: {str(e)}"
        )

@router.delete("/assistants/{assistant_id}", status_code=status.HTTP_200_OK)
async def delete_assistant(
    assistant_id: str,
    user_data: dict = Depends(get_current_user)
):
    """アシスタントをFirestoreから削除（管理者向け）"""
    user_id = user_data["uid"]
    
    # 権限チェック (管理者のみアクセス可能)
    user_ref = db.collection("users").document(user_id)
    user_doc = user_ref.get()
    
    if not user_doc.exists or not user_doc.to_dict().get("isAdmin", False):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="このエンドポイントは管理者のみ利用可能です"
        )
    
    # アシスタントの存在を確認
    assistant_ref = db.collection("assistants").document(assistant_id)
    assistant_doc = assistant_ref.get()
    
    if not assistant_doc.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="指定されたアシスタントが見つかりません"
        )
    
    assistant_data = assistant_doc.to_dict()
    
    # 削除前にキャッシュからも削除
    key = f"{assistant_data['grade']}_{assistant_data['subject']}_{assistant_data['chapter']}_{assistant_data['section']}"
    if key in assistants_service.assistant_cache:
        del assistants_service.assistant_cache[key]
    
    # Firestoreから削除
    try:
        assistant_ref.delete()
        return {
            "status": "success",
            "message": "アシスタントが正常に削除されました",
            "id": assistant_id
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"アシスタントの削除に失敗しました: {str(e)}"
        )

@router.patch("/rooms/{room_id}/assistant-settings", status_code=status.HTTP_200_OK)
async def update_room_assistant_settings(
    room_id: str,
    grade: Optional[str] = None,
    subject: Optional[str] = None,
    chapter: Optional[str] = None,
    section: Optional[str] = None,
    user_data: dict = Depends(get_current_user)
):
    """チャットルームのアシスタント設定を更新する"""
    user_id = user_data["uid"]
    
    # チャットルームの存在と権限を確認
    room_ref = db.collection("chatRooms").document(room_id)
    room_doc = room_ref.get()
    
    if not room_doc.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Chat room not found"
        )
    
    room_data = room_doc.to_dict()
    participants = room_data.get("participants", [])
    is_admin = False
    
    # ユーザーが管理者権限を持っているかチェック
    for participant in participants:
        if participant.get("userId") == user_id and participant.get("role") == "admin":
            is_admin = True
            break
    
    if not is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have permission to update this chat room"
        )
    
    # アシスタント設定を更新
    assistants_service.update_room_assistant_settings(
        room_id, 
        grade=grade, 
        subject=subject, 
        chapter=chapter, 
        section=section
    )
    
    # 更新後の設定を取得
    settings = assistants_service.get_room_assistant_settings(room_id)
    
    return {
        "status": "success",
        "message": "Assistant settings updated",
        "settings": settings
    }

@router.get("/rooms/{room_id}/assistant-settings", status_code=status.HTTP_200_OK)
async def get_room_assistant_settings(
    room_id: str,
    user_data: dict = Depends(get_current_user)
):
    """チャットルームのアシスタント設定を取得する"""
    user_id = user_data["uid"]
    
    # チャットルームの存在と参加権限を確認
    room_ref = db.collection("chatRooms").document(room_id)
    room_doc = room_ref.get()
    
    if not room_doc.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Chat room not found"
        )
    
    room_data = room_doc.to_dict()
    participants = room_data.get("participants", [])
    user_is_participant = False
    
    for participant in participants:
        if participant.get("userId") == user_id:
            user_is_participant = True
            break
    
    if not user_is_participant and room_data.get("isPrivate", True):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have access to this chat room"
        )
    
    # アシスタント設定を取得
    settings = assistants_service.get_room_assistant_settings(room_id)
    
    return {
        "settings": settings
    }

@router.get("/assistant-threads", status_code=status.HTTP_200_OK)
async def get_assistant_threads(
    user_data: dict = Depends(get_current_user)
):
    """OpenAI Assistants APIのスレッド一覧を取得（管理者向け）"""
    user_id = user_data["uid"]
    
    # 権限チェック (管理者のみアクセス可能)
    user_ref = db.collection("users").document(user_id)
    user_doc = user_ref.get()
    
    if not user_doc.exists or not user_doc.to_dict().get("isAdmin", False):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This endpoint is only available to administrators"
        )
        
    # スレッド一覧を取得
    try:
        threads = assistants_service.get_all_threads()
        return {"threads": threads}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error retrieving assistant threads: {str(e)}"
        )
