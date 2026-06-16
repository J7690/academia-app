import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart' as pf;

import 'whiteboard_models.dart';

/// Canvas de dessin du tableau blanc AcademiaClassroom.
///
/// Utilise `perfect_freehand` pour le lissage des traits.
/// Supporte : stylo, surligneur, gomme, palette de couleurs, épaisseurs.
class WhiteboardCanvas extends StatefulWidget {
  final bool isReadOnly;
  final List<WhiteboardStroke> remoteStrokes;
  final void Function(WhiteboardStroke stroke)? onStrokeCompleted;
  final VoidCallback? onClearAll;

  const WhiteboardCanvas({
    super.key,
    this.isReadOnly = false,
    this.remoteStrokes = const [],
    this.onStrokeCompleted,
    this.onClearAll,
  });

  @override
  State<WhiteboardCanvas> createState() => WhiteboardCanvasState();
}

class WhiteboardCanvasState extends State<WhiteboardCanvas> {
  // ─── State ──────────────────────────────────────────────────────────
  final List<WhiteboardStroke> _localStrokes = [];
  List<Point> _currentPoints = [];
  WhiteboardTool _tool = WhiteboardTool.pen;
  Color _color = const Color(0xFFFFFFFF);
  double _strokeWidth = 3.0;
  int _strokeCounter = 0;

  List<WhiteboardStroke> get allStrokes => [
        ...widget.remoteStrokes,
        ..._localStrokes,
      ];

  void clearLocal() {
    setState(() => _localStrokes.clear());
  }

  // ─── Gesture handlers ───────────────────────────────────────────────

  void _onPanStart(DragStartDetails details) {
    if (widget.isReadOnly) return;
    final pos = details.localPosition;
    setState(() {
      _currentPoints = [Point(pos.dx, pos.dy, 0.5)];
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (widget.isReadOnly) return;
    final pos = details.localPosition;
    setState(() {
      _currentPoints = [
        ..._currentPoints,
        Point(pos.dx, pos.dy, 0.5),
      ];
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (widget.isReadOnly || _currentPoints.isEmpty) return;

    _strokeCounter++;
    final stroke = WhiteboardStroke(
      id: 'local_$_strokeCounter',
      userId: 'local',
      points: List.from(_currentPoints),
      color: _tool == WhiteboardTool.eraser
          ? const Color(0xFF1E293B)
          : _color,
      strokeWidth: _tool == WhiteboardTool.eraser ? 20.0 : _strokeWidth,
      isEraser: _tool == WhiteboardTool.eraser,
    );

    setState(() {
      _localStrokes.add(stroke);
      _currentPoints = [];
    });

    widget.onStrokeCompleted?.call(stroke);
  }

  void _undo() {
    if (_localStrokes.isEmpty) return;
    setState(() => _localStrokes.removeLast());
  }

  // ─── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Toolbar ──────────────────────────────────────────────
        if (!widget.isReadOnly) _buildToolbar(),
        // ── Canvas ───────────────────────────────────────────────
        Expanded(
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: ClipRect(
              child: CustomPaint(
                painter: _WhiteboardPainter(
                  strokes: allStrokes,
                  currentPoints: _currentPoints,
                  currentColor: _tool == WhiteboardTool.eraser
                      ? const Color(0xFF1E293B)
                      : _color,
                  currentStrokeWidth:
                      _tool == WhiteboardTool.eraser ? 20.0 : _strokeWidth,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: const Color(0xFF0F172A),
      child: Row(
        children: [
          // ── Outils ──────────────────────────────────────────────
          _ToolBtn(
            icon: Icons.edit,
            selected: _tool == WhiteboardTool.pen,
            onTap: () => setState(() => _tool = WhiteboardTool.pen),
            tooltip: 'Stylo',
          ),
          _ToolBtn(
            icon: Icons.brush,
            selected: _tool == WhiteboardTool.highlighter,
            onTap: () => setState(() {
              _tool = WhiteboardTool.highlighter;
              _strokeWidth = 8.0;
            }),
            tooltip: 'Surligneur',
          ),
          _ToolBtn(
            icon: Icons.auto_fix_high,
            selected: _tool == WhiteboardTool.eraser,
            onTap: () => setState(() => _tool = WhiteboardTool.eraser),
            tooltip: 'Gomme',
          ),

          const SizedBox(width: 8),
          Container(width: 1, height: 24, color: Colors.white24),
          const SizedBox(width: 8),

          // ── Couleurs ────────────────────────────────────────────
          ...kWhiteboardColors.take(6).map(
            (wc) => GestureDetector(
              onTap: () => setState(() {
                _color = wc.color;
                if (_tool == WhiteboardTool.eraser) {
                  _tool = WhiteboardTool.pen;
                }
              }),
              child: Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: wc.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _color == wc.color
                        ? const Color(0xFF60A5FA)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),
          Container(width: 1, height: 24, color: Colors.white24),
          const SizedBox(width: 8),

          // ── Épaisseurs ──────────────────────────────────────────
          ...kStrokeWidths.map(
            (w) => GestureDetector(
              onTap: () => setState(() => _strokeWidth = w),
              child: Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _strokeWidth == w
                        ? const Color(0xFF60A5FA)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Container(
                  width: w * 2,
                  height: w * 2,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),

          const Spacer(),

          // ── Actions ─────────────────────────────────────────────
          _ToolBtn(
            icon: Icons.undo,
            selected: false,
            onTap: _undo,
            tooltip: 'Annuler',
          ),
          _ToolBtn(
            icon: Icons.delete_outline,
            selected: false,
            onTap: () {
              clearLocal();
              widget.onClearAll?.call();
            },
            tooltip: 'Tout effacer',
          ),
        ],
      ),
    );
  }
}

// ─── Tool button ──────────────────────────────────────────────────────────────

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String tooltip;

  const _ToolBtn({
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF3B82F6) : Colors.white10,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      ),
    );
  }
}

// ─── Painter ──────────────────────────────────────────────────────────────────

class _WhiteboardPainter extends CustomPainter {
  final List<WhiteboardStroke> strokes;
  final List<Point> currentPoints;
  final Color currentColor;
  final double currentStrokeWidth;

  _WhiteboardPainter({
    required this.strokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentStrokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF1E293B),
    );

    // ── Committed strokes ──────────────────────────────────────────
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke.points, stroke.color, stroke.strokeWidth,
          stroke.isEraser);
    }

    // ── Current stroke in progress ─────────────────────────────────
    if (currentPoints.isNotEmpty) {
      _drawStroke(canvas, currentPoints, currentColor, currentStrokeWidth,
          false);
    }
  }

  void _drawStroke(
    Canvas canvas,
    List<Point> points,
    Color color,
    double width,
    bool isEraser,
  ) {
    if (points.isEmpty) return;

    final pfPoints = points
        .map((p) => pf.PointVector(p.x, p.y, p.pressure))
        .toList();

    final outlinePoints = pf.getStroke(
      pfPoints,
      options: pf.StrokeOptions(
        size: width,
        thinning: isEraser ? 0 : 0.5,
        smoothing: 0.5,
        streamline: 0.5,
        simulatePressure: true,
      ),
    );

    if (outlinePoints.isEmpty) return;

    final path = ui.Path();
    if (outlinePoints.length == 1) {
      final p = outlinePoints.first;
      path.addOval(Rect.fromCircle(center: p, radius: width / 2));
    } else {
      path.moveTo(outlinePoints.first.dx, outlinePoints.first.dy);
      for (int i = 1; i < outlinePoints.length - 1; i++) {
        final p0 = outlinePoints[i];
        final p1 = outlinePoints[i + 1];
        path.quadraticBezierTo(
          p0.dx,
          p0.dy,
          (p0.dx + p1.dx) / 2,
          (p0.dy + p1.dy) / 2,
        );
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WhiteboardPainter old) => true;
}
