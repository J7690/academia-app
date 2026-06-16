import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/prep_concours_provider.dart';
import 'prep_sujet_blanc_exam_screen.dart';

class PrepSujetsBlancsScreen extends StatefulWidget {
  const PrepSujetsBlancsScreen({super.key});

  @override
  State<PrepSujetsBlancsScreen> createState() => _PrepSujetsBlancsScreenState();
}

class _PrepSujetsBlancsScreenState extends State<PrepSujetsBlancsScreen> {
  bool _initialized = false;
  String? _selectedType;

  static const _concoursTypes = <String, String>{
    '': 'Tous les concours',
    'TOUS': 'Concours Général',
    'ENAREF': 'ENAREF',
    'ADMIN_CIVIL': 'Administrateur Civil',
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

  void _onFilterChanged(String? type) {
    setState(() => _selectedType = type);
    context
        .read<PrepConcoursProvider>()
        .loadExamBlancs(concoursType: (type?.isEmpty ?? true) ? null : type);
  }

  Future<void> _requestGeneration() async {
    final type = _selectedType?.isNotEmpty == true ? _selectedType! : 'TOUS';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Générer un nouveau sujet'),
        content: Text(
          'L\'IA va composer un sujet blanc complet pour "${_concoursTypes[type] ?? type}".\n\nCela peut prendre 30 à 60 secondes.',
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
              ? 'Nouveau sujet blanc généré avec succès !'
              : 'Erreur lors de la génération. Réessaie.',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        title: const Text('Sujets blancs'),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFA3D65C), Color(0xFF1EA75C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Consumer<PrepConcoursProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              // Filter chips
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _concoursTypes.entries.map((e) {
                      final isSelected = (_selectedType ?? '') == e.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(e.value),
                          selected: isSelected,
                          selectedColor: const Color(0xFFA3D65C).withOpacity(0.3),
                          onSelected: (_) => _onFilterChanged(e.key),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Generate button
              if (provider.isGeneratingExam)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFFFFF3E0),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Génération en cours… L\'IA compose votre sujet blanc.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              // List
              Expanded(
                child: _buildList(provider),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<PrepConcoursProvider>(
        builder: (context, provider, _) {
          if (provider.isGeneratingExam) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: _requestGeneration,
            backgroundColor: const Color(0xFF1EA75C),
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
            label: const Text(
              'Nouveau sujet',
              style: TextStyle(color: Colors.white),
            ),
          );
        },
      ),
    );
  }

  Widget _buildList(PrepConcoursProvider provider) {
    if (provider.isLoading && provider.examBlancs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.examBlancs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'Aucun sujet blanc disponible pour le moment.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 8),
              const Text(
                'Appuie sur "Nouveau sujet" pour en générer un.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadExamBlancs(
        concoursType: (_selectedType?.isEmpty ?? true) ? null : _selectedType,
      ),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: provider.examBlancs.length,
        itemBuilder: (context, index) {
          final exam = provider.examBlancs[index];
          return _ExamBlancCard(
            exam: exam,
            onTap: () => _openExam(exam),
          );
        },
      ),
    );
  }
}

class _ExamBlancCard extends StatelessWidget {
  final ExamBlanc exam;
  final VoidCallback onTap;

  const _ExamBlancCard({required this.exam, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasScore = exam.userBestScore != null;
    final scoreColor = hasScore
        ? (exam.userBestScore! >= 70
            ? Colors.green
            : exam.userBestScore! >= 50
                ? Colors.orange
                : Colors.red)
        : Colors.grey;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      exam.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (exam.alreadyTaken)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: scoreColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${exam.userBestScore?.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: scoreColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _chip(Icons.help_outline, '${exam.totalQuestions} questions'),
                  _chip(Icons.timer_outlined, '${exam.durationMinutes} min'),
                  _chip(Icons.people_outline, '${exam.timesTaken} passages'),
                  if (exam.avgScore != null)
                    _chip(Icons.trending_up, 'Moy. ${exam.avgScore!.toStringAsFixed(0)}%'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA3D65C).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      exam.concoursType == 'TOUS' ? 'Général' : exam.concoursType,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    exam.alreadyTaken ? 'Reprendre' : 'Commencer',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1EA75C),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF1EA75C)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
