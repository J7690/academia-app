import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../providers/smart_whiteboard_provider.dart';

/// Écran de prévisualisation de la vidéo Smart Whiteboard
/// 
/// Permet de visualiser la vidéo MP4 générée par Kamatera,
/// de la partager, de la télécharger et de la publier dans le Challenge Feed.
class SmartWhiteboardPreviewScreen extends StatefulWidget {
  final String? projectId;
  final String? renderId;
  final String? videoUrl;

  const SmartWhiteboardPreviewScreen({
    super.key,
    this.projectId,
    this.renderId,
    this.videoUrl,
  });

  @override
  State<SmartWhiteboardPreviewScreen> createState() => _SmartWhiteboardPreviewScreenState();
}

class _SmartWhiteboardPreviewScreenState extends State<SmartWhiteboardPreviewScreen> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _isPolling = false;
  String? _resolvedVideoUrl;
  String? _videoError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final provider = context.read<SmartWhiteboardProvider>();

    // 1. Prendre l'URL déjà connue (widget ou provider)
    final url = widget.videoUrl ?? provider.renderVideoUrl;
    if (url != null) {
      await _initializeVideo(url);
      return;
    }

    // 2. Sinon, lancer le polling si on a un render job
    if (provider.currentRenderJobId != null && !_isPolling) {
      setState(() => _isPolling = true);
      await provider.pollRenderJob();
      if (!mounted) return;
      final polledUrl = provider.renderVideoUrl;
      setState(() => _isPolling = false);
      if (polledUrl != null) {
        await _initializeVideo(polledUrl);
      }
    }
  }

  Future<void> _initializeVideo(String url) async {
    setState(() { _resolvedVideoUrl = url; _videoError = null; });
    debugPrint('DEBUG-PREVIEW: _initializeVideo url=$url');
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      if (!mounted) return;
      debugPrint('DEBUG-PREVIEW: initialized OK duration=${controller.value.duration}');
      setState(() {
        _videoController = controller;
        _isInitialized = true;
      });
      await controller.setLooping(true);
      await controller.play();
    } catch (e) {
      debugPrint('DEBUG-PREVIEW ERROR: $e');
      if (!mounted) return;
      setState(() => _videoError = e.toString());
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
        title: const Text('Prévisualisation'),
        backgroundColor: const Color(0xFF1EA75C),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _handleShare,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _handleDownload,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _buildVideoPlayer(),
            ),
          ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_isInitialized && _videoController != null) {
      return AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: VideoPlayer(_videoController!),
      );
    }

    if (_videoError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text('Erreur lecteur vidéo', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_videoError!, style: const TextStyle(fontSize: 12, color: Colors.red), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('URL: ${_resolvedVideoUrl ?? "-"}', style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final label = _isPolling
        ? 'Rendu en cours...'
        : _resolvedVideoUrl != null
            ? 'Initialisation du lecteur...'
            : 'Chargement de la vidéo...';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.edit),
                  label: const Text('Modifier le storyboard'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleShare() {
    if (widget.videoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune vidéo à partager')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Partage - Fonctionnalité à implémenter')),
    );
  }

  void _handleDownload() {
    if (widget.videoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune vidéo à télécharger')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Téléchargement - Fonctionnalité à implémenter')),
    );
  }
}
