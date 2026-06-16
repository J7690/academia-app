import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';

import '../../../providers/prep_quiz_provider.dart';
import '../../../theme/prep_theme.dart';

/// Onglet Exercices — Exercices isolés par matière (QCM cliquables).
/// Chaque carte représente une matière ; un tap lance un quiz rapide
/// de 10–15 questions QCM via PrepQuizProvider.
class PrepExercisesTab extends StatelessWidget {
  const PrepExercisesTab({super.key});

  static const _subjects = <_SubjectDef>[
    _SubjectDef('Culture Générale', Icons.public, Color(0xFF6366F1), 15),
    _SubjectDef('Actualités du Burkina Faso', Icons.newspaper, Color(0xFF0891B2), 10),
    _SubjectDef('Français', Icons.menu_book, Color(0xFFDB2777), 10),
    _SubjectDef('Mathématiques', Icons.calculate, Color(0xFF059669), 10),
    _SubjectDef('Histoire-Géographie', Icons.map, Color(0xFFEA580C), 10),
    _SubjectDef('Tests Psychotechniques', Icons.psychology, Color(0xFF7C3AED), 10),
    _SubjectDef('Informatique', Icons.computer, Color(0xFF0E7490), 10),
    _SubjectDef('Droit Constitutionnel', Icons.gavel, Color(0xFF6D28D9), 10),
    _SubjectDef('Droit Administratif', Icons.account_balance, Color(0xFF1D4ED8), 10),
    _SubjectDef('Fiscalité', Icons.receipt_long, Color(0xFFB45309), 10),
    _SubjectDef('Économie Générale', Icons.trending_up, Color(0xFFF59E0B), 10),
    _SubjectDef('Pédagogie', Icons.school, Color(0xFFEC4899), 10),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: [
        // Header
        FadeInDown(
          duration: const Duration(milliseconds: 400),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: PrepTheme.gradientBox(PrepTheme.quizGradient, radius: 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Exercices par matière',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'QCM rapides · 10–15 questions · Correction immédiate',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Subject grid
        FadeInUp(
          delay: const Duration(milliseconds: 100),
          duration: const Duration(milliseconds: 400),
          child: const Text(
            'Choisis une matière',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: PrepTheme.textPrimary),
          ),
        ),
        const SizedBox(height: 12),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: _subjects.length,
          itemBuilder: (context, index) {
            final s = _subjects[index];
            return FadeInUp(
              delay: Duration(milliseconds: 50 * index),
              duration: const Duration(milliseconds: 350),
              child: _SubjectCard(def: s),
            );
          },
        ),
        const SizedBox(height: 24),

        // Concours-specific exercises
        FadeInUp(
          delay: const Duration(milliseconds: 300),
          duration: const Duration(milliseconds: 400),
          child: const Text(
            'Par concours',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: PrepTheme.textPrimary),
          ),
        ),
        const SizedBox(height: 12),
        FadeInUp(
          delay: const Duration(milliseconds: 350),
          duration: const Duration(milliseconds: 400),
          child: const _ConcoursExerciseGrid(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SubjectDef {
  final String name;
  final IconData icon;
  final Color color;
  final int defaultCount;

  const _SubjectDef(this.name, this.icon, this.color, this.defaultCount);
}

class _SubjectCard extends StatelessWidget {
  final _SubjectDef def;

  const _SubjectCard({required this.def});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final provider = context.read<PrepQuizProvider>();
        provider.startQuizFromServer(subject: def.name, count: def.defaultCount);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: PrepTheme.cardBox(borderColor: def.color.withOpacity(0.2)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: def.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(def.icon, color: def.color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  def.name,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: def.color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${def.defaultCount} QCM',
                  style: const TextStyle(fontSize: 10, color: PrepTheme.textTertiary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConcoursExerciseGrid extends StatelessWidget {
  const _ConcoursExerciseGrid();

  @override
  Widget build(BuildContext context) {
    final concours = [
      ('ENAREF', 'Régies financières', Icons.account_balance, const Color(0xFF7C3AED)),
      ('ADMIN_CIVIL', 'Administration', Icons.gavel, const Color(0xFF0891B2)),
      ('DOUANE', 'Douane', Icons.local_shipping, const Color(0xFFEA580C)),
      ('GREFFIERS', 'Justice', Icons.balance, const Color(0xFF059669)),
      ('PARAMILITAIRE', 'Paramilitaire', Icons.security, const Color(0xFF6366F1)),
      ('EDUCATION', 'Éducation', Icons.school, const Color(0xFFDB2777)),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: concours.map((c) {
        final (name, label, icon, color) = c;
        return GestureDetector(
          onTap: () {
            final provider = context.read<PrepQuizProvider>();
            provider.startQuizFromServer(concoursType: name, count: 15);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(PrepTheme.radiusFull),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
