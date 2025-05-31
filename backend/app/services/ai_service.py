from langchain.chains import ConversationChain
from langchain.memory import ConversationBufferMemory
from langchain.llms import OpenAI
from ..core.config import settings

class AIService:
    def __init__(self):
        # OpenAI APIの初期化
        self.llm = OpenAI(
            temperature=0.7,
            openai_api_key=settings.OPENAI_API_KEY
        )
        self.conversations = {}
    
    def get_conversation(self, conversation_id: str):
        if conversation_id not in self.conversations:
            memory = ConversationBufferMemory()
            self.conversations[conversation_id] = ConversationChain(
                llm=self.llm,
                memory=memory,
                verbose=True
            )
        return self.conversations[conversation_id]
    
    def process_message(self, conversation_id: str, message: str):
        conversation = self.get_conversation(conversation_id)
        response = conversation.predict(input=message)
        return response

ai_service = AIService()