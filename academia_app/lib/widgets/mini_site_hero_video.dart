import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../video/academia_playback_engine.dart';

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
  final String mediaType; // 'video' ou 'image'

  const _MiniSiteVideoItem({
    required this.url,
    required this.media,
    required this.mediaType,
  });
}

class _MiniSiteHeroVideoState extends State<MiniSiteHeroVideo> {
  bool _videoReady = false;
  List<_MiniSiteVideoItem> _playlist = const [];
  int _currentIndex = 0;
  String? _mediaSignature;
  String? _currentImageUrl;
  String? _currentVideoUrl;
  Timer? _imageTimer;

  void _cancelImageTimer() {
    _imageTimer?.cancel();
    _imageTimer = null;
  }

  void _scheduleNextImage() {
    _cancelImageTimer();
    if (_playlist.length <= 1) {
      return;
    }
    _imageTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || _playlist.isEmpty) {
        return;
      }
      final nextIndex = (_currentIndex + 1) % _playlist.length;
      _goToIndex(nextIndex);
    });
  }

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
    _cancelImageTimer();
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
    debugPrint(
      '[MiniSiteHeroVideo._buildPlaylist] start media_count=${widget.media.length} '
      'heroPosterMediaId=${widget.heroPosterMediaId}',
    );
    _cancelImageTimer();
    _videoReady = false;
    _currentVideoUrl = null;
    if (mounted) {
      setState(() {});
    }

    if (widget.media.isEmpty) {
      debugPrint('[MiniSiteHeroVideo._buildPlaylist] no_media');
      if (mounted) {
        setState(() {
          _playlist = const [];
        });
      }
      return;
    }

    final candidates = widget.media.where((m) {
      final type = (m['media_type'] ?? '').toString().toLowerCase();
      final isVideo = type.contains('video');
      final isImage = type.contains('image');
      if (!isVideo && !isImage) return false;
      final url = (m['url'] ?? '').toString().trim();
      final storagePath = (m['storage_path'] ?? '').toString().trim();
      return url.isNotEmpty || storagePath.isNotEmpty;
    }).toList(growable: false);

    debugPrint(
      '[MiniSiteHeroVideo._buildPlaylist] candidates_count=${candidates.length} '
      'details=' +
          candidates
              .map((m) =>
                  'id=${m['id']} type=${m['media_type']} so=${m['sort_order']} '
                  'hasUrl=${(m['url'] ?? '').toString().trim().isNotEmpty} '
                  'hasStoragePath=${(m['storage_path'] ?? '').toString().trim().isNotEmpty}')
              .toList()
              .toString(),
    );

    if (candidates.isEmpty) {
      debugPrint('[MiniSiteHeroVideo._buildPlaylist] no_candidates_after_filter');
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
      final type = (m['media_type'] ?? '').toString().toLowerCase();
      final isImage = type.contains('image');
      final mediaType = isImage ? 'image' : 'video';
      items.add(
        _MiniSiteVideoItem(
          url: resolved,
          media: m,
          mediaType: mediaType,
        ),
      );
    }

    if (!mounted) return;

    if (items.isEmpty) {
      debugPrint('[MiniSiteHeroVideo._buildPlaylist] no_items_after_resolve');
      setState(() {
        _playlist = const [];
      });
      return;
    }

    _playlist = items;
    final firstMedia = items.first.media;
    final firstId = firstMedia['id'];
    final firstType = firstMedia['media_type'];
    debugPrint(
      '[MiniSiteHeroVideo._buildPlaylist] playlist_ready size=${items.length} '
      'first_id=$firstId first_type=$firstType',
    );
    _currentIndex = 0;
    _goToIndex(0);
  }

  void _goToIndex(int index) {
    if (_playlist.isEmpty) return;
    _currentIndex = index % _playlist.length;
    final item = _playlist[_currentIndex];

    if (item.mediaType == 'image') {
      _currentImageUrl = item.url;
      _currentVideoUrl = null;
      _videoReady = true;
      if (mounted) {
        setState(() {});
      }
      _scheduleNextImage();
    } else {
      _currentImageUrl = null;
      _cancelImageTimer();
      _initVideo(item.url);
    }
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
    _videoReady = false;
    _currentImageUrl = null;
    _currentVideoUrl = null;
    if (mounted) {
      setState(() {});
    }

    if (!mounted) return;
    setState(() {
      _currentVideoUrl = url;
      _videoReady = true;
    });
  }

  void _onVideoCompleted() {
    if (_playlist.isEmpty) return;
    final nextIndex = (_currentIndex + 1) % _playlist.length;
    _goToIndex(nextIndex);
  }

  @override
  Widget build(BuildContext context) {
    final hasMedia = _playlist.isNotEmpty && _videoReady;
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
              child: () {
                if (_currentImageUrl != null) {
                  return Image.network(
                    _currentImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, _, __) {
                      return Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFA3D65C), Color(0xFF1EA75C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      );
                    },
                  );
                }

                if (hasMedia && _currentVideoUrl != null) {
                  return AcademiaPlaybackEngine.view(
                    url: _currentVideoUrl!,
                    autoplay: true,
                    looping: true,
                    muted: false,
                    showControls: false,
                    fit: BoxFit.cover,
                    onCompleted: _onVideoCompleted,
                  );
                }

                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFA3D65C), Color(0xFF1EA75C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                );
              }(),
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
