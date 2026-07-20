import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

/// En-tête (hero) unifié pour les onglets du dashboard étudiant.
///
/// Reproduit le pattern visuel de `_ApplicationsHeader` (onglet Candidatures)
/// pour offrir une cohérence forte avec les onglets Accueil, TD et Concours :
/// - Gradient doux (accent 8 % → blanc)
/// - Icône dans un cercle coloré (accent 12 %)
/// - Titre 20 pt w800 + sous-titre 13 pt
/// - Ligne de statistiques dans un `Wrap` (adaptatif — pas d'overflow)
/// - Animation d'entrée `FadeInDown` (400 ms)
class StudentTabHero extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final List<StudentTabHeroStat> stats;
  final EdgeInsetsGeometry margin;

  const StudentTabHero({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    this.stats = const [],
    this.margin = const EdgeInsets.fromLTRB(16, 16, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    final Color darkText =
        Color.lerp(accentColor, Colors.black, 0.55) ?? const Color(0xFF0A2540);
    final Color subText =
        Color.lerp(accentColor, Colors.black, 0.35) ?? const Color(0xFF374151);

    return FadeInDown(
      duration: const Duration(milliseconds: 400),
      child: Padding(
        padding: margin,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accentColor.withOpacity(0.14),
                Colors.white,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accentColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: darkText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: subText,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (stats.isNotEmpty) ...[
                const SizedBox(height: 14),
                // Wrap = adaptatif : passe à la ligne si l'espace manque
                // (corrige les overflows sur petits écrans).
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in stats)
                      _StatPill(
                        icon: s.icon,
                        label: s.label,
                        color: s.color ?? accentColor,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Descripteur d'une statistique affichée dans le hero.
class StudentTabHeroStat {
  final IconData icon;
  final String label;

  /// Optionnelle — si nulle, utilise la couleur d'accent du hero.
  final Color? color;

  const StudentTabHeroStat({
    required this.icon,
    required this.label,
    this.color,
  });
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color.lerp(color, Colors.black, 0.25) ?? color,
            ),
          ),
        ],
      ),
    );
  }
}
