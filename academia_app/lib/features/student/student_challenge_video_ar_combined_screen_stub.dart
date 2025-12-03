import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../widgets/student_video_player.dart';

class StudentChallengeVideoArCombinedScreen extends StatefulWidget {
  final String videoUrl;
  final Map<String, dynamic>? overlays;

  const StudentChallengeVideoArCombinedScreen({
    super.key,
    required this.videoUrl,
    this.overlays,
  });

  @override
  State<StudentChallengeVideoArCombinedScreen> createState() =>
      _StudentChallengeVideoArCombinedScreenState();
}

class _StudentChallengeVideoArCombinedScreenState
    extends State<StudentChallengeVideoArCombinedScreen> {
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final url = widget.videoUrl.trim();
    if (url.isEmpty) {
      return;
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoController = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      controller.setLooping(true);
      controller.play();
      setState(() {
        _videoInitialized = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _videoInitialized = false;
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vidéo + AR live'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.all(12.0),
              child: Center(
                child: _videoController != null && _videoInitialized
                    ? StudentVideoPlayer(
                        controller: _videoController!,
                        overlays: widget.overlays,
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Le mode AR live n’est pas disponible sur cette plateforme. Utilise l’app mobile pour placer des objets AR.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
