import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import 'hls_web_stub.dart'
    if (dart.library.html) 'hls_web.dart';

class MiniSiteHeroVideo extends StatefulWidget {
  final List<Map<String, dynamic>> media;
  final String title;
  final String location;
  final String? tagline;
  final String? logoUrl;
  final String? heroPosterMediaId;

  const MiniSiteHeroVideo({
    super.key,
    required this.media,
    required this.title,
    required this.location,
    this.tagline,
    this.logoUrl,
    this.heroPosterMediaId,
  });

  @override
  State<MiniSiteHeroVideo> createState() => _MiniSiteHeroVideoState();
}

class _MiniSiteVideoItem {
  final String url;
  final Map<String, dynamic> media;

  const _MiniSiteVideoItem({required this.url, required this.media});
}

class _MiniSiteHeroVideoState extends State<MiniSiteHeroVideo> {
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _isHlsWeb = false;
  String? _hlsUrl;
  List<_MiniSiteVideoItem> _playlist = const [];
  int _currentIndex = 0;
  String? _mediaSignature;

  @override
  void initState() {
    super.initState();
    _refreshIfNeeded();
  }

  @override
  void didUpdateWidget(MiniSiteHeroVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshIfNeeded();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _refreshIfNeeded() {
    final sig = _computeSignature(widget.media, widget.heroPosterMediaId);
    if (sig == _mediaSignature) {
      return;
    }
    _mediaSignature = sig;
    // Lancement asynchrone pour éviter de bloquer le build.
    Future.microtask(_buildPlaylist);
  }

  String _computeSignature(List<Map<String, dynamic>> media, String? heroPosterMediaId) {
    return '${heroPosterMediaId ?? ''}:${media.length}';
  }

  Future<void> _buildPlaylist() async {
    _videoController?.dispose();
    _videoController = null;
    _videoReady = false;
    _isHlsWeb = false;
    _hlsUrl = null;
    if (mounted) {
      setState(() {});
    }

    if (widget.media.isEmpty) {
      if (mounted) {
        setState(() {
          _playlist = const [];
        });
      }
      return;
    }

    final candidates = widget.media.where((m) {
      final type = (m['media_type'] ?? '').toString().toLowerCase();
      if (!type.contains('video')) return false;
      final url = (m['url'] ?? '').toString().trim();
      final storagePath = (m['storage_path'] ?? '').toString().trim();
      return url.isNotEmpty || storagePath.isNotEmpty;
    }).toList(growable: false);

    if (candidates.isEmpty) {
      if (mounted) {
        setState(() {
          _playlist = const [];
        });
      }
      return;
    }

    final heroId = widget.heroPosterMediaId;
    candidates.sort((a, b) {
      final idA = (a['id'] ?? '').toString();
      final idB = (b['id'] ?? '').toString();
      if (heroId != null && heroId.isNotEmpty) {
        final isHeroA = idA == heroId;
        final isHeroB = idB == heroId;
        if (isHeroA != isHeroB) {
          return isHeroA ? -1 : 1;
        }
      }
      final soA = (a['sort_order'] as int?) ?? 0;
      final soB = (b['sort_order'] as int?) ?? 0;
      return soA.compareTo(soB);
    });

    final client = Supabase.instance.client;
    final items = <_MiniSiteVideoItem>[];
    for (final m in candidates) {
      final resolved = await _resolveMediaUrl(client, m);
      if (resolved == null || resolved.isEmpty) continue;
      items.add(_MiniSiteVideoItem(url: resolved, media: m));
    }

    if (!mounted) return;

    if (items.isEmpty) {
      setState(() {
        _playlist = const [];
      });
      return;
    }

    _playlist = items;
    _currentIndex = 0;
    await _initVideo(items[0].url);
  }

  Future<String?> _resolveMediaUrl(SupabaseClient client, Map<String, dynamic> media) async {
    final directUrl = (media['url'] ?? '').toString().trim();
    if (directUrl.isNotEmpty) return directUrl;

    final storagePath = (media['storage_path'] ?? '').toString().trim();
    if (storagePath.isEmpty) return null;

    try {
      final url = await client.storage
          .from('university-media')
          .createSignedUrl(storagePath, 3600);
      return url;
    } catch (_) {
      return null;
    }
  }

  Future<void> _initVideo(String url) async {
    _videoController?.dispose();
    _videoController = null;
    _videoReady = false;
    _isHlsWeb = false;
    _hlsUrl = null;
    if (mounted) {
      setState(() {});
    }

    final lowerUrl = url.toLowerCase();
    final isHls = lowerUrl.contains('.m3u8');

    if (kIsWeb && isHls) {
      if (!mounted) return;
      setState(() {
        _isHlsWeb = true;
        _hlsUrl = url;
        _videoReady = true;
      });
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();

      var hasCompleted = false;
      controller.addListener(() {
        final value = controller.value;
        if (!mounted) return;
        if (!value.isInitialized) return;
        final duration = value.duration;
        if (duration == Duration.zero) return;
        if (!value.isPlaying && value.position >= duration && !hasCompleted) {
          hasCompleted = true;
          _onVideoCompleted();
        }
      });

      controller
        ..setLooping(false)
        ..setVolume(0)
        ..play();

      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _videoController = controller;
        _videoReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _videoController = null;
        _videoReady = false;
      });
    }
  }

  void _onVideoCompleted() {
    if (_playlist.isEmpty) return;
    _currentIndex = (_currentIndex + 1) % _playlist.length;
    final nextUrl = _playlist[_currentIndex].url;

    if (kIsWeb && _isHlsWeb) {
      setState(() {
        _hlsUrl = nextUrl;
      });
      return;
    }

    _initVideo(nextUrl);
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = _playlist.isNotEmpty && _videoReady;
    final width = MediaQuery.of(context).size.width;
    double aspectRatio;
    if (width < 600) {
      aspectRatio = 16 / 9;
    } else if (width < 1000) {
      aspectRatio = 16 / 7;
    } else {
      aspectRatio = 16 / 5;
    }

    final currentMedia = (_playlist.isNotEmpty && _currentIndex < _playlist.length)
        ? _playlist[_currentIndex].media
        : null;
    final mediaTitle = currentMedia?['title']?.toString() ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          children: [
            Positioned.fill(
              child: hasVideo && _videoController != null
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoController!.value.size.width,
                        height: _videoController!.value.size.height,
                        child: VideoPlayer(_videoController!),
                      ),
                    )
                  : hasVideo && _isHlsWeb && kIsWeb && _hlsUrl != null
                      ? const SizedBox.shrink()
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFA3D65C), Color(0xFF1EA75C)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
            ),
            if (hasVideo && _isHlsWeb && kIsWeb && _hlsUrl != null)
              Positioned.fill(
                child: HlsWebVideoPlayer(
                  url: _hlsUrl!,
                  autoplay: true,
                  loop: false,
                  muted: true,
                  onEnded: _onVideoCompleted,
                ),
              ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.45),
                      Colors.black.withOpacity(0.05),
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.location.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if ((widget.tagline ?? '').isNotEmpty || mediaTitle.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            mediaTitle.isNotEmpty
                                ? mediaTitle
                                : (widget.tagline ?? ''),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if ((widget.logoUrl ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          widget.logoUrl!,
                          height: 40,
                          width: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, _, __) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
