import 'package:flutter/material.dart';
import '../services/voicevox_service.dart';
import '../services/tts_example_service.dart';

class TTSDemoScreen extends StatefulWidget {
  const TTSDemoScreen({super.key});

  @override
  State<TTSDemoScreen> createState() => _TTSDemoScreenState();
}

class _TTSDemoScreenState extends State<TTSDemoScreen> {
  // テキスト入力用コントローラー
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _aiMessageController = TextEditingController();

  // サービスの初期化
  final VoicevoxService _voicevoxService = VoicevoxService(
    baseUrl: 'http://127.0.0.1:8000', // バックエンドAPIのURL
  );
  late final TTSExampleService _ttsExampleService;

  String? _roomId;
  String _aiResponse = '';
  bool _isPlaying = false;
  bool _isLoading = false;
  int _selectedSpeakerId = 1; // デフォルトの話者ID

  // 利用可能な話者リスト (VOICEVOX Engineのものを例示)
  final List<Map<String, dynamic>> _speakers = [
    {'id': 1, 'name': '四国めたん', 'style': 'ノーマル'},
    {'id': 2, 'name': '四国めたん', 'style': 'あまあま'},
    {'id': 3, 'name': '四国めたん', 'style': 'ツンツン'},
    {'id': 4, 'name': 'ずんだもん', 'style': 'ノーマル'},
    {'id': 5, 'name': 'ずんだもん', 'style': 'あまあま'},
    {'id': 6, 'name': 'ずんだもん', 'style': 'ツンツン'},
    {'id': 7, 'name': '春日部つむぎ', 'style': 'ノーマル'},
    {'id': 8, 'name': '雨晴はう', 'style': 'ノーマル'},
    {'id': 9, 'name': '波音リツ', 'style': 'ノーマル'},
    {'id': 10, 'name': '玄野武宏', 'style': 'ノーマル'},
  ];

  @override
  void initState() {
    super.initState();
    _ttsExampleService = TTSExampleService(baseUrl: 'http://127.0.0.1:8000');
    _createChatRoom();
  }

  @override
  void dispose() {
    _textController.dispose();
    _aiMessageController.dispose();
    _voicevoxService.dispose();
    _ttsExampleService.dispose();
    super.dispose();
  }

  // チャットルームの作成
  Future<void> _createChatRoom() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = _ttsExampleService.apiService;
      final response = await apiService.createChatRoom(
        name: "音声合成デモ",
        topic: "VOICEVOXによる音声合成テスト",
      );

      setState(() {
        _roomId = response['roomId'];
        _aiResponse = 'チャットルームが作成されました: $_roomId';
      });
    } catch (e) {
      setState(() {
        _aiResponse = 'チャットルーム作成エラー: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // AIにメッセージを送信して返答を音声合成
  Future<void> _sendMessageToAI() async {
    if (_aiMessageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メッセージを入力してください')),
      );
      return;
    }

    if (_roomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('チャットルームが作成されていません')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _aiResponse = '応答待機中...';
    });

    try {
      final result = await _ttsExampleService.getAIResponseAndSpeak(
        roomId: _roomId!,
        message: _aiMessageController.text,
        speakerId: _selectedSpeakerId,
      );

      setState(() {
        _aiResponse = result['text'];
      });
    } catch (e) {
      setState(() {
        _aiResponse = '音声合成エラー: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 音声の再生
  Future<void> _playVoice() async {
    if (_textController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('テキストを入力してください')),
      );
      return;
    }

    setState(() {
      _isPlaying = true;
    });

    try {
      await _voicevoxService.speak(
        _textController.text,
        speakerId: _selectedSpeakerId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('音声再生エラー: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }

  // 音声の停止
  Future<void> _stopVoice() async {
    await _voicevoxService.stop();
    setState(() {
      _isPlaying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('VOICEVOX音声合成デモ'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '基本デモ'),
              Tab(text: 'AI連携デモ'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 基本デモ画面
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 話者選択ドロップダウン
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: '話者を選択',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedSpeakerId,
                    items: _speakers.map((speaker) {
                      return DropdownMenuItem<int>(
                        value: speaker['id'],
                        child: Text('${speaker['name']} (${speaker['style']})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedSpeakerId = value;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // テキスト入力フィールド
                  TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      labelText: '読み上げるテキスト',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                  ),

                  const SizedBox(height: 16),

                  // 再生/停止ボタン
                  ElevatedButton.icon(
                    onPressed: _isPlaying ? _stopVoice : _playVoice,
                    icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                    label: Text(_isPlaying ? '停止' : '再生'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 注意書き
                  const Text(
                    '※ VOICEVOX Engineがローカルで起動している必要があります。',
                    style: TextStyle(color: Colors.grey),
                  ),

                  const SizedBox(height: 8),

                  // キャッシュについての説明
                  const Text(
                    '※ 一度再生した音声はサーバーでキャッシュされ、同じテキストは再利用されます。',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),

            // AI連携デモ画面
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'AIとのチャット (応答が音声で再生されます)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 16),

                  // 話者選択
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'AIの声',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedSpeakerId,
                    items: _speakers.map((speaker) {
                      return DropdownMenuItem<int>(
                        value: speaker['id'],
                        child: Text('${speaker['name']} (${speaker['style']})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedSpeakerId = value;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // AIへのメッセージ入力
                  TextField(
                    controller: _aiMessageController,
                    decoration: const InputDecoration(
                      labelText: 'AIへのメッセージ',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 1,
                    maxLines: 3,
                  ),

                  const SizedBox(height: 8),

                  // 送信ボタン
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _sendMessageToAI,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_isLoading ? '処理中...' : '送信して音声で聞く'),
                  ),

                  const SizedBox(height: 16),

                  // AIの応答表示
                  const Text(
                    'AIの応答:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SingleChildScrollView(
                        child: Text(_aiResponse),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // リピート再生ボタン (AIの応答があれば)
                  if (_aiResponse.isNotEmpty && _aiResponse != '応答待機中...')
                    ElevatedButton.icon(
                      onPressed: _isPlaying || _isLoading
                          ? null
                          : () => _ttsExampleService.speakText(
                                _aiResponse,
                                speakerId: _selectedSpeakerId,
                              ),
                      icon: const Icon(Icons.replay),
                      label: const Text('もう一度聞く'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
