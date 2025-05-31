import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/voicevox_service.dart';

/// AIの出力テキストを音声合成するサービス
class TTSExampleService {
  final ApiService apiService = ApiService();
  final VoicevoxService _voicevoxService;

  TTSExampleService({required String baseUrl})
      : _voicevoxService = VoicevoxService(baseUrl: baseUrl);

  /// AIからテキストを取得して音声合成する
  Future<Map<String, dynamic>> getAIResponseAndSpeak({
    required String roomId,
    required String message,
    int speakerId = 1,
    bool autoPlay = true,
  }) async {
    try {
      // AIからの応答を取得
      final response = await apiService.sendChatMessage(
        roomId,
        message,
        useAssistant: true,
      );

      final aiText = response['response'] as String;

      // 音声合成APIを呼び出し
      String? audioUrl;
      if (autoPlay) {
        // すぐに再生する場合
        await _voicevoxService.speak(aiText, speakerId: speakerId);
      } else {
        // URLのみ取得する場合
        audioUrl =
            await _voicevoxService.getAudioUrl(aiText, speakerId: speakerId);
      }

      return {
        'text': aiText,
        'audioUrl': audioUrl,
        'speakerId': speakerId,
      };
    } catch (e) {
      debugPrint('AI応答・音声合成エラー: $e');
      rethrow;
    }
  }

  /// テキストを音声合成する（既存のテキストがある場合）
  Future<void> speakText(String text, {int speakerId = 1}) async {
    await _voicevoxService.speak(text, speakerId: speakerId);
  }

  void dispose() {
    _voicevoxService.dispose();
  }
}
