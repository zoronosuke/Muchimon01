import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart';
import 'package:crypto/crypto.dart';
import 'dart:collection';

class VoicevoxService {
  // 半角→全角変換マッピング
  static final Map<String, String> _zenDigits = {
    '0': '０',
    '1': '１',
    '2': '２',
    '3': '３',
    '4': '４',
    '5': '５',
    '6': '６',
    '7': '７',
    '8': '８',
    '9': '９'
  };
  final String baseUrl;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ローカルキャッシュ（アプリ内メモリキャッシュ）
  final Map<String, String> _urlCache = {};

  VoicevoxService({required this.baseUrl});

  // キャッシュキーの生成（クライアント側でも同じアルゴリズムを使用）
  String _generateCacheKey(int speakerId, String text) {
    final hash = sha256.convert(utf8.encode('$speakerId-$text'));
    return hash.toString();
  }

  // 認証トークンを取得
  Future<String?> _getIdToken() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        return await user.getIdToken();
      }
      return null;
    } catch (e) {
      debugPrint('認証トークン取得エラー: $e');
      return null;
    }
  }

  // テキスト前処理 - 文字化けや読み上げエラーを防止
  String _preprocessText(String text) {
    debugPrint('前処理前のテキスト: $text');

    // ステップ1: トリムして空白を整理
    String processed = text.trim();

    // ステップ2: マークダウン記号や特殊文字の周りにスペースを追加
    final specialChars = [
      '#',
      '*',
      '+',
      '-',
      '_',
      '~',
      '`',
      '>',
      ':',
      '|',
      '(',
      ')',
      '{',
      '}',
      '[',
      ']',
      '<',
      '>',
      '"',
      "'",
      '/',
      '\\'
    ];

    for (final char in specialChars) {
      processed = processed.replaceAll(char, ' $char ');
    }

    // ステップ3: 連続スペースを単一スペースに変換
    processed = processed.replaceAll(RegExp(r'\s+'), ' ');

    // ステップ4: すべての数字を全角に変換（日本語TTS向け）
    processed = processed.replaceAllMapped(
      RegExp(r'\d+'),
      (match) {
        String digits = match.group(0)!;
        // 数字を全角に変換
        return digits.split('').map((d) => _zenDigits[d] ?? d).join('');
      },
    );

    // ステップ5: URLを特殊処理（VOICEVOXは時々URLをうまく処理できない）
    processed = processed.replaceAllMapped(
      RegExp(r'https?://[^\s]+'),
      (match) => 'URL省略',
    );

    // ステップ6: 句読点の前後にスペースを追加して読み上げを自然にする
    processed = processed.replaceAll('。', '。 ');
    processed = processed.replaceAll('、', '、 ');
    processed = processed.replaceAll('，', '， ');
    processed = processed.replaceAll('．', '． ');
    processed = processed.replaceAll('！', '！ ');
    processed = processed.replaceAll('？', '？ ');

    // 連続スペースを単一スペースに再変換
    processed = processed.replaceAll(RegExp(r'\s+'), ' ').trim();

    debugPrint('前処理後のテキスト: $processed');
    return processed;
  }

  // テキストを音声に変換して再生 - バグ修正強化版
  Future<void> speak(String text, {int speakerId = 1}) async {
    try {
      // 空文字の場合は何もしない
      if (text.trim().isEmpty) {
        debugPrint('空文字のため音声再生をスキップします');
        return;
      }

      // デバッグを追加
      debugPrint('音声変換リクエスト: $text (speaker: $speakerId)');

      // 前処理をここで実施して、必ず前処理済みの文字列を使用
      final preprocessedText = _preprocessText(text);
      debugPrint('前処理済みテキスト: $preprocessedText');

      // 長すぎるテキストは分割（日本語は文字ごとに処理が必要なため短くする）
      if (preprocessedText.length > 150) {
        debugPrint('長いテキストを分割して処理します: ${preprocessedText.length}文字');

        // 文章を適切に分割
        List<String> segments = [];

        // 句読点で分割する（。や、などの区切り）
        final rawSegments = preprocessedText
            .split(RegExp(r'([。、．,!?！？\n])'))
            .where((s) => s.trim().isNotEmpty)
            .toList();

        String currentSegment = '';

        for (var i = 0; i < rawSegments.length; i++) {
          var segment = rawSegments[i];

          // 1文字の句読点は前のセグメントに付ける
          if (segment.length == 1 && RegExp(r'[。、．,!?！？]').hasMatch(segment)) {
            if (currentSegment.isNotEmpty) {
              currentSegment += segment;
            } else {
              // 前のセグメントがない場合は次のセグメントに句読点を付ける
              continue;
            }
          } else {
            // 適切な長さになるまで文章を連結
            if (currentSegment.isEmpty) {
              currentSegment = segment;
            } else if (currentSegment.length + segment.length < 100) {
              currentSegment += segment;
            } else {
              // 長さが制限を超えたらセグメントリストに追加して新しいセグメント開始
              segments.add(currentSegment);
              currentSegment = segment;
            }
          }

          // 最後のセグメントか、長さが一定以上なら追加
          if (i == rawSegments.length - 1 || currentSegment.length >= 80) {
            if (currentSegment.isNotEmpty) {
              segments.add(currentSegment);
              currentSegment = '';
            }
          }
        }

        // 最後のセグメントが残っていれば追加
        if (currentSegment.isNotEmpty) {
          segments.add(currentSegment);
        }

        // 各セグメントを処理
        for (var segment in segments) {
          if (segment.trim().length >= 3) {
            // 最低3文字のセグメントを処理
            debugPrint('セグメント処理: $segment');
            await _processSingleSegment(segment, speakerId: speakerId);

            // セグメント間に間を空ける (文の区切りを自然にする)
            await Future.delayed(Duration(milliseconds: 300));
          }
        }
        return;
      }

      // 通常の処理（短いテキスト）
      await _processSingleSegment(preprocessedText, speakerId: speakerId);
    } catch (e) {
      debugPrint('音声再生エラー: $e');
      // エラーをスローしない - UIへの影響を最小化
      // 代わりにログ出力のみとする
    }
  }

  // 単一のテキストセグメントを処理 - 信頼性向上版
  Future<void> _processSingleSegment(String text,
      {required int speakerId}) async {
    try {
      // テキストが前処理済みかチェック
      String processedText = text;
      if (!text.contains('０') && !text.contains('１')) {
        // 数字が全角になっていない場合は前処理を実施
        processedText = _preprocessText(text);
      }

      // 前処理で空になった場合はスキップ
      if (processedText.trim().isEmpty) {
        return;
      }

      final url = await getAudioUrl(processedText, speakerId: speakerId);
      if (url != null) {
        debugPrint('音声URL取得成功: $url');

        // 確実に再生を停止させる
        try {
          await _audioPlayer.stop();
          // 状態をリセット
          await _audioPlayer.setVolume(1.0);
          // 少し待機
          await Future.delayed(Duration(milliseconds: 50));
        } catch (e) {
          // 停止失敗は無視
        }

        try {
          // URLのセット
          debugPrint('URLをセットします: $url');
          await _audioPlayer.setUrl(url, preload: true);

          // 再生の前に少し待機
          await Future.delayed(Duration(milliseconds: 100));

          // 再生開始
          debugPrint('音声再生を開始します');
          await _audioPlayer.play();
          debugPrint('再生開始完了');

          // 再生完了を待機する
          bool playbackCompleted = false;

          // プレーヤーの状態を監視して再生完了を検出
          final subscription = _audioPlayer.playerStateStream.listen((state) {
            debugPrint(
                'プレーヤー状態変化: ${state.processingState}, playing: ${state.playing}');
            if (state.processingState == ProcessingState.completed ||
                state.processingState == ProcessingState.idle) {
              playbackCompleted = true;
            }
          });

          // 再生状態をチェック
          await Future.delayed(Duration(milliseconds: 300));

          if (!_audioPlayer.playing && !playbackCompleted) {
            debugPrint('再生が自動停止した可能性があります。再試行します');
            await _audioPlayer.play();
          }

          // 再生完了を待つためのCompleterを追加
          final completer = Completer<void>();

          // 再生完了リスナーを登録
          final completionSubscription =
              _audioPlayer.processingStateStream.listen((state) {
            debugPrint('処理状態変化: $state');
            if (state == ProcessingState.completed) {
              if (!completer.isCompleted) {
                debugPrint('再生が完了しました');
                completer.complete();
              }
            }
          });

          // エラーリスナーも登録
          final errorSubscription = _audioPlayer.playbackEventStream.listen(
            (event) {},
            onError: (Object e, StackTrace st) {
              debugPrint('再生エラーが発生: $e');
              if (!completer.isCompleted) {
                completer.completeError(e);
              }
            },
          );

          // 再生が終了するまで待機（タイムアウト付き）
          int waitTime = 0;
          final maxWaitTime = 30000; // 最大30秒待機
          final checkInterval = 300; // 300ms間隔でチェック

          try {
            // タイムアウト付きで完了を待機
            await completer.future.timeout(Duration(milliseconds: maxWaitTime),
                onTimeout: () {
              debugPrint('再生完了待機がタイムアウトしました');
              return;
            });
          } catch (e) {
            debugPrint('再生待機中にエラー: $e');
          } finally {
            // ポーリングでも進捗をチェック（バックアップ）
            while (!playbackCompleted &&
                waitTime < maxWaitTime &&
                !completer.isCompleted) {
              await Future.delayed(Duration(milliseconds: checkInterval));
              waitTime += checkInterval;

              final duration = _audioPlayer.duration;
              final position = _audioPlayer.position;

              if (duration != null && position != null) {
                // 再生位置と長さの関係をチェック
                final progress =
                    position.inMilliseconds / duration.inMilliseconds;
                debugPrint(
                    '再生位置: ${position.inMilliseconds}ms / ${duration.inMilliseconds}ms (${(progress * 100).toStringAsFixed(1)}%)');

                // 再生が終了に近づいているかチェック
                if (position >= duration - Duration(milliseconds: 200)) {
                  debugPrint('再生完了に近いためループを終了します');
                  break;
                }

                // 再生が進んでいないか長時間停止している場合は終了
                if (position.inMilliseconds == 0 && waitTime > 5000) {
                  debugPrint('再生が開始されていないためループを終了します');
                  break;
                }
              }
            }

            // すべてのサブスクリプションを解除
            completionSubscription.cancel();
            errorSubscription.cancel();
          }

          // サブスクリプションを解除
          subscription.cancel();

          if (waitTime >= maxWaitTime) {
            debugPrint('再生待機時間が上限に達しました');
          }
        } catch (audioError) {
          debugPrint('音声再生エラー詳細: $audioError');

          // 代替方法を試す
          try {
            debugPrint('代替再生方法を試みます');
            // 一時的なプレーヤーを作成
            final tempPlayer = AudioPlayer();
            // 少し長めの待機を入れる
            await Future.delayed(Duration(milliseconds: 200));
            await tempPlayer.setUrl(url);
            await tempPlayer.play();
            debugPrint('代替再生開始');

            // この後不要になったらメインプレーヤーを停止
            await _audioPlayer.stop();

            // 一時プレーヤーを使い終わったら解放する
            tempPlayer.playerStateStream.listen((state) {
              if (state.processingState == ProcessingState.completed) {
                tempPlayer.dispose();
              }
            });
          } catch (e) {
            debugPrint('代替再生も失敗: $e');
          }
        }
      } else {
        debugPrint('音声URL取得失敗: null');

        // 失敗した場合、テキストを積極的に単純化して再試行
        final simplifiedText = _simplifyText(processedText, aggressive: true);
        if (simplifiedText != processedText) {
          debugPrint('積極的に単純化したテキストで再試行: $simplifiedText');
          final retryUrl =
              await getAudioUrl(simplifiedText, speakerId: speakerId);

          if (retryUrl != null) {
            debugPrint('再試行で音声URL取得成功: $retryUrl');
            try {
              await _audioPlayer.stop();
              await Future.delayed(Duration(milliseconds: 100));
              await _audioPlayer.setUrl(retryUrl);
              await _audioPlayer.play();
              debugPrint('再生開始（再試行後）');
            } catch (e) {
              debugPrint('再試行での再生も失敗: $e');
            }
          } else {
            debugPrint('再試行も失敗しました');
          }
        }
      }
    } catch (e) {
      debugPrint('セグメント処理エラー: $e');
    }
  }

  // テキストをさらに単純化（最後の手段）- 強化版
  String _simplifyText(String text, {bool aggressive = false}) {
    // 通常の単純化
    String simplified = text;

    // 特殊記号をすべて削除し、スペースに置換
    simplified = simplified.replaceAll(RegExp(r'[^\w\s一-龯ぁ-んァ-ヶ０-９]'), ' ');

    // 積極的な単純化（最終手段）
    if (aggressive) {
      // 20文字を超えるテキストを短く切り詰める
      if (simplified.length > 20) {
        simplified = simplified.substring(0, 20) + '等';
      }

      // 非日本語文字を全て除去
      simplified = simplified.replaceAll(RegExp(r'[a-zA-Z0-9]'), '');
    }

    // 連続スペースを単一スペースに変換
    simplified = simplified.replaceAll(RegExp(r'\s+'), ' ').trim();

    return simplified;
  }

  // 音声URLを取得（キャッシュ対応）- エンコーディング対応強化版
  Future<String?> getAudioUrl(String text, {int speakerId = 1}) async {
    try {
      debugPrint('getAudioUrl: テキスト[$text], 話者ID[$speakerId]');

      // クライアント側でキャッシュキーを生成
      final cacheKey = _generateCacheKey(speakerId, text);
      debugPrint('生成したキャッシュキー: $cacheKey');

      // ローカルキャッシュを確認
      if (_urlCache.containsKey(cacheKey)) {
        debugPrint('ローカルキャッシュからURLを返却');
        return _urlCache[cacheKey];
      }

      // 認証トークンを取得
      final String? token = await _getIdToken();
      if (token == null) {
        throw Exception('認証が必要です');
      }

      // ヘッダー設定 - 文字エンコーディングを明示的に指定
      final Map<String, String> headers = {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $token',
      };

      // 特殊文字チェック - 問題を起こしやすい文字があれば警告
      final bool hasProblematicChars =
          RegExp(r'[#\*\+\-_~`>:|]').hasMatch(text);
      if (hasProblematicChars) {
        debugPrint('警告: テキストに処理に問題を起こす可能性のある特殊文字が含まれています');
      }

      // APIリクエスト - POSTメソッド使用
      debugPrint('TTSサーバーにリクエスト送信: $baseUrl/tts/synthesize');

      // POSTリクエストボディを設定 - 直接UTF-8エンコードしてJSON形式で送信
      final requestBody = utf8.encode(jsonEncode({
        'text': text,
        'speaker_id': speakerId,
        // VOICEVOXエンジンの文字化け対策としてエンコーディング情報を追加
        'kana': false, // 読み仮名変換をオフ
        'enable_interrogative_upspeak': true, // 疑問文の語尾上げを有効化
      }));

      final response = await http.post(
        Uri.parse('$baseUrl/tts/synthesize'),
        headers: headers,
        body: requestBody,
      );

      debugPrint('サーバーレスポンス: ステータスコード ${response.statusCode}');

      if (response.statusCode == 200) {
        // レスポンスのデコードを明示的にUTF-8で行う
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final url = data['url'];
        debugPrint('取得したURL: $url');

        // URLを検証 - nullチェックと形式チェック
        if (url != null && url.toString().startsWith('http')) {
          // URLをローカルキャッシュに保存
          _urlCache[cacheKey] = url;
          debugPrint('正常なURLをローカルキャッシュに保存: $url');
          return url;
        } else {
          debugPrint('返却されたURLが無効: $url');
          // 代替メソッドを試す
          return await getAudioUrlWithGet(text, speakerId: speakerId);
        }
      } else {
        final errorBody = utf8.decode(response.bodyBytes);
        debugPrint('音声URL取得エラー: ${response.statusCode}');
        debugPrint('エラーレスポンス: $errorBody');

        // エラーが続く場合は代替メソッドを試行
        if (response.statusCode >= 400) {
          debugPrint('代替メソッドでの取得を試行します');
          return await getAudioUrlWithGet(text, speakerId: speakerId);
        }

        return null;
      }
    } catch (e) {
      debugPrint('音声URL取得エラー: $e');
      // 例外発生時も代替メソッドを試行
      try {
        debugPrint('例外発生のため代替メソッドでの取得を試行します');
        return await getAudioUrlWithGet(text, speakerId: speakerId);
      } catch (_) {
        return null;
      }
    }
  }

  // GETメソッドでの音声URL取得（代替方法）
  Future<String?> getAudioUrlWithGet(String text, {int speakerId = 1}) async {
    try {
      // クライアント側でキャッシュキーを生成
      final cacheKey = _generateCacheKey(speakerId, text);

      // ローカルキャッシュを確認
      if (_urlCache.containsKey(cacheKey)) {
        return _urlCache[cacheKey];
      }

      // 認証トークンを取得
      final String? token = await _getIdToken();
      if (token == null) {
        throw Exception('認証が必要です');
      }

      // ヘッダー設定
      final Map<String, String> headers = {
        'Authorization': 'Bearer $token',
      };

      // クエリパラメータをエンコード
      final encodedText = Uri.encodeComponent(text);

      // APIリクエスト - GETメソッド使用
      final response = await http.get(
        Uri.parse('$baseUrl/tts/audio?text=$encodedText&speaker_id=$speakerId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final url = data['url'];

        // URLをローカルキャッシュに保存
        if (url != null) {
          _urlCache[cacheKey] = url;
        }

        return url;
      } else {
        debugPrint('音声URL取得エラー: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('音声URL取得エラー: $e');
      return null;
    }
  }

  // 音声の再生を停止
  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  // リソース解放
  void dispose() {
    _audioPlayer.dispose();
  }
}
