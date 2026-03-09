import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import '../../video/academia_playback_engine.dart';

// ---------------------------------------------------------------------------
// Data models for scientific overlays
// ---------------------------------------------------------------------------

/// A freehand drawing stroke (whiteboard).
/// Points are stored in **relative** coordinates (0..1, 0..1) so they render
/// correctly at any canvas/video size.
class SciStroke {
  final List<PointVector> points;
  final Color color;
  final double size;
  final int? startMs;
  final int? endMs;

  SciStroke({
    required this.points,
    required this.color,
    required this.size,
    this.startMs,
    this.endMs,
  });

  Map<String, dynamic> toJson() => {
        'points': points
            .map((p) => {'x': p.x, 'y': p.y, 'pressure': p.pressure})
            .toList(),
        'color': color.value,
        'size': size,
        if (startMs != null) 'start_ms': startMs,
        if (endMs != null) 'end_ms': endMs,
      };
}

/// A positioned text/equation annotation zone.
class SciAnnotation {
  String id;
  String content;
  bool isLatex;
  Offset position; // relative (0..1, 0..1)
  double fontSize;
  double scale; // pinch-to-resize multiplier
  Color color;
  Color bgColor;
  int? startMs;
  int? endMs;

  SciAnnotation({
    required this.id,
    required this.content,
    this.isLatex = false,
    this.position = const Offset(0.1, 0.1),
    this.fontSize = 18,
    this.scale = 1.0,
    this.color = Colors.white,
    this.bgColor = const Color(0x88000000),
    this.startMs,
    this.endMs,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'isLatex': isLatex,
        'x': position.dx,
        'y': position.dy,
        'fontSize': fontSize,
        'scale': scale,
        'color': color.value,
        'bgColor': bgColor.value,
        if (startMs != null) 'start_ms': startMs,
        if (endMs != null) 'end_ms': endMs,
      };
}

// ---------------------------------------------------------------------------
// Scientific Studio Screen
// ---------------------------------------------------------------------------

/// Overlay screen for the scientific studio.
///
/// Features:
/// - Freehand drawing (whiteboard) with color/size picker
/// - LaTeX equation input and rendering
/// - Draggable annotation zones (text or equation)
/// - Export overlay data as JSON (to be burned into video by backend)
///
/// Returns a Map<String, dynamic> with 'strokes' and 'annotations' via pop.
class ChallengeScientificStudioScreen extends StatefulWidget {
  /// Optional existing overlay data to resume editing.
  final Map<String, dynamic>? existingOverlays;

  /// URL of the video to show as background.
  final String? videoUrl;

  const ChallengeScientificStudioScreen({
    super.key,
    this.existingOverlays,
    this.videoUrl,
  });

  @override
  State<ChallengeScientificStudioScreen> createState() =>
      _ChallengeScientificStudioScreenState();
}

class _ChallengeScientificStudioScreenState
    extends State<ChallengeScientificStudioScreen> {
  // Drawing
  final List<SciStroke> _strokes = [];
  final List<SciStroke> _redoStack = [];
  List<PointVector> _currentPoints = [];
  Color _penColor = Colors.white;
  double _penSize = 4.0;
  bool _isEraser = false;

  // Annotations
  final List<SciAnnotation> _annotations = [];

  // Mode
  String _mode = 'draw'; // draw, text, equation, select

  // Pinch-to-resize tracking
  double _baseScale = 1.0;

  // Pen colors
  static const List<Color> _penColors = [
    Colors.white,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.orange,
    Colors.purple,
    Colors.cyan,
  ];

  // Pen sizes
  static const List<double> _penSizes = [2, 4, 6, 10, 16];

  @override
  void initState() {
    super.initState();
    _loadExistingOverlays();
  }

  void _loadExistingOverlays() {
    final data = widget.existingOverlays;
    if (data == null) return;

    // Load strokes
    final rawStrokes = data['strokes'];
    if (rawStrokes is List) {
      for (final s in rawStrokes) {
        if (s is! Map) continue;
        final sm = Map<String, dynamic>.from(s);
        final pts = sm['points'];
        if (pts is! List || pts.isEmpty) continue;
        final points = <PointVector>[];
        for (final pt in pts) {
          if (pt is! Map) continue;
          final px = (pt['x'] as num?)?.toDouble();
          final py = (pt['y'] as num?)?.toDouble();
          final pr = (pt['pressure'] as num?)?.toDouble() ?? 0.5;
          if (px == null || py == null) continue;
          points.add(PointVector(px, py, pr));
        }
        if (points.isEmpty) continue;
        _strokes.add(SciStroke(
          points: points,
          color: Color(sm['color'] as int? ?? 0xFFFFFFFF),
          size: (sm['size'] as num?)?.toDouble() ?? 4.0,
          startMs: sm['start_ms'] as int?,
          endMs: sm['end_ms'] as int?,
        ));
      }
    }

    // Load annotations
    final annots = data['annotations'];
    if (annots is List) {
      for (final a in annots) {
        if (a is Map<String, dynamic>) {
          _annotations.add(SciAnnotation(
            id: a['id']?.toString() ?? _genId(),
            content: a['content']?.toString() ?? '',
            isLatex: a['isLatex'] == true,
            position: Offset(
              (a['x'] as num?)?.toDouble() ?? 0.1,
              (a['y'] as num?)?.toDouble() ?? 0.1,
            ),
            fontSize: (a['fontSize'] as num?)?.toDouble() ?? 18,
            scale: (a['scale'] as num?)?.toDouble() ?? 1.0,
            color: Color(a['color'] as int? ?? 0xFFFFFFFF),
            bgColor: Color(a['bgColor'] as int? ?? 0x88000000),
            startMs: a['start_ms'] as int?,
            endMs: a['end_ms'] as int?,
          ));
        }
      }
    }
  }

  String _genId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  // --- Drawing ---

  void _onPanStart(DragStartDetails details) {
    if (_mode != 'draw') return;
    final pos = details.localPosition;
    setState(() {
      _currentPoints = [PointVector(pos.dx, pos.dy)];
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_mode != 'draw') return;
    final pos = details.localPosition;
    setState(() {
      _currentPoints = List.from(_currentPoints)
        ..add(PointVector(pos.dx, pos.dy));
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_mode != 'draw') return;
    if (_currentPoints.isEmpty) return;

    if (_isEraser) {
      _eraseNearStrokes();
    } else {
      setState(() {
        _strokes.add(SciStroke(
          points: List.from(_currentPoints),
          color: _penColor,
          size: _penSize,
        ));
        _redoStack.clear();
      });
    }
    setState(() => _currentPoints = []);
  }

  void _eraseNearStrokes() {
    if (_currentPoints.isEmpty) return;
    final eraserPoints = _currentPoints;
    final threshold = _penSize * 3;

    _strokes.removeWhere((stroke) {
      for (final sp in stroke.points) {
        for (final ep in eraserPoints) {
          final dx = sp.x - ep.x;
          final dy = sp.y - ep.y;
          if (dx * dx + dy * dy < threshold * threshold) {
            return true;
          }
        }
      }
      return false;
    });
    setState(() {});
  }

  void _undoStroke() {
    if (_strokes.isEmpty) return;
    setState(() {
      _redoStack.add(_strokes.removeLast());
    });
  }

  void _redoStroke() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _strokes.add(_redoStack.removeLast());
    });
  }

  void _clearStrokes() {
    setState(() {
      _redoStack.addAll(_strokes.reversed);
      _strokes.clear();
    });
  }

  // --- Annotations ---

  void _addTextAnnotation() {
    final id = _genId();
    setState(() {
      _annotations.add(SciAnnotation(
        id: id,
        content: 'Texte ici',
        isLatex: false,
        position: const Offset(0.1, 0.3),
      ));
      _mode = 'select';
    });
    _editAnnotation(id);
  }

  void _addEquationAnnotation() {
    final id = _genId();
    setState(() {
      _annotations.add(SciAnnotation(
        id: id,
        content: r'E = mc^2',
        isLatex: true,
        position: const Offset(0.1, 0.5),
      ));
      _mode = 'select';
    });
    _editAnnotation(id);
  }

  void _editAnnotation(String id) {
    final annot = _annotations.firstWhere((a) => a.id == id);
    final ctrl = TextEditingController(text: annot.content);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        bool isLatex = annot.isLatex;
        Color selectedColor = annot.color;
        // Timeline: null means "always visible"
        double? startSec = annot.startMs != null ? annot.startMs! / 1000.0 : null;
        double? endSec = annot.endMs != null ? annot.endMs! / 1000.0 : null;
        bool hasTimeline = startSec != null || endSec != null;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Text(
                          isLatex ? 'Équation LaTeX' : 'Texte',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setSheetState(() => isLatex = !isLatex);
                          },
                          child: Text(
                            isLatex ? 'Passer en texte' : 'Passer en LaTeX',
                            style: const TextStyle(
                              color: Color(0xFF1EA75C),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Content input
                    TextField(
                      controller: ctrl,
                      autofocus: true,
                      maxLines: 3,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        hintText: isLatex
                            ? r'Ex: \frac{d}{dx} f(x) = \lim_{h \to 0}...'
                            : 'Saisir le texte...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    // LaTeX preview
                    if (isLatex && ctrl.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Math.tex(
                            ctrl.text,
                            textStyle: TextStyle(
                              color: selectedColor,
                              fontSize: 20,
                            ),
                            onErrorFallback: (err) => Text(
                              'Erreur LaTeX',
                              style: TextStyle(
                                color: Colors.red[300],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Color picker
                    const Text('Couleur',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: _penColors.map((c) {
                        final sel = c.value == selectedColor.value;
                        return GestureDetector(
                          onTap: () => setSheetState(() => selectedColor = c),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c,
                              border: Border.all(
                                color: sel
                                    ? const Color(0xFF1EA75C)
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Timeline toggle
                    Row(
                      children: [
                        const Text('Apparition temporelle',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const Spacer(),
                        Switch(
                          value: hasTimeline,
                          activeColor: const Color(0xFF1EA75C),
                          onChanged: (v) {
                            setSheetState(() {
                              hasTimeline = v;
                              if (v) {
                                startSec ??= 0;
                                endSec ??= 10;
                              } else {
                                startSec = null;
                                endSec = null;
                              }
                            });
                          },
                        ),
                      ],
                    ),

                    // Timeline sliders
                    if (hasTimeline) ...[
                      Row(
                        children: [
                          Text(
                            'Début: ${startSec?.toStringAsFixed(1) ?? "0"}s',
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                          Expanded(
                            child: Slider(
                              value: startSec ?? 0,
                              min: 0,
                              max: 120,
                              activeColor: const Color(0xFF1EA75C),
                              onChanged: (v) => setSheetState(() => startSec = v),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            'Fin: ${endSec?.toStringAsFixed(1) ?? "10"}s',
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                          Expanded(
                            child: Slider(
                              value: endSec ?? 10,
                              min: 0,
                              max: 120,
                              activeColor: const Color(0xFF00D2FF),
                              onChanged: (v) => setSheetState(() => endSec = v),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _annotations.removeWhere((a) => a.id == id);
                              });
                              Navigator.of(ctx).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                            ),
                            child: const Text('Supprimer'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                annot.content = ctrl.text;
                                annot.isLatex = isLatex;
                                annot.color = selectedColor;
                                annot.startMs = hasTimeline && startSec != null
                                    ? (startSec! * 1000).round()
                                    : null;
                                annot.endMs = hasTimeline && endSec != null
                                    ? (endSec! * 1000).round()
                                    : null;
                              });
                              Navigator.of(ctx).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1EA75C),
                            ),
                            child: const Text('Valider'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _deleteAnnotation(String id) {
    setState(() => _annotations.removeWhere((a) => a.id == id));
  }

  // --- Export ---

  Map<String, dynamic> _exportOverlays() {
    return {
      'strokes': _strokes.map((s) => s.toJson()).toList(),
      'annotations': _annotations.map((a) => a.toJson()).toList(),
    };
  }

  void _confirm() {
    Navigator.of(context).pop<Map<String, dynamic>>(_exportOverlays());
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildCanvas()),
            _buildToolbar(),
            if (_mode == 'draw') _buildDrawOptions(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop<Map<String, dynamic>?>(null),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
          const Spacer(),
          if (_strokes.isNotEmpty || _redoStack.isNotEmpty) ...[
            IconButton(
              onPressed: _strokes.isNotEmpty ? _undoStroke : null,
              icon: Icon(Icons.undo,
                  color: _strokes.isNotEmpty ? Colors.white : Colors.white24),
              tooltip: 'Annuler',
            ),
            IconButton(
              onPressed: _redoStack.isNotEmpty ? _redoStroke : null,
              icon: Icon(Icons.redo,
                  color: _redoStack.isNotEmpty ? Colors.white : Colors.white24),
              tooltip: 'Rétablir',
            ),
            IconButton(
              onPressed: _strokes.isNotEmpty ? _clearStrokes : null,
              icon: const Icon(Icons.delete_sweep, color: Colors.white70),
              tooltip: 'Effacer tout',
            ),
          ],
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _confirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1EA75C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
            child: const Text('Valider',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = constraints.biggest;

        return GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: Stack(
            children: [
              // Video background (or dark placeholder)
              Positioned.fill(
                child: widget.videoUrl != null && widget.videoUrl!.isNotEmpty
                    ? AcademiaPlaybackEngine.view(
                        url: widget.videoUrl!,
                        autoplay: true,
                        looping: true,
                        muted: true,
                        showControls: false,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: Colors.black87,
                        alignment: Alignment.center,
                        child: const Text(
                          'Zone vidéo',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white24, fontSize: 14),
                        ),
                      ),
              ),

              // Semi-transparent overlay for better drawing visibility
              Positioned.fill(
                child: Container(color: Colors.black.withValues(alpha: 0.15)),
              ),

              // Drawing layer
              Positioned.fill(
                child: CustomPaint(
                  painter: _StrokePainter(
                    strokes: _strokes,
                    currentPoints: _currentPoints,
                    currentColor: _isEraser ? Colors.grey : _penColor,
                    currentSize: _penSize,
                    isEraser: _isEraser,
                  ),
                ),
              ),

              // Annotation zones (draggable + pinch-to-resize)
              for (final annot in _annotations)
                Positioned(
                  left: annot.position.dx * canvasSize.width,
                  top: annot.position.dy * canvasSize.height,
                  child: GestureDetector(
                    onScaleStart: (_) {
                      _baseScale = annot.scale;
                    },
                    onScaleUpdate: (details) {
                      setState(() {
                        // Drag
                        annot.position = Offset(
                          (annot.position.dx +
                                  details.focalPointDelta.dx / canvasSize.width)
                              .clamp(0.0, 0.9),
                          (annot.position.dy +
                                  details.focalPointDelta.dy / canvasSize.height)
                              .clamp(0.0, 0.9),
                        );
                        // Pinch-to-resize
                        if (details.pointerCount >= 2) {
                          annot.scale = (_baseScale * details.scale).clamp(0.4, 4.0);
                        }
                      });
                    },
                    onTap: () => _editAnnotation(annot.id),
                    onLongPress: () => _deleteAnnotation(annot.id),
                    child: _buildAnnotationWidget(annot),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnnotationWidget(SciAnnotation annot) {
    return Transform.scale(
      scale: annot.scale,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: annot.bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24, width: 0.5),
        ),
        child: annot.isLatex
            ? Math.tex(
                annot.content,
                textStyle: TextStyle(
                  color: annot.color,
                  fontSize: annot.fontSize,
                ),
                onErrorFallback: (err) => Text(
                  annot.content,
                  style: TextStyle(
                    color: annot.color,
                    fontSize: annot.fontSize,
                    fontFamily: 'monospace',
                  ),
                ),
              )
            : Text(
                annot.content,
                style: TextStyle(
                  color: annot.color,
                  fontSize: annot.fontSize,
                ),
              ),
      ),
    );
  }

  Widget _buildToolbar() {
    final tools = <MapEntry<String, _ToolDef>>[
      MapEntry('draw', _ToolDef(Icons.brush, 'Dessiner')),
      MapEntry('text', _ToolDef(Icons.text_fields, 'Texte')),
      MapEntry('equation', _ToolDef(Icons.functions, 'Équation')),
      MapEntry('select', _ToolDef(Icons.open_with, 'Déplacer')),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: tools.map((t) {
          final selected = t.key == _mode;
          return GestureDetector(
            onTap: () {
              if (t.key == 'text') {
                _addTextAnnotation();
              } else if (t.key == 'equation') {
                _addEquationAnnotation();
              } else {
                setState(() => _mode = t.key);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  t.value.icon,
                  color: selected ? const Color(0xFF1EA75C) : Colors.white54,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  t.value.label,
                  style: TextStyle(
                    color:
                        selected ? const Color(0xFF1EA75C) : Colors.white54,
                    fontSize: 11,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDrawOptions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF111111),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Eraser toggle + pen sizes
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _isEraser = !_isEraser),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isEraser ? Colors.white24 : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_fix_high,
                        color: _isEraser ? Colors.white : Colors.white54,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Gomme',
                        style: TextStyle(
                          color: _isEraser ? Colors.white : Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ...List.generate(_penSizes.length, (i) {
                final s = _penSizes[i];
                final selected = s == _penSize && !_isEraser;
                return GestureDetector(
                  onTap: () => setState(() {
                    _penSize = s;
                    _isEraser = false;
                  }),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            selected ? const Color(0xFF1EA75C) : Colors.white24,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Container(
                      width: s.clamp(4, 14),
                      height: s.clamp(4, 14),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? _penColor : Colors.white54,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          // Color picker
          Row(
            children: _penColors.map((c) {
              final selected = c == _penColor && !_isEraser;
              return GestureDetector(
                onTap: () => setState(() {
                  _penColor = c;
                  _isEraser = false;
                }),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c,
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF1EA75C)
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _ToolDef {
  final IconData icon;
  final String label;
  const _ToolDef(this.icon, this.label);
}

class _StrokePainter extends CustomPainter {
  final List<SciStroke> strokes;
  final List<PointVector> currentPoints;
  final Color currentColor;
  final double currentSize;
  final bool isEraser;

  _StrokePainter({
    required this.strokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentSize,
    required this.isEraser,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw completed strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke.points, stroke.color, stroke.size);
    }

    // Draw current stroke
    if (currentPoints.isNotEmpty && !isEraser) {
      _drawStroke(canvas, currentPoints, currentColor, currentSize);
    }

    // Draw eraser indicator
    if (isEraser && currentPoints.isNotEmpty) {
      final last = currentPoints.last;
      final paint = Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(Offset(last.x, last.y), currentSize * 3, paint);
    }
  }

  void _drawStroke(
      Canvas canvas, List<PointVector> points, Color color, double size) {
    if (points.isEmpty) return;

    final outlinePoints = getStroke(
      points,
      options: StrokeOptions(
        size: size,
        thinning: 0.5,
        smoothing: 0.5,
        streamline: 0.5,
        simulatePressure: true,
      ),
    );

    if (outlinePoints.isEmpty) return;

    final path = Path();
    if (outlinePoints.length < 2) {
      // Single dot
      final p = outlinePoints.first;
      canvas.drawCircle(
        p,
        size / 2,
        Paint()..color = color,
      );
      return;
    }

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

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => true;
}
