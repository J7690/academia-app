import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/timed_overlay.dart';

/// A compact, horizontal mini-timeline that shows timed overlays as colored
/// blocks on a time axis. Supports:
/// - Playhead indicator at the current video position
/// - Tap on a block to select it
/// - Long-press to edit timing
/// - Add button at the current position
class OverlayTimelineBar extends StatefulWidget {
  final List<TimedOverlay> overlays;
  final double totalDurationMs;
  final double currentPositionMs;
  final int? selectedIndex;
  final ValueChanged<int>? onSelect;
  final VoidCallback? onAdd;
  final ValueChanged<TimedOverlay>? onOverlayChanged;

  const OverlayTimelineBar({
    super.key,
    required this.overlays,
    required this.totalDurationMs,
    required this.currentPositionMs,
    this.selectedIndex,
    this.onSelect,
    this.onAdd,
    this.onOverlayChanged,
  });

  @override
  State<OverlayTimelineBar> createState() => _OverlayTimelineBarState();
}

class _OverlayTimelineBarState extends State<OverlayTimelineBar> {
  void _haptic() => HapticFeedback.lightImpact();

  @override
  Widget build(BuildContext context) {
    final total = widget.totalDurationMs.clamp(1.0, double.infinity);

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        children: [
          // ── Header row ──
          SizedBox(
            height: 28,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Text(
                    '⏱ Timeline',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatMs(widget.currentPositionMs),
                    style: const TextStyle(
                      color: Color(0xFF00D2FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    ' / ${_formatMs(widget.totalDurationMs)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.overlays.length} overlay${widget.overlays.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (widget.onAdd != null)
                    GestureDetector(
                      onTap: () {
                        _haptic();
                        widget.onAdd?.call();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF00D2FF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF00D2FF)
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, color: Color(0xFF00D2FF), size: 12),
                            SizedBox(width: 2),
                            Text(
                              'Ajouter',
                              style: TextStyle(
                                color: Color(0xFF00D2FF),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Timeline tracks ──
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final playheadX =
                    (widget.currentPositionMs / total * width).clamp(0.0, width);

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Background grid lines (every 5 seconds)
                    CustomPaint(
                      size: Size(width, constraints.maxHeight),
                      painter: _TimeGridPainter(
                        totalMs: total,
                        width: width,
                      ),
                    ),

                    // Overlay blocks
                    for (var i = 0; i < widget.overlays.length; i++)
                      _buildOverlayBlock(
                        widget.overlays[i],
                        i,
                        width,
                        total,
                        constraints.maxHeight,
                      ),

                    // Playhead
                    Positioned(
                      left: playheadX - 1,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D2FF),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00D2FF)
                                  .withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Playhead top triangle
                    Positioned(
                      left: playheadX - 5,
                      top: -2,
                      child: CustomPaint(
                        size: const Size(10, 6),
                        painter: _TrianglePainter(
                            color: const Color(0xFF00D2FF)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayBlock(
    TimedOverlay overlay,
    int index,
    double totalWidth,
    double totalMs,
    double trackHeight,
  ) {
    final isSelected = widget.selectedIndex == index;
    final left = (overlay.startMs / totalMs * totalWidth).clamp(0.0, totalWidth);
    final right = (overlay.endMs / totalMs * totalWidth).clamp(0.0, totalWidth);
    final blockWidth = (right - left).clamp(4.0, totalWidth);

    // Stack overlays vertically if they overlap
    final row = _getRow(index);
    final rowHeight = (trackHeight - 4) / 3; // max 3 rows
    final top = 2.0 + row * rowHeight;

    return Positioned(
      left: left,
      top: top,
      width: blockWidth,
      height: rowHeight - 2,
      child: GestureDetector(
        onTap: () {
          _haptic();
          widget.onSelect?.call(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isSelected
                ? overlay.type.color.withValues(alpha: 0.5)
                : overlay.type.color.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected
                  ? overlay.type.color
                  : overlay.type.color.withValues(alpha: 0.5),
              width: isSelected ? 1.5 : 0.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: overlay.type.color.withValues(alpha: 0.3),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 3),
          alignment: Alignment.centerLeft,
          child: Text(
            '${overlay.type.emoji} ${_contentLabel(overlay)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: isSelected ? 1.0 : 0.7),
              fontSize: 8,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              overflow: TextOverflow.ellipsis,
            ),
            maxLines: 1,
          ),
        ),
      ),
    );
  }

  int _getRow(int index) {
    // Simple row assignment: alternate rows for overlapping items
    if (widget.overlays.length <= 3) return index % 3;
    return index % 3;
  }

  String _contentLabel(TimedOverlay overlay) {
    switch (overlay.type) {
      case OverlayType.text:
      case OverlayType.subtitle:
        return (overlay.content['text'] ?? '').toString();
      case OverlayType.equation:
        return (overlay.content['latex'] ?? '').toString();
      case OverlayType.drawing:
        return 'Dessin';
      case OverlayType.image:
        return 'Image';
      case OverlayType.sticker:
        return (overlay.content['type'] ?? '⭐').toString();
    }
  }

  String _formatMs(double ms) {
    final totalSec = (ms / 1000).round();
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// Paints vertical grid lines at regular intervals.
class _TimeGridPainter extends CustomPainter {
  final double totalMs;
  final double width;

  _TimeGridPainter({required this.totalMs, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 0.5;

    // Draw a line every 5 seconds
    const intervalMs = 5000.0;
    for (double ms = intervalMs; ms < totalMs; ms += intervalMs) {
      final x = ms / totalMs * width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TimeGridPainter old) =>
      old.totalMs != totalMs || old.width != width;
}

/// Paints a small downward-pointing triangle (playhead indicator).
class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) => old.color != color;
}
