import 'package:flutter/material.dart';

import '../../video/academia_playback_engine.dart';
import '../../widgets/video_overlays_layer.dart';

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
  @override
  void initState() {
    super.initState();
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
                child: widget.videoUrl.trim().isNotEmpty
                    ? Stack(
                        children: [
                          Positioned.fill(
                            child: AcademiaPlaybackEngine.view(
                              url: widget.videoUrl.trim(),
                              autoplay: true,
                              looping: true,
                              muted: false,
                              showControls: true,
                              fit: BoxFit.contain,
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: VideoOverlaysLayer(
                                overlays: widget.overlays,
                              ),
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Vidéo indisponible.',
                        style: TextStyle(color: Colors.white),
                      ),
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
