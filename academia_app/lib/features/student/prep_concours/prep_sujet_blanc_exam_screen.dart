import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/prep_concours_provider.dart';
import '../../../widgets/academia_rich_content.dart';

class PrepSujetBlancExamScreen extends StatefulWidget {
  final ExamBlanc exam;

  const PrepSujetBlancExamScreen({super.key, required this.exam});

  @override
  State<PrepSujetBlancExamScreen> createState() =>
      _PrepSujetBlancExamScreenState();
}

class _PrepSujetBlancExamScreenState extends State<PrepSujetBlancExamScreen> {
  // Flatten all questions from all sections
  late final List<_FlatQuestion> _questions;
  int _index = 0;
  String? _selectedLabel;

  DateTime? _examEndsAt;
  Timer? _timer;
  Duration _remaining = Duration.zero;
  DateTime? _examStartedAt;

  final Map<int, String?> _answersByIndex = {}; // QCM: label, Open: written text
  final Map<int, bool> _isCorrectByIndex = {};
  final Map<int, TextEditingController> _openControllers = {};
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    // Flatten sections into a sequential list
    final flat = <_FlatQuestion>[];
    for (final section in widget.exam.sections) {
      for (final q in section.questions) {
        flat.add(_FlatQuestion(
          sectionName: section.subjectName,
          question: q,
        ));
      }
    }
    _questions = flat;
    _startTimer();
    _examStartedAt = DateTime.now();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _openControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getOpenController(int idx) {
    return _openControllers.putIfAbsent(idx, () {
      final ctrl = TextEditingController(text: _answersByIndex[idx] ?? '');
      ctrl.addListener(() {
        _answersByIndex[idx] = ctrl.text;
      });
      return ctrl;
    });
  }

  void _startTimer() {
    final duration = Duration(minutes: widget.exam.durationMinutes);
    _examEndsAt = DateTime.now().add(duration);
    _remaining = duration;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final end = _examEndsAt;
      if (end == null) return;
      final diff = end.difference(DateTime.now());
      if (diff <= Duration.zero) {
        _timer?.cancel();
        if (mounted) {
          setState(() => _remaining = Duration.zero);
          _finish(auto: true);
        }
        return;
      }
      if (mounted) setState(() => _remaining = diff);
    });
  }

  String _fmt(Duration d) {
    final m = (d.inSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _selectAnswer(String label) {
    if (_isFinished) return;
    setState(() => _selectedLabel = label);
  }

  bool get _canConfirm {
    final q = _questions[_index];
    if (q.question.isOpen) {
      final text = _answersByIndex[_index]?.trim() ?? '';
      return text.isNotEmpty;
    }
    return _selectedLabel != null;
  }

  void _confirmAndNext() {
    if (_isFinished) return;

    final q = _questions[_index];

    if (q.question.isQcm) {
      if (_selectedLabel == null) return;
      final correct = q.question.choices.firstWhere(
        (c) => c.isCorrect,
        orElse: () => const ExamBlancChoice(label: '', text: '', isCorrect: false),
      );
      _answersByIndex[_index] = _selectedLabel;
      _isCorrectByIndex[_index] = _selectedLabel == correct.label;
    } else {
      // Open-ended: save text, mark as "pending" correction
      final text = _openControllers[_index]?.text.trim() ?? '';
      if (text.isEmpty) return;
      _answersByIndex[_index] = text;
      // For open questions, auto-correct not possible yet — mark as answered
      _isCorrectByIndex[_index] = false; // will be AI-corrected later
    }

    if (_index < _questions.length - 1) {
      setState(() {
        _index++;
        _selectedLabel = _answersByIndex[_index];
      });
    } else {
      _finish(auto: false);
    }
  }

  void _goToQuestion(int idx) {
    if (idx < 0 || idx >= _questions.length || _isFinished) return;
    setState(() {
      _index = idx;
      _selectedLabel = _answersByIndex[idx];
    });
  }

  Future<void> _finish({required bool auto}) async {
    if (_isFinished) return;

    if (!auto) {
      final unanswered = _questions.length - _answersByIndex.length;
      if (unanswered > 0) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Terminer l\'examen ?'),
            content: Text('Il te reste $unanswered question(s) sans réponse.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Continuer'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Terminer'),
              ),
            ],
          ),
        );
        if (confirm != true) return;
      }
    }

    _timer?.cancel();
    setState(() => _isFinished = true);

    final score = _isCorrectByIndex.values.where((v) => v).length;
    final total = _questions.length;
    final durationSec = _examStartedAt != null
        ? DateTime.now().difference(_examStartedAt!).inSeconds
        : null;

    // Submit to backend
    final provider = context.read<PrepConcoursProvider>();
    final answers = <Map<String, dynamic>>[];
    for (var i = 0; i < _questions.length; i++) {
      answers.add({
        'section': _questions[i].sectionName,
        'question': _questions[i].question.question,
        'answer': _answersByIndex[i],
        'is_correct': _isCorrectByIndex[i] ?? false,
      });
    }

    await provider.submitExamBlanc(
      examId: widget.exam.id,
      score: score,
      total: total,
      answers: answers,
      durationSeconds: durationSec,
    );
    if (!mounted) return;
    _showResults(score, total, durationSec);
  }

  void _showResults(int score, int total, int? durationSec) {
    final pct = total > 0 ? (score / total * 100) : 0.0;
    final color = pct >= 70
        ? Colors.green
        : pct >= 50
            ? Colors.orange
            : Colors.red;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Résultats'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              pct >= 70 ? Icons.emoji_events : Icons.assignment_turned_in,
              size: 56,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              '${pct.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text('$score / $total bonnes réponses'),
            if (durationSec != null) ...[
              const SizedBox(height: 4),
              Text(
                'Durée : ${(durationSec ~/ 60)} min ${(durationSec % 60)} sec',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 12),
            // Per-section breakdown
            ..._buildSectionBreakdown(),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Retour aux sujets'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSectionBreakdown() {
    final sectionScores = <String, List<int>>{};
    for (var i = 0; i < _questions.length; i++) {
      final name = _questions[i].sectionName;
      sectionScores.putIfAbsent(name, () => [0, 0]);
      sectionScores[name]![1]++;
      if (_isCorrectByIndex[i] == true) sectionScores[name]![0]++;
    }

    return sectionScores.entries.map((e) {
      final correct = e.value[0];
      final total = e.value[1];
      final pct = total > 0 ? (correct / total * 100) : 0.0;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(e.key, style: const TextStyle(fontSize: 12)),
            ),
            Text(
              '$correct/$total (${pct.toStringAsFixed(0)}%)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: pct >= 70
                    ? Colors.green
                    : pct >= 50
                        ? Colors.orange
                        : Colors.red,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.exam.title)),
        body: const Center(child: Text('Aucune question dans ce sujet.')),
      );
    }

    final q = _questions[_index];
    final isLast = _index == _questions.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        title: Text(
          '${_index + 1} / ${_questions.length}',
          style: const TextStyle(fontSize: 16),
        ),
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
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                _fmt(_remaining),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _remaining.inMinutes < 5 ? Colors.red[100] : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Section label + question type badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFA3D65C).withOpacity(0.15),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    q.sectionName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1EA75C),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: q.question.isOpen
                        ? Colors.orange.withOpacity(0.15)
                        : const Color(0xFF1EA75C).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    q.question.isOpen ? 'Rédaction' : 'QCM',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: q.question.isOpen ? Colors.orange[800] : const Color(0xFF1EA75C),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Question navigation dots
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _questions.length,
              itemBuilder: (ctx, i) {
                final answered = _answersByIndex.containsKey(i);
                final correct = _isCorrectByIndex[i];
                final isCurrent = i == _index;

                Color dotColor;
                if (_isFinished && correct != null) {
                  dotColor = correct ? Colors.green : Colors.red;
                } else if (answered) {
                  dotColor = const Color(0xFF1EA75C);
                } else if (isCurrent) {
                  dotColor = const Color(0xFFA3D65C);
                } else {
                  dotColor = Colors.grey[300]!;
                }

                return GestureDetector(
                  onTap: () => _goToQuestion(i),
                  child: Container(
                    width: 28,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: dotColor,
                      borderRadius: BorderRadius.circular(4),
                      border: isCurrent
                          ? Border.all(color: Colors.black26, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: answered || isCurrent
                              ? Colors.white
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Question + answer area (QCM or open-ended)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Points badge for open questions
                  if (q.question.isOpen)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${q.question.points} point(s)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  AcademiaRichContent(content: q.question.question),
                  const SizedBox(height: 16),

                  // ─── QCM choices ───
                  if (q.question.isQcm)
                    ...q.question.choices.map((choice) {
                      final isSelected = _selectedLabel == choice.label;
                      final showResult = _isFinished;
                      Color? cardColor;
                      if (showResult) {
                        if (choice.isCorrect) {
                          cardColor = Colors.green.withOpacity(0.1);
                        } else if (isSelected && !choice.isCorrect) {
                          cardColor = Colors.red.withOpacity(0.1);
                        }
                      } else if (isSelected) {
                        cardColor = const Color(0xFFA3D65C).withOpacity(0.2);
                      }

                      return Card(
                        elevation: 0,
                        color: cardColor ?? Colors.white,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF1EA75C)
                                : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _isFinished ? null : () => _selectAnswer(choice.label),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? const Color(0xFF1EA75C)
                                        : Colors.grey[200],
                                  ),
                                  child: Center(
                                    child: Text(
                                      choice.label,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(choice.text)),
                                if (showResult && choice.isCorrect)
                                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                if (showResult && isSelected && !choice.isCorrect)
                                  const Icon(Icons.cancel, color: Colors.red, size: 20),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                  // ─── Open-ended text input ───
                  if (q.question.isOpen) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isFinished ? Colors.grey[300]! : const Color(0xFF1EA75C).withOpacity(0.5),
                        ),
                      ),
                      child: TextField(
                        controller: _getOpenController(_index),
                        enabled: !_isFinished,
                        maxLines: 8,
                        minLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Rédigez votre réponse ici...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          contentPadding: const EdgeInsets.all(16),
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                    if (_isFinished) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Votre réponse sera évaluée par l\'IA',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],

                  // ─── Explanation / expected answer after finish ───
                  if (_isFinished && q.question.isQcm && q.question.explanation != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Explication :',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.blue),
                          ),
                          const SizedBox(height: 4),
                          Text(q.question.explanation!, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                  if (_isFinished && q.question.isOpen && q.question.expectedAnswer != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Corrigé type :',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.green),
                          ),
                          const SizedBox(height: 4),
                          Text(q.question.expectedAnswer!, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom action bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  if (_index > 0)
                    OutlinedButton(
                      onPressed: () => _goToQuestion(_index - 1),
                      child: const Text('Précédent'),
                    ),
                  const Spacer(),
                  if (!_isFinished)
                    FilledButton(
                      onPressed: _canConfirm ? _confirmAndNext : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1EA75C),
                      ),
                      child: Text(isLast ? 'Terminer' : 'Suivant'),
                    ),
                  if (_isFinished && !isLast)
                    FilledButton(
                      onPressed: () => _goToQuestion(_index + 1),
                      child: const Text('Suivant'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlatQuestion {
  final String sectionName;
  final ExamBlancQuestion question;

  const _FlatQuestion({required this.sectionName, required this.question});
}
