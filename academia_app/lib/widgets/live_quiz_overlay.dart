import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

/// Live quiz overlay for LiveKit rooms.
/// Host creates questions, students answer, results are shown in real-time.
///
/// Data Channel protocol:
/// - topic: 'quiz_question' → { question, options: [...], questionIndex, totalQuestions }
/// - topic: 'quiz_answer'   → { sender, questionIndex, selectedIndex }
/// - topic: 'quiz_results'  → { questionIndex, correctIndex, counts: [int,...], totalResponses }

class LiveQuizOverlay extends StatefulWidget {
  final Room room;
  final bool isHost;
  final String displayName;
  final VoidCallback onClose;

  const LiveQuizOverlay({
    super.key,
    required this.room,
    required this.isHost,
    required this.displayName,
    required this.onClose,
  });

  @override
  State<LiveQuizOverlay> createState() => _LiveQuizOverlayState();
}

class _LiveQuizOverlayState extends State<LiveQuizOverlay> {
  // Host state
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  int _correctIndex = 0;
  int _questionIndex = 0;
  bool _questionSent = false;
  final Map<String, int> _responses = {}; // sender → selectedIndex
  List<int> _answerCounts = [0, 0, 0, 0];

  // Student state
  String? _currentQuestion;
  List<String> _currentOptions = [];
  int? _selectedAnswer;
  bool _answered = false;
  int? _revealedCorrectIndex;
  List<int>? _revealedCounts;
  int? _revealedTotal;

  EventsListener<RoomEvent>? _quizListener;

  @override
  void initState() {
    super.initState();
    _quizListener = widget.room.createListener();
    _quizListener!.on<DataReceivedEvent>(_onData);
  }

  @override
  void dispose() {
    _quizListener?.dispose();
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onData(DataReceivedEvent event) {
    if (!mounted) return;
    try {
      final map = jsonDecode(utf8.decode(event.data)) as Map<String, dynamic>;

      if (event.topic == 'quiz_question' && !widget.isHost) {
        setState(() {
          _currentQuestion = (map['question'] ?? '').toString();
          final opts = map['options'];
          _currentOptions = opts is List ? opts.map((e) => e.toString()).toList() : [];
          _questionIndex = (map['questionIndex'] as int?) ?? 0;
          _selectedAnswer = null;
          _answered = false;
          _revealedCorrectIndex = null;
          _revealedCounts = null;
        });
      } else if (event.topic == 'quiz_answer' && widget.isHost) {
        final sender = (map['sender'] ?? '').toString();
        final idx = (map['selectedIndex'] as int?) ?? 0;
        setState(() {
          _responses[sender] = idx;
          _answerCounts = [0, 0, 0, 0];
          for (final v in _responses.values) {
            if (v >= 0 && v < _answerCounts.length) _answerCounts[v]++;
          }
        });
      } else if (event.topic == 'quiz_results') {
        final correctIdx = (map['correctIndex'] as int?) ?? 0;
        final counts = map['counts'];
        final total = (map['totalResponses'] as int?) ?? 0;
        setState(() {
          _revealedCorrectIndex = correctIdx;
          _revealedCounts = counts is List ? counts.map((e) => (e as int?) ?? 0).toList() : [];
          _revealedTotal = total;
        });
      }
    } catch (_) {}
  }

  void _sendQuestion() {
    final q = _questionController.text.trim();
    if (q.isEmpty) return;
    final options = _optionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    if (options.length < 2) return;

    final payload = jsonEncode({
      'question': q,
      'options': options,
      'questionIndex': _questionIndex,
    });
    try {
      widget.room.localParticipant?.publishData(
        utf8.encode(payload), reliable: true, topic: 'quiz_question',
      );
    } catch (_) {}

    setState(() {
      _questionSent = true;
      _responses.clear();
      _answerCounts = List.filled(options.length, 0);
      // Host also sees the question locally
      _currentQuestion = q;
      _currentOptions = options;
    });
  }

  void _sendAnswer(int idx) {
    if (_answered) return;
    final sender = widget.displayName.isNotEmpty
        ? widget.displayName
        : (widget.room.localParticipant?.identity ?? 'Student');
    final payload = jsonEncode({
      'sender': sender,
      'questionIndex': _questionIndex,
      'selectedIndex': idx,
    });
    try {
      widget.room.localParticipant?.publishData(
        utf8.encode(payload), reliable: true, topic: 'quiz_answer',
      );
    } catch (_) {}
    setState(() {
      _selectedAnswer = idx;
      _answered = true;
    });
  }

  void _revealResults() {
    final payload = jsonEncode({
      'questionIndex': _questionIndex,
      'correctIndex': _correctIndex,
      'counts': _answerCounts,
      'totalResponses': _responses.length,
    });
    try {
      widget.room.localParticipant?.publishData(
        utf8.encode(payload), reliable: true, topic: 'quiz_results',
      );
    } catch (_) {}
    setState(() {
      _revealedCorrectIndex = _correctIndex;
      _revealedCounts = List.from(_answerCounts);
      _revealedTotal = _responses.length;
    });
  }

  void _nextQuestion() {
    setState(() {
      _questionIndex++;
      _questionSent = false;
      _questionController.clear();
      for (final c in _optionControllers) {
        c.clear();
      }
      _correctIndex = 0;
      _responses.clear();
      _answerCounts = [0, 0, 0, 0];
      _currentQuestion = null;
      _currentOptions = [];
      _selectedAnswer = null;
      _answered = false;
      _revealedCorrectIndex = null;
      _revealedCounts = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(20),
            ),
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: widget.isHost ? _buildHostView() : _buildStudentView(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHostView() {
    if (!_questionSent) {
      return _buildQuestionForm();
    }
    return _buildHostResultsView();
  }

  Widget _buildQuestionForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.quiz, color: Color(0xFF1EA75C), size: 22),
            const SizedBox(width: 8),
            Text('Question ${_questionIndex + 1}',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close, color: Colors.white54, size: 20)),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _questionController,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          maxLines: 2,
          decoration: _inputDeco('Saisissez la question...'),
        ),
        const SizedBox(height: 12),
        ...List.generate(_optionControllers.length, (i) {
          final labels = ['A', 'B', 'C', 'D'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _correctIndex = i),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _correctIndex == i ? const Color(0xFF1EA75C) : Colors.white12,
                    ),
                    alignment: Alignment.center,
                    child: Text(labels[i],
                        style: TextStyle(
                          color: _correctIndex == i ? Colors.white : Colors.white54,
                          fontSize: 12, fontWeight: FontWeight.w700,
                        )),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _optionControllers[i],
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: _inputDeco('Option ${labels[i]}'),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        const Text('Tapez sur la lettre pour marquer la bonne réponse.',
            style: TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _sendQuestion,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1EA75C),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: const Icon(Icons.send, size: 18),
          label: const Text('Envoyer la question'),
        ),
      ],
    );
  }

  Widget _buildHostResultsView() {
    final totalResponses = _responses.length;
    final revealed = _revealedCorrectIndex != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.bar_chart, color: Color(0xFF6366F1), size: 22),
            const SizedBox(width: 8),
            Text('Résultats ($totalResponses réponses)',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close, color: Colors.white54, size: 20)),
          ],
        ),
        const SizedBox(height: 8),
        if (_currentQuestion != null)
          Text(_currentQuestion!, style: const TextStyle(color: Colors.white, fontSize: 14)),
        const SizedBox(height: 12),
        ...List.generate(_currentOptions.length, (i) {
          final count = i < _answerCounts.length ? _answerCounts[i] : 0;
          final pct = totalResponses > 0 ? (count / totalResponses * 100).round() : 0;
          final isCorrect = revealed && i == _revealedCorrectIndex;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isCorrect ? const Color(0xFF1EA75C).withValues(alpha: 0.3) : Colors.white10,
                border: isCorrect ? Border.all(color: const Color(0xFF1EA75C), width: 2) : null,
              ),
              child: Row(
                children: [
                  Expanded(child: Text(_currentOptions[i],
                      style: const TextStyle(color: Colors.white, fontSize: 13))),
                  Text('$count ($pct%)',
                      style: TextStyle(
                        color: isCorrect ? const Color(0xFF1EA75C) : Colors.white54,
                        fontSize: 12, fontWeight: FontWeight.w600,
                      )),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        if (!revealed)
          ElevatedButton.icon(
            onPressed: _revealResults,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.visibility, size: 18),
            label: const Text('Révéler la réponse'),
          )
        else
          ElevatedButton.icon(
            onPressed: _nextQuestion,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1EA75C),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.navigate_next, size: 18),
            label: const Text('Question suivante'),
          ),
      ],
    );
  }

  Widget _buildStudentView() {
    if (_currentQuestion == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.hourglass_empty, color: Colors.white38, size: 40),
          const SizedBox(height: 12),
          const Text('En attente de la question du professeur...',
              style: TextStyle(color: Colors.white54, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton(onPressed: widget.onClose, child: const Text('Fermer', style: TextStyle(color: Colors.white38))),
        ],
      );
    }

    final revealed = _revealedCorrectIndex != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.quiz, color: Color(0xFF1EA75C), size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text('Question ${_questionIndex + 1}',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
            IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close, color: Colors.white54, size: 20)),
          ],
        ),
        const SizedBox(height: 8),
        Text(_currentQuestion!, style: const TextStyle(color: Colors.white, fontSize: 14)),
        const SizedBox(height: 12),
        ...List.generate(_currentOptions.length, (i) {
          final isSelected = _selectedAnswer == i;
          final isCorrect = revealed && i == _revealedCorrectIndex;
          final isWrong = revealed && isSelected && i != _revealedCorrectIndex;
          Color bgColor = Colors.white10;
          Color borderColor = Colors.transparent;
          if (isCorrect) {
            bgColor = const Color(0xFF1EA75C).withValues(alpha: 0.3);
            borderColor = const Color(0xFF1EA75C);
          } else if (isWrong) {
            bgColor = Colors.redAccent.withValues(alpha: 0.3);
            borderColor = Colors.redAccent;
          } else if (isSelected && !revealed) {
            bgColor = const Color(0xFF6366F1).withValues(alpha: 0.3);
            borderColor = const Color(0xFF6366F1);
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: _answered ? null : () => _sendAnswer(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: bgColor,
                  border: borderColor != Colors.transparent ? Border.all(color: borderColor, width: 2) : null,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(_currentOptions[i],
                        style: const TextStyle(color: Colors.white, fontSize: 13))),
                    if (isCorrect) const Icon(Icons.check_circle, color: Color(0xFF1EA75C), size: 18),
                    if (isWrong) const Icon(Icons.cancel, color: Colors.redAccent, size: 18),
                    if (revealed && _revealedCounts != null && i < _revealedCounts!.length)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          '${_revealedCounts![i]}${_revealedTotal != null && _revealedTotal! > 0 ? " (${(_revealedCounts![i] / _revealedTotal! * 100).round()}%)" : ""}',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
        if (_answered && !revealed)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Réponse envoyée. En attente des résultats...',
                style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
          ),
      ],
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
      filled: true, fillColor: Colors.white10, isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    );
  }
}
