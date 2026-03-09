import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/student_direct_messages_provider.dart';
import '../../widgets/user_avatar.dart';
import 'student_dm_chat_screen.dart';

/// Liste des conversations privées (1-à-1) style WhatsApp
class StudentDmConversationsScreen extends StatefulWidget {
  const StudentDmConversationsScreen({super.key});

  @override
  State<StudentDmConversationsScreen> createState() =>
      _StudentDmConversationsScreenState();
}

class _StudentDmConversationsScreenState
    extends State<StudentDmConversationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentDirectMessagesProvider>().loadConversations();
    });
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(dt.year, dt.month, dt.day);
    if (msgDate == today) {
      return DateFormat('HH:mm').format(dt);
    } else if (msgDate == today.subtract(const Duration(days: 1))) {
      return 'Hier';
    }
    return DateFormat('dd/MM/yy').format(dt);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        elevation: 1,
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        title: const Text(
          'Messages privés',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
      ),
      body: Consumer<StudentDirectMessagesProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.conversations.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final convs = provider.conversations;
          if (convs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune conversation privée',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tape sur le nom d\'un membre dans un groupe pour démarrer une conversation.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: provider.loadConversations,
            child: ListView.builder(
              itemCount: convs.length,
              itemBuilder: (context, index) {
                final c = convs[index];
                final name =
                    c['other_display_name']?.toString() ?? 'Utilisateur';
                final lastMsg = c['last_message_content']?.toString() ?? '';
                final unread = c['unread_count'] is int
                    ? c['unread_count'] as int
                    : 0;
                final timeStr =
                    _formatTime(c['last_message_at']?.toString());
                final convId = c['conversation_id']?.toString() ?? '';
                final otherUserId = c['other_user_id']?.toString() ?? '';

                return FadeInUp(
                  duration: const Duration(milliseconds: 300),
                  delay: Duration(milliseconds: 60 * index),
                  child: ListTile(
                    leading: UserAvatar(
                      name: name,
                      radius: 24,
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontWeight:
                            unread > 0 ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      lastMsg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: unread > 0
                            ? Colors.black87
                            : Colors.grey.shade600,
                        fontWeight:
                            unread > 0 ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: unread > 0
                                ? const Color(0xFF25D366)
                                : Colors.grey.shade500,
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFF25D366),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unread > 99 ? '99+' : unread.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StudentDmChatScreen(
                            conversationId: convId,
                            otherUserName: name,
                            otherUserId: otherUserId,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
