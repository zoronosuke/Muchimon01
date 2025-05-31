from pydantic import BaseModel
from typing import Optional, List, Dict, Any, Union
from datetime import datetime

# ユーザープロフィール
class UserProfile(BaseModel):
    userId: str
    displayName: str
    email: str

# 学習セッション
class StudySessionStart(BaseModel):
    subject: Optional[str] = "数学"

class LessonResponse(BaseModel):
    lessonId: str
    title: str
    content: str
    nextAction: Optional[str] = None

class StudySessionResponse(BaseModel):
    sessionId: str
    startTime: datetime
    initialLesson: LessonResponse

# ムチモンに教える
class TeachRequest(BaseModel):
    teachingContent: str

class TeachResponse(BaseModel):
    status: str
    message: str
    feedback: str
    updatedProgress: int

# セッション終了
class EndSessionResponse(BaseModel):
    status: str
    summary: str
    finalScore: int

# ムチモン画像
class MochimonImage(BaseModel):
    id: str
    imageUrl: str
    description: str
    metadata: Optional[Dict[str, Any]] = None

class MochimonImagesResponse(BaseModel):
    images: List[MochimonImage]

# チャットルーム関連モデル
class ChatRoomRequest(BaseModel):
    name: Optional[str] = None
    topic: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None

class ChatRoomResponse(BaseModel):
    roomId: str
    name: str
    topic: str
    createdAt: datetime

class ChatRoomParticipant(BaseModel):
    userId: str
    joinedAt: datetime
    role: str = "member"

class LastMessage(BaseModel):
    content: str
    senderId: str
    timestamp: datetime

class ChatRoomDetail(BaseModel):
    id: str
    name: str
    topic: str
    createdAt: datetime
    updatedAt: datetime
    lastMessage: Optional[LastMessage] = None
    participants: Optional[List[Dict[str, Any]]] = None

class ChatRoomListResponse(BaseModel):
    rooms: List[ChatRoomDetail]

# チャットメッセージ関連モデル
class MessageAttachment(BaseModel):
    type: str  # 'image' | 'video' | 'file'
    url: str
    name: Optional[str] = None
    size: Optional[int] = None

class MessageReaction(BaseModel):
    emoji: str
    users: List[str]

class ReadReceipt(BaseModel):
    userId: str
    readAt: datetime

class ChatMessageRequest(BaseModel):
    sessionId: Optional[str] = None  # 互換性のため残す
    message: str
    attachments: Optional[List[MessageAttachment]] = None
    replyTo: Optional[str] = None

class ChatMessage(BaseModel):
    id: Optional[str] = None
    roomId: Optional[str] = None
    senderId: Optional[str] = None
    content: Optional[str] = None
    timestamp: datetime
    readBy: Optional[List[ReadReceipt]] = None
    attachments: Optional[List[MessageAttachment]] = None
    replyTo: Optional[str] = None
    isEdited: Optional[bool] = False
    reactions: Optional[List[MessageReaction]] = None
    
    # 互換性のため
    sender: Optional[str] = None
    message: Optional[str] = None

class ChatMessageResponse(BaseModel):
    response: str
    context: Optional[Dict[str, Any]] = None

class ChatHistoryResponse(BaseModel):
    messages: List[ChatMessage]
