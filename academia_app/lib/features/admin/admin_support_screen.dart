import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_support_provider.dart';
import 'admin_support_chat_screen.dart';

/// Écran admin: Inbox des conversations Support (tous rôles).
class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminSupportProvider>().loadConversations();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(dt.year, dt.month, dt.day);
    if (msgDate == today) return DateFormat('HH:mm').format(dt);
    if (msgDate == today.subtract(const Duration(days: 1))) return 'Hier';
    return DateFormat('dd/MM/yy').format(dt);
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'student':
        return const Color(0xFF2E7D32);
      case 'university':
        return const Color(0xFF1565C0);
      case 'instructor':
        return const Color(0xFF0D9488);
      case 'commercial':
        return const Color(0xFF7C3AED);
      case 'merchant':
        return const Color(0xFFEA580C);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'student':
        return 'Étudiant';
      case 'university':
        return 'Université';
      case 'instructor':
        return 'Enseignant';
      case 'commercial':
        return 'Commercial';
      case 'merchant':
        return 'Marchand';
      default:
        return role ?? 'Inconnu';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminSupportProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            // Search + Filters
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              color: Colors.white,
              child: Column(
                children: [
                  // Search bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher par nom ou email...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                provider.setSearch(null);
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onSubmitted: (v) => provider.setSearch(v),
                  ),
                  const SizedBox(height: 8),
                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Status filter
                        _FilterChip(
                          label: provider.filterStatus == null
                              ? 'Tous statuts'
                              : provider.filterStatus == 'open'
                                  ? 'Ouvertes'
                                  : 'Clôturées',
                          isActive: provider.filterStatus != null,
                          onTap: () {
                            if (provider.filterStatus == null) {
                              provider.setFilterStatus('open');
                            } else if (provider.filterStatus == 'open') {
                              provider.setFilterStatus('closed');
                            } else {
                              provider.setFilterStatus(null);
                            }
                          },
                        ),
                        const SizedBox(width: 6),
                        // Role filters
                        for (final role in ['student', 'university', 'instructor', 'commercial', 'merchant'])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _FilterChip(
                              label: _roleLabel(role),
                              isActive: provider.filterRole == role,
                              color: _roleColor(role),
                              onTap: () {
                                provider.setFilterRole(
                                  provider.filterRole == role ? null : role,
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Conversations list
            Expanded(
              child: _buildConversationsList(provider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConversationsList(AdminSupportProvider provider) {
    if (provider.isLoading && provider.conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(provider.error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: provider.loadConversations,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    final convs = provider.conversations;
    if (convs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.support_agent, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'Aucune conversation support',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                'Les demandes des utilisateurs apparaîtront ici.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.loadConversations,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: convs.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final c = convs[index];
          final name = c['requester_display_name']?.toString() ?? '';
          final email = c['requester_email']?.toString() ?? '';
          final role = c['requester_role']?.toString();
          final status = c['status']?.toString() ?? 'open';
          final lastMsg = c['last_message_content']?.toString() ?? '';
          final lastSide = c['last_message_sender_side']?.toString();
          final unread = c['unread_count'] is int ? c['unread_count'] as int : 0;
          final timeStr = _formatTime(c['last_message_at']?.toString());
          final convId = c['conversation_id']?.toString() ?? '';
          final isClosed = status == 'closed';

          final displayName = name.isNotEmpty ? name : email;
          final lastMsgPreview = lastSide == 'admin'
              ? 'Vous: $lastMsg'
              : lastMsg;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: _roleColor(role).withOpacity(0.15),
              child: Icon(
                _roleIcon(role),
                color: _roleColor(role),
                size: 22,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    displayName,
                    style: TextStyle(
                      fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _roleColor(role).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _roleLabel(role),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _roleColor(role),
                    ),
                  ),
                ),
                if (isClosed) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Clôturée',
                      style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              lastMsgPreview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: unread > 0 ? Colors.black87 : Colors.grey.shade600,
                fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.w400,
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
                    color: unread > 0 ? const Color(0xFF1EA75C) : Colors.grey.shade500,
                  ),
                ),
                if (unread > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1EA75C),
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
                  builder: (_) => ChangeNotifierProvider(
                    create: (_) => AdminSupportProvider(),
                    child: AdminSupportChatScreen(
                      conversationId: convId,
                      requesterName: displayName,
                      requesterRole: role ?? '',
                      status: status,
                    ),
                  ),
                ),
              ).then((_) {
                provider.loadConversations();
              });
            },
          );
        },
      ),
    );
  }

  IconData _roleIcon(String? role) {
    switch (role) {
      case 'student':
        return Icons.school_outlined;
      case 'university':
        return Icons.apartment_outlined;
      case 'instructor':
        return Icons.person_outlined;
      case 'commercial':
        return Icons.business_center_outlined;
      case 'merchant':
        return Icons.storefront_outlined;
      default:
        return Icons.person_outlined;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF1EA75C);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? c.withOpacity(0.12) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? c : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? c : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}
