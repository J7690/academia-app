import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/support_messages_provider.dart';
import '../features/support/support_chat_screen.dart';

/// Bouton flottant "Messagerie Support" avec badge non-lus.
/// Poll toutes les 30s pour récupérer le compteur de messages non lus.
class SupportFab extends StatefulWidget {
  const SupportFab({super.key});

  @override
  State<SupportFab> createState() => _SupportFabState();
}

class _SupportFabState extends State<SupportFab> {
  int _unreadCount = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadUnread();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadUnread();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUnread() async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) return;
      final dynamic response = await client.rpc('app_get_support_unread_count');
      if (response is Map<String, dynamic> && response['success'] == true) {
        final count = response['unread_count'];
        if (mounted) {
          setState(() {
            _unreadCount = count is int ? count : 0;
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton(
          heroTag: 'support_fab',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider(
                  create: (_) => SupportMessagesProvider(),
                  child: const SupportChatScreen(),
                ),
              ),
            ).then((_) {
              if (mounted) _loadUnread();
            });
          },
          backgroundColor: const Color(0xFF25D366),
          elevation: 4,
          child: const Icon(Icons.support_agent, color: Colors.white, size: 26),
        ),
        if (_unreadCount > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: const BoxDecoration(
                color: Color(0xFFFF3B30),
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              child: Center(
                child: Text(
                  _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
