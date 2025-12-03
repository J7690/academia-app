import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../widgets/hls_web_stub.dart'
    if (dart.library.html) '../../widgets/hls_web.dart';
import '../../widgets/pdf_viewer_stub.dart'
    if (dart.library.html) '../../widgets/pdf_viewer_web.dart';
import '../../widgets/student_video_player.dart';
import '../../widgets/academia_video_widget.dart';

class CourseResourceViewerScreen extends StatefulWidget {
  final Map<String, dynamic> resource;

  const CourseResourceViewerScreen({super.key, required this.resource});

  @override
  State<CourseResourceViewerScreen> createState() => _CourseResourceViewerScreenState();
}

class _CourseResourceViewerScreenState extends State<CourseResourceViewerScreen> {
  String? _url;
  String? _resolvedUrl;
  String? _error;
  bool _isLoading = true;
  bool _isVideo = false;
  bool _isAudio = false;
  bool _isHlsWeb = false;
  bool _isPdf = false;
  String? _hlsUrl;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    try {
      debugPrint('CourseResourceViewer: raw resource=' + widget.resource.toString());
      final type =
          widget.resource['resource_type']?.toString().toLowerCase() ?? '';
      final isVideoFromType =
          type.contains('video') || type.contains('vidéo');
      final isAudioFromType = type.contains('audio');
      final isFileResource = isVideoFromType ||
          isAudioFromType ||
          type.contains('document') ||
          type.contains('doc') ||
          type.contains('pdf') ||
          type.contains('image');

      String? resolvedUrl;

      if (isFileResource) {
        final bucket =
            widget.resource['storage_bucket']?.toString().trim() ?? '';
        final path = widget.resource['storage_path']?.toString().trim() ?? '';

        if (bucket.isNotEmpty && path.isNotEmpty) {
          // Cas 2 : schéma normal Supabase Storage bucket + path.
          final client = Supabase.instance.client;
          resolvedUrl = await client.storage.from(bucket).createSignedUrl(
                path,
                3600,
              );
        }
      } else {
        final externalUrl =
            widget.resource['external_url']?.toString().trim() ?? '';
        if (externalUrl.isNotEmpty) {
          resolvedUrl = externalUrl;
        }

        if (resolvedUrl == null || resolvedUrl.isEmpty) {
          final bucket =
              widget.resource['storage_bucket']?.toString().trim() ?? '';
          final path = widget.resource['storage_path']?.toString().trim() ?? '';

          // Cas 1 : certains contenus existants peuvent stocker directement une URL
          // complète (par ex. une URL Mux) dans storage_bucket, sans storage_path.
          // On tolère ce cas en utilisant directement cette URL.
          if (bucket.isNotEmpty && bucket.startsWith('http') && path.isEmpty) {
            resolvedUrl = bucket;
          } else if (bucket.isNotEmpty && path.isNotEmpty) {
            // Cas 2 : schéma normal Supabase Storage bucket + path.
            final client = Supabase.instance.client;
            resolvedUrl = await client.storage.from(bucket).createSignedUrl(
                  path,
                  3600,
                );
          }
        }
      }

      if (resolvedUrl == null || resolvedUrl.isEmpty) {
        debugPrint(
          'CourseResourceViewer: no URL resolved for resource=' +
              widget.resource.toString(),
        );
        setState(() {
          _error = 'Ressource non disponible.';
          _isLoading = false;
        });
        return;
      }

      _resolvedUrl = resolvedUrl;

      final lowerUrl = resolvedUrl.toLowerCase();
      final isHls = lowerUrl.contains('.m3u8');
      // Si l'URL pointe vers un flux HLS (.m3u8), on la traite comme une vidéo
      // même si resource_type n'indique pas explicitement "video".
      final isVideo = isVideoFromType || isHls;
      final isAudio = isAudioFromType && !isVideo;
      final isPdf = !isVideo &&
          !isAudio &&
          (type.contains('pdf') || lowerUrl.endsWith('.pdf'));

      debugPrint(
        'CourseResourceViewer: resolvedUrl=$resolvedUrl type=$type '
        'isVideo=$isVideo isAudio=$isAudio isHls=$isHls kIsWeb=$kIsWeb',
      );

      if ((isVideo || isAudio) && kIsWeb && isHls) {
        setState(() {
          _isVideo = isVideo;
          _isAudio = isAudio;
          _isHlsWeb = true;
          _hlsUrl = resolvedUrl;
          _isPdf = false;
          _isLoading = false;
        });
        return;
      }

      if (isVideo || isAudio) {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && isVideo) {
          setState(() {
            _videoController = null;
            _isVideo = isVideo;
            _isAudio = isAudio;
            _isPdf = false;
            _isLoading = false;
          });
        } else {
          final controller =
              VideoPlayerController.networkUrl(Uri.parse(resolvedUrl));
          await controller.initialize();
          controller.setLooping(isAudio);
          controller.play();
          setState(() {
            _videoController = controller;
            _isVideo = isVideo;
            _isAudio = isAudio;
            _isPdf = false;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _url = resolvedUrl;
          _isVideo = false;
          _isAudio = false;
          _isPdf = isPdf;
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
    final title = widget.resource['title']?.toString() ?? 'Ressource';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: _buildBody(),
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
    if (_isVideo || _isAudio) {
      if (_isHlsWeb && kIsWeb) {
        final url = _hlsUrl;
        if (url == null || url.isEmpty) {
          return const SizedBox.shrink();
        }
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: HlsWebVideoPlayer(
            url: url,
            autoplay: true,
            loop: _isAudio,
            muted: false,
            showControls: true,
          ),
        );
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && _isVideo) {
        final url = _resolvedUrl;
        if (url == null || url.isEmpty) {
          return const SizedBox.shrink();
        }
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: AcademiaVideoWidget(
            url: url,
            autoplay: true,
            loop: false,
            muted: false,
            showControls: true,
            resizeMode: 'contain',
          ),
        );
      }

      final controller = _videoController;
      if (controller == null) {
        return const SizedBox.shrink();
      }
      return StudentVideoPlayer(
        controller: controller,
        isAudio: _isAudio,
      );
    }
    if (_isPdf) {
      final url = _resolvedUrl ?? _url;
      if (url == null || url.isEmpty) {
        return const SizedBox.shrink();
      }
      return SizedBox(
        height: 600,
        child: PdfViewer(url: url),
      );
    }
    final url = _url;
    if (url == null || url.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Cette ressource va être ouverte pour visualisation. Aucun bouton de téléchargement direct n\'est proposé.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final uri = Uri.tryParse(url);
              if (uri == null) {
                return;
              }
              await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Ouvrir la ressource'),
          ),
        ],
      ),
    );
  }
}
