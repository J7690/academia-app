import 'package:flutter/material.dart';

import 'user_avatar.dart';

/// A TextField wrapper that detects `@` typing and shows an autocomplete
/// overlay with community members. When a member is selected, inserts
/// `@[DisplayName](userId)` into the text.
class MentionTextField extends StatefulWidget {
  final TextEditingController controller;
  final List<Map<String, dynamic>> members;
  final int minLines;
  final int maxLines;
  final String hintText;
  final TextCapitalization textCapitalization;
  final InputDecoration? decoration;

  const MentionTextField({
    super.key,
    required this.controller,
    required this.members,
    this.minLines = 1,
    this.maxLines = 5,
    this.hintText = 'Message',
    this.textCapitalization = TextCapitalization.sentences,
    this.decoration,
  });

  @override
  State<MentionTextField> createState() => MentionTextFieldState();
}

class MentionTextFieldState extends State<MentionTextField> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  String _mentionQuery = '';
  int _mentionStartIndex = -1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _removeOverlay();
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      _removeOverlay();
      return;
    }

    final cursorPos = selection.baseOffset;
    if (cursorPos <= 0) {
      _removeOverlay();
      return;
    }

    // Find the last '@' before cursor that isn't inside a completed mention
    final beforeCursor = text.substring(0, cursorPos);
    final atIndex = beforeCursor.lastIndexOf('@');

    if (atIndex < 0) {
      _removeOverlay();
      return;
    }

    // Check if this @ is inside a completed mention pattern @[Name](id)
    final afterAt = text.substring(atIndex);
    if (afterAt.startsWith('@[') && afterAt.contains('](') && afterAt.contains(')')) {
      _removeOverlay();
      return;
    }

    // Check there's no space before the @ (or it's at start of text)
    if (atIndex > 0 && text[atIndex - 1] != ' ' && text[atIndex - 1] != '\n') {
      _removeOverlay();
      return;
    }

    final query = beforeCursor.substring(atIndex + 1);

    // If query contains space after first word, it's not a mention anymore
    // Allow multi-word names though (up to 30 chars)
    if (query.length > 30 || query.contains('\n')) {
      _removeOverlay();
      return;
    }

    _mentionStartIndex = atIndex;
    _mentionQuery = query.toLowerCase();
    _showOverlay();
  }

  List<Map<String, dynamic>> get _filteredMembers {
    if (_mentionQuery.isEmpty) return widget.members.take(6).toList();
    return widget.members.where((m) {
      final name = (m['display_name'] ?? '').toString().toLowerCase();
      return name.contains(_mentionQuery);
    }).take(6).toList();
  }

  void _showOverlay() {
    final filtered = _filteredMembers;
    if (filtered.isEmpty) {
      _removeOverlay();
      return;
    }

    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, -8),
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.bottomLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final member = filtered[index];
                  final name = member['display_name']?.toString() ?? 'Utilisateur';
                  final role = member['role']?.toString() ?? '';
                  final avatarUrl = member['avatar_url']?.toString();

                  return InkWell(
                    onTap: () => _selectMember(member),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          UserAvatar(
                            imageUrl: avatarUrl,
                            name: name,
                            radius: 16,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (role == 'admin' || role == 'moderator')
                                  Text(
                                    role == 'admin' ? 'Admin' : 'Modérateur',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: role == 'admin'
                                          ? const Color(0xFFE74C3C)
                                          : const Color(0xFFF39C12),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _selectMember(Map<String, dynamic> member) {
    final name = member['display_name']?.toString() ?? 'Utilisateur';
    final userId = member['user_id']?.toString() ?? '';

    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;

    // Replace @query with @[Name](userId)
    final before = text.substring(0, _mentionStartIndex);
    final after = cursorPos < text.length ? text.substring(cursorPos) : '';
    final mention = '@[$name]($userId) ';

    widget.controller.text = '$before$mention$after';
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: before.length + mention.length),
    );

    _removeOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        textCapitalization: widget.textCapitalization,
        decoration: widget.decoration ??
            InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 16,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 0,
                vertical: 10,
              ),
            ),
      ),
    );
  }
}

/// Utility to parse mention patterns in message content and build
/// a rich text widget with teal-colored clickable mentions.
class MentionRenderer {
  /// Regex to match @[DisplayName](userId)
  static final _mentionRegex = RegExp(r'@\[([^\]]+)\]\(([^)]+)\)');

  /// Parse message content and return a list of TextSpans with mentions highlighted
  static List<InlineSpan> buildSpans(
    String text, {
    TextStyle? baseStyle,
    TextStyle? mentionStyle,
    void Function(String userId, String displayName)? onMentionTap,
  }) {
    final spans = <InlineSpan>[];
    final defaultBase = baseStyle ?? const TextStyle(fontSize: 14);
    final defaultMention = mentionStyle ??
        const TextStyle(
          fontSize: 14,
          color: Color(0xFF00897B),
          fontWeight: FontWeight.w600,
        );

    int lastEnd = 0;
    for (final match in _mentionRegex.allMatches(text)) {
      // Text before the mention
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: defaultBase,
        ));
      }
      // The mention itself
      final displayName = match.group(1) ?? '';
      final userId = match.group(2) ?? '';
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTap: onMentionTap != null
              ? () => onMentionTap(userId, displayName)
              : null,
          child: Text(
            '@$displayName',
            style: defaultMention,
          ),
        ),
      ));
      lastEnd = match.end;
    }
    // Remaining text after last mention
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: defaultBase,
      ));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: defaultBase));
    }

    return spans;
  }

  /// Convert mention format to plain display text (for copy/preview)
  static String toPlainText(String text) {
    return text.replaceAllMapped(_mentionRegex, (m) => '@${m.group(1)}');
  }

  /// Check if text contains any mentions
  static bool hasMentions(String text) => _mentionRegex.hasMatch(text);
}
