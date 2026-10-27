import 'package:flutter/material.dart';

class AlibabaMarketplaceTokens {
  static const Color brand = Color(0xFF4F46E5);
  static const Color brandLight = Color(0xFF6366F1);
  static const Color brandDark = Color(0xFF3730A3);
  static const Color brandInk = Color(0xFF1E1B4B);
  static const Color brandSoft = Color(0xFFEEF2FF);

  static const Color accent = Color(0xFFF97316);
  static const Color accentDark = Color(0xFFEA580C);
  static const Color accentSoft = Color(0xFFFFF7ED);

  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
  static const Color star = Color(0xFFF59E0B);

  static const Color primaryOrange = brand;
  static const Color primaryOrangePressed = brandDark;

  static const Color bg = Color(0xFFF6F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F3F9);
  static const Color divider = Color(0xFFE8EAF2);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMeta = Color(0xFF94A3B8);

  static const Color price = brandInk;

  static const double radiusCard = 18;
  static const double radiusChip = 999;
  static const double radiusSearch = 16;
  static const double radiusSheet = 28;

  static const double screenH = 16;
  static const double sectionGap = 20;
  static const double gridGap = 12;

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 450);
  static const Curve curve = Curves.easeOutCubic;
  static const Curve bounce = Curves.elasticOut;

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF312E81), Color(0xFF4F46E5), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFFB923C), Color(0xFFF97316), Color(0xFFEA580C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient imageScrim = LinearGradient(
    colors: [Color(0x00000000), Color(0x66000000)],
    begin: Alignment.center,
    end: Alignment.bottomCenter,
  );

  static List<BoxShadow> get shadowSoft => [
        BoxShadow(
          color: brandInk.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get shadowLifted => [
        BoxShadow(
          color: brand.withValues(alpha: 0.18),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> shadowColored(Color c) => [
        BoxShadow(
          color: c.withValues(alpha: 0.35),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];

  static const List<IconData> categoryIcons = [
    Icons.menu_book_rounded,
    Icons.laptop_mac_rounded,
    Icons.checkroom_rounded,
    Icons.headphones_rounded,
    Icons.restaurant_rounded,
    Icons.sports_soccer_rounded,
    Icons.home_work_rounded,
    Icons.brush_rounded,
    Icons.spa_rounded,
    Icons.handyman_rounded,
  ];

  static const List<Color> categoryColors = [
    Color(0xFF4F46E5),
    Color(0xFF0EA5E9),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
    Color(0xFFF97316),
    Color(0xFF10B981),
    Color(0xFF14B8A6),
    Color(0xFFE11D48),
    Color(0xFF84CC16),
    Color(0xFFF59E0B),
  ];

  static IconData categoryIcon(String label, int index) {
    final l = label.toLowerCase();
    if (l.contains('livre') || l.contains('cours') || l.contains('fourniture') || l.contains('scol')) return Icons.menu_book_rounded;
    if (l.contains('info') || l.contains('ordi') || l.contains('téléphone') || l.contains('electro') || l.contains('électro') || l.contains('tech')) return Icons.devices_rounded;
    if (l.contains('vêtement') || l.contains('mode') || l.contains('habit')) return Icons.checkroom_rounded;
    if (l.contains('aliment') || l.contains('nourriture') || l.contains('restau') || l.contains('cuisine')) return Icons.restaurant_rounded;
    if (l.contains('sport')) return Icons.sports_soccer_rounded;
    if (l.contains('maison') || l.contains('logement') || l.contains('immo')) return Icons.home_work_rounded;
    if (l.contains('beaut') || l.contains('santé') || l.contains('soin')) return Icons.spa_rounded;
    if (l.contains('service') || l.contains('répar')) return Icons.handyman_rounded;
    if (l.contains('art') || l.contains('déco')) return Icons.brush_rounded;
    return categoryIcons[index % categoryIcons.length];
  }

  static Color categoryColor(int index) => categoryColors[index % categoryColors.length];

  static String formatPrice(num n) {
    final s = n.round().toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}\u202f');
    return s;
  }

  static String currencyLabel(String? c) {
    final v = (c ?? '').trim().toUpperCase();
    if (v.isEmpty || v == 'XOF' || v == 'FCFA') return 'FCFA';
    return v;
  }

  static TextStyle sectionTitleStyle(BuildContext context) {
    return const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      color: textPrimary,
    );
  }

  static const TextStyle productTitle = TextStyle(
    fontSize: 13.5,
    height: 1.25,
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
    fontSize: 17,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    color: price,
  );
}
