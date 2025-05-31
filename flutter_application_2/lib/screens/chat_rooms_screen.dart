import 'package:flutter/material.dart';
import 'package:flutter_application_2/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import 'chat_detail_screen.dart';
import '../routes.dart';

class ChatRoomsScreen extends StatefulWidget {
  const ChatRoomsScreen({Key? key}) : super(key: key);

  @override
  _ChatRoomsScreenState createState() => _ChatRoomsScreenState();
}

class _ChatRoomsScreenState extends State<ChatRoomsScreen>
    with AutomaticKeepAliveClientMixin {
  final ApiService _apiService = ApiService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<dynamic> _chatRooms = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isCheckingAuth = true;

  // メモリキャッシュを保持してスクロール位置を維持する
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoadRooms();
  }

  // 認証状態を確認してからチャットルームを読み込む
  Future<void> _checkAuthAndLoadRooms() async {
    setState(() {
      _isCheckingAuth = true;
      _errorMessage = null;
    });

    // 現在のユーザーを取得
    final User? user = _auth.currentUser;

    if (user == null) {
      // ログインしていない場合はエラーメッセージを表示
      setState(() {
        _errorMessage = 'ログインが必要です。ログイン画面に移動してください。';
        _isCheckingAuth = false;
        _isLoading = false;
      });
      return;
    }

    // ユーザーがログインしている場合、IDトークンを確認
    try {
      final String? token = await user.getIdToken(true); // 強制的に更新したトークンを取得

      if (token == null) {
        setState(() {
          _errorMessage = '認証トークンの取得に失敗しました。再ログインしてください。';
          _isCheckingAuth = false;
          _isLoading = false;
        });
        return;
      }

      print(
          '認証トークン取得成功: ${token.substring(0, math.min(10, token.length))}...'); // トークンの一部だけをログに出力

      setState(() {
        _isCheckingAuth = false;
      });

      // 認証が確認できたらチャットルームを読み込む
      await _loadChatRooms();
    } catch (e) {
      setState(() {
        _errorMessage = '認証エラー: $e';
        _isCheckingAuth = false;
        _isLoading = false;
      });
    }
  }

  // キャッシュデータの有効期限（ミリ秒）
  final int _cacheExpirationTime = 60000; // 1分
  DateTime? _lastFetchTime;

  Future<void> _loadChatRooms() async {
    setState(() {
      if (_chatRooms.isEmpty) {
        // 初回読み込み時のみローディング表示
        _isLoading = true;
      }
      _errorMessage = null;
    });

    try {
      // 現在時刻を取得
      final now = DateTime.now();

      // 最後のフェッチ時間が有効期限内なら再読み込みをスキップ
      if (_lastFetchTime != null &&
          now.difference(_lastFetchTime!).inMilliseconds <
              _cacheExpirationTime &&
          _chatRooms.isNotEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final rooms = await _apiService.getChatRooms();
      _lastFetchTime = now; // 最終フェッチ時間を更新

      setState(() {
        _chatRooms = rooms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'チャットルームの読み込みに失敗しました: $e';
        _isLoading = false;
      });
    }
  }

  // ログイン画面に移動する
  void _navigateToLogin() {
    Navigator.pushReplacementNamed(context, Routes.login);
  }

  // チャットルームのオプションを表示
  Future<void> _showRoomOptions(Map<String, dynamic> room) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('チャットルームを削除'),
            onTap: () {
              Navigator.of(context).pop(); // モーダルを閉じる
              _confirmDeleteRoom(room);
            },
          ),
          ListTile(
            leading: const Icon(Icons.cancel),
            title: const Text('キャンセル'),
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // チャットルーム削除確認ダイアログを表示
  Future<void> _confirmDeleteRoom(Map<String, dynamic> room) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('チャットルームを削除'),
        content: Text('「${room['name']}」を削除してもよろしいですか？\nこの操作は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _deleteRoom(room['id']);
    }
  }

  // チャットルームを削除
  Future<void> _deleteRoom(String roomId) async {
    try {
      setState(() => _isLoading = true);

      await _apiService.deleteChatRoom(roomId);

      // 成功メッセージを表示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('チャットルームを削除しました')),
        );
      }

      // チャットルーム一覧を再読み込み
      await _loadChatRooms();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('チャットルーム削除エラー: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createNewChatRoom() async {
    TextEditingController nameController = TextEditingController();
    TextEditingController topicController = TextEditingController();

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新しいチャットを作成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'チャット名',
                hintText: '新しいチャット',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: topicController,
              decoration: const InputDecoration(
                labelText: 'トピック',
                hintText: '例: プログラミング、旅行、料理...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, {
                'name': nameController.text.trim(),
                'topic': topicController.text.trim(),
              });
            },
            child: const Text('作成'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        setState(() => _isLoading = true);

        // 名前かトピックが空の場合はデフォルト値が使用される（APIサーバー側で処理）
        final response = await _apiService.createChatRoom(
          name: result['name']!.isNotEmpty ? result['name'] : null,
          topic: result['topic']!.isNotEmpty ? result['topic'] : null,
        );

        // 新しいチャットルームを開く
        if (!mounted) return;

        // チャットルーム一覧を再読み込み
        await _loadChatRooms();

        // 新しく作成したチャットルームに移動
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              roomId: response['roomId'],
              roomName: response['name'],
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('チャットルームの作成に失敗しました: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin の実装に必要
    return Scaffold(
      appBar: AppBar(
        title: const Text('チャットルーム'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkAuthAndLoadRooms,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                _navigateToLogin();
              }
            },
            tooltip: 'ログアウト',
          ),
        ],
      ),
      body: _isCheckingAuth
          ? const Center(
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('認証状態を確認中...'),
              ],
            ))
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_errorMessage!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          if (_errorMessage!.contains('ログイン'))
                            ElevatedButton(
                              onPressed: _navigateToLogin,
                              child: const Text('ログイン画面へ'),
                            )
                          else
                            ElevatedButton(
                              onPressed: _checkAuthAndLoadRooms,
                              child: const Text('再試行'),
                            ),
                        ],
                      ),
                    )
                  : _chatRooms.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('チャットルームがありません'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _createNewChatRoom,
                                child: const Text('新しいチャットを作成'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadChatRooms,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: _chatRooms.length,
                            // パフォーマンス最適化
                            addAutomaticKeepAlives: false,
                            addRepaintBoundaries: false,
                            itemExtent: 96.0, // リストアイテムの高さを固定
                            cacheExtent: 500.0, // キャッシュ範囲を増やす
                            physics:
                                const AlwaysScrollableScrollPhysics(), // スクロール性能向上
                            itemBuilder: (context, index) {
                              // アイテムの描画を最適化するため、個別メソッドを使用
                              return _buildChatRoomItem(index);
                            },
                          ),
                        ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewChatRoom,
        child: const Icon(Icons.add),
        tooltip: '新しいチャットを作成',
      ),
    );
  }

  // チャットルームの各アイテムを構築する最適化されたメソッド
  Widget _buildChatRoomItem(int index) {
    // メモリ上に一時的に値を保持し、再構築を最小限に抑える
    final room = _chatRooms[index];
    final lastMessage = room['lastMessage'];
    final DateTime updatedAt = DateTime.parse(room['updatedAt']);
    final formattedDate = DateFormat('MM/dd HH:mm').format(updatedAt);

    // カードの事前計算済みの高さで描画を最適化
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        title: Text(
          room['name'] ?? 'チャット',
          style: const TextStyle(fontWeight: FontWeight.bold),
          // テキストレンダリングを最適化
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              room['topic'] ?? '',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (lastMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  lastMessage['content'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formattedDate,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12.0,
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatDetailScreen(
                roomId: room['id'],
                roomName: room['name'],
              ),
            ),
          ).then((_) => _loadChatRooms());
        },
        onLongPress: () => _showRoomOptions(room),
      ),
    );
  }
}
