import 'package:flutter/material.dart';

/// Widget interactif permettant à l'utilisateur de sélectionner une zone rectangulaire
/// sur l'écran pour un partage ciblé.
class ZoneSelector extends StatefulWidget {
  /// Widget enfant sur lequel la sélection s'effectue
  final Widget child;
  
  /// Callback appelé quand la sélection change
  final Function(Rect) onSelectionChanged;
  
  /// Callback appelé pour confirmer la sélection
  final VoidCallback onConfirm;
  
  /// Callback appelé pour annuler la sélection
  final VoidCallback onCancel;
  
  /// Couleur de l'overlay (zone non sélectionnée)
  final Color overlayColor;
  
  /// Couleur de la bordure de sélection
  final Color selectionBorderColor;

  const ZoneSelector({
    super.key,
    required this.child,
    required this.onSelectionChanged,
    required this.onConfirm,
    required this.onCancel,
    this.overlayColor = const Color(0x80000000),
    this.selectionBorderColor = const Color(0xFF3B82F6),
  });

  @override
  State<ZoneSelector> createState() => _ZoneSelectorState();
}

class _ZoneSelectorState extends State<ZoneSelector> {
  Rect _selectionRect = const Rect.fromLTWH(50, 100, 200, 150);
  bool _isDragging = false;
  bool _isResizing = false;
  Offset? _dragStartOffset;
  Rect? _initialRect;
  _ResizeHandle? _activeHandle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onSelectionChanged(_selectionRect);
    });
  }

  void _onPanStart(DragStartDetails details) {
    final localPosition = details.localPosition;
    final handle = _getResizeHandle(localPosition);
    
    if (handle != null) {
      _isResizing = true;
      _activeHandle = handle;
      _initialRect = _selectionRect;
    } else if (_selectionRect.contains(localPosition)) {
      _isDragging = true;
      _dragStartOffset = localPosition - _selectionRect.topLeft;
      _initialRect = _selectionRect;
    } else {
      // Nouvelle sélection
      _selectionRect = Rect.fromPoints(localPosition, localPosition);
      _isDragging = true;
      _dragStartOffset = Offset.zero;
      _initialRect = _selectionRect;
    }
    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails details, Size screenSize) {
    if (_isResizing && _activeHandle != null && _initialRect != null) {
      _selectionRect = _resizeRectWithHandle(
        _initialRect!,
        _activeHandle!,
        details.localPosition,
        screenSize,
      );
    } else if (_isDragging && _dragStartOffset != null) {
      final newTopLeft = details.localPosition - _dragStartOffset!;
      _selectionRect = Rect.fromLTWH(
        newTopLeft.dx.clamp(0, screenSize.width - _selectionRect.width),
        newTopLeft.dy.clamp(0, screenSize.height - _selectionRect.height),
        _selectionRect.width,
        _selectionRect.height,
      );
    }
    
    widget.onSelectionChanged(_selectionRect);
    setState(() {});
  }

  void _onPanEnd(DragEndDetails details) {
    _isDragging = false;
    _isResizing = false;
    _activeHandle = null;
    _dragStartOffset = null;
    _initialRect = null;
    setState(() {});
  }

  _ResizeHandle? _getResizeHandle(Offset position) {
    const handleSize = 20.0;
    final handles = [
      (_ResizeHandle.topLeft, _selectionRect.topLeft),
      (_ResizeHandle.topRight, _selectionRect.topRight),
      (_ResizeHandle.bottomLeft, _selectionRect.bottomLeft),
      (_ResizeHandle.bottomRight, _selectionRect.bottomRight),
      (_ResizeHandle.topCenter, Offset(_selectionRect.center.dx, _selectionRect.top)),
      (_ResizeHandle.bottomCenter, Offset(_selectionRect.center.dx, _selectionRect.bottom)),
      (_ResizeHandle.leftCenter, Offset(_selectionRect.left, _selectionRect.center.dy)),
      (_ResizeHandle.rightCenter, Offset(_selectionRect.right, _selectionRect.center.dy)),
    ];

    for (final (handle, center) in handles) {
      final handleRect = Rect.fromCenter(
        center: center,
        width: handleSize,
        height: handleSize,
      );
      if (handleRect.contains(position)) {
        return handle;
      }
    }
    return null;
  }


  Rect _resizeRectWithHandle(Rect initialRect, _ResizeHandle handle, Offset position, Size screenSize) {
    double left = initialRect.left;
    double top = initialRect.top;
    double right = initialRect.right;
    double bottom = initialRect.bottom;

    switch (handle) {
      case _ResizeHandle.topLeft:
        left = position.dx.clamp(0, right - 50);
        top = position.dy.clamp(0, bottom - 50);
        break;
      case _ResizeHandle.topRight:
        right = position.dx.clamp(left + 50, screenSize.width);
        top = position.dy.clamp(0, bottom - 50);
        break;
      case _ResizeHandle.bottomLeft:
        left = position.dx.clamp(0, right - 50);
        bottom = position.dy.clamp(top + 50, screenSize.height);
        break;
      case _ResizeHandle.bottomRight:
        right = position.dx.clamp(left + 50, screenSize.width);
        bottom = position.dy.clamp(top + 50, screenSize.height);
        break;
      case _ResizeHandle.topCenter:
        top = position.dy.clamp(0, bottom - 50);
        break;
      case _ResizeHandle.bottomCenter:
        bottom = position.dy.clamp(top + 50, screenSize.height);
        break;
      case _ResizeHandle.leftCenter:
        left = position.dx.clamp(0, right - 50);
        break;
      case _ResizeHandle.rightCenter:
        right = position.dx.clamp(left + 50, screenSize.width);
        break;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Widget enfant
          widget.child,
          
          // Overlay de sélection
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenSize = Size(constraints.maxWidth, constraints.maxHeight);
                
                return GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: (details) => _onPanUpdate(details, screenSize),
                  onPanEnd: _onPanEnd,
                  child: CustomPaint(
                    painter: _ZonePainter(
                      selectionRect: _selectionRect,
                      overlayColor: widget.overlayColor,
                      selectionBorderColor: widget.selectionBorderColor,
                    ),
                    size: screenSize,
                  ),
                );
              },
            ),
          ),
          
          // Boutons d'action
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close),
                  label: const Text('Annuler'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: widget.onConfirm,
                  icon: const Icon(Icons.share),
                  label: const Text('Partager la sélection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.selectionBorderColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          // Instructions
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '🎯 Sélectionnez la zone à partager\n'
                '• Touchez et glissez pour déplacer\n'
                '• Utilisez les poignées pour redimensionner',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ResizeHandle {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  topCenter,
  bottomCenter,
  leftCenter,
  rightCenter,
}

class _ZonePainter extends CustomPainter {
  final Rect selectionRect;
  final Color overlayColor;
  final Color selectionBorderColor;

  _ZonePainter({
    required this.selectionRect,
    required this.overlayColor,
    required this.selectionBorderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    
    // Dessiner l'overlay
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(selectionRect)
      ..fillType = PathFillType.evenOdd;
    
    paint.color = overlayColor;
    canvas.drawPath(overlayPath, paint);
    
    // Dessiner la bordure de sélection
    paint
      ..color = selectionBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(selectionRect, paint);
    
    // Dessiner les poignées de redimensionnement
    final handlePaint = Paint()
      ..color = selectionBorderColor
      ..style = PaintingStyle.fill;
    
    final handles = [
      selectionRect.topLeft,
      selectionRect.topRight,
      selectionRect.bottomLeft,
      selectionRect.bottomRight,
      Offset(selectionRect.center.dx, selectionRect.top),
      Offset(selectionRect.center.dx, selectionRect.bottom),
      Offset(selectionRect.left, selectionRect.center.dy),
      Offset(selectionRect.right, selectionRect.center.dy),
    ];
    
    for (final handle in handles) {
      canvas.drawCircle(handle, 6, handlePaint);
      canvas.drawCircle(handle, 6, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1);
    }
    
    // Dessiner les dimensions
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${selectionRect.width.round()} × ${selectionRect.height.round()}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    
    final textOffset = Offset(
      selectionRect.center.dx - textPainter.width / 2,
      selectionRect.center.dy - textPainter.height / 2,
    );
    
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(_ZonePainter oldDelegate) {
    return oldDelegate.selectionRect != selectionRect ||
        oldDelegate.overlayColor != overlayColor ||
        oldDelegate.selectionBorderColor != selectionBorderColor;
  }
}
