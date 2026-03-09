import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../providers/bobodo_provider.dart';
import '../../../theme/prep_theme.dart';
import '../../share/share_service.dart';
import '../../share/share_mode_provider.dart';
import '../../share/widgets/share_signature.dart';

class StudentBobodoTab extends StatefulWidget {
  const StudentBobodoTab({super.key});

  @override
  State<StudentBobodoTab> createState() => _StudentBobodoTabState();
}

class _StudentBobodoTabState extends State<StudentBobodoTab> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _shareBoundaryKey = GlobalKey();
  final ShareService _shareService = ShareService();
  bool _showEmojiPicker = false;
  int _prevMessageCount = 0;

  static const _suggestedPrompts = [
    "Qu'est-ce qu'Academia ?",
    'Aide à l\'orientation',
    'Universités partenaires',
    'Comment postuler ?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  Future<void> _shareCurrentView() async {
    await _shareService.shareCurrentView(
      context: context,
      boundaryKey: _shareBoundaryKey,
      shareText: 'Découvert via Academia – Faciliter l\'accès aux formations.',
    );
  }

  void _showSessionsSheet() {
    final provider = context.read<BobodoProvider>();
    provider.loadSessions();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SessionsSheet(
        onNewConversation: () {
          Navigator.pop(ctx);
          provider.startNewConversation();
        },
        onSelectSession: (id) {
          Navigator.pop(ctx);
          provider.switchToSession(id);
        },
      ),
    );
  }

  void _showMessageActions(String content) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PrepTheme.cardBg,
          borderRadius: BorderRadius.circular(PrepTheme.radiusLg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy, color: PrepTheme.primary),
              title: const Text('Copier'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: content));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copié dans le presse-papiers'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.share_outlined, color: PrepTheme.primary),
              title: const Text('Partager'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: content));
                Navigator.pop(ctx);
                _shareCurrentView();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _shareBoundaryKey,
      child: Stack(
        children: [
          Consumer<BobodoProvider>(
            builder: (context, provider, child) {
              final messages = provider.messages;

              // Auto-scroll on new messages
              if (messages.length != _prevMessageCount) {
                _prevMessageCount = messages.length;
                _scrollToBottom();
              }
              // Also scroll when loading starts (typing indicator appears)
              if (provider.isLoading) {
                _scrollToBottom();
              }

              return Container(
                color: PrepTheme.scaffoldBg,
                child: Column(
                  children: [
                    // ─── Header bar ───
                    _buildHeader(provider),
                    // ─── Messages area ───
                    Expanded(
                      child: messages.isEmpty && !provider.isLoading
                          ? _buildWelcomeView()
                          : _buildMessagesList(provider, messages),
                    ),
                    // ─── Error / Retry bar ───
                    if (provider.error != null)
                      _buildErrorBar(provider),
                    // ─── Input bar ───
                    _buildInputBar(provider),
                    // ─── Emoji picker ───
                    if (_showEmojiPicker)
                      SizedBox(
                        height: 260,
                        child: EmojiPicker(
                          onEmojiSelected: (_, emoji) {
                            _controller.text += emoji.emoji;
                            _controller.selection = TextSelection.fromPosition(
                              TextPosition(offset: _controller.text.length),
                            );
                          },
                          config: const Config(
                            height: 260,
                            checkPlatformCompatibility: true,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: IgnorePointer(
              child: Consumer<ShareModeProvider>(
                builder: (context, shareMode, _) {
                  if (!shareMode.isShareModeEnabled) {
                    return const SizedBox.shrink();
                  }
                  return const ShareSignature();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────
  Widget _buildHeader(BobodoProvider provider) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top > 0 ? 8 : 16,
        8,
        8,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: PrepTheme.headerGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bobodo',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  provider.isLoading ? 'En train de réfléchir...' : 'Assistant Academia',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, color: Colors.white, size: 20),
            tooltip: 'Nouvelle conversation',
            onPressed: () => provider.startNewConversation(),
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white, size: 20),
            tooltip: 'Historique',
            onPressed: _showSessionsSheet,
          ),
          Consumer<ShareModeProvider>(
            builder: (context, shareMode, _) {
              if (shareMode.isShareModeEnabled) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.share, color: Colors.white, size: 20),
                tooltip: 'Partager',
                onPressed: shareMode.isBusy ? null : _shareCurrentView,
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Welcome view with suggestions ────────────────────────────────
  Widget _buildWelcomeView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          FadeIn(
            duration: const Duration(milliseconds: 600),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: PrepTheme.headerGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: PrepTheme.glowShadow(PrepTheme.primary),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 40),
            ),
          ),
          const SizedBox(height: 20),
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: const Text(
              'Bonjour ! Je suis Bobodo 👋',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: PrepTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          FadeInUp(
            delay: const Duration(milliseconds: 300),
            child: const Text(
              'Ton assistant Academia. Pose-moi une question sur les formations, l\'orientation, les universités partenaires ou Nexiom Group.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: PrepTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          FadeInUp(
            delay: const Duration(milliseconds: 400),
            child: const Text(
              'Suggestions',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PrepTheme.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (int i = 0; i < _suggestedPrompts.length; i++)
                FadeInUp(
                  delay: Duration(milliseconds: 500 + i * 100),
                  child: _SuggestionChip(
                    label: _suggestedPrompts[i],
                    onTap: () {
                      _controller.text = _suggestedPrompts[i];
                      _send(context);
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Messages list ────────────────────────────────────────────────
  Widget _buildMessagesList(BobodoProvider provider, List<Map<String, dynamic>> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: messages.length + (provider.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        // Typing indicator at the end
        if (index == messages.length) {
          return _buildTypingIndicator();
        }

        final msg = messages[index];
        final isUser = msg['sender'] == 'student';
        final messageId = msg['id']?.toString();
        final content = msg['content']?.toString() ?? '';
        final createdAt = msg['created_at']?.toString();
        final isLastBotMessage = !isUser &&
            index == messages.length - 1 &&
            !provider.isLoading;

        // Date separator
        Widget? dateSeparator;
        if (index == 0 || _shouldShowDateSeparator(messages, index)) {
          dateSeparator = _buildDateSeparator(createdAt);
        }

        return Column(
          children: [
            if (dateSeparator != null) dateSeparator,
            FadeInUp(
              duration: const Duration(milliseconds: 300),
              from: 10,
              child: _buildMessageBubble(
                content: content,
                isUser: isUser,
                messageId: messageId,
                createdAt: createdAt,
                provider: provider,
                isLastBotMessage: isLastBotMessage,
              ),
            ),
          ],
        );
      },
    );
  }

  bool _shouldShowDateSeparator(List<Map<String, dynamic>> messages, int index) {
    if (index == 0) return true;
    final prev = DateTime.tryParse(messages[index - 1]['created_at']?.toString() ?? '');
    final curr = DateTime.tryParse(messages[index]['created_at']?.toString() ?? '');
    if (prev == null || curr == null) return false;
    return prev.day != curr.day || prev.month != curr.month || prev.year != curr.year;
  }

  Widget _buildDateSeparator(String? dateStr) {
    final dt = DateTime.tryParse(dateStr ?? '');
    String label = '';
    if (dt != null) {
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        label = 'Aujourd\'hui';
      } else if (dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day - 1) {
        label = 'Hier';
      } else {
        label = DateFormat('d MMMM yyyy', 'fr_FR').format(dt);
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: PrepTheme.divider,
            borderRadius: BorderRadius.circular(PrepTheme.radiusFull),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: PrepTheme.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Single message bubble ────────────────────────────────────────
  Widget _buildMessageBubble({
    required String content,
    required bool isUser,
    String? messageId,
    String? createdAt,
    required BobodoProvider provider,
    bool isLastBotMessage = false,
  }) {
    final time = DateTime.tryParse(createdAt ?? '');
    final timeStr = time != null ? DateFormat.Hm().format(time) : '';
    final selectedFeedback =
        messageId != null ? provider.feedbackForMessage(messageId) : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // Bot avatar
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 6, bottom: 4),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: PrepTheme.headerGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 16),
            ),
          ],
          // Bubble
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageActions(content),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.78,
                ),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                decoration: BoxDecoration(
                  color: isUser
                      ? PrepTheme.primary
                      : PrepTheme.cardBg,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isUser ? PrepTheme.primary : Colors.black)
                          .withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Message content
                    if (isUser)
                      SelectableText(
                        content,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          height: 1.45,
                        ),
                      )
                    else
                      MarkdownBody(
                        data: content,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(
                            fontSize: 14,
                            color: PrepTheme.textPrimary,
                            height: 1.5,
                          ),
                          strong: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: PrepTheme.textPrimary,
                          ),
                          em: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: PrepTheme.textPrimary,
                          ),
                          listBullet: const TextStyle(
                            fontSize: 14,
                            color: PrepTheme.textPrimary,
                          ),
                          code: TextStyle(
                            fontSize: 13,
                            backgroundColor: PrepTheme.primary.withValues(alpha: 0.08),
                            color: PrepTheme.primaryDark,
                            fontFamily: 'monospace',
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: PrepTheme.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: PrepTheme.divider),
                          ),
                          codeblockPadding: const EdgeInsets.all(12),
                          blockquoteDecoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: PrepTheme.primary.withValues(alpha: 0.4),
                                width: 3,
                              ),
                            ),
                          ),
                          blockquotePadding: const EdgeInsets.only(left: 12),
                          a: const TextStyle(
                            color: PrepTheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                          h1: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: PrepTheme.textPrimary,
                          ),
                          h2: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: PrepTheme.textPrimary,
                          ),
                          h3: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: PrepTheme.textPrimary,
                          ),
                        ),
                        onTapLink: (text, href, title) {
                          if (href != null) {
                            launchUrl(Uri.parse(href),
                                mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    const SizedBox(height: 4),
                    // Timestamp + feedback row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 10,
                            color: isUser
                                ? Colors.white.withValues(alpha: 0.7)
                                : PrepTheme.textTertiary,
                          ),
                        ),
                        if (!isUser && messageId != null) ...[
                          const SizedBox(width: 8),
                          _FeedbackButton(
                            icon: selectedFeedback == 'up'
                                ? Icons.thumb_up_alt
                                : Icons.thumb_up_alt_outlined,
                            isActive: selectedFeedback == 'up',
                            isUser: isUser,
                            onTap: () => provider.sendFeedback(
                              messageId: messageId,
                              rating: 'up',
                            ),
                          ),
                          const SizedBox(width: 2),
                          _FeedbackButton(
                            icon: selectedFeedback == 'down'
                                ? Icons.thumb_down_alt
                                : Icons.thumb_down_alt_outlined,
                            isActive: selectedFeedback == 'down',
                            isUser: isUser,
                            isDanger: true,
                            onTap: () => provider.sendFeedback(
                              messageId: messageId,
                              rating: 'down',
                            ),
                          ),
                          const SizedBox(width: 2),
                          _FeedbackButton(
                            icon: Icons.copy_outlined,
                            isActive: false,
                            isUser: isUser,
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: content));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Copié'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                    // Regenerate button on last bot message
                    if (isLastBotMessage && !provider.isLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: InkWell(
                          onTap: () => provider.regenerateLastResponse(),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.refresh,
                                  size: 13,
                                  color: PrepTheme.primary.withValues(alpha: 0.7),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Régénérer',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: PrepTheme.primary.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Typing indicator ─────────────────────────────────────────────
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 6, bottom: 4),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: PrepTheme.headerGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 16),
          ),
          Shimmer.fromColors(
            baseColor: PrepTheme.divider,
            highlightColor: PrepTheme.shimmer,
            child: Container(
              width: 72,
              height: 36,
              decoration: BoxDecoration(
                color: PrepTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _Dot(),
                  SizedBox(width: 4),
                  _Dot(),
                  SizedBox(width: 4),
                  _Dot(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Error bar ────────────────────────────────────────────────────
  Widget _buildErrorBar(BobodoProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: PrepTheme.dangerSurface,
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: PrepTheme.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              provider.error ?? 'Erreur',
              style: const TextStyle(fontSize: 12, color: PrepTheme.danger),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (provider.lastFailedMessage != null)
            TextButton.icon(
              onPressed: () => provider.retryLastFailed(),
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Réessayer', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: PrepTheme.danger,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }

  // ─── Input bar ────────────────────────────────────────────────────
  Widget _buildInputBar(BobodoProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      decoration: BoxDecoration(
        color: PrepTheme.cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Emoji toggle
            IconButton(
              icon: Icon(
                _showEmojiPicker
                    ? Icons.keyboard
                    : Icons.emoji_emotions_outlined,
                color: PrepTheme.textTertiary,
                size: 22,
              ),
              onPressed: () {
                setState(() {
                  _showEmojiPicker = !_showEmojiPicker;
                  if (_showEmojiPicker) {
                    _focusNode.unfocus();
                  } else {
                    _focusNode.requestFocus();
                  }
                });
              },
            ),
            // Text field
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: PrepTheme.scaffoldBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: PrepTheme.divider),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 4,
                  minLines: 1,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Pose une question à Bobodo...',
                    hintStyle: TextStyle(
                      color: PrepTheme.textTertiary,
                      fontSize: 14,
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: (_) => _send(context),
                  onTap: () {
                    if (_showEmojiPicker) {
                      setState(() => _showEmojiPicker = false);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Send button
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: PrepTheme.headerGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: PrepTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 18),
                padding: EdgeInsets.zero,
                onPressed: provider.isLoading ? null : () => _send(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send(BuildContext context) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() => _showEmojiPicker = false);
    final provider = context.read<BobodoProvider>();
    await provider.sendUserMessage(text);
  }
}

// ─── Small widgets ──────────────────────────────────────────────────

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: PrepTheme.textTertiary,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _FeedbackButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final bool isUser;
  final bool isDanger;
  final VoidCallback onTap;

  const _FeedbackButton({
    required this.icon,
    required this.isActive,
    required this.isUser,
    this.isDanger = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDanger ? PrepTheme.danger : PrepTheme.primary;
    final inactiveColor =
        isUser ? Colors.white.withValues(alpha: 0.6) : PrepTheme.textTertiary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: 14,
          color: isActive ? activeColor : inactiveColor,
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PrepTheme.radiusFull),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: PrepTheme.cardBg,
            borderRadius: BorderRadius.circular(PrepTheme.radiusFull),
            border: Border.all(color: PrepTheme.primary.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: PrepTheme.primary.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: PrepTheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sessions history sheet ─────────────────────────────────────────

class _SessionsSheet extends StatelessWidget {
  final VoidCallback onNewConversation;
  final ValueChanged<String> onSelectSession;

  const _SessionsSheet({
    required this.onNewConversation,
    required this.onSelectSession,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: const BoxDecoration(
        color: PrepTheme.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: PrepTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.history, color: PrepTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Conversations',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: PrepTheme.textPrimary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onNewConversation,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nouvelle'),
                  style: TextButton.styleFrom(
                    foregroundColor: PrepTheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: Consumer<BobodoProvider>(
              builder: (context, provider, _) {
                final sessions = provider.sessions;
                if (sessions.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Aucune conversation pour le moment',
                      style: TextStyle(
                        color: PrepTheme.textTertiary,
                        fontSize: 14,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                  itemBuilder: (context, index) {
                    final s = sessions[index];
                    final id = s['id']?.toString() ?? '';
                    final title = s['title']?.toString() ?? 'Conversation';
                    final updatedAt = DateTime.tryParse(
                      s['updated_at']?.toString() ?? '',
                    );
                    final isActive = id == provider.currentSessionId;
                    return ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isActive
                              ? PrepTheme.primary.withValues(alpha: 0.12)
                              : PrepTheme.scaffoldBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chat_bubble_outline,
                          size: 16,
                          color: isActive
                              ? PrepTheme.primary
                              : PrepTheme.textTertiary,
                        ),
                      ),
                      title: Text(
                        title.isEmpty ? 'Conversation' : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w400,
                          color: PrepTheme.textPrimary,
                        ),
                      ),
                      subtitle: updatedAt != null
                          ? Text(
                              DateFormat('d MMM yyyy, HH:mm').format(updatedAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: PrepTheme.textTertiary,
                              ),
                            )
                          : null,
                      trailing: isActive
                          ? const Icon(
                              Icons.check_circle,
                              size: 18,
                              color: PrepTheme.primary,
                            )
                          : null,
                      onTap: () => onSelectSession(id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
