import 'package:flutter/material.dart';

/// Overlay de création de quiz pour l'hôte AcademiaClassroom.
class AcademiaQuizOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final void Function(Map<String, dynamic> question) onSendQuestion;

  const AcademiaQuizOverlay({
    super.key,
    required this.onClose,
    required this.onSendQuestion,
  });

  @override
  State<AcademiaQuizOverlay> createState() => _AcademiaQuizOverlayState();
}

class _AcademiaQuizOverlayState extends State<AcademiaQuizOverlay> {
  final _questionCtrl = TextEditingController();
  final _optionCtrls = List.generate(4, (_) => TextEditingController());
  int _correctIndex = 0;
  int _durationSeconds = 30;

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _send() {
    final question = _questionCtrl.text.trim();
    if (question.isEmpty) return;
    final options = _optionCtrls.map((c) => c.text.trim()).toList();
    if (options.any((o) => o.isEmpty)) return;

    widget.onSendQuestion({
      'question': question,
      'options': options,
      'correct_index': _correctIndex,
      'duration_seconds': _durationSeconds,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: widget.onClose,
        child: Container(
          color: Colors.black54,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(Icons.quiz, color: Color(0xFF60A5FA), size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Envoyer un quiz',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                          onPressed: widget.onClose,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Question
                    _Field(
                      controller: _questionCtrl,
                      label: 'Question',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    // Options A-D
                    ...List.generate(4, (i) {
                      final letter = ['A', 'B', 'C', 'D'][i];
                      final isSelected = _correctIndex == i;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _correctIndex = i),
                              child: Container(
                                width: 22,
                                height: 22,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF34D399)
                                        : Colors.white38,
                                    width: 2,
                                  ),
                                  color: isSelected
                                      ? const Color(0xFF34D399)
                                      : Colors.transparent,
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check,
                                        size: 14, color: Colors.white)
                                    : null,
                              ),
                            ),
                            Expanded(
                              child: _Field(
                                controller: _optionCtrls[i],
                                label: 'Option $letter',
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    // Durée
                    Row(
                      children: [
                        const Text(
                          'Durée (s) :',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(width: 12),
                        ...([15, 30, 60].map(
                          (d) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('${d}s'),
                              selected: _durationSeconds == d,
                              selectedColor: const Color(0xFF3B82F6),
                              onSelected: (_) =>
                                  setState(() => _durationSeconds = d),
                              labelStyle: TextStyle(
                                color: _durationSeconds == d
                                    ? Colors.white
                                    : Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Bouton envoyer
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.send, size: 16),
                        label: const Text('Envoyer aux participants'),
                        onPressed: _send,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;

  const _Field({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3B82F6)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
