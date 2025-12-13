import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/prep_concours_provider.dart';
import 'prep_diagnostic_screen.dart';
import 'prep_exam_screen.dart';
import 'prep_progress_screen.dart';
import 'prep_training_screen.dart';

class PrepChaptersScreen extends StatefulWidget {
  final PrepSubject subject;

  const PrepChaptersScreen({
    super.key,
    required this.subject,
  });

  @override
  State<PrepChaptersScreen> createState() => _PrepChaptersScreenState();
}

class _PrepChaptersScreenState extends State<PrepChaptersScreen> {
  bool _initialized = false;

  Future<void> _openChapterActions(PrepChapter chapter) async {
    if (!mounted) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(chapter.title),
                subtitle: const Text('Choisis une activité'),
              ),
              ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: const Text('Entraînement'),
                onTap: () => Navigator.of(sheetContext).pop('training'),
              ),
              ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('Diagnostic'),
                onTap: () => Navigator.of(sheetContext).pop('diagnostic'),
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Examen blanc'),
                onTap: () => Navigator.of(sheetContext).pop('exam'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'training') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PrepTrainingScreen(subject: widget.subject, chapter: chapter),
        ),
      );
      return;
    }

    if (action == 'diagnostic') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PrepDiagnosticScreen(subject: widget.subject, chapter: chapter),
        ),
      );
      return;
    }

    if (action == 'exam') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PrepExamScreen(subject: widget.subject, chapter: chapter),
        ),
      );
      return;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrepConcoursProvider>().loadChapters(widget.subject.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        title: Text(widget.subject.title),
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
        builder: (context, provider, child) {
          final chapters = provider.getChaptersForSubject(widget.subject.id);

          if (provider.isLoading && chapters.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && chapters.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      provider.error!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => provider.loadChapters(widget.subject.id),
                      child: const Text('Recharger'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: const Icon(Icons.insights_outlined),
                  title: const Text('Historique & stats'),
                  subtitle: const Text('Suivre tes progrès et tes tentatives.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PrepProgressScreen(subject: widget.subject),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: const Icon(Icons.fact_check_outlined),
                  title: const Text('Diagnostic (QCM)'),
                  subtitle: const Text('Évaluer ton niveau en 10–20 questions.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PrepDiagnosticScreen(subject: widget.subject),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Examen blanc (chronométré)'),
                  subtitle: const Text('Simulation : 20 questions, 20 minutes.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PrepExamScreen(subject: widget.subject),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: const Icon(Icons.play_circle_outline),
                  title: const Text('Entraînement (QCM)'),
                  subtitle: const Text('Session rapide (questions publiées).'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PrepTrainingScreen(subject: widget.subject),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (chapters.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Aucun chapitre n\'est encore renseigné pour cette matière.',
                    textAlign: TextAlign.center,
                  ),
                )
              else ...[
                const Text(
                  'Chapitres',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                for (final c in chapters)
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      title: Text(c.title),
                      subtitle: c.description != null && c.description!.trim().isNotEmpty
                          ? Text(
                              c.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        _openChapterActions(c);
                      },
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
