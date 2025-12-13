import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/prep_concours_provider.dart';
import 'prep_progress_screen.dart';

class PrepDiagnosticScreen extends StatefulWidget {
  final PrepSubject subject;
  final PrepChapter? chapter;
  final int numQuestions;

  const PrepDiagnosticScreen({
    super.key,
    required this.subject,
    this.chapter,
    this.numQuestions = 15,
  });

  @override
  State<PrepDiagnosticScreen> createState() => _PrepDiagnosticScreenState();
}

class _PrepDiagnosticResultsScreen extends StatelessWidget {
  final String subjectTitle;
  final String? chapterTitle;
  final List<PrepQuestion> questions;
  final Map<String, String?> answersByQuestionId;
  final Map<String, bool?> isCorrectByQuestionId;
  final int correctCount;
  final PrepSubject subject;

  const _PrepDiagnosticResultsScreen({
    required this.subjectTitle,
    required this.chapterTitle,
    required this.questions,
    required this.answersByQuestionId,
    required this.isCorrectByQuestionId,
    required this.correctCount,
    required this.subject,
  });

  @override
  Widget build(BuildContext context) {
    final total = questions.length;
    final title = chapterTitle == null || chapterTitle!.trim().isEmpty
        ? subjectTitle
        : chapterTitle!;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        title: Text('Résultats - $title'),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Historique & stats',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PrepProgressScreen(subject: subject),
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Diagnostic terminé',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text('Score: $correctCount / $total'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Corrections',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < questions.length; i++)
            _DiagnosticCorrectionCard(
              index: i,
              question: questions[i],
              userAnswer: answersByQuestionId[questions[i].id],
              isCorrect: isCorrectByQuestionId[questions[i].id],
            ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1EA75C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticCorrectionCard extends StatelessWidget {
  final int index;
  final PrepQuestion question;
  final String? userAnswer;
  final bool? isCorrect;

  const _DiagnosticCorrectionCard({
    required this.index,
    required this.question,
    required this.userAnswer,
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final correctAnswer = question.correctAnswer;
    final ok = isCorrect == true;
    final hasUserAnswer = userAnswer != null && userAnswer!.trim().isNotEmpty;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Question ${index + 1}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              question.question,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  ok ? Icons.check_circle_outline : Icons.cancel_outlined,
                  color: ok ? const Color(0xFF1EA75C) : Colors.redAccent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  ok ? 'Correct' : 'Incorrect',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: ok ? const Color(0xFF1EA75C) : Colors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              hasUserAnswer ? 'Ta réponse: $userAnswer' : 'Ta réponse: (aucune)',
            ),
            if (correctAnswer != null && correctAnswer.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Bonne réponse: $correctAnswer',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            if (question.explanation != null && question.explanation!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Explication',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(question.explanation!),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrepDiagnosticScreenState extends State<PrepDiagnosticScreen> {
  bool _initialized = false;
  bool _isSubmitting = false;

  List<PrepQuestion> _questions = const [];
  int _index = 0;
  String? _selectedAnswer;
  DateTime? _startedAt;

  final Map<String, String?> _answersByQuestionId = {};
  final Map<String, bool?> _isCorrectByQuestionId = {};

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
      limit: widget.numQuestions,
    );

    if (!mounted) return;
    setState(() {
      _questions = questions;
      _index = 0;
      _selectedAnswer = null;
      _startedAt = DateTime.now();
      _answersByQuestionId.clear();
      _isCorrectByQuestionId.clear();
    });

    if (questions.isNotEmpty) {
      await provider.loadChoices(questions.first.id);
    }
  }

  Future<void> _finish() async {
    var correct = 0;
    for (final q in _questions) {
      if (_isCorrectByQuestionId[q.id] == true) {
        correct += 1;
      }
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _PrepDiagnosticResultsScreen(
          subjectTitle: widget.subject.title,
          chapterTitle: widget.chapter?.title,
          questions: _questions,
          answersByQuestionId: Map<String, String?>.from(_answersByQuestionId),
          isCorrectByQuestionId: Map<String, bool?>.from(_isCorrectByQuestionId),
          correctCount: correct,
          subject: widget.subject,
        ),
      ),
    );
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

      _answersByQuestionId[q.id] = selected;
      _isCorrectByQuestionId[q.id] = isCorrect;

      await provider.createAttempt(
        questionId: q.id,
        attemptType: 'diagnostic',
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
      await _finish();
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
        ? 'Diagnostic - ${widget.subject.title}'
        : 'Diagnostic - ${widget.chapter!.title}';

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
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Fermer'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PrepProgressScreen(subject: widget.subject),
                          ),
                        );
                      },
                      child: const Text('Voir stats'),
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
