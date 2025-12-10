class HeroAnimationDef {
  final String id;
  final String code;
  final String name;
  final Map<String, dynamic> config;

  const HeroAnimationDef({
    required this.id,
    required this.code,
    required this.name,
    required this.config,
  });

  factory HeroAnimationDef.fromJson(Map<String, dynamic> json) {
    return HeroAnimationDef(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      config: json['config'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['config'] as Map)
          : const <String, dynamic>{},
    );
  }
}

class HeroRender {
  final String id;
  final String playlistItemId;
  final String status;
  final String? renderUrl;
  final String? thumbnailUrl;
  final String? logs;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const HeroRender({
    required this.id,
    required this.playlistItemId,
    required this.status,
    this.renderUrl,
    this.thumbnailUrl,
    this.logs,
    this.createdAt,
    this.updatedAt,
  });

  factory HeroRender.fromJson(Map<String, dynamic> json) {
    DateTime? parseTs(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    return HeroRender(
      id: json['id']?.toString() ?? '',
      playlistItemId: json['playlist_item_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      renderUrl: json['render_url']?.toString(),
      thumbnailUrl: json['thumbnail_url']?.toString(),
      logs: json['logs']?.toString(),
      createdAt: parseTs(json['created_at']),
      updatedAt: parseTs(json['updated_at']),
    );
  }
}

class HeroOverlays {
  final List<Map<String, dynamic>> layers;

  const HeroOverlays({required this.layers});

  factory HeroOverlays.fromJson(dynamic json) {
    if (json is List) {
      final list = json
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
      return HeroOverlays(layers: list);
    }
    if (json is Map<String, dynamic> && json['layers'] is List) {
      final list = (json['layers'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
      return HeroOverlays(layers: list);
    }
    return const HeroOverlays(layers: <Map<String, dynamic>>[]);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'layers': layers,
    };
  }
}

class HeroPlaylistItem {
  final String id;
  final String slot;
  final String mediaType; // 'video' ou 'image'
  final String? baseVideoUrl;
  final String? baseImageUrl;
  final String? title;
  final String? subtitle;
  final int sortOrder;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final HeroOverlays? overlays;
  final HeroRender? lastRender;

  const HeroPlaylistItem({
    required this.id,
    required this.slot,
    required this.mediaType,
    this.baseVideoUrl,
    this.baseImageUrl,
    this.title,
    this.subtitle,
    required this.sortOrder,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.overlays,
    this.lastRender,
  });

  factory HeroPlaylistItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseTs(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    HeroOverlays? overlays;
    final overlaysRaw = json['overlays'];
    if (overlaysRaw != null) {
      overlays = HeroOverlays.fromJson(overlaysRaw);
    }

    HeroRender? lastRender;
    final lastRenderRaw = json['last_render'];
    if (lastRenderRaw is Map<String, dynamic>) {
      lastRender = HeroRender.fromJson(lastRenderRaw);
    }

    return HeroPlaylistItem(
      id: json['id']?.toString() ?? '',
      slot: json['slot']?.toString() ?? 'default',
      mediaType: json['media_type']?.toString() ?? 'video',
      baseVideoUrl: json['base_video_url']?.toString(),
      baseImageUrl: json['base_image_url']?.toString(),
      title: json['title']?.toString(),
      subtitle: json['subtitle']?.toString(),
      sortOrder: json['sort_order'] is int
          ? json['sort_order'] as int
          : int.tryParse(json['sort_order']?.toString() ?? '') ?? 0,
      isActive: json['is_active'] is bool
          ? json['is_active'] as bool
          : json['is_active']?.toString() == 'true',
      createdAt: parseTs(json['created_at']),
      updatedAt: parseTs(json['updated_at']),
      overlays: overlays,
      lastRender: lastRender,
    );
  }
}
