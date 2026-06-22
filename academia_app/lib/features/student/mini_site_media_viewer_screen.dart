import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../video/academia_playback_engine.dart';
import '../../widgets/adaptive_video_container.dart';

class MiniSiteMediaViewerScreen extends StatefulWidget {
  final Map<String, dynamic> media;

  const MiniSiteMediaViewerScreen({super.key, required this.media});

  @override
  State<MiniSiteMediaViewerScreen> createState() => _MiniSiteMediaViewerScreenState();
}

class _MiniSiteMediaViewerScreenState extends State<MiniSiteMediaViewerScreen> {
  String? _url;
  String? _resolvedUrl;
  String? _error;
  bool _isLoading = true;
  bool _isVideo = false;
  int? _videoWidth;
  int? _videoHeight;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    try {
      final mediaType = widget.media['media_type']?.toString().toLowerCase() ?? '';
      final isVideo = mediaType.contains('video');
      final storagePath = widget.media['storage_path']?.toString() ?? '';
      final directUrl = widget.media['url']?.toString().trim() ?? '';
      
      // Extract video dimensions if available
      _videoWidth = widget.media['width'] as int?;
      _videoHeight = widget.media['height'] as int?;

      String? resolvedUrl;

      if (directUrl.isNotEmpty) {
        resolvedUrl = directUrl;
      } else if (storagePath.isNotEmpty) {
        final client = Supabase.instance.client;
        resolvedUrl = await client.storage
            .from('university-media')
            .createSignedUrl(storagePath, 3600);
      }

      if (resolvedUrl == null || resolvedUrl.isEmpty) {
        setState(() {
          _error = 'Média non disponible.';
          _isLoading = false;
        });
        return;
      }

      _resolvedUrl = resolvedUrl;

      if (isVideo) {
        setState(() {
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1EA75C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Retour'),
            ),
          ),
        ),
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
      final url = _resolvedUrl;
      if (url == null || url.isEmpty) {
        return const SizedBox.shrink();
      }
      // Use AdaptiveVideoContainer for auto aspect ratio detection
      final videoWidth = _videoWidth ?? 1920;
      final videoHeight = _videoHeight ?? 1080;
      final videoAspectRatio = videoWidth / videoHeight;
      
      return AdaptiveVideoContainer(
        videoAspectRatio: videoAspectRatio,
        useAdaptiveSizing: true,
        child: AcademiaPlaybackEngine.view(
          url: url,
          autoplay: true,
          looping: true,
          muted: false,
          showControls: true,
          fit: BoxFit.contain,
        ),
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
