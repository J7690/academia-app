import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'hero_media_carousel.dart';

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

class _MiniSiteHeroVideoState extends State<MiniSiteHeroVideo> {
  List<HeroMediaItem> _heroItems = const [];
  Map<String, Map<String, dynamic>> _mediaById = const {};
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
    if (widget.media.isEmpty) {
      debugPrint('[MiniSiteHeroVideo._buildPlaylist] no_media');
      if (mounted) {
        setState(() {
          _heroItems = const [];
          _mediaById = const {};
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
          _heroItems = const [];
          _mediaById = const {};
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
    final items = <HeroMediaItem>[];
    final mediaById = <String, Map<String, dynamic>>{};
    for (final m in candidates) {
      final resolved = await _resolveMediaUrl(client, m);
      if (resolved == null || resolved.isEmpty) continue;

      final type = (m['media_type'] ?? '').toString().toLowerCase();
      final isImage = type.contains('image');
      final mediaType = isImage ? 'image' : 'video';

      String? posterUrl;
      final playbackRaw = m['playback'];
      if (playbackRaw is Map) {
        final playback = Map<String, dynamic>.from(playbackRaw);
        final rawPoster = (playback['poster_url'] ?? '').toString().trim();
        if (rawPoster.isNotEmpty) {
          posterUrl = rawPoster;
        }
      }

      var id = (m['id'] ?? '').toString();
      if (id.isEmpty) {
        id = 'media_${items.length}';
      }
      final sortOrder = (m['sort_order'] as int?) ?? items.length;

      items.add(
        HeroMediaItem(
          id: id,
          mediaType: mediaType,
          url: resolved,
          posterUrl: posterUrl,
          sortOrder: sortOrder,
        ),
      );
      mediaById[id] = m;
    }

    if (!mounted) return;

    if (items.isEmpty) {
      debugPrint('[MiniSiteHeroVideo._buildPlaylist] no_items_after_resolve');
      setState(() {
        _heroItems = const [];
        _mediaById = const {};
      });
      return;
    }

    final firstMedia = mediaById[items.first.id];
    final firstId = firstMedia?['id'];
    final firstType = firstMedia?['media_type'];
    debugPrint(
      '[MiniSiteHeroVideo._buildPlaylist] playlist_ready size=${items.length} '
      'first_id=$firstId first_type=$firstType',
    );

    setState(() {
      _heroItems = items;
      _mediaById = mediaById;
    });
  }

  Future<String?> _resolveMediaUrl(SupabaseClient client, Map<String, dynamic> media) async {
    final type = (media['media_type'] ?? '').toString().toLowerCase();
    final isImage = type.contains('image');

    final playbackRaw = media['playback'];
    if (!isImage && playbackRaw is Map) {
      final playback = Map<String, dynamic>.from(playbackRaw);
      final bestUrl = (playback['best_url'] ?? '').toString().trim();
      if (bestUrl.isNotEmpty) {
        return bestUrl;
      }
    }

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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    double aspectRatio;
    if (width < 600) {
      aspectRatio = 16 / 9;
    } else if (width < 1000) {
      aspectRatio = 16 / 7;
    } else {
      aspectRatio = 16 / 5;
    }

    final mediaById = _mediaById;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: HeroMediaCarousel(
        items: _heroItems,
        aspectRatio: aspectRatio,
        useAspectRatio: true,
        autoplay: true,
        loopVideos: false,
        mutedByDefault: kIsWeb,
        showControls: false,
        defaultImageDuration: const Duration(seconds: 5),
        overlayBuilder: (context, currentItem) {
          final hasMedia = currentItem != null;
          final media = hasMedia ? mediaById[currentItem!.id] : null;
          final mediaTitle = media?['title']?.toString() ?? '';

          return Stack(
            fit: StackFit.expand,
            children: [
              if (!hasMedia)
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF7BC96F), Color(0xFFE8F5E9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.45),
                      Colors.black.withOpacity(0.1),
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
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
                          if ((widget.tagline ?? '').isNotEmpty ||
                              mediaTitle.isNotEmpty) ...[
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
                            errorBuilder: (context, _, __) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
