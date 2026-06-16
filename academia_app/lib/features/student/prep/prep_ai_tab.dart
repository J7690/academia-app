import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

import '../../../services/prep_ai_service.dart';
import '../../../theme/prep_theme.dart';

/// Onglet IA Tutor — Chat IA contextuel pour aide à la préparation.
class PrepAiTab extends StatefulWidget {
  const PrepAiTab({super.key});

  @override
  State<PrepAiTab> createState() => _PrepAiTabState();
}

class _PrepAiTabState extends State<PrepAiTab> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMessage(
      role: _Role.assistant,
      content:
          'Salut ! 👋 Je suis ton tuteur IA pour la préparation aux concours. '
          'Pose-moi n\'importe quelle question : exercices de maths, droit constitutionnel, '
          'culture générale, méthodologie de dissertation… Je suis là pour t\'aider ! 🎯\n\n'
          '⚠️ _Les réponses IA sont fournies à titre indicatif et peuvent contenir des erreurs. '
          'Elles ne remplacent pas un enseignant qualifié._',
    ));
    _initConversation();
  }

  Future<void> _initConversation() async {
    _conversationId = await PrepAiService.createConversation(
      title: 'Tuteur IA',
      subject: 'Général',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(role: _Role.user, content: text));
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    _callAi(text);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _callAi(String text) async {
    // Build history for context
    final history = _messages
        .where((m) => m.role != _Role.assistant || _messages.indexOf(m) > 0)
        .map((m) => {
              'role': m.role == _Role.user ? 'user' : 'assistant',
              'content': m.content,
            })
        .toList();

    try {
      final response = await PrepAiService.chat(
        conversationId: _conversationId,
        messages: history,
        userMessage: text,
      );
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(_ChatMessage(role: _Role.assistant, content: response));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(_ChatMessage(
          role: _Role.assistant,
          content: 'Désolé, une erreur est survenue. Réessaie dans un instant. 🔄',
        ));
      });
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ─── Header ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: PrepTheme.aiGradient),
            boxShadow: PrepTheme.glowShadow(PrepTheme.xpPurple),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tuteur IA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Pose tes questions, je t\'explique tout',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(PrepTheme.radiusFull),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: Color(0xFF4ADE80), size: 8),
                      SizedBox(width: 6),
                      Text('En ligne',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ─── Suggestions chips ───────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _SuggestionChip('Explique la séparation des pouvoirs', onTap: () {
                  _controller.text = 'Explique-moi la séparation des pouvoirs';
                  _sendMessage();
                }),
                _SuggestionChip('Méthode de dissertation', onTap: () {
                  _controller.text = 'Quelle est la méthode pour une bonne dissertation ?';
                  _sendMessage();
                }),
                _SuggestionChip('Préparer l\'ENAREF', onTap: () {
                  _controller.text = 'Comment bien préparer le concours de l\'ENAREF au Burkina Faso ?';
                  _sendMessage();
                }),
                _SuggestionChip('Résoudre une équation', onTap: () {
                  _controller.text = 'Aide-moi à résoudre une équation mathématique';
                  _sendMessage();
                }),
              ],
            ),
          ),
        ),

        // ─── Messages ────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _messages.length + (_isTyping ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length && _isTyping) {
                return _TypingIndicator();
              }
              final msg = _messages[index];
              return _MessageBubble(message: msg, index: index);
            },
          ),
        ),

        // ─── Input ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: PrepTheme.cardBg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: PrepTheme.scaffoldBg,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Pose ta question…',
                        hintStyle: TextStyle(color: PrepTheme.textTertiary, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: PrepTheme.aiGradient),
                    shape: BoxShape.circle,
                    boxShadow: PrepTheme.glowShadow(PrepTheme.xpPurple),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Models ──────────────────────────────────────────────────────
enum _Role { user, assistant }

class _ChatMessage {
  final _Role role;
  final String content;

  const _ChatMessage({required this.role, required this.content});
}

// ─── Widgets ─────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final int index;

  const _MessageBubble({required this.message, required this.index});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == _Role.user;

    return FadeInUp(
      duration: const Duration(milliseconds: 300),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          decoration: BoxDecoration(
            color: isUser ? PrepTheme.primary : PrepTheme.cardBg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            boxShadow: isUser ? [] : PrepTheme.softShadow,
            border: isUser ? null : Border.all(color: PrepTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: PrepTheme.aiGradient),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 12),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Tuteur IA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: PrepTheme.xpPurple,
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                message.content,
                style: TextStyle(
                  fontSize: 14,
                  color: isUser ? Colors.white : PrepTheme.textPrimary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FadeInUp(
        duration: const Duration(milliseconds: 300),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PrepTheme.cardBg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
            ),
            boxShadow: PrepTheme.softShadow,
            border: Border.all(color: PrepTheme.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DotPulse(delay: 0),
              const SizedBox(width: 4),
              _DotPulse(delay: 200),
              const SizedBox(width: 4),
              _DotPulse(delay: 400),
            ],
          ),
        ),
      ),
    );
  }
}

class _DotPulse extends StatefulWidget {
  final int delay;

  const _DotPulse({required this.delay});

  @override
  State<_DotPulse> createState() => _DotPulseState();
}

class _DotPulseState extends State<_DotPulse> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: PrepTheme.xpPurple,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip(this.label, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: PrepTheme.xpPurpleSurface,
            borderRadius: BorderRadius.circular(PrepTheme.radiusFull),
            border: Border.all(color: PrepTheme.xpPurple.withOpacity(0.2)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: PrepTheme.xpPurple,
            ),
          ),
        ),
      ),
    );
  }
}
