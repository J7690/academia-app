import 'package:flutter/material.dart';

/// Widget visuel d'un domino avec points réalistes (0-6 par face).
class DominoWidget extends StatelessWidget {
  final int topValue;
  final int bottomValue;
  final bool isHidden;
  final double size;
  final bool isSelected;

  const DominoWidget({
    super.key,
    required this.topValue,
    required this.bottomValue,
    this.isHidden = false,
    this.size = 60,
    this.isSelected = false,
  });

  /// Parse "[3|5]" format from generator
  factory DominoWidget.fromString(String s, {double size = 60, bool isSelected = false}) {
    final clean = s.replaceAll('[', '').replaceAll(']', '');
    if (clean.contains('?')) {
      return DominoWidget(topValue: 0, bottomValue: 0, isHidden: true, size: size, isSelected: isSelected);
    }
    final parts = clean.split('|');
    return DominoWidget(
      topValue: int.tryParse(parts[0]) ?? 0,
      bottomValue: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
      size: size,
      isSelected: isSelected,
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = size;
    final h = size * 1.8;

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? const Color(0xFF2E7D32) : const Color(0xFF424242),
          width: isSelected ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected ? const Color(0xFF2E7D32).withAlpha(60) : Colors.black.withAlpha(30),
            blurRadius: isSelected ? 8 : 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(child: _buildFace(isHidden ? -1 : topValue, w)),
          Container(height: 1.5, color: const Color(0xFF424242)),
          Expanded(child: _buildFace(isHidden ? -1 : bottomValue, w)),
        ],
      ),
    );
  }

  Widget _buildFace(int value, double faceWidth) {
    if (value < 0) {
      return const Center(
        child: Text('?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1565C0))),
      );
    }
    return CustomPaint(
      painter: _DominoFacePainter(value: value),
      size: Size(faceWidth, faceWidth * 0.8),
    );
  }
}

class _DominoFacePainter extends CustomPainter {
  final int value;
  _DominoFacePainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = const Color(0xFF212121);
    final r = size.width * 0.1;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final dx = size.width * 0.28;
    final dy = size.height * 0.3;

    // Positions des points selon la valeur (0-6)
    final positions = <Offset>[];
    switch (value) {
      case 0:
        break;
      case 1:
        positions.add(Offset(cx, cy));
        break;
      case 2:
        positions.add(Offset(cx - dx, cy - dy));
        positions.add(Offset(cx + dx, cy + dy));
        break;
      case 3:
        positions.add(Offset(cx - dx, cy - dy));
        positions.add(Offset(cx, cy));
        positions.add(Offset(cx + dx, cy + dy));
        break;
      case 4:
        positions.add(Offset(cx - dx, cy - dy));
        positions.add(Offset(cx + dx, cy - dy));
        positions.add(Offset(cx - dx, cy + dy));
        positions.add(Offset(cx + dx, cy + dy));
        break;
      case 5:
        positions.add(Offset(cx - dx, cy - dy));
        positions.add(Offset(cx + dx, cy - dy));
        positions.add(Offset(cx, cy));
        positions.add(Offset(cx - dx, cy + dy));
        positions.add(Offset(cx + dx, cy + dy));
        break;
      case 6:
        positions.add(Offset(cx - dx, cy - dy));
        positions.add(Offset(cx + dx, cy - dy));
        positions.add(Offset(cx - dx, cy));
        positions.add(Offset(cx + dx, cy));
        positions.add(Offset(cx - dx, cy + dy));
        positions.add(Offset(cx + dx, cy + dy));
        break;
    }

    for (final p in positions) {
      canvas.drawCircle(p, r, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DominoFacePainter old) => old.value != value;
}
