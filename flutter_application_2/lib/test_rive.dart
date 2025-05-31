import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rive Animation Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const RiveTestScreen(),
    );
  }
}

class RiveTestScreen extends StatefulWidget {
  const RiveTestScreen({Key? key}) : super(key: key);

  @override
  State<RiveTestScreen> createState() => _RiveTestScreenState();
}

class _RiveTestScreenState extends State<RiveTestScreen> {
  Artboard? _artboard;
  List<String> animationNames = [];
  String? selectedAnimation;
  RiveAnimationController? _controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRiveFile();
  }

  void _loadRiveFile() {
    RiveFile.asset('assets/animations/muchimon01.riv').then((file) {
      final artboard = file.mainArtboard;
      animationNames = [];

      // Get all animations
      for (final animation in file.mainArtboard.animations) {
        print('Animation found: ${animation.name}');
        animationNames.add(animation.name);
      }

      // Set up the initial animation
      if (animationNames.isNotEmpty) {
        selectedAnimation = animationNames.first;
        _controller = SimpleAnimation(selectedAnimation!);
        artboard.addController(_controller!);
      }

      setState(() {
        _artboard = artboard;
        isLoading = false;
      });
    }).catchError((error) {
      print('Error loading Rive file: $error');
      setState(() {
        isLoading = false;
      });
    });
  }

  void _changeAnimation(String animationName) {
    if (_artboard == null) return;

    setState(() {
      // Reset the artboard
      _artboard = null;
      isLoading = true;
    });

    // Reload the file with the new animation
    RiveFile.asset('assets/animations/muchimon01.riv').then((file) {
      final artboard = file.mainArtboard;
      _controller = SimpleAnimation(animationName);
      artboard.addController(_controller!);

      setState(() {
        _artboard = artboard;
        selectedAnimation = animationName;
        isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rive アニメーションテスト'),
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _artboard != null
                    ? Rive(artboard: _artboard!)
                    : const Center(child: Text('Riveファイルの読み込みに失敗しました')),
          ),
          if (animationNames.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'アニメーション一覧:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: animationNames
                        .map(
                          (name) => ElevatedButton(
                            onPressed: () => _changeAnimation(name),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedAnimation == name
                                  ? Colors.blue
                                  : Colors.grey,
                            ),
                            child: Text(name),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
