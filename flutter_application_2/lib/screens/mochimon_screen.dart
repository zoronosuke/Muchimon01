import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

class MochimonScreen extends StatefulWidget {
  const MochimonScreen({Key? key}) : super(key: key);

  @override
  State<MochimonScreen> createState() => _MochimonScreenState();
}

class _MochimonScreenState extends State<MochimonScreen> {
  Artboard? _artboard;
  RiveAnimationController? _controller;
  bool _isPlaying = true;
  List<String> _animations = [];
  String? _currentAnimation;

  @override
  void initState() {
    super.initState();
    _loadRiveFile();
  }

  void _loadRiveFile() {
    RiveFile.asset('assets/animations/god.riv').then((file) {
      // Get the main artboard
      final artboard = file.mainArtboard;
      _animations = [];

      // List all animations
      for (final animation in artboard.animations) {
        _animations.add(animation.name);
        debugPrint('Animation found: ${animation.name}');
      }

      // Set initial animation
      if (_animations.isNotEmpty) {
        _currentAnimation = _animations.first;
        _controller = SimpleAnimation(_currentAnimation!);
        artboard.addController(_controller!);
      }

      setState(() {
        _artboard = artboard;
      });
    }).catchError((error) {
      debugPrint('Error loading Rive file: $error');
    });
  }

  void _togglePlay() {
    if (_controller == null) return;

    setState(() {
      _isPlaying = !_isPlaying;
      _controller!.isActive = _isPlaying;
    });
  }

  void _changeAnimation(String animationName) {
    if (_artboard == null) return;

    // Clean up old controller
    _controller?.dispose();

    // Create new controller
    _controller = SimpleAnimation(animationName);
    _artboard!.addController(_controller!);

    setState(() {
      _currentAnimation = animationName;
      _isPlaying = true;
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
        title: const Text('ムチモン'),
        automaticallyImplyLeading: false, // 戻るボタンを非表示にする
      ),
      body: Column(
        children: [
          // Animation display area
          Expanded(
            flex: 3,
            child: _artboard != null
                ? Rive(artboard: _artboard!)
                : const Center(child: CircularProgressIndicator()),
          ),

          // Control panel
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Play/Pause button
                ElevatedButton.icon(
                  onPressed: _togglePlay,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(_isPlaying ? '一時停止' : '再生'),
                ),

                const SizedBox(height: 16),

                // Animation selection
                if (_animations.isNotEmpty) ...[
                  const Text(
                    'アニメーション:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _animations.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final animation = _animations[index];
                        final isSelected = _currentAnimation == animation;

                        return ElevatedButton(
                          onPressed: () => _changeAnimation(animation),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isSelected ? Colors.blue : Colors.grey,
                          ),
                          child: Text(animation),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
