import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/academia_practice_engine.dart';

/// Overlay d'exercice TD en live pour l'étudiant.
class AcademiaTdExerciseOverlay extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final String sessionId;
  final VoidCallback onDismiss;

  const AcademiaTdExerciseOverlay({
    super.key,
    required this.exercise,
    required this.sessionId,
    required this.onDismiss,
  });

  @override
  State<AcademiaTdExerciseOverlay> createState() =>
      _AcademiaTdExerciseOverlayState();
}

class _AcademiaTdExerciseOverlayState
    extends State<AcademiaTdExerciseOverlay> {
  final _engine = AcademiaPracticeEngine.instance;
  int? _selectedIndex;
  bool _submitted = false;
  late int _secondsLeft;
  Timer? _timer;

  String get _questionId => widget.exercise['question_id']?.toString() ?? '';
  String get _content => widget.exercise['content']?.toString() ?? '';
  List<String> get _options {
    final opts = widget.exercise['options'];
    if (opts is List) return opts.map((e) => e.toString()).toList();
    return [];
  }

  int get _timeLimit =>
      (widget.exercise['time_limit_seconds'] as int?) ?? 60;

  @override
  void initState() {
    super.initState();
    _secondsLeft = _timeLimit;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        _timer?.cancel();
        if (!_submitted) _autoSubmit();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _submit(int index) async {
    if (_submitted) return;
    setState(() {
      _selectedIndex = index;
      _submitted = true;
    });

    await _engine.submitAnswer(
      questionId: _questionId,
      sessionId: widget.sessionId,
      selectedIndex: index,
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) widget.onDismiss();
    });
  }

  void _autoSubmit() {
    setState(() => _submitted = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFBBF24), width: 2),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.school, color: Color(0xFFFBBF24), size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Exercice TD',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _secondsLeft <= 10
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_secondsLeft}s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Question
                Text(
                  _content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                // Options
                ...List.generate(_options.length, (i) {
                  final letter = ['A', 'B', 'C', 'D', 'E', 'F'][i];
                  final isSelected = _selectedIndex == i;

                  return GestureDetector(
                    onTap: _submitted ? null : () => _submit(i),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                            : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF334155),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? const Color(0xFF3B82F6)
                                  : Colors.white12,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              letter,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _options[i],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                // Feedback
                if (_submitted)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '✓ Réponse soumise',
                      style: TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
