# TTS ワーカー実装 (VOICEVOX Engine)

AIの出力を音声で出力するための TTS (Text-to-Speech) サービスの実装です。VOICEVOX Engineを使用して高品質な日本語音声合成を行い、効率的にキャッシュします。

## 実装方針

- ハッシュベースの永続キー (`sha256("$speakerId-$text")`) を使用してオブジェクト化
- Cloud Storage に音声ファイルを保存し、重複生成を回避
- Firestore にメタデータを保存して高速アクセス
- ライフサイクルルールで音声ファイルを自動削除（30日後）し、ストレージコストを抑制

## セットアップ手順

### バックエンド

1. VOICEVOX Engineをインストール・起動
   - [VOICEVOX公式サイト](https://voicevox.hiroshiba.jp/) からダウンロード
   - デフォルトポート: 50021

2. Firebase設定
   - Cloud Storageバケットの作成
   - Firestoreデータベースの有効化
   - サービスアカウント認証情報の取得

3. 環境変数の設定 (.envファイルに追加)
   ```
   VOICEVOX_ENGINE_URL=http://127.0.0.1:50021
   STORAGE_BUCKET_NAME=your-firebase-bucket-name
   STORAGE_TTS_FOLDER=tts
   TTS_CACHE_EXPIRY_DAYS=7
   ```

4. ライフサイクルルールの設定
   - `storage_lifecycle_rules.json` をFirebase Cloud Storageのライフサイクルルールとして適用
   - コマンド例: `gcloud storage buckets update gs://your-bucket-name --lifecycle-file=storage_lifecycle_rules.json`

### フロントエンド (Flutter)

1. 必要なパッケージの追加
   ```
   flutter pub add just_audio crypto
   ```

2. APIエンドポイントの設定
   - `VoicevoxService` インスタンス作成時にバックエンドの URL を指定

## 使用方法

### バックエンドAPI

- `POST /tts/synthesize`: テキストを音声に変換
  ```json
  {
    "text": "こんにちは、VOICEVOXです",
    "speaker_id": 1
  }
  ```

- `GET /tts/audio?text=こんにちは&speaker_id=1`: テキストを音声に変換 (GETリクエスト)

### レスポンス例

```json
{
  "url": "https://storage.googleapis.com/your-bucket/tts/abcdef1234.mp3",
  "cacheKey": "abcdef1234567890...",
  "createdAt": "2025-04-20T22:30:00.000Z",
  "expiresAt": "2025-05-20T22:30:00.000Z",
  "cached": true
}
```

## 実装詳細

### サーバー側

- `TTSService` クラス：
  - VOICEVOXエンジンへのリクエスト処理
  - ハッシュによるキャッシュキー生成
  - Cloud Storage への保存
  - Firestoreでのメタデータ管理

### クライアント側

- `VoicevoxService` クラス：
  - APIリクエスト
  - 音声再生
  - ローカルキャッシュ

- `TTSExampleService` クラス：
  - AIとのチャット統合例
  - 音声合成の利用例

## セキュリティ対策

- 個人情報を含むテキストの場合は、暗号化バケットの使用を推奨
- CMEKまたはGoogle管理暗号化を使用
- サーバー側でのバリデーション

## 課題と改善点

- 現状は日本語テキストのみ対応
- テキストの長さ制限は未実装
- エラーハンドリングを強化する余地あり
