import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  // ローカル開発環境のAPIエンドポイント
  final String baseUrl = 'http://127.0.0.1:8000';
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 認証トークンを取得するヘルパーメソッド
  Future<String?> _getIdToken() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        return await user.getIdToken();
      }
      return null;
    } catch (e) {
      print('認証トークン取得エラー: $e');
      return null;
    }
  }

  // HTTP GETリクエスト用のヘルパーメソッド
  Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      // 認証トークンを取得
      final String? token = await _getIdToken();

      // ヘッダー設定
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };

      // トークンがある場合は認証ヘッダーを追加
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      } else {
        print('警告: 認証トークンがないままリクエスト実行');
      }

      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        // UTF-8エンコーディングを明示的に指定してデコードする
        var decodedResponse = utf8.decode(response.bodyBytes);
        return jsonDecode(decodedResponse);
      } else {
        throw Exception(
            'データの取得に失敗しました: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('ネットワークエラー: $e');
    }
  }

  // HTTP POSTリクエスト用のヘルパーメソッド
  Future<Map<String, dynamic>> post(
      String endpoint, Map<String, dynamic> data) async {
    try {
      // 認証トークンを取得
      final String? token = await _getIdToken();

      // ヘッダー設定
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };

      // トークンがある場合は認証ヘッダーを追加
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      } else {
        print('警告: 認証トークンがないままリクエスト実行');
      }

      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'データの送信に失敗しました: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('ネットワークエラー: $e');
    }
  }

  // APIのルート情報を取得
  Future<Map<String, dynamic>> getRootInfo() async {
    return await get('/');
  }

  // 学習セッション開始
  Future<Map<String, dynamic>> startStudySession(String subject) async {
    return await post('/study/session/start', {'subject': subject});
  }

  // レッスン情報取得
  Future<Map<String, dynamic>> getLesson(String sessionId) async {
    return await get('/study/session/$sessionId/lesson');
  }

  // ムチモン画像一覧取得
  Future<List<dynamic>> getMochimonImages() async {
    final response = await get('/mochimon/images');
    return response['images'] as List<dynamic>;
  }

  // ムチモンに授業をする
  Future<Map<String, dynamic>> teachMochimon(
      String sessionId, String teachingContent) async {
    return await post('/study/session/$sessionId/teach',
        {'teachingContent': teachingContent});
  }

  // 学習セッション終了
  Future<Map<String, dynamic>> endStudySession(String sessionId) async {
    return await post('/study/session/$sessionId/end', {});
  }

  // Firebaseテスト用エンドポイント呼び出し
  Future<Map<String, dynamic>> testFirebase() async {
    return await get('/study/test/firebase');
  }

  // ====== チャット機能 (新) ======

  // チャットルーム作成
  Future<Map<String, dynamic>> createChatRoom({
    String? name,
    String? topic,
    Map<String, dynamic>? metadata,
  }) async {
    return await post('/chat/rooms', {
      if (name != null) 'name': name,
      if (topic != null) 'topic': topic,
      if (metadata != null) 'metadata': metadata,
    });
  }

  // チャットルーム一覧取得
  Future<List<dynamic>> getChatRooms() async {
    final response = await get('/chat/rooms');
    return response['rooms'] as List<dynamic>;
  }

  // チャットルーム詳細取得
  Future<Map<String, dynamic>> getChatRoomDetail(String roomId) async {
    return await get('/chat/rooms/$roomId');
  }

  // チャットメッセージ送信 (ルームベース)
  Future<Map<String, dynamic>> sendChatMessage(String roomId, String message,
      {String language = 'ja', bool useAssistant = false}) async {
    return await post(
        '/chat/rooms/$roomId/messages?use_assistant=$useAssistant',
        {'message': message, 'language': language});
  }

  // OpenAI Assistants APIを使ったチャットメッセージ送信
  Future<Map<String, dynamic>> sendAssistantMessage(
      String roomId, String message,
      {String language = 'ja'}) async {
    return await post('/chat/rooms/$roomId/assistant-messages',
        {'message': message, 'language': language});
  }

  // チャットメッセージ履歴取得 (ルームベース)
  Future<List<dynamic>> getChatRoomMessages(String roomId) async {
    final response = await get('/chat/rooms/$roomId/messages');
    return response['messages'] as List<dynamic>;
  }

  // 利用可能な学習単元を取得
  Future<Map<String, dynamic>> getAvailableStudyUnits() async {
    return await get('/study/units');
  }

  // チャットルーム削除
  Future<Map<String, dynamic>> deleteChatRoom(String roomId) async {
    try {
      // 認証トークンを取得
      final String? token = await _getIdToken();

      // ヘッダー設定
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };

      // トークンがある場合は認証ヘッダーを追加
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      } else {
        print('警告: 認証トークンがないままリクエスト実行');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/chat/rooms/$roomId'),
        headers: headers,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        // 成功の場合、空のオブジェクトを返しても良い
        return response.body.isEmpty ? {} : jsonDecode(response.body);
      } else {
        throw Exception(
            'チャットルームの削除に失敗しました: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('ネットワークエラー: $e');
    }
  }

  // ===== 以下は既存のAPIとの互換性のため =====

  // チャットメッセージ送信 (レガシー)
  Future<Map<String, dynamic>> sendMessage(
      String sessionId, String message) async {
    return await post(
        '/chat/message', {'sessionId': sessionId, 'message': message});
  }

  // 対話履歴取得 (レガシー)
  Future<List<dynamic>> getChatHistory(String sessionId) async {
    final response = await get('/chat/messages?sessionId=$sessionId');
    return response['messages'] as List<dynamic>;
  }
}
