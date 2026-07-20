import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/smart_whiteboard_provider.dart';
import '../../../student/video_publish_screen.dart';
import '../../../../video/academia_playback_view.dart';

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
  bool _isPolling = false;
  String? _resolvedVideoUrl;

  @override
  void initState() {
    super.initState();
    debugPrint('[WB-PREVIEW] initState — projectId=${widget.projectId} renderId=${widget.renderId} videoUrl=${widget.videoUrl}');
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final provider = context.read<SmartWhiteboardProvider>();
    debugPrint('[WB-PREVIEW] _start — provider.renderVideoUrl=${provider.renderVideoUrl} provider.currentRenderJobId=${provider.currentRenderJobId}');

    // 1. Prendre l'URL déjà connue (widget ou provider)
    final url = widget.videoUrl ?? provider.renderVideoUrl;
    if (url != null) {
      debugPrint('[WB-PREVIEW] URL already known, skipping poll → $url');
      _setVideoUrl(url);
      return;
    }

    // 2. Sinon, lancer le polling si on a un render job
    if (provider.currentRenderJobId != null && !_isPolling) {
      debugPrint('[WB-PREVIEW] Starting poll for renderJobId=${provider.currentRenderJobId}');
      setState(() => _isPolling = true);
      await provider.pollRenderJob();
      if (!mounted) return;
      final polledUrl = provider.renderVideoUrl;
      debugPrint('[WB-PREVIEW] Poll done — polledUrl=$polledUrl state=${provider.state}');
      setState(() => _isPolling = false);
      if (polledUrl != null) {
        _setVideoUrl(polledUrl);
      } else {
        debugPrint('[WB-PREVIEW] ⚠️ Poll finished but NO video URL. error=${provider.errorMessage}');
      }
    } else {
      debugPrint('[WB-PREVIEW] ⚠️ No URL and no renderJobId — nothing to play');
    }
  }

  void _setVideoUrl(String url) {
    debugPrint('[WB-PREVIEW] ✅ _setVideoUrl → ${url.length > 80 ? '${url.substring(0, 80)}...' : url}');
    setState(() { _resolvedVideoUrl = url; });
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
    // URL résolue → AcademiaPlaybackView (natif Android avec safeCodecSelector)
    if (_resolvedVideoUrl != null) {
      debugPrint('[WB-PREVIEW] Building AcademiaPlaybackView for url=${_resolvedVideoUrl!.substring(0, _resolvedVideoUrl!.length.clamp(0, 60))}...');
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AcademiaPlaybackView(
          url: _resolvedVideoUrl!,
          autoplay: true,
          looping: true,
          muted: false,
          showControls: true,
          fit: BoxFit.contain,
          showErrorText: true,
        ),
      );
    }

    // Polling ou chargement
    final label = _isPolling
        ? 'Rendu en cours...'
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

  /// URL de la vidéo effectivement disponible (widget, résolue ou provider).
  String? get _effectiveVideoUrl {
    final provider = context.read<SmartWhiteboardProvider>();
    return _resolvedVideoUrl ?? widget.videoUrl ?? provider.renderVideoUrl;
  }

  Future<void> _handlePublish() async {
    final url = _effectiveVideoUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La vidéo n\'est pas encore prête.')),
      );
      return;
    }

    // Réutilise le flux de publication existant du Challenge (caption, cover,
    // visibilité...). La vidéo est déjà uploadée : on passe l'URL rendue.
    final published = await Navigator.of(context).push<bool?>(
      MaterialPageRoute(
        builder: (_) => VideoPublishScreen(
          videoUrl: url,
          videoType: 'free',
        ),
      ),
    );

    if (!mounted) return;
    if (published == true) {
      // Ferme le studio Smart Whiteboard et remonte vers le feed.
      Navigator.of(context).pop(true);
    }
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Action principale : publier dans le Challenge
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _resolvedVideoUrl != null ? _handlePublish : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1EA75C),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.upload),
              label: const Text(
                'Publier dans le Challenge',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
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
