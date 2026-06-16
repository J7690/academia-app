import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/academia_chat_service.dart';

/// Panneau de chat persistant pour AcademiaClassroom.
///
/// Charge l'historique depuis Supabase, écoute les nouveaux messages
/// via Realtime, et envoie via RPC.
class AcademiaPersistentChatPanel extends StatefulWidget {
  final String sessionId;
  final String localUserId;
  final String localDisplayName;

  const AcademiaPersistentChatPanel({
    super.key,
    required this.sessionId,
    required this.localUserId,
    required this.localDisplayName,
  });

  @override
  State<AcademiaPersistentChatPanel> createState() =>
      _AcademiaPersistentChatPanelState();
}

class _AcademiaPersistentChatPanelState
    extends State<AcademiaPersistentChatPanel> {
  final _service = AcademiaChatService.instance;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    if (_channel != null) _service.unsubscribe(_channel!);
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final msgs = await _service.loadMessages(sessionId: widget.sessionId);
    if (!mounted) return;
    setState(() {
      _messages.addAll(msgs.reversed);
      _loading = false;
    });
    _scrollToBottom();
  }

  void _subscribeRealtime() {
    _channel = _service.subscribeToMessages(
      sessionId: widget.sessionId,
      onInsert: (payload) {
        if (!mounted) return;
        // Éviter les doublons avec nos propres messages
        final id = payload['id']?.toString();
        if (_messages.any((m) => m['id'] == id)) return;
        setState(() => _messages.add(payload));
        _scrollToBottom();
      },
    );
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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    // Optimistic insert
    final optimistic = {
      'id': 'opt_${DateTime.now().millisecondsSinceEpoch}',
      'sender_id': widget.localUserId,
      'sender_name': widget.localDisplayName,
      'content': text,
      'message_type': 'text',
      'created_at': DateTime.now().toIso8601String(),
    };
    setState(() => _messages.add(optimistic));
    _scrollToBottom();

    await _service.sendMessage(
      sessionId: widget.sessionId,
      content: text,
    );
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
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Chat',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${_messages.length}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: Color(0xFF60A5FA)))
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucun message',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _buildMessage(_messages[i]),
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
                      hintText: 'Message…',
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
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.send, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final senderId = msg['sender_id']?.toString() ?? '';
    final isMe = senderId == widget.localUserId;
    final name = (msg['sender_name'] ?? 'Utilisateur').toString();
    final content = (msg['content'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Text(
              name,
              style: const TextStyle(
                color: Color(0xFF60A5FA),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          Container(
            margin: EdgeInsets.only(
              top: 2,
              left: isMe ? 40 : 0,
              right: isMe ? 0 : 40,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isMe
                  ? const Color(0xFF3B82F6).withValues(alpha: 0.8)
                  : const Color(0xFF334155),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(isMe ? 12 : 2),
                bottomRight: Radius.circular(isMe ? 2 : 12),
              ),
            ),
            child: Text(
              content,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
