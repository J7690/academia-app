import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/academia_quiz_service.dart';

/// Overlay affiché chez l'étudiant quand un quiz est reçu via Data Channel.
class AcademiaQuizStudentOverlay extends StatefulWidget {
  final String? questionId;
  final String question;
  final List<String> options;
  final int durationSeconds;
  final VoidCallback onDismiss;

  const AcademiaQuizStudentOverlay({
    super.key,
    this.questionId,
    required this.question,
    required this.options,
    required this.durationSeconds,
    required this.onDismiss,
  });

  @override
  State<AcademiaQuizStudentOverlay> createState() =>
      _AcademiaQuizStudentOverlayState();
}

class _AcademiaQuizStudentOverlayState
    extends State<AcademiaQuizStudentOverlay> {
  final _quizService = AcademiaQuizService.instance;
  int? _selectedIndex;
  bool _submitted = false;
  bool? _isCorrect;
  late int _secondsLeft;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.durationSeconds;
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

    if (widget.questionId != null) {
      final correct = await _quizService.submitAnswer(
        questionId: widget.questionId!,
        selectedIndex: index,
      );
      if (mounted) setState(() => _isCorrect = correct);
    }

    // Auto dismiss après 3s
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) widget.onDismiss();
    });
  }

  void _autoSubmit() {
    if (_selectedIndex != null) {
      _submit(_selectedIndex!);
    } else {
      setState(() => _submitted = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) widget.onDismiss();
      });
    }
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
            border: Border.all(color: const Color(0xFF3B82F6), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header + timer
              Row(
                children: [
                  const Icon(Icons.quiz, color: Color(0xFF60A5FA), size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Quiz',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _secondsLeft <= 5
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
                widget.question,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              // Options
              ...List.generate(widget.options.length, (i) {
                final letter = ['A', 'B', 'C', 'D'][i];
                final isSelected = _selectedIndex == i;
                Color bgColor = const Color(0xFF0F172A);
                Color borderColor = const Color(0xFF334155);

                if (_submitted && isSelected) {
                  bgColor = _isCorrect == true
                      ? const Color(0xFF059669).withValues(alpha: 0.3)
                      : const Color(0xFFEF4444).withValues(alpha: 0.3);
                  borderColor = _isCorrect == true
                      ? const Color(0xFF34D399)
                      : const Color(0xFFEF4444);
                } else if (isSelected) {
                  bgColor = const Color(0xFF3B82F6).withValues(alpha: 0.2);
                  borderColor = const Color(0xFF3B82F6);
                }

                return GestureDetector(
                  onTap: _submitted ? null : () => _submit(i),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? borderColor
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
                            widget.options[i],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (_submitted && isSelected)
                          Icon(
                            _isCorrect == true
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: _isCorrect == true
                                ? const Color(0xFF34D399)
                                : const Color(0xFFEF4444),
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              }),
              // Feedback post-submit
              if (_submitted && _isCorrect != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _isCorrect == true ? '✓ Bonne réponse !' : '✗ Mauvaise réponse',
                    style: TextStyle(
                      color: _isCorrect == true
                          ? const Color(0xFF34D399)
                          : const Color(0xFFEF4444),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
