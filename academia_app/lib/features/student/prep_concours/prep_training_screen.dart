import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/prep_concours_provider.dart';
import 'prep_progress_screen.dart';

class PrepTrainingScreen extends StatefulWidget {
  final PrepSubject subject;
  final PrepChapter? chapter;

  const PrepTrainingScreen({
    super.key,
    required this.subject,
    this.chapter,
  });

  @override
  State<PrepTrainingScreen> createState() => _PrepTrainingScreenState();
}

class _PrepTrainingScreenState extends State<PrepTrainingScreen> {
  bool _initialized = false;
  bool _isSubmitting = false;

  List<PrepQuestion> _questions = const [];
  int _index = 0;
  String? _selectedAnswer;
  DateTime? _startedAt;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    final provider = context.read<PrepConcoursProvider>();
    final questions = await provider.loadPublishedQuestions(
      subjectId: widget.subject.id,
      chapterId: widget.chapter?.id,
      limit: 10,
    );

    if (!mounted) return;
    setState(() {
      _questions = questions;
      _index = 0;
      _selectedAnswer = null;
      _startedAt = DateTime.now();
    });

    if (questions.isNotEmpty) {
      await provider.loadChoices(questions.first.id);
    }
  }

  Future<void> _next() async {
    if (_questions.isEmpty) return;

    final provider = context.read<PrepConcoursProvider>();
    final q = _questions[_index];

    final now = DateTime.now();
    final startedAt = _startedAt;
    final timeSpent = startedAt == null ? null : now.difference(startedAt).inSeconds;

    final selected = _selectedAnswer;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final isCorrect = q.correctAnswer != null && selected != null
          ? q.correctAnswer!.trim() == selected.trim()
          : null;

      await provider.createAttempt(
        questionId: q.id,
        attemptType: 'training',
        selectedAnswer: selected,
        isCorrect: isCorrect,
        timeSpentSec: timeSpent,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }

    final nextIndex = _index + 1;
    if (nextIndex >= _questions.length) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('Session terminée'),
            content: const Text('Bravo !'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PrepProgressScreen(subject: widget.subject),
                    ),
                  );
                },
                child: const Text('Voir stats'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('Fermer'),
              ),
            ],
          );
        },
      );
      return;
    }

    setState(() {
      _index = nextIndex;
      _selectedAnswer = null;
      _startedAt = DateTime.now();
    });

    await provider.loadChoices(_questions[_index].id);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.chapter == null
        ? 'Entraînement - ${widget.subject.title}'
        : 'Entraînement - ${widget.chapter!.title}';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        title: Text(title),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Historique & stats',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PrepProgressScreen(subject: widget.subject),
                ),
              );
            },
          ),
        ],
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
          if (provider.isLoading && _questions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && _questions.isEmpty) {
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
                      onPressed: _load,
                      child: const Text('Recharger'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (_questions.isEmpty) {
            final label = widget.chapter == null
                ? widget.subject.title
                : widget.chapter!.title;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Aucune question publiée pour le moment pour "$label".\n(Le module est prêt : il faut publier des questions côté admin.)',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final q = _questions[_index];
          final choices = provider.getChoicesForQuestion(q.id);

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Question ${_index + 1}/${_questions.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      q.question,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (choices.isEmpty)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: choices.length,
                      itemBuilder: (context, index) {
                        final c = choices[index];
                        final value = c.choiceText;
                        final selected = _selectedAnswer == value;
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: selected
                                  ? const Color(0xFF1EA75C)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: ListTile(
                            title: Text(value),
                            onTap: _isSubmitting
                                ? null
                                : () {
                                    setState(() {
                                      _selectedAnswer = value;
                                    });
                                  },
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: (_isSubmitting || choices.isEmpty)
                      ? null
                      : () {
                          unawaited(_next());
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1EA75C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Valider et continuer'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
