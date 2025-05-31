// routes.dart
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart'; // ChatPage用
import 'screens/tts_demo_screen.dart'; // TTSDemoScreen用
import 'screens/mochimon_screen.dart'; // MochimonScreen用

// アプリケーションで使用するルート名の定数
class Routes {
  static const String login = '/login';
  static const String home = '/home';
  static const String chat = '/chat';
  static const String ttsDemo = '/tts-demo';
  static const String mochimon = '/mochimon';
  // 他のルートも必要に応じて追加
}

// アプリケーションのルート設定
class AppRouter {
  // 初期ルート名を返す
  static String get initialRoute => Routes.login;

  // ルート名に基づいて画面を生成するジェネレーター
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case Routes.home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case Routes.chat:
        return MaterialPageRoute(builder: (_) => const ChatPage());
      case Routes.ttsDemo:
        return MaterialPageRoute(builder: (_) => const TTSDemoScreen());
      case Routes.mochimon:
        return MaterialPageRoute(builder: (_) => const MochimonScreen());
      default:
        // 未定義のルートの場合はエラー画面を表示
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
