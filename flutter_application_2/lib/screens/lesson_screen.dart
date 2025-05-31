import 'package:flutter/material.dart';

class LessonScreen extends StatelessWidget {
  final String sessionId;

  const LessonScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('レッスン'),
      ),
      body: Center(
        child: Text('セッションID: $sessionId'),
      ),
    );
  }
}
