import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CommunicationScreen extends StatefulWidget {
  const CommunicationScreen({super.key});

  @override
  _CommunicationScreenState createState() => _CommunicationScreenState();
}

class _CommunicationScreenState extends State<CommunicationScreen> {
  final ApiService _apiService = ApiService();
  String _response = 'APIレスポンスがここに表示されます';
  bool _isLoading = false;

  Future<void> _testApiConnection() async {
    setState(() {
      _isLoading = true;
      _response = 'リクエスト送信中...';
    });

    try {
      final response = await _apiService.getRootInfo();
      setState(() {
        _response = 'APIレスポンス: ${response.toString()}';
      });
    } catch (e) {
      setState(() {
        _response = 'エラー: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testFirebase() async {
    setState(() {
      _isLoading = true;
      _response = 'Firebaseテスト実行中...';
    });

    try {
      final response = await _apiService.testFirebase();
      setState(() {
        _response = 'Firebaseテスト結果:\n${response.toString()}';
      });
    } catch (e) {
      setState(() {
        _response = 'エラー: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('コミュニケーション'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _isLoading ? null : _testApiConnection,
                child: const Text('APIに接続テスト'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _isLoading ? null : _testFirebase,
                child: const Text('Firebaseテスト'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/tts-demo');
                },
                child: const Text('音声合成デモ'),
              ),
              const SizedBox(height: 20),
              _isLoading ? const CircularProgressIndicator() : Container(),
              const SizedBox(height: 20),
              Text(
                _response,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
