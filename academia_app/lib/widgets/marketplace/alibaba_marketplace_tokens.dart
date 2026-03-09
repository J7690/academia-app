import 'package:flutter/material.dart';

class AlibabaMarketplaceTokens {
  static const Color primaryOrange = Color(0xFFFF6A00);
  static const Color primaryOrangePressed = Color(0xFFE65F00);

  static const Color bg = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFEEEFF2);

  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textMeta = Color(0xFF999999);

  static const Color price = Color(0xFFFF3B30);

  static const double radiusCard = 12;
  static const double radiusChip = 999;
  static const double radiusSearch = 12;

  static const double screenH = 12;
  static const double sectionGap = 12;
  static const double gridGap = 10;

  static TextStyle sectionTitleStyle(BuildContext context) {
    return const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      color: textPrimary,
    );
  }

  static const TextStyle productTitle = TextStyle(
    fontSize: 13,
    height: 1.15,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle productMeta = TextStyle(
    fontSize: 11,
    height: 1.15,
    fontWeight: FontWeight.w500,
    color: textMeta,
  );

  static const TextStyle priceStyle = TextStyle(
    fontSize: 16,
    height: 1.1,
    fontWeight: FontWeight.w900,
    color: price,
  );
}
