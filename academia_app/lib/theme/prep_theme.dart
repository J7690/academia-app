import 'package:flutter/material.dart';

/// Design system for the "Préparation Concours" module.
///
/// Color psychology applied to learning:
/// - Deep teal/cyan → focus & calm concentration
/// - Warm amber/gold → motivation & achievement
/// - Soft coral → energy without stress
/// - Cool slate → readability & rest for the eyes
/// - Emerald green → success & positive reinforcement
abstract final class PrepTheme {
  // ─── Primary palette (Deep Ocean Teal) ─────────────────────────
  static const Color primary = Color(0xFF0891B2);
  static const Color primaryLight = Color(0xFF22D3EE);
  static const Color primaryDark = Color(0xFF0E7490);
  static const Color primarySurface = Color(0xFFECFEFF);

  // ─── Accent (Warm Amber) ───────────────────────────────────────
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentLight = Color(0xFFFBBF24);
  static const Color accentSurface = Color(0xFFFFFBEB);

  // ─── Success (Emerald) ─────────────────────────────────────────
  static const Color success = Color(0xFF059669);
  static const Color successLight = Color(0xFF34D399);
  static const Color successSurface = Color(0xFFECFDF5);

  // ─── Energy (Coral) ────────────────────────────────────────────
  static const Color coral = Color(0xFFF97316);
  static const Color coralLight = Color(0xFFFB923C);
  static const Color coralSurface = Color(0xFFFFF7ED);

  // ─── Danger / Wrong answer ─────────────────────────────────────
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerLight = Color(0xFFFCA5A5);
  static const Color dangerSurface = Color(0xFFFEF2F2);

  // ─── XP / Gamification (Purple) ────────────────────────────────
  static const Color xpPurple = Color(0xFF8B5CF6);
  static const Color xpPurpleLight = Color(0xFFA78BFA);
  static const Color xpPurpleSurface = Color(0xFFF5F3FF);

  // ─── Streak (Fire) ─────────────────────────────────────────────
  static const Color streakOrange = Color(0xFFEA580C);
  static const Color streakYellow = Color(0xFFFBBF24);

  // ─── Neutral / Text ────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textOnDark = Colors.white;

  // ─── Backgrounds ───────────────────────────────────────────────
  static const Color scaffoldBg = Color(0xFFF0F9FF);
  static const Color cardBg = Colors.white;
  static const Color divider = Color(0xFFE2E8F0);
  static const Color shimmer = Color(0xFFE0F2FE);

  // ─── Gradients ─────────────────────────────────────────────────
  static const List<Color> headerGradient = [Color(0xFF0891B2), Color(0xFF06B6D4)];
  static const List<Color> quizGradient = [Color(0xFF6366F1), Color(0xFF8B5CF6)];
  static const List<Color> streakGradient = [Color(0xFFEA580C), Color(0xFFF59E0B)];
  static const List<Color> successGradient = [Color(0xFF059669), Color(0xFF34D399)];
  static const List<Color> aiGradient = [Color(0xFF8B5CF6), Color(0xFFEC4899)];
  static const List<Color> xpGradient = [Color(0xFFF59E0B), Color(0xFFF97316)];

  // ─── Radii ─────────────────────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusFull = 999;

  // ─── Shadows ───────────────────────────────────────────────────
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: const Color(0xFF0891B2).withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> glowShadow(Color color) => [
        BoxShadow(
          color: color.withOpacity(0.25),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];

  // ─── Helpers ───────────────────────────────────────────────────
  static BoxDecoration gradientBox(List<Color> colors, {double radius = radiusLg}) =>
      BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
      );

  static BoxDecoration cardBox({Color? borderColor}) => BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: borderColor ?? divider),
        boxShadow: softShadow,
      );

  static BoxDecoration glassBox({double opacity = 0.85}) => BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      );

  static Widget chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(radiusFull),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      );

  static Widget xpBadge(int xp) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: xpGradient),
          borderRadius: BorderRadius.circular(radiusFull),
          boxShadow: glowShadow(accent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              '$xp XP',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );

  static Widget streakBadge(int days) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: streakGradient),
          borderRadius: BorderRadius.circular(radiusFull),
          boxShadow: glowShadow(streakOrange),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              '$days jour${days > 1 ? 's' : ''}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}
