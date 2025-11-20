import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

class MiniSiteMediaViewerScreen extends StatefulWidget {
  final Map<String, dynamic> media;

  const MiniSiteMediaViewerScreen({super.key, required this.media});

  @override
  State<MiniSiteMediaViewerScreen> createState() => _MiniSiteMediaViewerScreenState();
}

class _MiniSiteMediaViewerScreenState extends State<MiniSiteMediaViewerScreen> {
  String? _url;
  String? _error;
  bool _isLoading = true;
  bool _isVideo = false;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    try {
      final storagePath = widget.media['storage_path']?.toString() ?? '';
      final mediaType = widget.media['media_type']?.toString().toLowerCase() ?? '';
      final isVideo = mediaType.contains('video');

      if (storagePath.isEmpty) {
        setState(() {
          _error = 'Média non disponible.';
          _isLoading = false;
        });
        return;
      }

      final client = Supabase.instance.client;
      final resolvedUrl = await client.storage.from('university-media').createSignedUrl(
            storagePath,
            3600,
          );

      if (isVideo) {
        final controller = VideoPlayerController.networkUrl(Uri.parse(resolvedUrl));
        await controller.initialize();
        controller.setLooping(true);
        controller.play();
        setState(() {
          _videoController = controller;
          _isVideo = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _url = resolvedUrl;
          _isVideo = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
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
    final title = widget.media['title']?.toString() ?? 'Média';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const CircularProgressIndicator();
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(_error!),
      );
    }
    if (_isVideo) {
      final controller = _videoController;
      if (controller == null) {
        return const SizedBox.shrink();
      }
      final aspectRatio = controller.value.aspectRatio == 0
          ? 16 / 9
          : controller.value.aspectRatio;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AspectRatio(
            aspectRatio: aspectRatio,
            child: VideoPlayer(controller),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  if (controller.value.isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                  setState(() {});
                },
                icon: Icon(
                  controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
              ),
            ],
          ),
        ],
      );
    }
    final url = _url;
    if (url == null || url.isEmpty) {
      return const SizedBox.shrink();
    }
    return InteractiveViewer(
      child: Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Text('Erreur lors du chargement de l\'image.');
        },
      ),
    );
  }
}
