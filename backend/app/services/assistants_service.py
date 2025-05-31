import os
from openai import OpenAI
from typing import Optional, Dict, Any, List, Tuple
from ..core.config import settings
from ..services.firebase_service import db
from datetime import datetime
import uuid

class AssistantsService:
    def __init__(self):
        # Use the Assistants-specific API key
        self.client = OpenAI(api_key=settings.OPENAI_API_ASSISTANTS_KEY)
        # Cache for thread IDs by room ID
        self.thread_cache = {}
        # Cache for assistant IDs
        self.assistant_cache = {}
        
        # Default assistant (default to secondary 1, math, chapter 1, section 1)
        self.default_grade = "中1"
        self.default_subject = "数学"
        self.default_chapter = "1章"
        self.default_section = "1節①"
        
        # Initialize assistant catalog
        self._initialize_assistants()
        
    def _initialize_assistants(self):
        """初期化時にアシスタント情報をFirestoreから読み込む"""
        # 最初にFirestoreからアシスタント情報を取得
        assistants_collection = db.collection("assistants")
        assistants_docs = list(assistants_collection.stream())
        
        # Firestoreにアシスタントがない場合は初期データをセットアップ
        if not assistants_docs:
            print("Firestoreにアシスタントがないため、初期データを設定します")
            initial_assistants = [
                {
                    "id": "asst_vL8HUNpgf5WUeVTl1TW8QqBz",
                    "grade": "中1",
                    "subject": "数学",
                    "chapter": "1章",
                    "section": "1節①",
                    "name": "正の数負の数 基本概念",
                    "description": "中学1年数学の正の数と負の数についての基本概念を教えるアシスタント"
                },
                {
                    "id": "asst_x3G2YOwOKh8NnZBWM0Q78VAr",
                    "grade": "中1",
                    "subject": "数学",
                    "chapter": "1章",
                    "section": "1節②",
                    "name": "正の数負の数 応用",
                    "description": "中学1年数学の正の数と負の数についての応用問題を扱うアシスタント"
                }
            ]
            
            # Firestoreに初期アシスタント情報を保存
            for assistant in initial_assistants:
                assistant_ref = assistants_collection.document(assistant["id"])
                assistant_ref.set(assistant)
                
                # ローカルキャッシュにも追加
                key = self._get_assistant_key(
                    assistant["grade"], 
                    assistant["subject"], 
                    assistant["chapter"], 
                    assistant["section"]
                )
                self.assistant_cache[key] = assistant["id"]
                
            print(f"{len(initial_assistants)}個の初期アシスタントをFirestoreに登録しました")
        else:
            # 既存のアシスタント情報をキャッシュに読み込む
            for doc in assistants_docs:
                assistant = doc.to_dict()
                # ID、学年、科目などが含まれているか確認
                if all(key in assistant for key in ["id", "grade", "subject", "chapter", "section"]):
                    key = self._get_assistant_key(
                        assistant["grade"], 
                        assistant["subject"], 
                        assistant["chapter"], 
                        assistant["section"]
                    )
                    self.assistant_cache[key] = assistant["id"]
            
            print(f"Firestoreから{len(assistants_docs)}個のアシスタント情報を読み込みました")
    
    def _get_assistant_key(self, grade: str, subject: str, chapter: str, section: str) -> str:
        """アシスタントを識別するためのキーを生成"""
        return f"{grade}_{subject}_{chapter}_{section}"
    
    def get_assistant_id(self, grade: Optional[str] = None, subject: Optional[str] = None, 
                         chapter: Optional[str] = None, section: Optional[str] = None) -> str:
        """指定された学年、科目、章、節に対応するアシスタントIDを取得"""
        # デフォルト値を使用
        grade = grade or self.default_grade
        subject = subject or self.default_subject
        chapter = chapter or self.default_chapter
        section = section or self.default_section
        
        # キャッシュから検索
        key = self._get_assistant_key(grade, subject, chapter, section)
        if key in self.assistant_cache:
            return self.assistant_cache[key]
        
        # キャッシュにない場合、Firestoreから検索
        query = (
            db.collection("assistants")
            .where("grade", "==", grade)
            .where("subject", "==", subject)
            .where("chapter", "==", chapter)
            .where("section", "==", section)
            .limit(1)
        )
        
        results = list(query.stream())
        if results:
            assistant_id = results[0].id
            # キャッシュに追加
            self.assistant_cache[key] = assistant_id
            return assistant_id
            
        # 見つからない場合は最初のセクションのアシスタントを試す
        if section != "1節①":
            return self.get_assistant_id(grade, subject, chapter, "1節①")
        
        # それでも見つからない場合はデフォルトを返す
        return self.assistant_cache.get(
            self._get_assistant_key(
                self.default_grade,
                self.default_subject,
                self.default_chapter,
                self.default_section
            ),
            "asst_vL8HUNpgf5WUeVTl1TW8QqBz"  # 絶対的なフォールバック
        )
    
    def get_room_assistant_settings(self, room_id: str) -> Dict[str, str]:
        """チャットルームに関連付けられているアシスタント設定を取得"""
        room_ref = db.collection("chatRooms").document(room_id)
        room_doc = room_ref.get()
        
        if room_doc.exists:
            room_data = room_doc.to_dict()
            metadata = room_data.get("metadata", {})
            
            # アシスタント設定を取得
            # 各プロパティを確認: まずassistant_prefixされたプロパティを確認し、
            # なければ直接のプロパティを確認、それもなければデフォルト値を使用
            return {
                "grade": metadata.get("assistant_grade", metadata.get("grade", self.default_grade)),
                "subject": metadata.get("assistant_subject", metadata.get("subject", self.default_subject)),
                "chapter": metadata.get("assistant_chapter", metadata.get("chapter", self.default_chapter)),
                "section": metadata.get("assistant_section", metadata.get("section", self.default_section))
            }
        
        # ルームが存在しない場合はデフォルト値
        return {
            "grade": self.default_grade,
            "subject": self.default_subject,
            "chapter": self.default_chapter,
            "section": self.default_section
        }
    
    def update_room_assistant_settings(self, room_id: str, 
                                       grade: Optional[str] = None, 
                                       subject: Optional[str] = None,
                                       chapter: Optional[str] = None,
                                       section: Optional[str] = None) -> None:
        """チャットルームのアシスタント設定を更新"""
        room_ref = db.collection("chatRooms").document(room_id)
        room_doc = room_ref.get()
        
        if room_doc.exists:
            room_data = room_doc.to_dict()
            metadata = room_data.get("metadata", {})
            
            # 指定された項目のみ更新
            if grade:
                metadata["assistant_grade"] = grade
            if subject:
                metadata["assistant_subject"] = subject
            if chapter:
                metadata["assistant_chapter"] = chapter
            if section:
                metadata["assistant_section"] = section
                
            # 新しいアシスタントIDを取得
            assistant_id = self.get_assistant_id(
                metadata.get("assistant_grade"),
                metadata.get("assistant_subject"),
                metadata.get("assistant_chapter"),
                metadata.get("assistant_section")
            )
            
            # メタデータにアシスタントIDも保存
            metadata["assistant_id"] = assistant_id
            
            # Firestoreを更新
            room_ref.update({"metadata": metadata})
        
    def _get_thread_id_for_room(self, room_id: str) -> str:
        """Get or create a thread ID for a given room ID, using Firestore for persistence."""
        # Check cache first
        if room_id in self.thread_cache:
            return self.thread_cache[room_id]
            
        # Check Firestore for existing mapping
        room_ref = db.collection("chatRooms").document(room_id)
        room_doc = room_ref.get()
        
        if room_doc.exists:
            room_data = room_doc.to_dict()
            metadata = room_data.get("metadata", {})
            
            # If thread ID exists in metadata, use it
            if "openai_thread_id" in metadata:
                thread_id = metadata["openai_thread_id"]
                self.thread_cache[room_id] = thread_id
                return thread_id
        
        # No thread ID found, create a new thread
        return self._create_new_thread_for_room(room_id)
    
    def _create_new_thread_for_room(self, room_id: str) -> str:
        """Create a new OpenAI thread and associate it with the room."""
        # Create a new thread
        thread = self.client.beta.threads.create()
        thread_id = thread.id
        
        # Update Firestore with the thread ID
        room_ref = db.collection("chatRooms").document(room_id)
        room_doc = room_ref.get()
        
        if room_doc.exists:
            room_data = room_doc.to_dict()
            metadata = room_data.get("metadata", {})
            metadata["openai_thread_id"] = thread_id
            
            # Update room metadata
            room_ref.update({
                "metadata": metadata
            })
        
        # Add to cache
        self.thread_cache[room_id] = thread_id
        return thread_id
    
    async def send_message(self, room_id: str, message: str, 
                           grade: Optional[str] = None, 
                           subject: Optional[str] = None,
                           chapter: Optional[str] = None, 
                           section: Optional[str] = None) -> Dict[str, Any]:
        """Send a message to the assistant and get a response."""
        # Get thread ID for this room
        thread_id = self._get_thread_id_for_room(room_id)
        
        # Add message to thread
        self.client.beta.threads.messages.create(
            thread_id=thread_id,
            role="user",
            content=message
        )
        
        # 特定のアシスタント設定が指定されていない場合、ルームから取得
        if not all([grade, subject, chapter, section]):
            room_settings = self.get_room_assistant_settings(room_id)
            grade = grade or room_settings.get("grade")
            subject = subject or room_settings.get("subject")
            chapter = chapter or room_settings.get("chapter")
            section = section or room_settings.get("section")
        
        # アシスタントIDを取得
        assistant_id = self.get_assistant_id(grade, subject, chapter, section)
        
        # デバッグ情報をログに出力
        print(f"Assistants API使用: room_id={room_id}, grade={grade}, subject={subject}, chapter={chapter}, section={section}, assistant_id={assistant_id}")
        
        # Run the assistant
        run = self.client.beta.threads.runs.create(
            thread_id=thread_id,
            assistant_id=assistant_id
        )
        
        # Wait for completion
        while True:
            run_status = self.client.beta.threads.runs.retrieve(
                thread_id=thread_id,
                run_id=run.id
            )
            if run_status.status == "completed":
                break
            elif run_status.status in ["failed", "cancelled", "expired"]:
                raise Exception(f"Run failed with status: {run_status.status}")
        
        # Get messages (newest first)
        messages = self.client.beta.threads.messages.list(
            thread_id=thread_id
        )
        
        # Extract assistant's response
        assistant_messages = [
            msg for msg in messages.data 
            if msg.role == "assistant"
        ]
        
        if not assistant_messages:
            return {"content": "No response from assistant."}
        
        # Get the latest assistant message
        latest_message = assistant_messages[0]
        
        # Extract content based on the structure (assuming text content)
        message_content = ""
        for content_part in latest_message.content:
            if content_part.type == "text":
                message_content += content_part.text.value
        
        return {
            "content": message_content,
            "thread_id": thread_id,
            "message_id": latest_message.id
        }
    
    def get_all_threads(self) -> List[Dict[str, Any]]:
        """Get a list of all threads (useful for admin purposes)."""
        threads = self.client.beta.threads.list()
        return [{
            "id": thread.id,
            "created_at": thread.created_at,
            "metadata": thread.metadata
        } for thread in threads.data]

# Create a singleton instance
assistants_service = AssistantsService()
