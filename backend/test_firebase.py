import firebase_admin
from firebase_admin import credentials

# 環境変数から認証情報のパスを取得
import os
from dotenv import load_dotenv
load_dotenv()

try:
    cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
    print(f"Firebase credentials path: {cred_path}")
    
    cred = credentials.Certificate(cred_path)
    firebase_app = firebase_admin.initialize_app(cred)
    
    print("Firebase initialized successfully!")
    print(f"Project ID: {firebase_app.project_id}")
except Exception as e:
    print(f"Error initializing Firebase: {e}")