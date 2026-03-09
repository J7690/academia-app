import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Renders video overlay layers (texts, equations, subtitles, stickers,
/// scientific annotations/strokes) on top of a video.
///
/// The overlay payload structure (from _buildOverlaysPayload):
/// ```json
/// {
///   "background": { "theme": "universite-vert" },
///   "filter": "none",
///   "texts": [{ "text": "...", "x": 0.5, "y": 0.8, "align": "center" }],
///   "equations": [{ "latex": "...", "x": 0.5, "y": 0.2 }],
///   "subtitles": [{ "text": "...", "start_ms": 0, "end_ms": 5000 }],
///   "stickers": [{ "type": "star", "x": 0.9, "y": 0.1 }],
///   "ar_objects": [...],
///   "scientific": {
///     "strokes": [{ "points": [...], "color": 0xFF..., "size": 4.0 }],
///     "annotations": [{ "content": "...", "isLatex": true, "x": 0.1, "y": 0.1, ... }]
///   }
/// }
/// ```
class VideoOverlaysLayer extends StatelessWidget {
  final Map<String, dynamic>? overlays;
  final double? positionMs;

  const VideoOverlaysLayer({
    super.key,
    required this.overlays,
    this.positionMs,
  });

  bool _isVisibleAtPosition(Map<String, dynamic> item, double? positionMs) {
    if (positionMs == null) return true;
    final startRaw = item['start_ms'];
    final endRaw = item['end_ms'];
    final start = (startRaw is num) ? startRaw.toDouble() : null;
    final end = (endRaw is num) ? endRaw.toDouble() : null;
    if (start == null && end == null) return true;
    final s = start ?? 0.0;
    final e = end ?? double.infinity;
    return positionMs >= s && positionMs <= e;
  }

  @override
  Widget build(BuildContext context) {
    final data = overlays;
    if (data == null || data.isEmpty) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];

    final zones = data['zones'];
    if (zones is List) {
      for (final item in zones) {
        if (item is! Map) continue;
        final z = Map<String, dynamic>.from(item);
        if (!_isVisibleAtPosition(z, positionMs)) continue;
        final x = (z['x'] as num?)?.toDouble() ?? 0.1;
        final y = (z['y'] as num?)?.toDouble() ?? 0.1;
        final w = (z['w'] as num?)?.toDouble() ?? 0.8;
        final h = (z['h'] as num?)?.toDouble() ?? 0.2;
        children.add(_ZoneOverlay(
          x: x,
          y: y,
          w: w,
          h: h,
          zone: z,
        ));
      }
    }

    // ── Text overlays ──
    final texts = data['texts'];
    if (texts is List) {
      for (final item in texts) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        // Skip scientific_studio entries (handled separately)
        if (m['type'] == 'scientific_studio') continue;
        if (!_isVisibleAtPosition(m, positionMs)) continue;
        final text = m['text']?.toString() ?? '';
        if (text.isEmpty) continue;
        final x = (m['x'] as num?)?.toDouble() ?? 0.5;
        final y = (m['y'] as num?)?.toDouble() ?? 0.8;
        children.add(_PositionedOverlay(
          x: x,
          y: y,
          child: _TextOverlayWidget(text: text, align: m['align']?.toString()),
        ));
      }
    }

    // ── Equation overlays (LaTeX) ──
    final equations = data['equations'];
    if (equations is List) {
      for (final item in equations) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        if (!_isVisibleAtPosition(m, positionMs)) continue;
        final latex = m['latex']?.toString() ?? '';
        if (latex.isEmpty) continue;
        final x = (m['x'] as num?)?.toDouble() ?? 0.5;
        final y = (m['y'] as num?)?.toDouble() ?? 0.2;
        children.add(_PositionedOverlay(
          x: x,
          y: y,
          child: _LatexOverlayWidget(latex: latex),
        ));
      }
    }

    // ── Subtitles ──
    final subtitles = data['subtitles'];
    if (subtitles is List && subtitles.isNotEmpty) {
      final visible = <Map<String, dynamic>>[];
      for (var i = 0; i < subtitles.length; i++) {
        final item = subtitles[i];
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        if (!_isVisibleAtPosition(m, positionMs)) continue;
        final text = m['text']?.toString() ?? '';
        if (text.isEmpty) continue;
        visible.add(m);
      }

      for (var i = 0; i < visible.length; i++) {
        final m = visible[i];
        final text = m['text']?.toString() ?? '';
        if (text.isEmpty) continue;
        children.add(_PositionedOverlay(
          x: 0.5,
          y: 0.88 + (i * 0.04),
          child: _SubtitleWidget(text: text),
        ));
      }
    }

    // ── Stickers ──
    final stickers = data['stickers'];
    if (stickers is List) {
      for (final item in stickers) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        if (!_isVisibleAtPosition(m, positionMs)) continue;
        final type = m['type']?.toString() ?? '';
        if (type.isEmpty || type == 'none') continue;
        final x = (m['x'] as num?)?.toDouble() ?? 0.9;
        final y = (m['y'] as num?)?.toDouble() ?? 0.1;
        children.add(_PositionedOverlay(
          x: x,
          y: y,
          child: _StickerWidget(type: type),
        ));
      }
    }

    // ── Scientific studio overlays ──
    final scientific = data['scientific'];
    if (scientific is Map) {
      final sci = Map<String, dynamic>.from(scientific);

      // Strokes (freehand drawing)
      final strokes = sci['strokes'];
      if (strokes is List && strokes.isNotEmpty) {
        children.add(Positioned.fill(
          child: CustomPaint(
            painter: _StrokesPainter(strokes: strokes),
          ),
        ));
      }

      // Annotations (text/equation zones)
      final annotations = sci['annotations'];
      if (annotations is List) {
        for (final item in annotations) {
          if (item is! Map) continue;
          final m = Map<String, dynamic>.from(item);
          final content = m['content']?.toString() ?? '';
          if (content.isEmpty) continue;
          final isLatex = m['isLatex'] == true;
          final x = (m['x'] as num?)?.toDouble() ?? 0.1;
          final y = (m['y'] as num?)?.toDouble() ?? 0.1;
          final fontSize = (m['fontSize'] as num?)?.toDouble() ?? 18.0;
          final colorVal = m['color'] as int?;
          final bgColorVal = m['bgColor'] as int?;
          final color = colorVal != null ? Color(colorVal) : Colors.white;
          final bgColor =
              bgColorVal != null ? Color(bgColorVal) : const Color(0x88000000);

          final scale = (m['scale'] as num?)?.toDouble() ?? 1.0;

          children.add(_PositionedOverlay(
            x: x,
            y: y,
            child: Transform.scale(
              scale: scale,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: isLatex
                    ? Math.tex(
                        content,
                        textStyle: TextStyle(color: color, fontSize: fontSize),
                      )
                    : Text(
                        content,
                        style: TextStyle(
                          color: color,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ));
        }
      }
    }

    // ── Scientific studio entries stored in texts array ──
    if (texts is List) {
      for (final item in texts) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        if (m['type'] != 'scientific_studio') continue;
        final sciData = m['data'];
        if (sciData is! Map) continue;
        final sci = Map<String, dynamic>.from(sciData);

        final strokes = sci['strokes'];
        if (strokes is List && strokes.isNotEmpty) {
          children.add(Positioned.fill(
            child: CustomPaint(
              painter: _StrokesPainter(strokes: strokes),
            ),
          ));
        }

        final annotations = sci['annotations'];
        if (annotations is List) {
          for (final ann in annotations) {
            if (ann is! Map) continue;
            final a = Map<String, dynamic>.from(ann);
            final content = a['content']?.toString() ?? '';
            if (content.isEmpty) continue;
            final isLatex = a['isLatex'] == true;
            final x = (a['x'] as num?)?.toDouble() ?? 0.1;
            final y = (a['y'] as num?)?.toDouble() ?? 0.1;
            final fontSize = (a['fontSize'] as num?)?.toDouble() ?? 18.0;
            final colorVal = a['color'] as int?;
            final bgColorVal = a['bgColor'] as int?;
            final color = colorVal != null ? Color(colorVal) : Colors.white;
            final bgColor = bgColorVal != null
                ? Color(bgColorVal)
                : const Color(0x88000000);
            final scale = (a['scale'] as num?)?.toDouble() ?? 1.0;

            children.add(_PositionedOverlay(
              x: x,
              y: y,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: isLatex
                      ? Math.tex(
                          content,
                          textStyle:
                              TextStyle(color: color, fontSize: fontSize),
                        )
                      : Text(
                          content,
                          style: TextStyle(
                            color: color,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
            ));
          }
        }
      }
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(children: children);
  }
}

// ---------------------------------------------------------------------------
// Positioned overlay helper — places a child at relative (x, y) coordinates
// where (0,0) = top-left and (1,1) = bottom-right.
// ---------------------------------------------------------------------------
class _PositionedOverlay extends StatelessWidget {
  final double x;
  final double y;
  final Widget child;

  const _PositionedOverlay({
    required this.x,
    required this.y,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: FractionalOffset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0)),
      child: child,
    );
  }
}

class _ZoneOverlay extends StatelessWidget {
  final double x;
  final double y;
  final double w;
  final double h;
  final Map<String, dynamic> zone;

  const _ZoneOverlay({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.zone,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final left = (size.width * x).clamp(0.0, size.width);
    final top = (size.height * y).clamp(0.0, size.height);
    final width = (size.width * w).clamp(24.0, size.width);
    final height = (size.height * h).clamp(24.0, size.height);

    final styleRaw = zone['style'];
    final style = styleRaw is Map ? Map<String, dynamic>.from(styleRaw) : const <String, dynamic>{};
    final blurSigma = (style['blur_sigma'] as num?)?.toDouble() ?? 0.0;
    final radius = (style['radius'] as num?)?.toDouble() ?? 10.0;
    final padding = (style['padding'] as num?)?.toDouble() ?? 10.0;

    final bgOpacity = (style['bg_opacity'] as num?)?.toDouble() ?? 0.55;
    final bgColorVal = style['bg_color'] as int?;
    final bgColorBase = bgColorVal != null ? Color(bgColorVal) : Colors.black;
    final bgColor = bgColorBase.withValues(alpha: bgOpacity.clamp(0.0, 1.0));

    final borderColorVal = style['border_color'] as int?;
    final borderColor = borderColorVal != null ? Color(borderColorVal) : Colors.white.withValues(alpha: 0.25);
    final borderWidth = (style['border_width'] as num?)?.toDouble() ?? 1.0;

    final content = _ZoneContent(zone: zone);

    Widget box = Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: blurSigma > 0 ? Colors.transparent : bgColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: content,
    );

    if (blurSigma > 0) {
      box = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            color: bgColor,
            child: box,
          ),
        ),
      );
    }

    return Positioned(
      left: left,
      top: top,
      child: box,
    );
  }
}

class _ZoneContent extends StatelessWidget {
  final Map<String, dynamic> zone;

  const _ZoneContent({required this.zone});

  @override
  Widget build(BuildContext context) {
    final contentRaw = zone['content'];
    final content = contentRaw is Map ? Map<String, dynamic>.from(contentRaw) : const <String, dynamic>{};

    final text = (content['text'] ?? zone['text'])?.toString() ?? '';
    final latex = (content['latex'] ?? zone['latex'])?.toString() ?? '';

    if (latex.isNotEmpty) {
      return SingleChildScrollView(
        child: Math.tex(
          latex,
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Text overlay widget
// ---------------------------------------------------------------------------
class _TextOverlayWidget extends StatelessWidget {
  final String text;
  final String? align;

  const _TextOverlayWidget({required this.text, this.align});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.8,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xAA000000),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        textAlign: align == 'left'
            ? TextAlign.left
            : align == 'right'
                ? TextAlign.right
                : TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LaTeX equation overlay widget
// ---------------------------------------------------------------------------
class _LatexOverlayWidget extends StatelessWidget {
  final String latex;

  const _LatexOverlayWidget({required this.latex});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.85,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Math.tex(
        latex,
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Subtitle widget
// ---------------------------------------------------------------------------
class _SubtitleWidget extends StatelessWidget {
  final String text;

  const _SubtitleWidget({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.9,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xBB000000),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sticker widget
// ---------------------------------------------------------------------------
class _StickerWidget extends StatelessWidget {
  final String type;

  const _StickerWidget({required this.type});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    switch (type) {
      case 'star':
        icon = Icons.star;
        break;
      case 'heart':
        icon = Icons.favorite;
        break;
      case 'idea':
        icon = Icons.lightbulb;
        break;
      default:
        icon = Icons.emoji_emotions;
    }
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: Color(0x66000000),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.amber, size: 32),
    );
  }
}

// ---------------------------------------------------------------------------
// CustomPainter for scientific studio freehand strokes
// ---------------------------------------------------------------------------
class _StrokesPainter extends CustomPainter {
  final List<dynamic> strokes;

  _StrokesPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke is! Map) continue;
      final s = Map<String, dynamic>.from(stroke);
      final points = s['points'];
      if (points is! List || points.isEmpty) continue;

      final colorVal = s['color'] as int?;
      final strokeSize = (s['size'] as num?)?.toDouble() ?? 4.0;
      final color = colorVal != null ? Color(colorVal) : Colors.white;

      final paint = Paint()
        ..color = color
        ..strokeWidth = strokeSize
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final path = ui.Path();
      bool first = true;
      for (final pt in points) {
        if (pt is! Map) continue;
        final px = (pt['x'] as num?)?.toDouble();
        final py = (pt['y'] as num?)?.toDouble();
        if (px == null || py == null) continue;
        // Points are stored as relative (0..videoWidth, 0..videoHeight)
        // Normalize to canvas size
        final dx = (px / 1080.0) * size.width;
        final dy = (py / 1920.0) * size.height;
        if (first) {
          path.moveTo(dx, dy);
          first = false;
        } else {
          path.lineTo(dx, dy);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokesPainter oldDelegate) {
    return oldDelegate.strokes != strokes;
  }
}
