import 'package:flutter/material.dart';

/// Palette « Ciel Academia ».
///
/// Toutes les valeurs sont reprises telles quelles de l'onglet Accueil
/// (`student_home_mobile.dart` et `student_mobile_scaffold.dart`) afin que
/// Cours, Lives et Accueil forment un ensemble cohérent.
///
/// Règle unique et non négociable : [live] ne sert **que** à signaler une
/// séance réellement en cours. Il n'est jamais utilisé comme couleur
/// décorative — c'est ce qui le rend immédiatement lisible.
class AcademiaPalette {
  const AcademiaPalette._();

  // ── Ciel — fond global de l'app ───────────────────────────────────────
  static const Color sky1 = Color(0xFF62A8FF);
  static const Color sky2 = Color(0xFF9ED7FF);
  static const Color sky3 = Color(0xFFDFF4FF);

  /// Fond d'écran identique à `StudentMobileScaffold`.
  static const LinearGradient skyBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [sky1, sky2, sky3],
  );

  // ── Vert Academia — couleur d'action, identité COURS ──────────────────
  static const Color green900 = Color(0xFF0A2540);
  static const Color green700 = Color(0xFF1B5E20);
  static const Color green600 = Color(0xFF2E7D32);
  static const Color green500 = Color(0xFF43A047);
  static const Color green100 = Color(0xFFC8E6C9);
  static const Color green50 = Color(0xFFE8F5E9);

  // ── Bleu — identité LIVES ─────────────────────────────────────────────
  static const Color navy = Color(0xFF0A2540);
  static const Color blue = Color(0xFF1565C0);
  static const Color blueLight = Color(0xFF62A8FF);
  static const Color blue50 = Color(0xFFE3F2FD);

  // ── Accents repris de l'Accueil ───────────────────────────────────────
  static const Color amber = Color(0xFFF59E0B);
  static const Color amber50 = Color(0xFFFFF7E6);
  static const Color orange = Color(0xFFE65100);
  static const Color purple = Color(0xFF4A148C);
  static const Color purpleLight = Color(0xFF7C43BD);
  static const Color teal = Color(0xFF00695C);
  static const Color teal50 = Color(0xFFE1F5FE);
  static const Color success = Color(0xFF16A34A);

  /// Rouge « en direct » — usage strictement réservé au live.
  static const Color live = Color(0xFFD32F2F);
  static const Color live50 = Color(0xFFFFEBEE);

  // ── Texte ─────────────────────────────────────────────────────────────
  static const Color ink = Color(0xFF0A2540);
  static const Color text = Color(0xFF212121);
  static const Color muted = Color(0xFF757575);
  static const Color faint = Color(0xFF9CA3AF);

  // ── Surfaces ──────────────────────────────────────────────────────────
  static const Color surface = Colors.white;
  static const Color surfaceAlt = Color(0xFFF7F8FA);
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderStrong = Color(0xFFD7DDE5);

  // ── Dégradés signature ────────────────────────────────────────────────
  static const LinearGradient coursHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [green700, green600, green500],
  );

  static const LinearGradient livesHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, blue, blueLight],
  );

  /// Orientation — le teal est la dernière couleur de l'Accueil restée libre.
  /// Vert = Cours, bleu = Lives, violet = Prépa, teal = Orientation.
  static const LinearGradient orientationHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00363B), teal, blueLight],
  );

  /// Uniquement pour le bouton « Rejoindre le direct ».
  static const LinearGradient onAir = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [live, orange],
  );

  static const LinearGradient warm = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [amber, orange],
  );

  static const LinearGradient cool = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue, teal],
  );

  static const LinearGradient prep = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [purple, purpleLight],
  );

  /// Palette de couvertures utilisée quand un contenu n'a pas d'image.
  /// L'index est dérivé du titre pour rester stable d'un rebuild à l'autre.
  static const List<LinearGradient> covers = [
    coursHeader,
    cool,
    warm,
    prep,
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [success, teal],
    ),
    livesHeader,
  ];

  static LinearGradient coverFor(String seed) {
    if (seed.isEmpty) return covers.first;
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    return covers[hash % covers.length];
  }

  // ── Ombres ────────────────────────────────────────────────────────────
  static List<BoxShadow> get shadowSoft => const [
        BoxShadow(
          color: Color(0x0F0A2540),
          offset: Offset(0, 1),
          blurRadius: 3,
        ),
      ];

  static List<BoxShadow> get shadowCard => const [
        BoxShadow(
          color: Color(0x170A2540),
          offset: Offset(0, 4),
          blurRadius: 14,
        ),
      ];

  static List<BoxShadow> shadowAccent(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.28),
          offset: const Offset(0, 6),
          blurRadius: 18,
        ),
      ];

  // ── Rayons ────────────────────────────────────────────────────────────
  static const double rSm = 10;
  static const double rMd = 14;
  static const double rLg = 18;
  static const double rXl = 22;
}
