import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // キーイベント用
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore用
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login_page.dart'; // lib/ はソースルートなので省略

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

/// MyApp はアプリ全体の設定（家全体の設計図）を行う
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: LoginPage(), // 初期画面としてログイン画面を表示
    );
    // return MaterialApp(
    //   home: const ChatPage(), // 初期画面としてチャット画面を表示
    // );
  }
}

/// ChatPage はチャット画面全体を管理する StatefulWidget
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // ユーザーの入力内容を管理するコントローラーとフォーカス用ノード
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  // チャットの全メッセージを保持するリスト
  final List<Message> _messages = [];
  // Firestoreのインスタンス
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ユーザーの入力テキストを送信し、チャットボットから自動返信を追加する
  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      // ユーザーのメッセージを追加
      _messages.add(Message(text: text, isUser: true));
      // 入力欄をクリア
      _controller.clear();
      // 自動返信（ここでは「研究頑張って」）
      _messages.add(Message(text: '研究頑張って', isUser: false));
    });

    // Firestoreにユーザーのメッセージを保存
    try {
      await _firestore.collection('messages').add({
        'text': text,
        'isUser': true,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Firestoreに自動返信メッセージを保存
      await _firestore.collection('messages').add({
        'text': '研究頑張って',
        'isUser': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving message to Firestore: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatbot'),
      ),
      body: Column(
        children: [
          // メッセージ表示部分
          Expanded(child: ChatMessages(messages: _messages)),
          // 入力エリア部分（下部に固定）
          ChatInput(
            controller: _controller,
            focusNode: _focusNode,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

/// ChatMessages ウィジェットは、メッセージリストを表示する
class ChatMessages extends StatelessWidget {
  final List<Message> messages;
  const ChatMessages({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        return MessageBubble(message: msg);
      },
    );
  }
}

/// MessageBubble は個々のメッセージ表示を担当するウィジェット
class MessageBubble extends StatelessWidget {
  final Message message;
  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    // ユーザーのメッセージは右寄せ、チャットボットのは左寄せ
    return Container(
      padding: const EdgeInsets.all(8.0),
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8.0),
          color: message.isUser ? Colors.lightBlue[100] : Colors.grey[300],
        ),
        child: Text(message.text),
      ),
    );
  }
}

class ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  const ChatInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        height: 60,
        child: Row(
          children: [
            // キーボードイベントを処理するために KeyboardListener で TextField をラップ
            Expanded(
              child: KeyboardListener(
                focusNode: focusNode,
                onKeyEvent: (KeyEvent event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.enter) {
                    // HardwareKeyboard.instance.logicalKeysPressed からシフトキーのチェック
                    final keys = HardwareKeyboard.instance.logicalKeysPressed;
                    if (!keys.contains(LogicalKeyboardKey.shiftLeft) &&
                        !keys.contains(LogicalKeyboardKey.shiftRight)) {
                      // シフトキーが押されていなければ送信
                      onSend();
                      return;
                    }
                    // シフト＋エンターの場合は、そのまま改行（TextField に入力される）
                  }
                },
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'メッセージを入力...',
                    border: InputBorder.none,
                  ),
                  maxLines: null, // 複数行入力を許可
                ),
              ),
            ),
            // 送信ボタン（アイコンボタン）
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: onSend,
            ),
          ],
        ),
      ),
    );
  }
}

/// Message クラスは、メッセージの内容と発信者情報を保持するシンプルなクラス
class Message {
  final String text;
  final bool isUser; // true: ユーザー、false: チャットボット

  Message({required this.text, required this.isUser});
}
