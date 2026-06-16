import 'package:flutter/material.dart';

import '../../../services/academia_ai_service.dart';

/// Panneau IA pédagogique pour AcademiaClassroom.
///
/// Permet aux participants de poser des questions à l'IA,
/// demander un résumé, ou générer un exercice.
class AcademiaAiPanel extends StatefulWidget {
  final String sessionId;
  final String? courseSubject;
  final List<String> recentMessages;

  const AcademiaAiPanel({
    super.key,
    required this.sessionId,
    this.courseSubject,
    this.recentMessages = const [],
  });

  @override
  State<AcademiaAiPanel> createState() => _AcademiaAiPanelState();
}

class _AcademiaAiPanelState extends State<AcademiaAiPanel> {
  final _ai = AcademiaAiService.instance;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_AiMessage> _messages = [];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    _controller.clear();

    setState(() {
      _messages.add(_AiMessage(text, isUser: true));
      _loading = true;
    });
    _scrollToBottom();

    final response = await _ai.answerQuestion(
      question: text,
      sessionId: widget.sessionId,
      courseSubject: widget.courseSubject,
    );

    if (!mounted) return;
    setState(() {
      _messages.add(_AiMessage(
        response ?? 'Désolé, je n\'ai pas pu répondre.',
        isUser: false,
      ));
      _loading = false;
    });
    _scrollToBottom();
  }

  Future<void> _summarize() async {
    if (_loading) return;
    setState(() {
      _messages.add(_AiMessage('Résumé de la session…', isUser: true));
      _loading = true;
    });
    _scrollToBottom();

    final response = await _ai.summarizeSession(
      sessionId: widget.sessionId,
      recentMessages: widget.recentMessages,
    );

    if (!mounted) return;
    setState(() {
      _messages.add(_AiMessage(
        response ?? 'Impossible de générer le résumé.',
        isUser: false,
      ));
      _loading = false;
    });
    _scrollToBottom();
  }

  Future<void> _generateExercise() async {
    if (_loading) return;
    setState(() {
      _messages.add(_AiMessage('Générer un exercice…', isUser: true));
      _loading = true;
    });
    _scrollToBottom();

    final response = await _ai.generateExercise(
      subject: widget.courseSubject ?? 'matière générale',
      sessionId: widget.sessionId,
    );

    if (!mounted) return;
    setState(() {
      _messages.add(_AiMessage(
        response ?? 'Impossible de générer l\'exercice.',
        isUser: false,
      ));
      _loading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(left: BorderSide(color: Color(0xFF334155), width: 1)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF0F172A),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Color(0xFFFBBF24), size: 16),
                SizedBox(width: 8),
                Text(
                  'Assistant IA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Quick actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                _ActionChip('Résumé', Icons.summarize, _summarize),
                const SizedBox(width: 6),
                _ActionChip('Exercice', Icons.school, _generateExercise),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'Posez une question à l\'IA',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _messages.length) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFBBF24),
                              ),
                            ),
                          ),
                        );
                      }
                      return _buildMessage(_messages[i]);
                    },
                  ),
          ),
          // Input
          Container(
            padding: const EdgeInsets.all(8),
            color: const Color(0xFF0F172A),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Demandez à l\'IA…',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _ask(),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _ask,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFBBF24),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child:
                        const Icon(Icons.send, color: Colors.black, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(_AiMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment:
            msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(
              left: msg.isUser ? 40 : 0,
              right: msg.isUser ? 0 : 40,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: msg.isUser
                  ? const Color(0xFF334155)
                  : const Color(0xFF1E3A5F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              msg.content,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiMessage {
  final String content;
  final bool isUser;
  _AiMessage(this.content, {required this.isUser});
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionChip(this.label, this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF334155),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF475569)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFFBBF24), size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
