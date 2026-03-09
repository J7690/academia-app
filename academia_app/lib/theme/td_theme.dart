import 'package:flutter/material.dart';

/// Design system for the TD module and role-specific palettes.
/// Inspired by Google Classroom, Canvas LMS, Coursera, and Duolingo.
abstract final class TdTheme {
  // ─── Role palettes ───────────────────────────────────────────────
  // Instructor (Teal)
  static const Color instructorPrimary = Color(0xFF0D9488);
  static const Color instructorPrimaryLight = Color(0xFF14B8A6);
  static const Color instructorSurface = Color(0xFFF0FDFA);
  static const Color instructorAccent = Color(0xFF2DD4BF);
  static const List<Color> instructorGradient = [Color(0xFF0D9488), Color(0xFF14B8A6)];

  // Admin TD (Violet)
  static const Color adminTdPrimary = Color(0xFF7C3AED);
  static const Color adminTdPrimaryLight = Color(0xFF8B5CF6);
  static const Color adminTdSurface = Color(0xFFF5F3FF);
  static const Color adminTdAccent = Color(0xFFA78BFA);
  static const List<Color> adminTdGradient = [Color(0xFF7C3AED), Color(0xFF8B5CF6)];

  // Student TD (Indigo)
  static const Color studentTdPrimary = Color(0xFF4F46E5);
  static const Color studentTdPrimaryLight = Color(0xFF6366F1);
  static const Color studentTdSurface = Color(0xFFEEF2FF);
  static const Color studentTdAccent = Color(0xFF818CF8);
  static const List<Color> studentTdGradient = [Color(0xFF4F46E5), Color(0xFF6366F1)];

  // ─── Shared semantic colors ──────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFEA580C);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);
  static const Color neutral = Color(0xFF6B7280);

  // ─── Background & surface ────────────────────────────────────────
  static const Color scaffoldBg = Color(0xFFF8FAFC);
  static const Color cardBg = Colors.white;
  static const Color divider = Color(0xFFE5E7EB);

  // ─── Text ────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  // ─── Shared radii ───────────────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;

  // ─── Shared helpers ──────────────────────────────────────────────
  static BoxDecoration gradientHeader(List<Color> colors) => BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );

  static BoxDecoration cardDecoration({Color? borderColor}) => BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: borderColor ?? divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );

  static Widget kpiCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(radiusMd),
          border: Border.all(color: divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(radiusSm),
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
  }

  static (String, Color) accessStatusInfo(String status) {
    switch (status) {
      case 'pending_payment':
        return ('En attente paiement', warning);
      case 'waiting_admin':
        return ('En attente admin', info);
      case 'active':
        return ('Actif', success);
      case 'completed':
        return ('Termin\u00e9', neutral);
      default:
        return (status.isEmpty ? 'Inconnu' : status, neutral);
    }
  }

  static String formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  static String formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  // ─── Discipline color palette ──────────────────────────────────
  static const Map<String, Color> disciplineColors = {
    'mathématiques': Color(0xFF4F46E5),
    'maths': Color(0xFF4F46E5),
    'physique': Color(0xFFEA580C),
    'chimie': Color(0xFF059669),
    'français': Color(0xFFDC2626),
    'anglais': Color(0xFF7C3AED),
    'histoire-géo': Color(0xFFD97706),
    'histoire': Color(0xFFD97706),
    'géographie': Color(0xFFD97706),
    'informatique': Color(0xFF0891B2),
    'svt': Color(0xFF16A34A),
    'philosophie': Color(0xFF9333EA),
    'économie': Color(0xFF0D9488),
    'droit': Color(0xFF1D4ED8),
  };

  static Color colorForDiscipline(String? name) {
    if (name == null || name.isEmpty) return studentTdPrimary;
    final key = name.toLowerCase().trim();
    return disciplineColors[key] ?? studentTdPrimary;
  }

  static Color colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return studentTdPrimary;
    try {
      final h = hex.replaceFirst('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return studentTdPrimary;
    }
  }

  static List<Color> gradientForDiscipline(String? name) {
    final base = colorForDiscipline(name);
    return [base, Color.lerp(base, Colors.white, 0.2) ?? base];
  }

  // ─── Gamification helpers ──────────────────────────────────────

  static BoxDecoration gradientCard(List<Color> colors, {double radius = radiusLg}) => BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static Widget xpBadge(int xp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEF4444)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt, color: Colors.white, size: 12),
          const SizedBox(width: 2),
          Text('$xp XP',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  static Widget streakBadge(int streak) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF97316)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 11)),
          const SizedBox(width: 2),
          Text('$streak j',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  static Widget levelBadge(int level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: studentTdPrimary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('Niv. $level',
          style: const TextStyle(color: studentTdPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  static Widget progressBar({
    required double value,
    Color? color,
    double height = 6,
  }) {
    final c = color ?? studentTdPrimary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          backgroundColor: c.withOpacity(0.12),
          valueColor: AlwaysStoppedAnimation<Color>(c),
        ),
      ),
    );
  }

  static Widget disciplineChip(String name, {Color? color}) {
    final c = color ?? colorForDiscipline(name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(radiusSm),
        border: Border.all(color: c.withOpacity(0.2)),
      ),
      child: Text(
        name,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c),
      ),
    );
  }
}
