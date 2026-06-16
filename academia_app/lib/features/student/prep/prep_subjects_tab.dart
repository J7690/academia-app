import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';

import '../../../providers/prep_concours_provider.dart';
import '../../../theme/prep_theme.dart';
import '../prep_concours/prep_sujet_blanc_exam_screen.dart';

/// Onglet Sujets — Sujets blancs générés par l'IA + possibilité d'en demander un nouveau.
class PrepSubjectsTab extends StatefulWidget {
  const PrepSubjectsTab({super.key});

  @override
  State<PrepSubjectsTab> createState() => _PrepSubjectsTabState();
}

class _PrepSubjectsTabState extends State<PrepSubjectsTab> {
  String _selectedConcours = '';
  bool _initialized = false;

  static const _concoursTypes = <String, String>{
    '': 'Tous',
    'TOUS': 'Général',
    'ENAREF': 'ENAREF',
    'ADMIN_CIVIL': 'Admin Civil',
    'GREFFIERS': 'Greffiers',
    'GRH': 'GRH',
    'DOUANE': 'Douane',
    'PARAMILITAIRE': 'Paramilitaire',
    'EDUCATION': 'Éducation',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PrepConcoursProvider>().loadExamBlancs();
    });
  }

  void _onFilterChanged(String type) {
    setState(() => _selectedConcours = type);
    context
        .read<PrepConcoursProvider>()
        .loadExamBlancs(concoursType: type.isEmpty ? null : type);
  }

  Future<void> _requestGeneration() async {
    final type = _selectedConcours.isNotEmpty ? _selectedConcours : 'TOUS';
    final label = _concoursTypes[type] ?? type;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Générer un nouveau sujet'),
        content: Text(
          'L\'IA va composer un sujet blanc complet pour "$label".\n\nCela peut prendre 30 à 60 secondes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Générer'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final provider = context.read<PrepConcoursProvider>();
    final success = await provider.requestNewExamBlanc(concoursType: type);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Nouveau sujet blanc généré !'
              : 'Erreur lors de la génération. Réessaie.',
        ),
        backgroundColor: success ? PrepTheme.success : Colors.red,
      ),
    );
  }

  Future<void> _openExam(ExamBlanc exam) async {
    final provider = context.read<PrepConcoursProvider>();
    final fullExam = await provider.getExamBlanc(exam.id);
    if (fullExam == null || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de charger ce sujet.')),
        );
      }
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrepSujetBlancExamScreen(exam: fullExam),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PrepConcoursProvider>(
      builder: (context, provider, _) {
        return Stack(
          children: [
            Column(
              children: [
                // ─── Filter chips ──────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _concoursTypes.entries.map((e) {
                        final isSelected = _selectedConcours == e.key;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(e.value,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : PrepTheme.textSecondary,
                                )),
                            selected: isSelected,
                            selectedColor: PrepTheme.primary,
                            backgroundColor: PrepTheme.cardBg,
                            side: BorderSide(
                              color: isSelected ? PrepTheme.primary : PrepTheme.divider,
                            ),
                            showCheckmark: false,
                            onSelected: (_) => _onFilterChanged(e.key),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // ─── Generating banner ─────────────────────────────
                if (provider.isGeneratingExam)
                  FadeInDown(
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: PrepTheme.primarySurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: PrepTheme.primary.withAlpha(60)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: PrepTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'L\'IA compose votre sujet blanc…',
                              style: TextStyle(fontSize: 13, color: PrepTheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ─── Exam list ─────────────────────────────────────
                Expanded(child: _buildList(provider)),
              ],
            ),

            // ─── FAB: generate new exam ──────────────────────────
            if (!provider.isGeneratingExam)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.extended(
                  heroTag: 'fab_generate_exam',
                  onPressed: _requestGeneration,
                  backgroundColor: PrepTheme.primary,
                  icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  label: const Text(
                    'Nouveau sujet',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildList(PrepConcoursProvider provider) {
    if (provider.isLoading && provider.examBlancs.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: PrepTheme.primary),
      );
    }

    if (provider.examBlancs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined, size: 48, color: PrepTheme.textTertiary),
            const SizedBox(height: 12),
            const Text(
              'Aucun sujet blanc disponible',
              style: TextStyle(color: PrepTheme.textTertiary, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'Appuie sur "Nouveau sujet" pour en générer un.',
              style: TextStyle(color: PrepTheme.textTertiary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: PrepTheme.primary,
      onRefresh: () => provider.loadExamBlancs(
        concoursType: _selectedConcours.isEmpty ? null : _selectedConcours,
      ),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        itemCount: provider.examBlancs.length,
        itemBuilder: (context, index) {
          final exam = provider.examBlancs[index];
          return FadeInUp(
            delay: Duration(milliseconds: 40 * index),
            duration: const Duration(milliseconds: 350),
            child: _ExamBlancCard(
              exam: exam,
              onTap: () => _openExam(exam),
            ),
          );
        },
      ),
    );
  }
}

// ─── Exam Blanc Card ──────────────────────────────────────────────────
class _ExamBlancCard extends StatelessWidget {
  final ExamBlanc exam;
  final VoidCallback onTap;

  const _ExamBlancCard({required this.exam, required this.onTap});

  Color get _typeColor {
    switch (exam.concoursType) {
      case 'ENAREF':
        return const Color(0xFF7C3AED);
      case 'ADMIN_CIVIL':
        return const Color(0xFF0891B2);
      case 'GREFFIERS':
        return const Color(0xFFDB2777);
      case 'GRH':
        return const Color(0xFFEA580C);
      case 'DOUANE':
        return const Color(0xFF059669);
      case 'PARAMILITAIRE':
        return const Color(0xFF6366F1);
      case 'EDUCATION':
        return const Color(0xFF0D9488);
      default:
        return PrepTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasScore = exam.userBestScore != null;
    final scoreColor = hasScore
        ? (exam.userBestScore! >= 70
            ? PrepTheme.success
            : exam.userBestScore! >= 50
                ? Colors.orange
                : Colors.red)
        : PrepTheme.textTertiary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: PrepTheme.cardBox(
        borderColor: exam.alreadyTaken ? scoreColor.withAlpha(60) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(PrepTheme.radiusLg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: _typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.assignment, color: _typeColor, size: 24),
                ),
                const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exam.title,
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
                          PrepTheme.chip(
                            exam.concoursType == 'TOUS' ? 'Général' : exam.concoursType,
                            _typeColor,
                          ),
                          PrepTheme.chip(
                            '${exam.totalQuestions} Q',
                            PrepTheme.textSecondary,
                          ),
                          PrepTheme.chip(
                            '${exam.durationMinutes} min',
                            PrepTheme.textSecondary,
                          ),
                          if (exam.alreadyTaken && hasScore)
                            PrepTheme.chip(
                              '${exam.userBestScore!.toStringAsFixed(0)}%',
                              scoreColor,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action hint
                Icon(
                  exam.alreadyTaken ? Icons.replay : Icons.play_arrow,
                  color: _typeColor,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
