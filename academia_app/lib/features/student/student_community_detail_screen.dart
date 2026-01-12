import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/student_communities_provider.dart';
import 'community_audio_recorder.dart'
    if (dart.library.html) 'community_audio_recorder_stub.dart';

class StudentCommunityDetailScreen extends StatefulWidget {
  final String communityId;
  final String initialName;
  final String initialDescription;

  const StudentCommunityDetailScreen({
    super.key,
    required this.communityId,
    required this.initialName,
    required this.initialDescription,
  });

  @override
  State<StudentCommunityDetailScreen> createState() => _StudentCommunityDetailScreenState();
}

class _StudentCommunityDetailScreenState extends State<StudentCommunityDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _loadingPosts = false;
  Map<String, dynamic>? _replyToPost;
  CommunityAudioRecorder? _audioRecorder;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<StudentCommunitiesProvider>();
      await _loadPosts();
      provider.subscribeToCommunityPosts(widget.communityId);
      await provider.markCommunityRead(widget.communityId);
    });
  }

  @override
  void dispose() {
    final provider = context.read<StudentCommunitiesProvider>();
    provider.unsubscribeFromCommunityPosts();
    _messageController.dispose();
    _audioRecorder?.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _loadingPosts = true;
    });
    final provider = context.read<StudentCommunitiesProvider>();
    await provider.loadCommunityPosts(widget.communityId);
    await provider.loadCommunityPolls(widget.communityId);
    if (!mounted) return;
    setState(() {
      _loadingPosts = false;
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final provider = context.read<StudentCommunitiesProvider>();
    final replyToId = _replyToPost != null
        ? _replyToPost!['id']?.toString()
        : null;
    final ok = await provider.addPost(
      communityId: widget.communityId,
      content: text,
      replyToPostId: replyToId,
    );
    if (!mounted) return;
    if (!ok && provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!)),
      );
      return;
    }
    _messageController.clear();
    setState(() {
      _replyToPost = null;
    });
  }

  void _insertEmoji(String emoji) {
    final text = _messageController.text;
    // Pour l'instant, on insère simplement à la fin du texte.
    _messageController.text = text + emoji;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
  }

  Future<void> _showEmojiPickerForInput() async {
    const categories = {
      'Smileys': [
        '😀', '😁', '😂', '🤣', '😃', '😄', '😅', '😊', '😇', '😉', '🙂', '🙃', '😋',
        '😎', '🥰', '😍', '😘', '😙', '😚', '😜', '🤪',
      ],
      'Émotions': [
        '😢', '😭', '😡', '🤯', '😱', '😴', '🤔', '😇', '😤', '🤗', '🤨', '😐',
      ],
      'Gestes': [
        '👍', '👎', '👏', '🙌', '🙏', '🤝', '💪', '👌', '🤌', '✌️', '🤞', '🤟', '👋',
      ],
      'Cœurs': [
        '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '💖', '💗', '💘', '💝', '💕',
      ],
      'Études': [
        '📚', '📖', '📝', '✏️', '📌', '📎', '📅', '📊', '💻', '🖥️', '⌛', '⏰', '🎓',
      ],
      'Fun': [
        '🔥', '✨', '🎉', '⭐', '🌟', '⚡', '🎧', '🎁', '🍀', '😈', '👑',
      ],
    };

    const emojiNames = {
      '😀': 'sourire',
      '😁': 'sourire large',
      '😂': 'rire',
      '🤣': 'rire fort',
      '😊': 'souriant',
      '😍': 'amoureux',
      '😘': 'bisou',
      '😎': 'cool',
      '😢': 'triste',
      '😭': 'pleurs',
      '😡': 'colère',
      '🤯': 'explosion de tête',
      '👍': 'pouce',
      '🙏': 'merci',
      '👏': 'applaudissements',
      '💪': 'force',
      '🔥': 'feu',
      '✨': 'étincelles',
      '❤️': 'coeur',
      '💚': 'coeur vert',
      '📚': 'livres',
      '🎓': 'diplôme',
    };

    String activeCategory = categories.keys.first;
    String query = '';

    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
              final allInCategory = <String>[];
              categories.forEach((name, list) {
                if (name == activeCategory) {
                  allInCategory.addAll(list);
                }
              });

              final filtered = allInCategory.where((e) {
                if (query.isEmpty) return true;
                final name = emojiNames[e] ?? '';
                return name.toLowerCase().contains(query.toLowerCase());
              }).toList();

              return Padding(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final cat in categories.keys)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(cat),
                                  selected: activeCategory == cat,
                                  onSelected: (_) {
                                    setModalState(() {
                                      activeCategory = cat;
                                      query = '';
                                    });
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Rechercher un emoji (ex: coeur, rire...)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            query = value.trim();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: filtered
                            .map(
                              (e) => GestureDetector(
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  _insertEmoji(e);
                                },
                                child: Text(
                                  e,
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                            )
                            .toList(),
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

  Future<void> _pickAndUploadAttachment() async {
    final provider = context.read<StudentCommunitiesProvider>();

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'pdf',
        'doc',
        'docx',
        'mp3',
        'm4a',
        'wav',
        'ogg',
      ],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    final bytes = file.bytes;
    final fileName = file.name;
    final ext = (file.extension ?? '').toLowerCase();

    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de lire le contenu du fichier.'),
        ),
      );
      return;
    }

    String type = 'file';
    if (ext == 'jpg' || ext == 'jpeg' || ext == 'png') {
      type = 'image';
    } else if (ext == 'mp3' || ext == 'm4a' || ext == 'wav' || ext == 'ogg') {
      type = 'audio';
    }

    final url = await provider.uploadCommunityMedia(
      communityId: widget.communityId,
      bytes: bytes as Uint8List,
      fileName: fileName,
      mimeType: ext,
    );

    if (!mounted) return;

    if (url == null) {
      if (provider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error!)),
        );
      }
      return;
    }

    final replyToId = _replyToPost != null
        ? _replyToPost!['id']?.toString()
        : null;

    final ok = await provider.addPost(
      communityId: widget.communityId,
      content: '',
      type: type,
      mediaUrl: url,
      replyToPostId: replyToId,
    );

    if (!mounted) return;

    if (!ok && provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!)),
      );
      return;
    }

    setState(() {
      _replyToPost = null;
    });
  }

  Future<void> _toggleRecording() async {
    final provider = context.read<StudentCommunitiesProvider>();

    _audioRecorder ??= CommunityAudioRecorder();

    if (_isRecording) {
      final bytes = await _audioRecorder!.stop();
      setState(() {
        _isRecording = false;
      });

      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Impossible de récupérer l\'enregistrement audio.',
            ),
          ),
        );
        return;
      }

      final fileName =
          'vocal_${DateTime.now().millisecondsSinceEpoch}.m4a';

      final url = await provider.uploadCommunityMedia(
        communityId: widget.communityId,
        bytes: bytes,
        fileName: fileName,
        mimeType: 'm4a',
      );

      if (!mounted) return;

      if (url == null) {
        if (provider.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(provider.error!)),
          );
        }
        return;
      }

      final replyToId = _replyToPost != null
          ? _replyToPost!['id']?.toString()
          : null;

      final ok = await provider.addPost(
        communityId: widget.communityId,
        content: '',
        type: 'audio',
        mediaUrl: url,
        replyToPostId: replyToId,
      );

      if (!mounted) return;

      if (!ok && provider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error!)),
        );
        return;
      }

      setState(() {
        _replyToPost = null;
      });
    } else {
      try {
        final hasPermission = await _audioRecorder!.hasPermission();
        if (!hasPermission) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "L'enregistrement audio n'est pas disponible depuis cette version (navigateur web).",
              ),
            ),
          );
          return;
        }

        await _audioRecorder!.start();
        if (!mounted) return;
        setState(() {
          _isRecording = true;
        });
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Impossible de démarrer l\'enregistrement audio.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openReportCommunityDialog() async {
    final provider = context.read<StudentCommunitiesProvider>();
    final reasonController = TextEditingController();
    final detailsController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Signaler la communauté'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Raison du signalement *',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: detailsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Détails (optionnel)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Envoyer'),
            ),
          ],
        );
      },
    );

    if (result != true) return;
    final reason = reasonController.text.trim();
    final details = detailsController.text.trim();
    if (reason.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merci de préciser une raison pour ton signalement.'),
        ),
      );
      return;
    }

    final ok = await provider.reportCommunity(
      communityId: widget.communityId,
      reason: reason,
      details: details.isEmpty ? null : details,
    );
    if (!mounted) return;
    if (!ok && provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merci, ton signalement a bien été pris en compte.'),
        ),
      );
    }
  }

  Future<void> _confirmDeleteMyPost(Map<String, dynamic> post) async {
    final postId = post['id']?.toString() ?? '';
    if (postId.isEmpty) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer ce message'),
          content: const Text(
            'Ce message sera supprim e9 pour tous les membres du groupe. Continuer ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final provider = context.read<StudentCommunitiesProvider>();
    final ok = await provider.deleteMyPost(
      communityId: widget.communityId,
      postId: postId,
    );
    if (!mounted) return;
    if (!ok && provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!)),
      );
    }
  }

  Future<void> _openReportPostDialog(Map<String, dynamic> post) async {
    final provider = context.read<StudentCommunitiesProvider>();
    final reasonController = TextEditingController();
    final detailsController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Signaler ce message'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Raison du signalement *',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: detailsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Détails (optionnel)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Envoyer'),
            ),
          ],
        );
      },
    );

    if (result != true) return;
    final reason = reasonController.text.trim();
    final details = detailsController.text.trim();
    if (reason.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merci de préciser une raison pour ton signalement.'),
        ),
      );
      return;
    }

    final postId = post['id']?.toString();
    if (postId == null || postId.isEmpty) {
      return;
    }

    final ok = await provider.reportPost(
      postId: postId,
      reason: reason,
      details: details.isEmpty ? null : details,
    );
    if (!mounted) return;
    if (!ok && provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merci, ton signalement a bien été pris en compte.'),
        ),
      );
    }
  }

  Widget _buildPostContent(
    Map<String, dynamic> p,
    Map<String, dynamic>? replyTo,
  ) {
    final type = (p['type'] ?? 'text').toString();
    final content = (p['content'] ?? '').toString();
    final mediaUrl = (p['media_url'] ?? '').toString();

    Widget mainContent;

    // Cas texte simple (comportement existant)
    if (type == 'text' || mediaUrl.isEmpty) {
      mainContent = Text(
        content,
        style: const TextStyle(fontSize: 14),
      );
    } else if (type == 'image' && mediaUrl.isNotEmpty) {
      // Cas image
      mainContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              mediaUrl,
              fit: BoxFit.cover,
            ),
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ],
      );
    } else if (type == 'audio' && mediaUrl.isNotEmpty) {
      // Cas message vocal : player inline
      mainContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AudioAttachmentPlayer(url: mediaUrl),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ],
      );
    } else {
      // Autres types de fichiers : afficher comme pièce jointe cliquable avec nom + icône
      final uri = Uri.tryParse(mediaUrl);
      String label = mediaUrl;
      if (uri != null && uri.pathSegments.isNotEmpty) {
        label = uri.pathSegments.last;
      }

      final lower = label.toLowerCase();
      IconData icon = Icons.insert_drive_file;
      if (lower.endsWith('.pdf')) {
        icon = Icons.picture_as_pdf;
      } else if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
        icon = Icons.description;
      } else if (lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png')) {
        icon = Icons.image;
      }

      mainContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () async {
              final uri = Uri.tryParse(mediaUrl);
              if (uri != null) {
                await launchUrl(uri);
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ],
      );
    }

    final repliedText = replyTo != null
        ? (replyTo['content'] ?? '').toString()
        : '';

    if (repliedText.isEmpty) {
      return mainContent;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
            border: const Border(
              left: BorderSide(
                color: Color(0xFF1EA75C),
                width: 3,
              ),
            ),
          ),
          child: Text(
            repliedText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
        ),
        mainContent,
      ],
    );
  }

  Future<void> _toggleReaction({
    required Map<String, dynamic> post,
    required String emoji,
  }) async {
    final provider = context.read<StudentCommunitiesProvider>();
    final postId = post['id']?.toString();
    if (postId == null || postId.isEmpty) return;
    await provider.togglePostReaction(
      communityId: widget.communityId,
      postId: postId,
      emoji: emoji,
    );
    if (!mounted) return;
    if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!)),
      );
    }
  }

  Future<void> _showReactionPicker(Map<String, dynamic> post) async {
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🔥'];
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: emojis
                  .map(
                    (e) => GestureDetector(
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _toggleReaction(post: post, emoji: e);
                      },
                      child: Text(
                        e,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReactionsRow(
    Map<String, dynamic> post,
    bool isMine,
  ) {
    final raw = post['reactions'];
    final reactions = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          reactions.add(Map<String, dynamic>.from(item));
        }
      }
    }

    if (reactions.isEmpty) {
      return Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: TextButton(
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => _showReactionPicker(post),
          child: const Text(
            'Réagir',
            style: TextStyle(
              fontSize: 11,
              color: Colors.black45,
            ),
          ),
        ),
      );
    }

    reactions.sort((a, b) {
      final ca = (a['count'] is int) ? a['count'] as int : 0;
      final cb = (b['count'] is int) ? b['count'] as int : 0;
      return cb.compareTo(ca);
    });

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Wrap(
        alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
        spacing: 4,
        runSpacing: 2,
        children: [
          ...reactions.map((r) {
            final emoji = (r['emoji'] ?? '').toString();
            final count = (r['count'] is int) ? r['count'] as int : 0;
            final reactedByMe = r['reacted_by_me'] == true;
            return GestureDetector(
              onTap: () => _toggleReaction(post: post, emoji: emoji),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: reactedByMe
                      ? const Color(0xFFDCF8C6)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$emoji $count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        reactedByMe ? FontWeight.w600 : FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
              ),
            );
          }),
          GestureDetector(
            onTap: () => _showReactionPicker(post),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Icon(
                Icons.add_reaction_outlined,
                size: 16,
                color: Colors.black38,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreatePollDialog() async {
    final provider = context.read<StudentCommunitiesProvider>();
    final questionController = TextEditingController();
    final optionsController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Nouveau sondage'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: questionController,
                  decoration: const InputDecoration(
                    labelText: 'Question du sondage',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Options (une par ligne)',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: optionsController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Option 1\nOption 2\nOption 3...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Créer'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final question = questionController.text;
    final options = optionsController.text.split('\n');
    final ok = await provider.createCommunityPoll(
      communityId: widget.communityId,
      question: question,
      options: options,
    );
    if (!mounted) return;
    if (!ok && provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!)),
      );
    }
  }

  Widget _buildPollCard(Map<String, dynamic> poll) {
    final question = (poll['question'] ?? '').toString();
    final isClosed = poll['is_closed'] == true;
    final pollId = poll['id']?.toString() ?? '';
    final rawOptions = poll['options'];
    final options = <Map<String, dynamic>>[];
    if (rawOptions is List) {
      for (final item in rawOptions) {
        if (item is Map) {
          options.add(Map<String, dynamic>.from(item));
        }
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.poll, size: 18, color: Color(0xFF1EA75C)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isClosed)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text(
                    'Clôturé',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...options.map((opt) {
            final idx = opt['index'] is int ? opt['index'] as int : 0;
            final text = (opt['text'] ?? '').toString();
            final votes = opt['votes'] is int ? opt['votes'] as int : 0;
            final votedByMe = opt['voted_by_me'] == true;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InkWell(
                onTap: isClosed || pollId.isEmpty
                    ? null
                    : () {
                        context
                            .read<StudentCommunitiesProvider>()
                            .voteCommunityPoll(
                              communityId: widget.communityId,
                              pollId: pollId,
                              optionIndex: idx,
                            );
                      },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: votedByMe
                        ? const Color(0xFFDCF8C6)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          text,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        votes.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Formate la date pour l'en-tête style WhatsApp
  String _formatWhatsAppDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return "AUJOURD'HUI";
    } else if (messageDate == yesterday) {
      return 'HIER';
    } else {
      return DateFormat('dd MMMM yyyy', 'fr_FR').format(date).toUpperCase();
    }
  }

  /// Génère une couleur pour le nom de l'auteur (style WhatsApp)
  Color _getAuthorColor(String name) {
    if (name.isEmpty) return Colors.grey;
    final colors = [
      const Color(0xFF00A884), // Teal
      const Color(0xFF5DADE2), // Bleu clair
      const Color(0xFFE74C3C), // Rouge
      const Color(0xFF9B59B6), // Violet
      const Color(0xFFF39C12), // Orange
      const Color(0xFF1ABC9C), // Turquoise
      const Color(0xFFE91E63), // Rose
      const Color(0xFF3498DB), // Bleu
    ];
    final index = name.codeUnitAt(0) % colors.length;
    return colors[index];
  }

  /// Vérifie si un post a des réactions
  bool _hasReactions(Map<String, dynamic> post) {
    final reactions = post['reactions'];
    if (reactions == null) return false;
    if (reactions is List) return reactions.isNotEmpty;
    return false;
  }

  void _openGroupInfoSheet() {
    final provider = context.read<StudentCommunitiesProvider>();
    Map<String, dynamic>? community;
    for (final c in provider.communities) {
      if (c['id']?.toString() == widget.communityId) {
        community = c;
        break;
      }
    }

    final name = community?['name']?.toString() ?? widget.initialName;
    final description =
        community?['description']?.toString() ?? widget.initialDescription;
    final category = community?['category']?.toString() ?? '';
    final visibility = community?['visibility']?.toString() ?? 'public';
    final joinPolicy = community?['join_policy']?.toString() ?? 'open';
    final membersCount = community?['members_count'];

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (description.isNotEmpty)
                Text(
                  description,
                  style: const TextStyle(fontSize: 13),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (category.isNotEmpty)
                    Chip(
                      label: Text(category),
                      visualDensity: VisualDensity.compact,
                    ),
                  Chip(
                    label: Text(
                      visibility == 'public' ? 'Publique' : 'Privée',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text(
                      () {
                        final jp = joinPolicy.toLowerCase();
                        if (jp == 'request') return 'Adhésion sur demande';
                        if (jp == 'invite_only') return 'Sur invitation';
                        return 'Adhésion ouverte';
                      }(),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (membersCount is int)
                    Chip(
                      label: Text(
                        '$membersCount membre${membersCount > 1 ? 's' : ''}',
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _shareGroup() {
    final provider = context.read<StudentCommunitiesProvider>();
    Map<String, dynamic>? community;
    for (final c in provider.communities) {
      if (c['id']?.toString() == widget.communityId) {
        community = c;
        break;
      }
    }

    final name = community?['name']?.toString() ?? widget.initialName;
    final description =
        community?['description']?.toString() ?? widget.initialDescription;
    final slug = community?['slug']?.toString();

    final buffer = StringBuffer()
      ..writeln('Je t\'invite à rejoindre mon groupe "$name" sur Academia.')
      ..writeln();
    if (description.isNotEmpty) {
      buffer.writeln(description);
      buffer.writeln();
    }
    if (slug != null && slug.isNotEmpty) {
      buffer.writeln('Lien : https://academia.nexium-group.com/communities/$slug');
    }

    Share.share(buffer.toString().trim());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentCommunitiesProvider>(
      builder: (context, provider, child) {
        final posts = provider.posts;
        final currentUserId = provider.currentUserId;

        return Scaffold(
          // Fond type WhatsApp : motif de fond
          backgroundColor: const Color(0xFFECE5DD),
          appBar: AppBar(
            elevation: 1,
            backgroundColor: const Color(0xFF075E54),
            leadingWidth: 30,
            titleSpacing: 0,
            title: Row(
              children: [
                // Avatar du groupe style WhatsApp
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade300,
                  child: Text(
                    widget.initialName.isNotEmpty
                        ? widget.initialName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.initialName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.initialDescription.isNotEmpty)
                        Text(
                          widget.initialDescription,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            foregroundColor: Colors.white,
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'report_community') {
                    _openReportCommunityDialog();
                  } else if (value == 'create_poll') {
                    _openCreatePollDialog();
                  } else if (value == 'group_info') {
                    _openGroupInfoSheet();
                  } else if (value == 'share_group') {
                    _shareGroup();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'group_info',
                    child: Text('Infos du groupe'),
                  ),
                  PopupMenuItem(
                    value: 'share_group',
                    child: Text('Partager le groupe'),
                  ),
                  PopupMenuItem(
                    value: 'create_poll',
                    child: Text('Créer un sondage'),
                  ),
                  PopupMenuItem(
                    value: 'report_community',
                    child: Text('Signaler la communauté'),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // On enlève le bloc descriptif détaillé en haut pour laisser plus
              // de place au chat, le résumé est désormais dans l'AppBar.
              if (posts.isNotEmpty)
                Builder(
                  builder: (context) {
                    Map<String, dynamic>? pinnedPost;
                    for (final post in posts) {
                      if (post['is_pinned'] == true) {
                        pinnedPost = post;
                        break;
                      }
                    }
                    if (pinnedPost == null) {
                      return const SizedBox.shrink();
                    }
                    final pinnedContent =
                        (pinnedPost['content'] ?? '').toString();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3CD),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.push_pin,
                              size: 16,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                pinnedContent.isNotEmpty
                                    ? pinnedContent
                                    : 'Message épinglé',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              Consumer<StudentCommunitiesProvider>(
                builder: (context, provider, child) {
                  final polls = provider.polls;
                  if (polls.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: polls.map(_buildPollCard).toList(),
                  );
                },
              ),
              Expanded(
                child: _loadingPosts
                    ? const Center(child: CircularProgressIndicator())
                    : posts.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                'Aucun message pour cette communauté pour le moment. Sois le premier à écrire !',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                            itemCount: posts.length,
                            itemBuilder: (context, index) {
                              final p = posts[index];
                              final createdAtRaw =
                                  (p['created_at'] ?? '').toString();
                              final createdAt =
                                  DateTime.tryParse(createdAtRaw);
                              final replyToId =
                                  p['reply_to_post_id']?.toString() ?? '';
                              Map<String, dynamic>? replyTo;
                              if (replyToId.isNotEmpty) {
                                for (final other in posts) {
                                  if (other['id']?.toString() == replyToId) {
                                    replyTo = other;
                                    break;
                                  }
                                }
                              }

                              final isMine = currentUserId != null &&
                                  p['author_id']?.toString() == currentUserId;

                              final dayKey = createdAt != null
                                  ? DateFormat('yyyy-MM-dd').format(createdAt)
                                  : '';
                              String? previousDayKey;
                              if (index > 0) {
                                final prevRaw =
                                    (posts[index - 1]['created_at'] ?? '')
                                        .toString();
                                final prevDate = DateTime.tryParse(prevRaw);
                                if (prevDate != null) {
                                  previousDayKey = DateFormat('yyyy-MM-dd')
                                      .format(prevDate);
                                }
                              }

                              final showDateHeader =
                                  dayKey.isNotEmpty && dayKey != previousDayKey;

                              final timeText = createdAt != null
                                  ? DateFormat('HH:mm').format(createdAt)
                                  : createdAtRaw;

                              // Nom de l'auteur pour les messages des autres
                              final authorName = p['author_display_name']?.toString() ??
                                  p['author_email']?.toString()?.split('@').first ??
                                  'Utilisateur';

                              return Column(
                                children: [
                                  // En-tête de date style WhatsApp
                                  if (showDateHeader)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD9DBE1),
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.05),
                                              blurRadius: 2,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          _formatWhatsAppDateHeader(createdAt!),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF54656F),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  // Bulle de message style WhatsApp
                                  Align(
                                    alignment: isMine
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      margin: EdgeInsets.only(
                                        top: 2,
                                        bottom: 2,
                                        left: isMine ? 60 : 8,
                                        right: isMine ? 8 : 60,
                                      ),
                                      padding: const EdgeInsets.fromLTRB(9, 6, 9, 6),
                                      decoration: BoxDecoration(
                                        color: isMine
                                            ? const Color(0xFFD9FDD3) // Vert WhatsApp
                                            : Colors.white,
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(isMine ? 8 : 0),
                                          topRight: Radius.circular(isMine ? 0 : 8),
                                          bottomLeft: const Radius.circular(8),
                                          bottomRight: const Radius.circular(8),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 1,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Nom de l'auteur (seulement pour les autres)
                                          if (!isMine)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 2),
                                              child: Text(
                                                authorName,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: _getAuthorColor(authorName),
                                                ),
                                              ),
                                            ),
                                          _buildPostContent(p, replyTo),
                                          const SizedBox(height: 2),
                                          // Heure alignée à droite style WhatsApp
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              const Spacer(),
                                              Text(
                                                timeText,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              // Double check pour les messages envoyés
                                              if (isMine) ...[
                                                const SizedBox(width: 3),
                                                Icon(
                                                  Icons.done_all,
                                                  size: 16,
                                                  color: Colors.blue.shade400,
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (_hasReactions(p))
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: _buildReactionsRow(p, isMine),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: isMine
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'reply') {
                                          setState(() {
                                            _replyToPost = p;
                                          });
                                        } else if (value == 'delete') {
                                          _confirmDeleteMyPost(p);
                                        } else if (value == 'report') {
                                          _openReportPostDialog(p);
                                        }
                                      },
                                      itemBuilder: (context) {
                                        final items = <PopupMenuEntry<String>>[
                                          const PopupMenuItem(
                                            value: 'reply',
                                            child: Text('Répondre'),
                                          ),
                                        ];
                                        if (isMine) {
                                          items.add(
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Supprimer pour tout le monde'),
                                            ),
                                          );
                                        }
                                        items.add(
                                          const PopupMenuItem(
                                            value: 'report',
                                            child: Text('Signaler ce message'),
                                          ),
                                        );
                                        return items;
                                      },
                                      padding: EdgeInsets.zero,
                                      child: const Icon(
                                        Icons.more_vert,
                                        size: 18,
                                        color: Colors.black45,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
              ),
              // Zone de saisie style WhatsApp
              Container(
                color: const Color(0xFFF0F0F0),
                padding: EdgeInsets.only(
                  left: 8,
                  right: 8,
                  bottom: MediaQuery.of(context).padding.bottom + 8,
                  top: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Barre de réponse si active
                    if (_replyToPost != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: const Border(
                            left: BorderSide(
                              color: Color(0xFF25D366),
                              width: 4,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Réponse',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF25D366),
                                    ),
                                  ),
                                  Text(
                                    _replyToPost!['content']?.toString() ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _replyToPost = null;
                                });
                              },
                              child: Icon(
                                Icons.close,
                                size: 20,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Barre de saisie
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Champ de texte style WhatsApp
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Bouton emoji (décoratif)
                                IconButton(
                                  icon: Icon(
                                    Icons.emoji_emotions_outlined,
                                    color: Colors.grey.shade600,
                                  ),
                                  onPressed: _showEmojiPickerForInput,
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(),
                                ),
                                // Champ de texte
                                Expanded(
                                  child: TextField(
                                    controller: _messageController,
                                    minLines: 1,
                                    maxLines: 5,
                                    textCapitalization: TextCapitalization.sentences,
                                    decoration: InputDecoration(
                                      hintText: 'Message',
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
                                ),
                                // Bouton pièce jointe
                                IconButton(
                                  icon: Icon(
                                    Icons.attach_file,
                                    color: Colors.grey.shade600,
                                  ),
                                  onPressed: provider.isSaving
                                      ? null
                                      : _pickAndUploadAttachment,
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 4),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Bouton envoyer/micro style WhatsApp
                        Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF25D366),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              _messageController.text.trim().isEmpty && !kIsWeb
                                  ? (_isRecording ? Icons.stop : Icons.mic)
                                  : Icons.send,
                              color: Colors.white,
                              size: 22,
                            ),
                            onPressed: provider.isSaving
                                ? null
                                : () {
                                    if (_messageController.text.trim().isEmpty && !kIsWeb) {
                                      _toggleRecording();
                                    } else {
                                      _sendMessage();
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AudioAttachmentPlayer extends StatefulWidget {
  final String url;

  const _AudioAttachmentPlayer({
    required this.url,
  });

  @override
  State<_AudioAttachmentPlayer> createState() => _AudioAttachmentPlayerState();
}

class _AudioAttachmentPlayerState extends State<_AudioAttachmentPlayer> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
      });
    });
  }

  Future<void> _toggle() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    try {
      if (_isPlaying) {
        await _player.pause();
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
        }
      } else {
        await _player.play(UrlSource(widget.url));
        if (mounted) {
          setState(() {
            _isPlaying = true;
          });
        }
      }
    } catch (_) {
      // On reste silencieux côté UI en cas d'erreur ponctuelle de lecture.
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F4EA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: _isLoading ? null : _toggle,
          ),
          const SizedBox(width: 8),
          const Text(
            'Message vocal',
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
