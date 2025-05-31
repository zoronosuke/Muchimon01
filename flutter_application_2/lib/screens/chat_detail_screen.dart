import 'package:flutter/material.dart';
import 'package:flutter_application_2/services/api_service.dart';
import 'package:flutter_application_2/services/voicevox_service.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatDetailScreen extends StatefulWidget {
  final String roomId;
  final String roomName;

  const ChatDetailScreen({
    Key? key,
    required this.roomId,
    required this.roomName,
  }) : super(key: key);

  @override
  _ChatDetailScreenState createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();
  final VoicevoxService _voicevoxService =
      VoicevoxService(baseUrl: 'http://127.0.0.1:8000');
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  bool _isVerticalLayout = true; // true for top/bottom, false for left/right
  bool _useAssistant = true; // OpenAI Assistants APIをデフォルトで使用
  bool _ttsEnabled = true; // 音声読み上げの有効/無効
  int _selectedSpeakerId = 1; // デフォルトの話者ID
  bool _isPlaying = false; // 音声再生中フラグ

  // 音声入力関連
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _recognizedText = '';
  bool _speechEnabled = false;

  // チャットルームの情報
  Map<String, dynamic>? _roomDetails;
  String _assistantName = "学習アシスタント";

  // ムチモンとガクモンの声の設定
  int _muchimonVoiceId = 4; // ずんだもん (デフォルト)
  int _gakumonVoiceId = 10; // 玄野武宏 (デフォルト)

  // 保存されている声の設定を取得するキー
  static const String _muchimonVoiceKey = 'muchimon_voice_id';
  static const String _gakumonVoiceKey = 'gakumon_voice_id';

  // Riveアニメーション関連
  Artboard? _muchimonArtboard;
  Artboard? _godArtboard;
  RiveAnimationController? _muchimonController;
  RiveAnimationController? _godController;

  @override
  void initState() {
    super.initState();
    _loadVoicePreferences();
    _loadRoomDetails();
    _loadMessages();
    _initSpeech();
    _loadMuchimonAnimation();
    _loadGodAnimation();
  }

  void _loadGodAnimation() {
    RiveFile.asset('assets/animations/god.riv').then((file) {
      final artboard = file.mainArtboard;

      if (file.mainArtboard.animations.isNotEmpty) {
        final animationName = file.mainArtboard.animations.first.name;
        _godController = SimpleAnimation(animationName);
        artboard.addController(_godController!);
      }

      setState(() {
        _godArtboard = artboard;
      });
    }).catchError((error) {
      print('Error loading God Rive file: $error');
    });
  }

  void _loadMuchimonAnimation() {
    RiveFile.asset('assets/animations/muchimon01.riv').then((file) {
      final artboard = file.mainArtboard;

      if (file.mainArtboard.animations.isNotEmpty) {
        final animationName = file.mainArtboard.animations.first.name;
        _muchimonController = SimpleAnimation(animationName);
        artboard.addController(_muchimonController!);
      }

      setState(() {
        _muchimonArtboard = artboard;
      });
    }).catchError((error) {
      print('Error loading Muchimon Rive file: $error');
    });
  }

  Future<void> _loadVoicePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _muchimonVoiceId = prefs.getInt(_muchimonVoiceKey) ?? 4;
        _gakumonVoiceId = prefs.getInt(_gakumonVoiceKey) ?? 10;
      });
      print('最新の音声設定を読み込みました: ムチモン=$_muchimonVoiceId, ガクモン=$_gakumonVoiceId');
    } catch (e) {
      print('音声設定の読み込みに失敗しました: $e');
    }
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onError: (error) => print('音声認識エラー: $error'),
        onStatus: (status) => print('音声認識ステータス: $status'),
      );
    } catch (e) {
      print('音声認識の初期化に失敗しました: $e');
      _speechEnabled = false;
    }

    if (!mounted) return;
    setState(() {});
  }

  void _startListening() async {
    if (!_speechEnabled) {
      await _initSpeech();
      if (!_speechEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('お使いのデバイスで音声認識が利用できません')),
        );
        return;
      }
    }

    setState(() {
      _isListening = true;
      _recognizedText = '';
    });

    await _speech.listen(
      onResult: _onSpeechResult,
      localeId: 'ja_JP',
    );
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _recognizedText = result.recognizedWords;
      _messageController.text = _recognizedText;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
    });
  }

  Future<void> _loadRoomDetails() async {
    try {
      final roomDetails = await _apiService.getChatRoomDetail(widget.roomId);

      final metadata = roomDetails['metadata'] as Map<String, dynamic>?;
      if (metadata != null) {
        setState(() {
          _roomDetails = roomDetails;

          if (metadata.containsKey('assistant')) {
            _assistantName = metadata['assistant'] as String? ?? "学習アシスタント";
          }

          if (metadata.containsKey('muchimon_voice_id')) {
            _muchimonVoiceId = metadata['muchimon_voice_id'] as int? ?? 4;
            print('チャットルームのメタデータからムチモンの声を設定: $_muchimonVoiceId');
          }

          if (metadata.containsKey('gakumon_voice_id')) {
            _gakumonVoiceId = metadata['gakumon_voice_id'] as int? ?? 10;
            print('チャットルームのメタデータからガクモンの声を設定: $_gakumonVoiceId');
          }
        });
      }
    } catch (e) {
      print('チャットルーム詳細の取得に失敗しました: $e');
    }
  }

  @override
  void dispose() {
    if (_speech.isListening) {
      _speech.stop();
    }
    _messageController.dispose();
    _scrollController.dispose();
    _voicevoxService.dispose();
    _muchimonController?.dispose();
    _godController?.dispose();
    super.dispose();
  }

  Future<void> _speakText(String text) async {
    if (!_ttsEnabled || text.isEmpty) return;

    try {
      setState(() {
        _isPlaying = true;
      });

      int speakerId;

      if (text.startsWith('ムチモン：')) {
        speakerId = _muchimonVoiceId;
        print('ムチモンの声($_muchimonVoiceId)で再生します');
      } else if (text.startsWith('ガクモン：')) {
        speakerId = _gakumonVoiceId;
        print('ガクモンの声($_gakumonVoiceId)で再生します');
      } else {
        speakerId = _selectedSpeakerId;
        print('デフォルトの声($_selectedSpeakerId)で再生します');
      }

      await _voicevoxService.speak(text, speakerId: speakerId);
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

  Future<void> _stopSpeaking() async {
    await _voicevoxService.stop();
    setState(() {
      _isPlaying = false;
    });
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final messages = await _apiService.getChatRoomMessages(widget.roomId);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _errorMessage = 'メッセージの読み込みに失敗しました: $e';
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildAiCharacterWithBubble(dynamic message) {
    final DateTime timestamp = DateTime.parse(message['timestamp']);
    final formattedTime = DateFormat('HH:mm').format(timestamp);
    final bool isTemporary = message['isTemporary'] == true;

    final String content = message['content'] ?? '';

    bool showGakumon = true;
    bool showMuchimon = true;
    String displayContent = content;

    if (content.startsWith('ガクモン：')) {
      showGakumon = true;
      showMuchimon = false;
      displayContent = content.substring('ガクモン：'.length);
    } else if (content.startsWith('ムチモン：')) {
      showGakumon = false;
      showMuchimon = true;
      displayContent = content.substring('ムチモン：'.length);
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          showMuchimon && _muchimonArtboard != null
              ? SizedBox(
                  width: 80,
                  height: 120,
                  child: Rive(
                    artboard: _muchimonArtboard!,
                    fit: BoxFit.contain,
                  ),
                )
              : const SizedBox(width: 80),
          Expanded(
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20.0),
                        boxShadow: isTemporary
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 2.0,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayContent,
                            style: TextStyle(
                              fontSize: 16.0,
                              color: Colors.black87,
                              fontStyle: isTemporary
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (_ttsEnabled && !isTemporary)
                                IconButton(
                                  icon: Icon(
                                    _isPlaying ? Icons.stop : Icons.volume_up,
                                    size: 20,
                                    color: Colors.blue,
                                  ),
                                  onPressed: _isPlaying
                                      ? _stopSpeaking
                                      : () => _speakText(content),
                                  padding: EdgeInsets.zero,
                                  constraints:
                                      const BoxConstraints(minWidth: 30),
                                  visualDensity: VisualDensity.compact,
                                ),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  formattedTime,
                                  style: TextStyle(
                                    fontSize: 10.0,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          showGakumon && _godArtboard != null
              ? SizedBox(
                  width: 80,
                  height: 120,
                  child: Rive(
                    artboard: _godArtboard!,
                    fit: BoxFit.contain,
                  ),
                )
              : const SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _buildUserLastMessage(dynamic message) {
    final DateTime timestamp = DateTime.parse(message['timestamp']);
    final formattedTime = DateFormat('HH:mm').format(timestamp);
    final bool isTemporary = message['isTemporary'] == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: isTemporary
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 2.0,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message['content'],
                    style: TextStyle(
                      fontSize: 16.0,
                      color: Colors.black87,
                      fontStyle:
                          isTemporary ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      formattedTime,
                      style: TextStyle(
                        fontSize: 10.0,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 20,
            child: Icon(Icons.person),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      _messageController.clear();

      setState(() {
        _messages.add({
          'id': 'temp-${DateTime.now().millisecondsSinceEpoch}',
          'senderId': 'currentUser',
          'content': message,
          'timestamp': DateTime.now().toIso8601String(),
          'isTemporary': true,
        });
      });
      _scrollToBottom();

      Map<String, dynamic> response;
      if (_useAssistant) {
        response = await _apiService
            .sendAssistantMessage(widget.roomId, message, language: 'ja');
      } else {
        response = await _apiService.sendChatMessage(widget.roomId, message,
            language: 'ja', useAssistant: false);
      }

      await _loadMessages();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('メッセージの送信に失敗しました: $e')),
      );
      setState(() {
        _messages.removeWhere((msg) => msg['isTemporary'] == true);
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, -1),
            blurRadius: 3.0,
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
            onPressed: _isListening ? _stopListening : _startListening,
            color: _isListening ? Colors.red : Colors.grey,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'メッセージを入力...',
                border: InputBorder.none,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              maxLines: null,
              keyboardType: TextInputType.multiline,
            ),
          ),
          IconButton(
            icon: _isSending
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.0),
                  )
                : const Icon(Icons.send),
            onPressed: _isSending ? null : _sendMessage,
            color: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isVerticalLayout) {
      dynamic latestAiMessage;
      dynamic latestUserMessage;

      for (int i = _messages.length - 1; i >= 0; i--) {
        final message = _messages[i];
        final isUserMessage = message['senderId'] != 'ai-assistant';

        if (isUserMessage && latestUserMessage == null) {
          latestUserMessage = message;
        } else if (!isUserMessage && latestAiMessage == null) {
          latestAiMessage = message;
        }

        if (latestAiMessage != null && latestUserMessage != null) {
          break;
        }
      }

      return Column(
        children: [
          if (latestAiMessage != null)
            _buildAiCharacterWithBubble(latestAiMessage),
          const Spacer(),
          if (latestUserMessage != null)
            _buildUserLastMessage(latestUserMessage),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8.0),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isUserMessage = message['senderId'] != 'ai-assistant';
        final DateTime timestamp = DateTime.parse(message['timestamp']);
        final formattedTime = DateFormat('HH:mm').format(timestamp);
        final bool isTemporary = message['isTemporary'] == true;

        if (isUserMessage) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(16.0),
                      boxShadow: isTemporary
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 2.0,
                                offset: const Offset(0, 1),
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message['content'],
                          style: TextStyle(
                            color: Colors.black87,
                            fontStyle: isTemporary
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            formattedTime,
                            style: TextStyle(
                              fontSize: 10.0,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const CircleAvatar(
                  child: Icon(Icons.person),
                ),
              ],
            ),
          );
        } else {
          final String content = message['content'] ?? '';

          bool showGakumon = true;
          bool showMuchimon = true;
          String displayContent = content;

          if (content.startsWith('ガクモン：')) {
            showGakumon = true;
            showMuchimon = false;
            displayContent = content.substring('ガクモン：'.length);
          } else if (content.startsWith('ムチモン：')) {
            showGakumon = false;
            showMuchimon = true;
            displayContent = content.substring('ムチモン：'.length);
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                showMuchimon && _muchimonArtboard != null
                    ? SizedBox(
                        width: 60,
                        height: 90,
                        child: Rive(
                          artboard: _muchimonArtboard!,
                          fit: BoxFit.contain,
                        ),
                      )
                    : const SizedBox(width: 60),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16.0),
                      boxShadow: isTemporary
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 2.0,
                                offset: const Offset(0, 1),
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayContent,
                          style: TextStyle(
                            color: Colors.black87,
                            fontStyle: isTemporary
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_ttsEnabled && !isTemporary)
                              IconButton(
                                icon: Icon(
                                  _isPlaying ? Icons.stop : Icons.volume_up,
                                  size: 20,
                                  color: Colors.blue,
                                ),
                                onPressed: _isPlaying
                                    ? _stopSpeaking
                                    : () => _speakText(content),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 30),
                                visualDensity: VisualDensity.compact,
                              ),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                formattedTime,
                                style: TextStyle(
                                  fontSize: 10.0,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                showGakumon && _godArtboard != null
                    ? SizedBox(
                        width: 60,
                        height: 90,
                        child: Rive(
                          artboard: _godArtboard!,
                          fit: BoxFit.contain,
                        ),
                      )
                    : const SizedBox(width: 60),
              ],
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.roomName),
        actions: [
          IconButton(
            icon: Icon(_ttsEnabled ? Icons.volume_up : Icons.volume_off),
            tooltip: _ttsEnabled ? '音声読み上げON' : '音声読み上げOFF',
            onPressed: () {
              setState(() {
                _ttsEnabled = !_ttsEnabled;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text(_ttsEnabled ? '音声読み上げをONにしました' : '音声読み上げをOFFにしました'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                _assistantName,
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(_useAssistant ? Icons.chat_bubble : Icons.person),
            tooltip: _useAssistant ? 'OpenAI Assistant使用中' : '通常AIモード',
            onPressed: () {
              setState(() {
                _useAssistant = !_useAssistant;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_useAssistant
                      ? 'OpenAI Assistants APIモードに切り替えました'
                      : '通常AIモードに切り替えました'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '表示切替',
            onPressed: () {
              setState(() {
                _isVerticalLayout = !_isVerticalLayout;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadMessages,
                              child: const Text('再試行'),
                            ),
                          ],
                        ),
                      )
                    : _messages.isEmpty
                        ? const Center(child: Text('メッセージがありません'))
                        : _buildMessageList(),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }
}
