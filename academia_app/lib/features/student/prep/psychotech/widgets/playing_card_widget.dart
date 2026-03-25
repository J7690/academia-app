import 'package:flutter/material.dart';

/// Widget visuel d'une carte à jouer (As-10 + couleurs ♠♥♦♣).
class PlayingCardWidget extends StatelessWidget {
  final int value; // 1-13 (1=As, 11=V, 12=D, 13=R)
  final String suit; // ♠, ♥, ♦, ♣
  final bool isHidden;
  final double width;
  final bool isSelected;

  const PlayingCardWidget({
    super.key,
    required this.value,
    required this.suit,
    this.isHidden = false,
    this.width = 52,
    this.isSelected = false,
  });

  factory PlayingCardWidget.fromString(String s, {double width = 52, bool isSelected = false}) {
    if (s.contains('?')) {
      return PlayingCardWidget(value: 0, suit: '', isHidden: true, width: width, isSelected: isSelected);
    }
    final suitChar = s.substring(s.length - 1);
    final valStr = s.substring(0, s.length - 1);
    int val;
    switch (valStr) {
      case 'A': val = 1; break;
      case 'V': val = 11; break;
      case 'D': val = 12; break;
      case 'R': val = 13; break;
      default: val = int.tryParse(valStr) ?? 1;
    }
    return PlayingCardWidget(value: val, suit: suitChar, width: width, isSelected: isSelected);
  }

  String get _valueLabel {
    switch (value) {
      case 1: return 'A';
      case 11: return 'V';
      case 12: return 'D';
      case 13: return 'R';
      default: return '$value';
    }
  }

  Color get _suitColor {
    return (suit == '♥' || suit == '♦') ? const Color(0xFFD32F2F) : const Color(0xFF212121);
  }

  @override
  Widget build(BuildContext context) {
    final h = width * 1.5;

    if (isHidden) {
      return Container(
        width: width,
        height: h,
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: const Center(
          child: Text('?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      );
    }

    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected ? const Color(0xFF2E7D32) : const Color(0xFF9E9E9E),
          width: isSelected ? 2.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected ? const Color(0xFF2E7D32).withAlpha(60) : Colors.black.withAlpha(30),
            blurRadius: isSelected ? 8 : 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Top-left value + suit
          Positioned(
            top: 3,
            left: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(_valueLabel, style: TextStyle(fontSize: width * 0.25, fontWeight: FontWeight.w800, color: _suitColor, height: 1)),
                Text(suit, style: TextStyle(fontSize: width * 0.2, color: _suitColor, height: 1)),
              ],
            ),
          ),
          // Center suit (big)
          Center(
            child: Text(suit, style: TextStyle(fontSize: width * 0.5, color: _suitColor)),
          ),
          // Bottom-right value + suit (rotated)
          Positioned(
            bottom: 3,
            right: 4,
            child: Transform.rotate(
              angle: 3.14159,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(_valueLabel, style: TextStyle(fontSize: width * 0.25, fontWeight: FontWeight.w800, color: _suitColor, height: 1)),
                  Text(suit, style: TextStyle(fontSize: width * 0.2, color: _suitColor, height: 1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
