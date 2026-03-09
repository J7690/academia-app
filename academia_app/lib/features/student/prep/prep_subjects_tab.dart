import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

import '../../../theme/prep_theme.dart';

/// Onglet Sujets — Banque d'épreuves par concours, année, matière.
class PrepSubjectsTab extends StatefulWidget {
  const PrepSubjectsTab({super.key});

  @override
  State<PrepSubjectsTab> createState() => _PrepSubjectsTabState();
}

class _PrepSubjectsTabState extends State<PrepSubjectsTab> {
  String _selectedConcours = 'Tous';
  String _selectedYear = 'Toutes';
  String _selectedSubject = 'Toutes';

  static const _concoursList = ['Tous', 'ENAM', 'ENS', 'ENSET', 'BAC', 'BEPC', 'IRIC'];
  static const _yearsList = ['Toutes', '2025', '2024', '2023', '2022', '2021', '2020'];
  static const _subjectsList = [
    'Toutes',
    'Culture Générale',
    'Mathématiques',
    'Droit',
    'Économie',
    'Français',
    'Anglais',
    'Physique-Chimie',
    'Biologie',
    'Histoire-Géo',
  ];

  @override
  Widget build(BuildContext context) {
    final papers = _getDemoPapers();

    return Column(
      children: [
        // ─── Filters ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              // Search bar
              FadeInDown(
                duration: const Duration(milliseconds: 350),
                child: Container(
                  decoration: BoxDecoration(
                    color: PrepTheme.cardBg,
                    borderRadius: BorderRadius.circular(PrepTheme.radiusFull),
                    border: Border.all(color: PrepTheme.divider),
                    boxShadow: PrepTheme.softShadow,
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher un sujet, une épreuve…',
                      hintStyle: TextStyle(color: PrepTheme.textTertiary, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: PrepTheme.textTertiary, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterDropdown(
                      label: 'Concours',
                      value: _selectedConcours,
                      items: _concoursList,
                      color: PrepTheme.xpPurple,
                      onChanged: (v) => setState(() => _selectedConcours = v),
                    ),
                    const SizedBox(width: 8),
                    _FilterDropdown(
                      label: 'Année',
                      value: _selectedYear,
                      items: _yearsList,
                      color: PrepTheme.primary,
                      onChanged: (v) => setState(() => _selectedYear = v),
                    ),
                    const SizedBox(width: 8),
                    _FilterDropdown(
                      label: 'Matière',
                      value: _selectedSubject,
                      items: _subjectsList,
                      color: PrepTheme.success,
                      onChanged: (v) => setState(() => _selectedSubject = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ─── Papers list ─────────────────────────────────────────
        Expanded(
          child: papers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_open, size: 48, color: PrepTheme.textTertiary),
                      const SizedBox(height: 12),
                      const Text(
                        'Aucun sujet trouvé',
                        style: TextStyle(color: PrepTheme.textTertiary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  physics: const BouncingScrollPhysics(),
                  itemCount: papers.length,
                  itemBuilder: (context, index) {
                    final paper = papers[index];
                    return FadeInUp(
                      delay: Duration(milliseconds: 40 * index),
                      duration: const Duration(milliseconds: 350),
                      child: _PaperCard(paper: paper),
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<_ExamPaper> _getDemoPapers() {
    final all = <_ExamPaper>[
      _ExamPaper(
        title: 'Épreuve de Culture Générale',
        concours: 'ENAM',
        year: '2024',
        subject: 'Culture Générale',
        isOfficial: true,
        hasCorrection: true,
        difficulty: 3,
      ),
      _ExamPaper(
        title: 'Épreuve de Droit Administratif',
        concours: 'ENAM',
        year: '2024',
        subject: 'Droit',
        isOfficial: true,
        hasCorrection: true,
        difficulty: 4,
      ),
      _ExamPaper(
        title: 'Mathématiques — Série C',
        concours: 'BAC',
        year: '2024',
        subject: 'Mathématiques',
        isOfficial: true,
        hasCorrection: true,
        difficulty: 3,
      ),
      _ExamPaper(
        title: 'Épreuve de Français',
        concours: 'BEPC',
        year: '2024',
        subject: 'Français',
        isOfficial: true,
        hasCorrection: false,
        difficulty: 2,
      ),
      _ExamPaper(
        title: 'Économie Politique',
        concours: 'ENAM',
        year: '2023',
        subject: 'Économie',
        isOfficial: true,
        hasCorrection: true,
        difficulty: 4,
      ),
      _ExamPaper(
        title: 'Relations Internationales',
        concours: 'IRIC',
        year: '2023',
        subject: 'Culture Générale',
        isOfficial: true,
        hasCorrection: false,
        difficulty: 4,
      ),
      _ExamPaper(
        title: 'Physique-Chimie — Série D',
        concours: 'BAC',
        year: '2023',
        subject: 'Physique-Chimie',
        isOfficial: true,
        hasCorrection: true,
        difficulty: 3,
      ),
      _ExamPaper(
        title: 'Pédagogie Générale',
        concours: 'ENS',
        year: '2024',
        subject: 'Culture Générale',
        isOfficial: true,
        hasCorrection: false,
        difficulty: 3,
      ),
      _ExamPaper(
        title: 'Biologie — SVT',
        concours: 'BAC',
        year: '2024',
        subject: 'Biologie',
        isOfficial: true,
        hasCorrection: true,
        difficulty: 2,
      ),
      _ExamPaper(
        title: 'Droit Constitutionnel',
        concours: 'ENAM',
        year: '2022',
        subject: 'Droit',
        isOfficial: true,
        hasCorrection: true,
        difficulty: 5,
      ),
    ];

    return all.where((p) {
      if (_selectedConcours != 'Tous' && p.concours != _selectedConcours) return false;
      if (_selectedYear != 'Toutes' && p.year != _selectedYear) return false;
      if (_selectedSubject != 'Toutes' && p.subject != _selectedSubject) return false;
      return true;
    }).toList();
  }
}

// ─── Models ──────────────────────────────────────────────────────
class _ExamPaper {
  final String title;
  final String concours;
  final String year;
  final String subject;
  final bool isOfficial;
  final bool hasCorrection;
  final int difficulty;

  const _ExamPaper({
    required this.title,
    required this.concours,
    required this.year,
    required this.subject,
    this.isOfficial = false,
    this.hasCorrection = false,
    this.difficulty = 1,
  });
}

// ─── Widgets ─────────────────────────────────────────────────────
class _FilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final Color color;
  final ValueChanged<String> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(PrepTheme.radiusFull),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: $value',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(label,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            const Divider(height: 1),
            ...items.map((item) => ListTile(
                  title: Text(item),
                  trailing: item == value
                      ? Icon(Icons.check_circle, color: color, size: 20)
                      : null,
                  onTap: () {
                    onChanged(item);
                    Navigator.of(ctx).pop();
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _PaperCard extends StatelessWidget {
  final _ExamPaper paper;

  const _PaperCard({required this.paper});

  Color get _concoursColor {
    switch (paper.concours) {
      case 'ENAM':
        return const Color(0xFF7C3AED);
      case 'ENS':
        return const Color(0xFF0891B2);
      case 'ENSET':
        return const Color(0xFFEA580C);
      case 'BAC':
        return const Color(0xFF059669);
      case 'BEPC':
        return const Color(0xFF6366F1);
      case 'IRIC':
        return const Color(0xFFDB2777);
      default:
        return PrepTheme.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: PrepTheme.cardBox(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(PrepTheme.radiusLg),
          onTap: () => _showPaperDetail(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _concoursColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.description, color: _concoursColor, size: 24),
                ),
                const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        paper.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: PrepTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          PrepTheme.chip(paper.concours, _concoursColor),
                          PrepTheme.chip(paper.year, PrepTheme.textSecondary),
                          if (paper.isOfficial)
                            PrepTheme.chip('Officiel', PrepTheme.success),
                          if (paper.hasCorrection)
                            PrepTheme.chip('Corrigé', PrepTheme.primary),
                        ],
                      ),
                    ],
                  ),
                ),
                // Difficulty dots
                Column(
                  children: [
                    ...List.generate(5, (i) => Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(bottom: 2),
                          decoration: BoxDecoration(
                            color: i < paper.difficulty
                                ? _concoursColor
                                : PrepTheme.divider,
                            shape: BoxShape.circle,
                          ),
                        )),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPaperDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PrepTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: PrepTheme.gradientBox(
                  [_concoursColor, _concoursColor.withOpacity(0.8)],
                  radius: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paper.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _whiteChip(paper.concours),
                        _whiteChip(paper.year),
                        _whiteChip(paper.subject),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Actions
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.visibility,
                      label: 'Voir le sujet',
                      color: PrepTheme.primary,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Le viewer PDF sera connecté au backend Supabase.')),
                        );
                      },
                    ),
                  ),
                  if (paper.hasCorrection) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.check_circle,
                        label: 'Voir le corrigé',
                        color: PrepTheme.success,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Le corrigé sera connecté au backend Supabase.')),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              _ActionButton(
                icon: Icons.auto_awesome,
                label: 'Générer un quiz depuis ce sujet (IA)',
                color: PrepTheme.xpPurple,
                onTap: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('La génération IA de quiz sera connectée prochainement.')),
                  );
                },
              ),
              const SizedBox(height: 20),
              // Info
              const Text('Informations',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _InfoRow(label: 'Concours', value: paper.concours),
              _InfoRow(label: 'Année', value: paper.year),
              _InfoRow(label: 'Matière', value: paper.subject),
              _InfoRow(label: 'Difficulté', value: '${'⭐' * paper.difficulty}'),
              _InfoRow(label: 'Officiel', value: paper.isOfficial ? 'Oui' : 'Non'),
              _InfoRow(label: 'Corrigé disponible', value: paper.hasCorrection ? 'Oui' : 'Non'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _whiteChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(PrepTheme.radiusFull),
        ),
        child: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(PrepTheme.radiusMd),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: PrepTheme.textTertiary)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: PrepTheme.textPrimary)),
        ],
      ),
    );
  }
}
