import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:story_view/story_view.dart';

import '../providers/community_stories_provider.dart';
import '../theme/prep_theme.dart';
import 'user_avatar.dart';

/// Horizontal stories bar displayed at the top of a community detail screen.
/// Shows author circles with gradient ring (unviewed) or grey ring (viewed).
class CommunityStoriesBar extends StatelessWidget {
  final String communityId;

  const CommunityStoriesBar({super.key, required this.communityId});

  @override
  Widget build(BuildContext context) {
    return Consumer<CommunityStoriesProvider>(
      builder: (context, provider, _) {
        final grouped = provider.storiesByAuthor;

        return SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: grouped.length + 1, // +1 for "add" button
            itemBuilder: (context, index) {
              // First item: add story button
              if (index == 0) {
                return _AddStoryButton(communityId: communityId);
              }
              final author = grouped[index - 1];
              final authorName = author['author_name']?.toString() ?? '';
              final authorAvatar = author['author_avatar_url']?.toString();
              final hasUnviewed = author['has_unviewed'] == true;
              final isMe = author['is_me'] == true;
              final stories = author['stories'] as List<Map<String, dynamic>>? ?? [];

              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _StoryViewerScreen(
                        communityId: communityId,
                        stories: stories,
                        authorName: authorName,
                        isMe: isMe,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: hasUnviewed
                              ? const LinearGradient(
                                  colors: PrepTheme.headerGradient,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          border: hasUnviewed
                              ? null
                              : Border.all(color: Colors.grey.shade300, width: 2),
                        ),
                        child: UserAvatar(
                          imageUrl: authorAvatar,
                          name: authorName,
                          radius: 26,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 64,
                        child: Text(
                          isMe ? 'Moi' : authorName.split(' ').first,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: PrepTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// "+" button to add a new story
class _AddStoryButton extends StatelessWidget {
  final String communityId;

  const _AddStoryButton({required this.communityId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showCreateStorySheet(context),
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  width: 57,
                  height: 57,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: PrepTheme.scaffoldBg,
                    border: Border.all(color: PrepTheme.divider, width: 1.5),
                  ),
                  child: const Icon(Icons.camera_alt, color: PrepTheme.primary, size: 24),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: PrepTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const SizedBox(
              width: 64,
              child: Text(
                'Ajouter',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: PrepTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateStorySheet(BuildContext context) {
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
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: PrepTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nouvelle story',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: PrepTheme.textPrimary),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: PrepTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library, color: PrepTheme.primary),
              ),
              title: const Text('Photo depuis la galerie'),
              subtitle: const Text('Partage un moment de ta journée'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage(context, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: PrepTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, color: PrepTheme.primary),
              ),
              title: const Text('Prendre une photo'),
              subtitle: const Text('Capture l\'instant'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: PrepTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.text_fields, color: PrepTheme.primary),
              ),
              title: const Text('Story texte'),
              subtitle: const Text('Écris un message sur fond coloré'),
              onTap: () {
                Navigator.pop(ctx);
                _showTextStoryCreator(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(BuildContext context, ImageSource source) async {
    final provider = context.read<CommunityStoriesProvider>();
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1080, imageQuality: 80);
    if (picked == null) return;

    final Uint8List bytes;
    if (kIsWeb) {
      bytes = await picked.readAsBytes();
    } else {
      bytes = await File(picked.path).readAsBytes();
    }
    if (bytes.isEmpty) return;

    final ext = picked.name.split('.').last.toLowerCase();

    // Show loading
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Publication de la story...'), duration: Duration(seconds: 2)),
    );

    final url = await provider.uploadStoryMedia(
      communityId: communityId,
      bytes: bytes,
      fileName: picked.name,
      mimeType: ext,
    );
    if (url == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Erreur upload')),
      );
      return;
    }

    final ok = await provider.createStory(
      communityId: communityId,
      type: 'image',
      mediaUrl: url,
    );
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story publiée !'), duration: Duration(seconds: 1)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Erreur')),
      );
    }
  }

  void _showTextStoryCreator(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TextStoryCreatorScreen(communityId: communityId),
      ),
    );
  }
}

/// Full-screen text story creator
class _TextStoryCreatorScreen extends StatefulWidget {
  final String communityId;
  const _TextStoryCreatorScreen({required this.communityId});

  @override
  State<_TextStoryCreatorScreen> createState() => _TextStoryCreatorScreenState();
}

class _TextStoryCreatorScreenState extends State<_TextStoryCreatorScreen> {
  final _controller = TextEditingController();
  int _colorIndex = 0;
  bool _publishing = false;

  static const _bgColors = [
    Color(0xFF00897B), // Teal
    Color(0xFF5C6BC0), // Indigo
    Color(0xFFE53935), // Red
    Color(0xFF8E24AA), // Purple
    Color(0xFFFB8C00), // Orange
    Color(0xFF1E88E5), // Blue
    Color(0xFF43A047), // Green
    Color(0xFF6D4C41), // Brown
    Color(0xFF546E7A), // Blue Grey
    Color(0xFFD81B60), // Pink
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _publishing = true);

    final provider = context.read<CommunityStoriesProvider>();
    final colorHex = '#${_bgColors[_colorIndex].value.toRadixString(16).substring(2)}';

    final ok = await provider.createStory(
      communityId: widget.communityId,
      type: 'text',
      textContent: text,
      bgColor: colorHex,
    );

    if (!mounted) return;
    setState(() => _publishing = false);

    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story publiée !'), duration: Duration(seconds: 1)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Erreur')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _bgColors[_colorIndex];
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Story texte'),
        actions: [
          if (_publishing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _publish,
              child: const Text('Publier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  maxLines: null,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Écris ta story...',
                    hintStyle: TextStyle(color: Colors.white54, fontSize: 24),
                  ),
                ),
              ),
            ),
          ),
          // Color picker
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _bgColors.length,
              itemBuilder: (context, i) {
                final isSelected = i == _colorIndex;
                return GestureDetector(
                  onTap: () => setState(() => _colorIndex = i),
                  child: Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: _bgColors[i],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

/// Full-screen story viewer using story_view package
class _StoryViewerScreen extends StatefulWidget {
  final String communityId;
  final List<Map<String, dynamic>> stories;
  final String authorName;
  final bool isMe;

  const _StoryViewerScreen({
    required this.communityId,
    required this.stories,
    required this.authorName,
    this.isMe = false,
  });

  @override
  State<_StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<_StoryViewerScreen> {
  late StoryController _storyController;
  final List<StoryItem> _storyItems = [];

  @override
  void initState() {
    super.initState();
    _storyController = StoryController();
    _buildStoryItems();
    // Mark all as viewed
    final provider = context.read<CommunityStoriesProvider>();
    for (final s in widget.stories) {
      final id = s['id']?.toString();
      if (id != null && s['viewed_by_me'] != true) {
        provider.markViewed(id);
      }
    }
  }

  void _buildStoryItems() {
    for (final s in widget.stories) {
      final type = s['type']?.toString() ?? 'text';
      final mediaUrl = s['media_url']?.toString() ?? '';
      final textContent = s['text_content']?.toString() ?? '';
      final bgColorStr = s['bg_color']?.toString() ?? '#00897B';
      final caption = s['caption']?.toString() ?? '';
      final createdAt = DateTime.tryParse(s['created_at']?.toString() ?? '');
      final timeStr = createdAt != null ? DateFormat('HH:mm').format(createdAt) : '';

      if (type == 'image' && mediaUrl.isNotEmpty) {
        _storyItems.add(
          StoryItem.pageImage(
            url: mediaUrl,
            controller: _storyController,
            caption: Text(
              caption.isNotEmpty ? '$caption  $timeStr' : timeStr,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            imageFit: BoxFit.contain,
          ),
        );
      } else if (type == 'text') {
        Color bgColor;
        try {
          bgColor = Color(int.parse(bgColorStr.replaceFirst('#', '0xFF')));
        } catch (_) {
          bgColor = const Color(0xFF00897B);
        }
        _storyItems.add(
          StoryItem.text(
            title: textContent,
            backgroundColor: bgColor,
            textStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _storyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_storyItems.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
        body: const Center(child: Text('Aucune story', style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          StoryView(
            storyItems: _storyItems,
            controller: _storyController,
            onComplete: () => Navigator.pop(context),
            onVerticalSwipeComplete: (direction) {
              if (direction == Direction.down) Navigator.pop(context);
            },
            progressPosition: ProgressPosition.top,
            repeat: false,
            inline: false,
          ),
          // Author info overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 40,
            left: 16,
            right: 60,
            child: Row(
              children: [
                UserAvatar(
                  imageUrl: widget.stories.first['author_avatar_url']?.toString(),
                  name: widget.authorName,
                  radius: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.isMe ? 'Ma story' : widget.authorName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Delete button for own stories
          if (widget.isMe)
            Positioned(
              top: MediaQuery.of(context).padding.top + 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
                onPressed: () async {
                  final storyId = widget.stories.first['id']?.toString();
                  if (storyId == null) return;
                  final provider = context.read<CommunityStoriesProvider>();
                  await provider.deleteStory(storyId: storyId, communityId: widget.communityId);
                  if (mounted) Navigator.pop(context);
                },
              ),
            ),
        ],
      ),
    );
  }
}
