import 'dart:async';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/student_direct_messages_provider.dart';
import '../../widgets/academia_rich_content.dart';
import '../../widgets/academia_math_input.dart';
import 'community_audio_recorder.dart'
    if (dart.library.html) 'community_audio_recorder_stub.dart';

/// Écran de chat privé 1-à-1 style WhatsApp
class StudentDmChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String otherUserId;

  const StudentDmChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    required this.otherUserId,
  });

  @override
  State<StudentDmChatScreen> createState() => _StudentDmChatScreenState();
}

class _StudentDmChatScreenState extends State<StudentDmChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _loadingMessages = false;
  bool _isUploading = false;
  CommunityAudioRecorder? _audioRecorder;
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<StudentDirectMessagesProvider>();
      setState(() => _loadingMessages = true);
      await provider.loadMessages(widget.conversationId);
      provider.subscribeToDmMessages(widget.conversationId);
      await provider.markConversationRead(widget.conversationId);
      if (mounted) setState(() => _loadingMessages = false);
    });
  }

  @override
  void dispose() {
    final provider = context.read<StudentDirectMessagesProvider>();
    provider.unsubscribeFromDmMessages();
    _recordingTimer?.cancel();
    _messageController.dispose();
    _audioRecorder?.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    final provider = context.read<StudentDirectMessagesProvider>();
    final ok = await provider.sendMessage(
      conversationId: widget.conversationId,
      content: text,
    );
    if (!mounted) return;
    if (!ok && provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!)),
      );
    }
  }

  Future<void> _pickAndUploadAttachment() async {
    final provider = context.read<StudentDirectMessagesProvider>();
    if (_isUploading) return;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: kIsWeb,
      type: FileType.custom,
      allowedExtensions: const [
        'jpg', 'jpeg', 'png',
        'pdf', 'doc', 'docx',
        'mp3', 'm4a', 'wav', 'ogg',
      ],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final fileName = file.name;
    final ext = (file.extension ?? '').toLowerCase();

    // Sur Android/iOS, file.bytes est souvent null → lire depuis file.path
    Uint8List? bytes = file.bytes;
    if (bytes == null && !kIsWeb) {
      final path = file.path;
      if (path != null && path.isNotEmpty) {
        try {
          bytes = await File(path).readAsBytes();
          debugPrint('[DM pickAttachment] Read ${bytes.length} bytes from path: $path');
        } catch (e) {
          debugPrint('[DM pickAttachment] Error reading file path: $e');
        }
      }
    }

    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de lire le contenu du fichier.'),
        ),
      );
      return;
    }

    const maxSizeBytes = 10 * 1024 * 1024; // 10 MB
    if (bytes.length > maxSizeBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le fichier dépasse la limite de 10 Mo.'),
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

    setState(() => _isUploading = true);
    final url = await provider.uploadDmMedia(
      conversationId: widget.conversationId,
      bytes: bytes,
      fileName: fileName,
      mimeType: ext,
    );
    if (mounted) setState(() => _isUploading = false);

    if (!mounted) return;

    if (url == null) {
      if (provider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error!)),
        );
      }
      return;
    }

    final ok = await provider.sendMessage(
      conversationId: widget.conversationId,
      content: '',
      type: type,
      mediaUrl: url,
    );

    if (!mounted) return;
    if (!ok && provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!)),
      );
    }
  }

  Future<void> _toggleRecording() async {
    final provider = context.read<StudentDirectMessagesProvider>();

    _audioRecorder ??= CommunityAudioRecorder();

    if (_isRecording) {
      _recordingTimer?.cancel();
      final bytes = await _audioRecorder!.stop();
      setState(() {
        _isRecording = false;
        _recordingSeconds = 0;
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

      final ext = _audioRecorder!.fileExtension;
      final fileName =
          'vocal_${DateTime.now().millisecondsSinceEpoch}.$ext';

      setState(() => _isUploading = true);
      final url = await provider.uploadDmMedia(
        conversationId: widget.conversationId,
        bytes: bytes,
        fileName: fileName,
        mimeType: ext,
      );
      if (mounted) setState(() => _isUploading = false);

      if (!mounted) return;

      if (url == null) {
        if (provider.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(provider.error!)),
          );
        }
        return;
      }

      final ok = await provider.sendMessage(
        conversationId: widget.conversationId,
        content: '',
        type: 'audio',
        mediaUrl: url,
      );

      if (!mounted) return;
      if (!ok && provider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error!)),
        );
      }
    } else {
      try {
        final hasPermission = await _audioRecorder!.hasPermission();
        if (!hasPermission) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Permission micro refusée. Autorise l'accès au microphone dans les paramètres de ton téléphone.",
              ),
            ),
          );
          return;
        }

        await _audioRecorder!.start();
        if (!mounted) return;
        setState(() {
          _isRecording = true;
          _recordingSeconds = 0;
        });
        _recordingTimer?.cancel();
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          setState(() {
            _recordingSeconds++;
          });
        });
      } catch (e) {
        debugPrint('[DmAudioRecorder] start error: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Impossible de démarrer l\'enregistrement : ${e.toString().length > 80 ? e.toString().substring(0, 80) : e}',
            ),
          ),
        );
      }
    }
  }

  Widget _buildMessageContent(Map<String, dynamic> m) {
    final content = (m['content'] ?? '').toString();
    final type = (m['type'] ?? 'text').toString();
    final mediaUrl = (m['media_url'] ?? '').toString();

    if (type == 'text' || mediaUrl.isEmpty) {
      if (content.isNotEmpty) {
        return AcademiaRichContent(
          content: content,
          style: const TextStyle(fontSize: 14),
        );
      }
      return const SizedBox.shrink();
    }

    Widget mediaWidget;

    if (type == 'image') {
      mediaWidget = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(mediaUrl, fit: BoxFit.cover),
      );
    } else if (type == 'audio') {
      mediaWidget = _DmAudioPlayer(url: mediaUrl);
    } else {
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
      }
      mediaWidget = InkWell(
        onTap: () async {
          final u = Uri.tryParse(mediaUrl);
          if (u != null) await launchUrl(u);
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
      );
    }

    if (content.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          mediaWidget,
          const SizedBox(height: 8),
          AcademiaRichContent(
            content: content,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      );
    }
    return mediaWidget;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);
    if (msgDate == today) return "AUJOURD'HUI";
    if (msgDate == yesterday) return 'HIER';
    return DateFormat('dd MMMM yyyy', 'fr_FR').format(date).toUpperCase();
  }

  Color _getAuthorColor(String name) {
    if (name.isEmpty) return Colors.grey;
    const colors = [
      Color(0xFF00A884),
      Color(0xFF5DADE2),
      Color(0xFFE74C3C),
      Color(0xFF9B59B6),
      Color(0xFFF39C12),
      Color(0xFF1ABC9C),
      Color(0xFFE91E63),
      Color(0xFF3498DB),
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentDirectMessagesProvider>(
      builder: (context, provider, _) {
        final messages = provider.messages;
        final currentUserId = provider.currentUserId;

        return Scaffold(
          backgroundColor: const Color(0xFFECE5DD),
          appBar: AppBar(
            elevation: 1,
            backgroundColor: const Color(0xFF075E54),
            foregroundColor: Colors.white,
            leadingWidth: 30,
            titleSpacing: 0,
            title: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _getAuthorColor(widget.otherUserName),
                  child: Text(
                    widget.otherUserName.isNotEmpty
                        ? widget.otherUserName[0].toUpperCase()
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
                  child: Text(
                    widget.otherUserName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: _loadingMessages
                    ? const Center(child: CircularProgressIndicator())
                    : messages.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Aucun message. Envoie le premier !',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(12, 8, 12, 8),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final m = messages[index];
                              final createdAt = DateTime.tryParse(
                                  (m['created_at'] ?? '').toString());
                              final isMine = currentUserId != null &&
                                  m['sender_id']?.toString() ==
                                      currentUserId;
                              final content =
                                  (m['content'] ?? '').toString();
                              final timeText = createdAt != null
                                  ? DateFormat('HH:mm').format(createdAt)
                                  : '';

                              final dayKey = createdAt != null
                                  ? DateFormat('yyyy-MM-dd')
                                      .format(createdAt)
                                  : '';
                              String? prevDayKey;
                              if (index > 0) {
                                final prev = DateTime.tryParse(
                                    (messages[index - 1]['created_at'] ??
                                            '')
                                        .toString());
                                if (prev != null) {
                                  prevDayKey =
                                      DateFormat('yyyy-MM-dd').format(prev);
                                }
                              }
                              final showDate =
                                  dayKey.isNotEmpty && dayKey != prevDayKey;

                              return Column(
                                children: [
                                  if (showDate && createdAt != null)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD9DBE1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _formatDateHeader(createdAt),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF54656F),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Align(
                                    alignment: isMine
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: GestureDetector(
                                      onLongPress: () {
                                        if (content.isNotEmpty) {
                                          Clipboard.setData(
                                              ClipboardData(text: content));
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content:
                                                  Text('Message copié'),
                                              duration:
                                                  Duration(seconds: 1),
                                            ),
                                          );
                                        }
                                      },
                                      child: Container(
                                        margin: EdgeInsets.only(
                                          top: 2,
                                          bottom: 2,
                                          left: isMine ? 60 : 8,
                                          right: isMine ? 8 : 60,
                                        ),
                                        padding:
                                            const EdgeInsets.fromLTRB(
                                                9, 6, 9, 6),
                                        decoration: BoxDecoration(
                                          color: isMine
                                              ? const Color(0xFFD9FDD3)
                                              : Colors.white,
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(
                                                isMine ? 8 : 0),
                                            topRight: Radius.circular(
                                                isMine ? 0 : 8),
                                            bottomLeft:
                                                const Radius.circular(8),
                                            bottomRight:
                                                const Radius.circular(8),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.05),
                                              blurRadius: 1,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildMessageContent(m),
                                            const SizedBox(height: 2),
                                            Row(
                                              mainAxisSize:
                                                  MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                const Spacer(),
                                                if (m['edited_at'] !=
                                                    null)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets
                                                            .only(
                                                            right: 4),
                                                    child: Text(
                                                      'modifié',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontStyle:
                                                            FontStyle
                                                                .italic,
                                                        color: Colors.grey
                                                            .shade500,
                                                      ),
                                                    ),
                                                  ),
                                                Text(
                                                  timeText,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors
                                                        .grey.shade600,
                                                  ),
                                                ),
                                                if (isMine) ...[
                                                  const SizedBox(width: 3),
                                                  Icon(
                                                    Icons.done_all,
                                                    size: 16,
                                                    color: Colors
                                                        .blue.shade400,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
              ),
              // Indicateur d'upload en cours
              if (_isUploading)
                const LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: Color(0xFFE0E0E0),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF25D366)),
                ),
              // Zone de saisie
              Container(
                color: const Color(0xFFF0F0F0),
                padding: EdgeInsets.only(
                  left: 8,
                  right: 8,
                  bottom: MediaQuery.of(context).padding.bottom + 8,
                  top: 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _isRecording
                          ? Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: const Color(0xFFFCA5A5),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.fiber_manual_record,
                                      size: 12, color: Color(0xFFDC2626)),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${(_recordingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_recordingSeconds % 60).toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      color: Color(0xFFDC2626),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () {
                                      _recordingTimer?.cancel();
                                      _audioRecorder?.stop();
                                      setState(() {
                                        _isRecording = false;
                                        _recordingSeconds = 0;
                                      });
                                    },
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.delete_outline,
                                            size: 16, color: Color(0xFF9CA3AF)),
                                        SizedBox(width: 4),
                                        Text(
                                          'Annuler',
                                          style: TextStyle(
                                            color: Color(0xFF9CA3AF),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Bouton formule mathématique
                                  AcademiaMathButton(
                                    iconSize: 22,
                                    onInsertFormula: (tex) {
                                      final current = _messageController.text;
                                      final selection = _messageController.selection;
                                      final insert = ' \$${tex}\$ ';
                                      if (selection.isValid && selection.baseOffset >= 0) {
                                        final newText = current.replaceRange(
                                          selection.start, selection.end, insert);
                                        _messageController.value = TextEditingValue(
                                          text: newText,
                                          selection: TextSelection.collapsed(
                                            offset: selection.start + insert.length),
                                        );
                                      } else {
                                        _messageController.text = current + insert;
                                        _messageController.selection = TextSelection.collapsed(
                                          offset: _messageController.text.length);
                                      }
                                    },
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _messageController,
                                      minLines: 1,
                                      maxLines: 5,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      decoration: InputDecoration(
                                        hintText: 'Message',
                                        hintStyle: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 16,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 0,
                                          vertical: 10,
                                        ),
                                      ),
                                    ),
                                  ),
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
                    Container(
                      decoration: BoxDecoration(
                        color: _isRecording
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF25D366),
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
                                if (_messageController.text.trim().isEmpty &&
                                    !kIsWeb) {
                                  _toggleRecording();
                                } else {
                                  _sendMessage();
                                }
                              },
                      ),
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

class _DmAudioPlayer extends StatefulWidget {
  final String url;

  const _DmAudioPlayer({required this.url});

  @override
  State<_DmAudioPlayer> createState() => _DmAudioPlayerState();
}

class _DmAudioPlayerState extends State<_DmAudioPlayer> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _hasError = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
    _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _toggle() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      if (_isPlaying) {
        await _player.pause();
        if (mounted) setState(() => _isPlaying = false);
      } else {
        await _player.play(UrlSource(widget.url));
        if (mounted) setState(() => _isPlaying = true);
      }
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_duration.inMilliseconds > 0)
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F4EA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _isLoading ? null : _toggle,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF25D366),
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 18,
                      color: Colors.white,
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: Colors.black12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF25D366),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _hasError
                      ? 'Erreur lecture'
                      : '${_fmt(_position)} / ${_duration.inMilliseconds > 0 ? _fmt(_duration) : '--:--'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: _hasError ? Colors.red.shade400 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
