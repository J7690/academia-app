import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/opportunity_comments_provider.dart';
import '../report_content_sheet.dart';

/// Bottom sheet pour afficher et gérer les commentaires d'une opportunité
class OpportunityCommentsSheet extends StatefulWidget {
  final String opportunityId;
  final String opportunityTitle;

  const OpportunityCommentsSheet({
    super.key,
    required this.opportunityId,
    required this.opportunityTitle,
  });

  /// Affiche le bottom sheet des commentaires
  static Future<void> show(
    BuildContext context, {
    required String opportunityId,
    required String opportunityTitle,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OpportunityCommentsSheet(
        opportunityId: opportunityId,
        opportunityTitle: opportunityTitle,
      ),
    );
  }

  @override
  State<OpportunityCommentsSheet> createState() => _OpportunityCommentsSheetState();
}

class _OpportunityCommentsSheetState extends State<OpportunityCommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OpportunityCommentsProvider>().loadComments(
            widget.opportunityId,
            refresh: true,
          );
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    final provider = context.read<OpportunityCommentsProvider>();
    final success = await provider.addComment(widget.opportunityId, content);

    if (success && mounted) {
      _commentController.clear();
      _focusNode.unfocus();
    }

    if (mounted) {
      setState(() => _isSending = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le commentaire ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<OpportunityCommentsProvider>().deleteComment(
            commentId,
            widget.opportunityId,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Commentaires',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0A2540),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Consumer<OpportunityCommentsProvider>(
                        builder: (context, provider, _) {
                          final total = provider.getTotal(widget.opportunityId);
                          return Text(
                            '$total commentaire${total > 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: const Color(0xFF6B7280),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Liste des commentaires
          Expanded(
            child: Consumer<OpportunityCommentsProvider>(
              builder: (context, provider, _) {
                final comments = provider.getComments(widget.opportunityId);
                final isLoading = provider.isLoading;
                final hasMore = provider.hasMore(widget.opportunityId);

                if (isLoading && comments.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (comments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Aucun commentaire',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Soyez le premier à commenter !',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollEndNotification &&
                        notification.metrics.extentAfter < 100 &&
                        hasMore &&
                        !isLoading) {
                      provider.loadComments(widget.opportunityId);
                    }
                    return false;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: comments.length + (hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= comments.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      final comment = comments[index];
                      return _CommentItem(
                        comment: comment,
                        onDelete: () => _deleteComment(comment['id'].toString()),
                      );
                    },
                  ),
                );
              },
            ),
          ),

          // Input
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 12 + bottomPadding,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: 'Écrire un commentaire...',
                        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSending ? null : _sendComment,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    color: const Color(0xFF3275D0),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentItem extends StatelessWidget {
  final Map<String, dynamic> comment;
  final VoidCallback? onDelete;

  const _CommentItem({
    required this.comment,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final userId = comment['user_id']?.toString() ?? '';
    final userName = comment['user_name']?.toString() ?? 'Utilisateur';
    final userAvatar = comment['user_avatar']?.toString();
    final content = comment['content']?.toString() ?? '';
    final createdAt = comment['created_at']?.toString();
    final timeAgo = _formatTimeAgo(createdAt);

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = currentUserId == userId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFF3F4F6),
            backgroundImage:
                userAvatar != null && userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,
            child: userAvatar == null || userAvatar.isEmpty
                ? Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0A2540),
                        ),
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF374151),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Delete button (owner only)
          if (isOwner)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              iconSize: 18,
              color: const Color(0xFF9CA3AF),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          // Report button (non-owner)
          if (!isOwner)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 16, color: Color(0xFF9CA3AF)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onSelected: (val) {
                final commentId = comment['id']?.toString();
                if (val == 'report' && commentId != null) {
                  ReportContentSheet.show(context,
                    contentType: 'comment', contentId: commentId,
                    targetUserId: userId,
                    contentPreview: content.length > 80 ? '${content.substring(0, 80)}...' : content);
                } else if (val == 'block') {
                  UserModerationSheet.show(context, userId: userId, userName: userName);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'report', child: Text('Signaler', style: TextStyle(fontSize: 13))),
                PopupMenuItem(value: 'block', child: Text('Bloquer', style: TextStyle(fontSize: 13, color: Colors.red))),
              ],
            ),
        ],
      ),
    );
  }

  String _formatTimeAgo(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';

    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'À l\'instant';
      if (diff.inMinutes < 60) return '${diff.inMinutes}min';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}j';
      return '${(diff.inDays / 7).floor()}sem';
    } catch (_) {
      return '';
    }
  }
}
