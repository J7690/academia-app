import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_config.dart';
import '../../../theme/td_theme.dart';

/// Onglet IA Tuteur TD — Chat IA adapté aux programmes universitaires BF.
/// Utilise l'Edge Function td-tutor-chat (pipeline TD séparé du concours).
class TdAiTutorTab extends StatefulWidget {
  const TdAiTutorTab({super.key});

  @override
  State<TdAiTutorTab> createState() => _TdAiTutorTabState();
}

class _TdAiTutorTabState extends State<TdAiTutorTab> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _sending = false;
  String? _selectedSubject;

  static const _subjects = [
    'Mathématiques', 'Physique', 'Chimie', 'Biologie',
    'Droit Civil', 'Droit Constitutionnel', 'Droit Administratif',
    'Économie', 'Gestion', 'Comptabilité',
    'Philosophie', 'Sociologie', 'Histoire', 'Géographie',
    'Informatique', 'Médecine', 'Agronomie', 'Lettres',
  ];

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text));
      _controller.clear();
      _sending = true;
    });
    _scrollToBottom();

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        setState(() {
          _messages.add(_ChatMessage(role: 'assistant', content: 'Vous devez être connecté pour utiliser le tuteur IA.'));
          _sending = false;
        });
        return;
      }

      final uri = Uri.parse('${SupabaseConfig.url}/functions/v1/td-tutor-chat');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'apikey': SupabaseConfig.anonKey,
        },
        body: jsonEncode({
          'message': text,
          if (_selectedSubject != null) 'subject': _selectedSubject,
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = (data['reply'] ?? 'Désolé, je n\'ai pas pu répondre.').toString();
        setState(() => _messages.add(_ChatMessage(role: 'assistant', content: reply)));
      } else {
        setState(() => _messages.add(_ChatMessage(role: 'assistant', content: 'Erreur du serveur (${response.statusCode}). Réessayez.')));
      }
    } catch (e) {
      setState(() => _messages.add(_ChatMessage(role: 'assistant', content: 'Erreur de connexion. Vérifiez votre réseau.')));
    } finally {
      setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Subject selector
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: TdTheme.scaffoldBg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Matière :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF616161))),
              const SizedBox(height: 6),
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _SubjectChip(
                      label: 'Toutes',
                      isSelected: _selectedSubject == null,
                      onTap: () => setState(() => _selectedSubject = null),
                    ),
                    ..._subjects.map((s) => _SubjectChip(
                      label: s,
                      isSelected: _selectedSubject == s,
                      onTap: () => setState(() => _selectedSubject = s),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: _messages.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_sending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _sending) {
                      return const _TypingIndicator();
                    }
                    return _MessageBubble(message: _messages[index]);
                  },
                ),
        ),

        // Input
        Container(
          padding: EdgeInsets.only(
            left: 16, right: 8, top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : MediaQuery.of(context).padding.bottom + 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 8, offset: const Offset(0, -2))],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Posez votre question ou soumettez un exercice...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: _sending ? null : _sendMessage,
                icon: Icon(Icons.send_rounded, color: _sending ? const Color(0xFFBDBDBD) : TdTheme.studentTdGradient[1]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        Icon(Icons.auto_awesome, size: 48, color: TdTheme.studentTdGradient[1].withAlpha(120)),
        const SizedBox(height: 16),
        const Text('Tuteur IA — Cours d\'appui', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(
          'Je suis votre assistant pour toutes les matières universitaires.\n'
          'Posez une question, soumettez un exercice ou demandez une explication.\n\n'
          '⚠️ Les réponses IA sont fournies à titre indicatif et peuvent contenir des erreurs. '
          'Elles ne remplacent pas un enseignant qualifié.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF757575), height: 1.5),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _SuggestionChip('Résoudre une intégrale', onTap: () {
              _controller.text = 'Aide-moi à résoudre cette intégrale : ∫(2x + 3)dx';
              _sendMessage();
            }),
            _SuggestionChip('Expliquer un concept de droit', onTap: () {
              _controller.text = 'Explique-moi le principe de la responsabilité civile délictuelle en droit burkinabè.';
              _sendMessage();
            }),
            _SuggestionChip('Méthode de dissertation', onTap: () {
              _controller.text = 'Quelle est la méthode pour rédiger une bonne dissertation juridique ?';
              _sendMessage();
            }),
            _SuggestionChip('Exercice de comptabilité', onTap: () {
              _controller.text = 'Aide-moi à passer cette écriture comptable selon le SYSCOHADA révisé.';
              _sendMessage();
            }),
          ],
        ),
      ],
    );
  }
}

class _ChatMessage {
  final String role;
  final String content;
  _ChatMessage({required this.role, required this.content});
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser ? TdTheme.studentTdGradient[1] : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.auto_awesome, size: 14, color: TdTheme.studentTdGradient[1]),
                  const SizedBox(width: 4),
                  Text('Tuteur IA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: TdTheme.studentTdGradient[1])),
                ]),
              ),
            SelectableText(
              message.content,
              style: TextStyle(fontSize: 14, color: isUser ? Colors.white : const Color(0xFF212121), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: TdTheme.studentTdGradient[1])),
          const SizedBox(width: 10),
          const Text('Le tuteur réfléchit...', style: TextStyle(fontSize: 12, color: Color(0xFF757575))),
        ]),
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _SubjectChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? TdTheme.studentTdGradient[1] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? TdTheme.studentTdGradient[1] : const Color(0xFFBDBDBD)),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF616161))),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: TdTheme.studentTdGradient[1].withAlpha(15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: TdTheme.studentTdGradient[1].withAlpha(60)),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: TdTheme.studentTdGradient[1], fontWeight: FontWeight.w500)),
      ),
    );
  }
}
