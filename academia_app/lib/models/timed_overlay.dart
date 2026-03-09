import 'package:flutter/material.dart';

/// Types of overlays that can appear on a video at specific times.
enum OverlayType {
  text('📝', 'Texte', Color(0xFF4CAF50)),
  equation('🧮', 'Formule', Color(0xFF2196F3)),
  drawing('✏️', 'Dessin', Color(0xFFFF9800)),
  image('🖼️', 'Image', Color(0xFF9C27B0)),
  sticker('⭐', 'Sticker', Color(0xFFFFEB3B)),
  subtitle('💬', 'Sous-titre', Color(0xFF00BCD4));

  final String emoji;
  final String label;
  final Color color;
  const OverlayType(this.emoji, this.label, this.color);
}

/// Animation presets for overlay enter/exit.
enum OverlayAnimation {
  none,
  fadeIn,
  fadeOut,
  slideUp,
  slideDown,
  slideLeft,
  slideRight,
  pop,
  bounce,
  shrink,
}

/// A single timed overlay element that appears/disappears during video playback.
class TimedOverlay {
  final String id;
  final OverlayType type;
  double startMs; // when it appears (milliseconds)
  double endMs;   // when it disappears (milliseconds)
  double x;       // normalized position 0..1
  double y;       // normalized position 0..1
  double scale;
  double rotation; // degrees
  double opacity;  // 0..1
  Map<String, dynamic> content; // type-specific data
  OverlayAnimation enterAnim;
  OverlayAnimation exitAnim;

  TimedOverlay({
    required this.id,
    required this.type,
    required this.startMs,
    required this.endMs,
    this.x = 0.5,
    this.y = 0.5,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.opacity = 1.0,
    this.content = const {},
    this.enterAnim = OverlayAnimation.fadeIn,
    this.exitAnim = OverlayAnimation.fadeOut,
  });

  /// Whether this overlay should be visible at the given playback position.
  bool isVisibleAt(double positionMs) {
    return positionMs >= startMs && positionMs <= endMs;
  }

  /// Duration in milliseconds.
  double get durationMs => endMs - startMs;

  /// Compute the effective opacity at a given position, including enter/exit animations.
  /// The fade zone is 300ms at each end.
  double effectiveOpacity(double positionMs) {
    if (!isVisibleAt(positionMs)) return 0.0;

    const fadeDurationMs = 300.0;
    double o = opacity;

    // Enter animation fade
    if (enterAnim == OverlayAnimation.fadeIn ||
        enterAnim == OverlayAnimation.pop ||
        enterAnim == OverlayAnimation.bounce) {
      final elapsed = positionMs - startMs;
      if (elapsed < fadeDurationMs) {
        o *= (elapsed / fadeDurationMs).clamp(0.0, 1.0);
      }
    }

    // Exit animation fade
    if (exitAnim == OverlayAnimation.fadeOut ||
        exitAnim == OverlayAnimation.shrink) {
      final remaining = endMs - positionMs;
      if (remaining < fadeDurationMs) {
        o *= (remaining / fadeDurationMs).clamp(0.0, 1.0);
      }
    }

    return o.clamp(0.0, 1.0);
  }

  /// Serialize to JSON for storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'start_ms': startMs,
      'end_ms': endMs,
      'x': x,
      'y': y,
      'scale': scale,
      'rotation': rotation,
      'opacity': opacity,
      'content': content,
      'enter_anim': enterAnim.name,
      'exit_anim': exitAnim.name,
    };
  }

  /// Deserialize from JSON.
  factory TimedOverlay.fromJson(Map<String, dynamic> json) {
    return TimedOverlay(
      id: json['id']?.toString() ?? UniqueKey().toString(),
      type: OverlayType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => OverlayType.text,
      ),
      startMs: (json['start_ms'] as num?)?.toDouble() ?? 0,
      endMs: (json['end_ms'] as num?)?.toDouble() ?? 5000,
      x: (json['x'] as num?)?.toDouble() ?? 0.5,
      y: (json['y'] as num?)?.toDouble() ?? 0.5,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      content: json['content'] is Map
          ? Map<String, dynamic>.from(json['content'] as Map)
          : const {},
      enterAnim: OverlayAnimation.values.firstWhere(
        (a) => a.name == json['enter_anim'],
        orElse: () => OverlayAnimation.fadeIn,
      ),
      exitAnim: OverlayAnimation.values.firstWhere(
        (a) => a.name == json['exit_anim'],
        orElse: () => OverlayAnimation.fadeOut,
      ),
    );
  }

  TimedOverlay copyWith({
    String? id,
    OverlayType? type,
    double? startMs,
    double? endMs,
    double? x,
    double? y,
    double? scale,
    double? rotation,
    double? opacity,
    Map<String, dynamic>? content,
    OverlayAnimation? enterAnim,
    OverlayAnimation? exitAnim,
  }) {
    return TimedOverlay(
      id: id ?? this.id,
      type: type ?? this.type,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      content: content ?? Map<String, dynamic>.from(this.content),
      enterAnim: enterAnim ?? this.enterAnim,
      exitAnim: exitAnim ?? this.exitAnim,
    );
  }
}
