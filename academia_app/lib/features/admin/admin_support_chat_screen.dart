import 'dart:async';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/admin_support_provider.dart';
import '../student/community_audio_recorder.dart'
    if (dart.library.html) '../student/community_audio_recorder_stub.dart';

/// Écran admin: chat d'une conversation support individuelle.
/// Avec support: texte, images, documents, vocal, photo caméra.
class AdminSupportChatScreen extends StatefulWidget {
  final String conversationId;
  final String requesterName;
  final String requesterRole;
  final String status;

  const AdminSupportChatScreen({
    super.key,
    required this.conversationId,
    required this.requesterName,
    required this.requesterRole,
    required this.status,
  });

  @override
  State<AdminSupportChatScreen> createState() => _AdminSupportChatScreenState();
}

class _AdminSupportChatScreenState extends State<AdminSupportChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _initialLoading = true;
  bool _isUploading = false;
  CommunityAudioRecorder? _audioRecorder;
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
    _messageController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<AdminSupportProvider>();
      await provider.loadMessages(widget.conversationId);
      provider.subscribeToMessages(widget.conversationId);
      await provider.markRead(widget.conversationId);
      if (mounted) {
        setState(() => _initialLoading = false);
        _scrollToBottom(animate: false);
      }
    });
  }

  @override
  void dispose() {
    try { context.read<AdminSupportProvider>().unsubscribeFromMessages(); } catch (_) {}
    _recordingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder?.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(target,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    final provider = context.read<AdminSupportProvider>();
    final ok = await provider.sendMessage(widget.conversationId, text);
    if (!mounted) return;
    if (ok) {
      _scrollToBottom();
    } else if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!)),
      );
    }
  }

  Future<void> _toggleStatus() async {
    final newStatus = _currentStatus == 'open' ? 'closed' : 'open';
    final provider = context.read<AdminSupportProvider>();
    final ok = await provider.setConversationStatus(widget.conversationId, newStatus);
    if (!mounted) return;
    if (ok) {
      setState(() => _currentStatus = newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus == 'closed'
              ? 'Conversation clôturée.'
              : 'Conversation ré-ouverte.'),
        ),
      );
    }
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(dt.year, dt.month, dt.day);
    if (msgDate == today) return DateFormat('HH:mm').format(dt);
    if (msgDate == today.subtract(const Duration(days: 1))) {
      return 'Hier ${DateFormat('HH:mm').format(dt)}';
    }
    return DateFormat('dd/MM HH:mm').format(dt);
  }

  Future<void> _pickAndUploadAttachment() async {
    if (_isUploading) return;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false, withData: kIsWeb,
      type: FileType.custom,
      allowedExtensions: const ['jpg','jpeg','png','pdf','doc','docx','mp3','m4a','wav','ogg'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final ext = (file.extension ?? '').toLowerCase();
    Uint8List? bytes = file.bytes;
    if (bytes == null && !kIsWeb) {
      final path = file.path;
      if (path != null && path.isNotEmpty) {
        try { bytes = await File(path).readAsBytes(); } catch (_) {}
      }
    }
    if (bytes == null || bytes.isEmpty || bytes.length > 10 * 1024 * 1024) return;
    String type = 'file';
    if (['jpg','jpeg','png'].contains(ext)) type = 'image';
    else if (['mp3','m4a','wav','ogg'].contains(ext)) type = 'audio';
    setState(() => _isUploading = true);
    final provider = context.read<AdminSupportProvider>();
    final url = await provider.uploadSupportMedia(
      conversationId: widget.conversationId, bytes: bytes, fileName: file.name, mimeType: ext);
    if (mounted) setState(() => _isUploading = false);
    if (!mounted || url == null) return;
    await provider.sendMessage(widget.conversationId, '', type: type, mediaUrl: url);
    if (mounted) _scrollToBottom();
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) return;
    setState(() => _isUploading = true);
    final provider = context.read<AdminSupportProvider>();
    final url = await provider.uploadSupportMedia(
      conversationId: widget.conversationId, bytes: bytes, fileName: picked.name, mimeType: 'jpg');
    if (mounted) setState(() => _isUploading = false);
    if (!mounted || url == null) return;
    await provider.sendMessage(widget.conversationId, '', type: 'image', mediaUrl: url);
    if (mounted) _scrollToBottom();
  }

  Future<void> _toggleRecording() async {
    final provider = context.read<AdminSupportProvider>();
    _audioRecorder ??= CommunityAudioRecorder();
    if (_isRecording) {
      _recordingTimer?.cancel();
      final bytes = await _audioRecorder!.stop();
      setState(() { _isRecording = false; _recordingSeconds = 0; });
      if (bytes == null || bytes.isEmpty) return;
      final ext = _audioRecorder!.fileExtension;
      final fileName = 'vocal_${DateTime.now().millisecondsSinceEpoch}.$ext';
      setState(() => _isUploading = true);
      final url = await provider.uploadSupportMedia(
        conversationId: widget.conversationId, bytes: bytes, fileName: fileName, mimeType: ext);
      if (mounted) setState(() => _isUploading = false);
      if (!mounted || url == null) return;
      await provider.sendMessage(widget.conversationId, '', type: 'audio', mediaUrl: url);
      if (mounted) _scrollToBottom();
    } else {
      try {
        final hasPerm = await _audioRecorder!.hasPermission();
        if (!hasPerm) return;
        await _audioRecorder!.start();
        if (!mounted) return;
        setState(() { _isRecording = true; _recordingSeconds = 0; });
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _recordingSeconds++);
        });
      } catch (e) { debugPrint('[AdminSupportChat] audio error: $e'); }
    }
  }

  Widget _buildMessageContent(Map<String, dynamic> msg) {
    final content = (msg['content'] ?? '').toString();
    final type = (msg['type'] ?? 'text').toString();
    final mediaUrl = (msg['media_url'] ?? '').toString();
    if (type == 'text' || mediaUrl.isEmpty) {
      return content.isNotEmpty ? Text(content, style: const TextStyle(fontSize: 14, height: 1.4)) : const SizedBox.shrink();
    }
    if (type == 'image') {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(borderRadius: BorderRadius.circular(8),
          child: Image.network(mediaUrl, fit: BoxFit.cover,
            loadingBuilder: (_, child, p) => p == null ? child : const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)))),
        if (content.isNotEmpty) ...[const SizedBox(height: 4), Text(content, style: const TextStyle(fontSize: 14, height: 1.4))],
      ]);
    }
    if (type == 'audio') return _AdminAudioPlayer(url: mediaUrl);
    final uri = Uri.tryParse(mediaUrl);
    String label = mediaUrl;
    if (uri != null && uri.pathSegments.isNotEmpty) label = uri.pathSegments.last;
    final lower = label.toLowerCase();
    IconData fileIcon = Icons.insert_drive_file;
    if (lower.endsWith('.pdf')) fileIcon = Icons.picture_as_pdf;
    else if (lower.endsWith('.doc') || lower.endsWith('.docx')) fileIcon = Icons.description;
    return InkWell(
      onTap: () { final u = Uri.tryParse(mediaUrl); if (u != null) launchUrl(u, mode: LaunchMode.externalApplication); },
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(fileIcon, size: 28, color: const Color(0xFF1EA75C)),
        const SizedBox(width: 8),
        Flexible(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, decoration: TextDecoration.underline, color: Color(0xFF1EA75C)))),
      ]),
    );
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
        return role ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isClosed = _currentStatus == 'closed';

    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        elevation: 1,
        backgroundColor: const Color(0xFF1EA75C),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.requesterName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_roleLabel(widget.requesterRole)} ${isClosed ? '· Clôturée' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(isClosed ? Icons.lock_open : Icons.check_circle_outline),
            tooltip: isClosed ? 'Ré-ouvrir' : 'Clôturer',
            onPressed: _toggleStatus,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<AdminSupportProvider>(
              builder: (context, provider, _) {
                if (_initialLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = provider.messages;
                if (messages.isNotEmpty) _scrollToBottom();

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Aucun message dans cette conversation.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isAdmin = msg['sender_side'] == 'admin';
                    final timeStr = _formatTime(msg['created_at']?.toString());
                    final isRead = msg['is_read'] == true;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: isAdmin
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isAdmin)
                            Container(
                              width: 28,
                              height: 28,
                              margin: const EdgeInsets.only(right: 6, bottom: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32).withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person, size: 16,
                                  color: Color(0xFF2E7D32)),
                            ),
                          Flexible(
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.78,
                              ),
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                              decoration: BoxDecoration(
                                color: isAdmin
                                    ? const Color(0xFFDCF8C6)
                                    : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(12),
                                  topRight: const Radius.circular(12),
                                  bottomLeft: Radius.circular(isAdmin ? 12 : 2),
                                  bottomRight: Radius.circular(isAdmin ? 2 : 12),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isAdmin)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Text(
                                        widget.requesterName,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2E7D32),
                                        ),
                                      ),
                                    ),
                                  _buildMessageContent(msg),
                                  const SizedBox(height: 2),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          timeStr,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        if (isAdmin) ...[
                                          const SizedBox(width: 3),
                                          Icon(
                                            Icons.done_all,
                                            size: 14,
                                            color: isRead
                                                ? const Color(0xFF53BDEB)
                                                : Colors.grey.shade400,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Input bar (disabled if closed)
          Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: isClosed
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Conversation clôturée. Ré-ouvrez pour répondre.',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isUploading)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 8),
                              Text('Envoi en cours...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ]),
                          ),
                        if (_isRecording)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(children: [
                              const Icon(Icons.mic, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Text('Enregistrement... ${_recordingSeconds}s', style: const TextStyle(color: Colors.red, fontSize: 13)),
                              const Spacer(),
                              TextButton(onPressed: _toggleRecording, child: const Text('Envoyer', style: TextStyle(fontWeight: FontWeight.w600))),
                            ]),
                          ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.attach_file, color: Color(0xFF1EA75C), size: 22),
                              onPressed: _isUploading ? null : _pickAndUploadAttachment,
                              tooltip: 'Joindre un fichier',
                            ),
                            IconButton(
                              icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF1EA75C), size: 22),
                              onPressed: _isUploading ? null : _takePhoto,
                              tooltip: 'Prendre une photo',
                            ),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                                child: TextField(
                                  controller: _messageController,
                                  textCapitalization: TextCapitalization.sentences,
                                  maxLines: 4, minLines: 1,
                                  decoration: const InputDecoration(
                                    hintText: 'Répondre...', hintStyle: TextStyle(color: Colors.grey),
                                    border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Consumer<AdminSupportProvider>(
                              builder: (context, provider, _) {
                                final hasText = _messageController.text.trim().isNotEmpty;
                                if (hasText) {
                                  return Container(width: 42, height: 42,
                                    decoration: const BoxDecoration(color: Color(0xFF1EA75C), shape: BoxShape.circle),
                                    child: IconButton(
                                      icon: provider.isSaving
                                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : const Icon(Icons.send, color: Colors.white, size: 20),
                                      onPressed: provider.isSaving ? null : _sendMessage,
                                    ),
                                  );
                                }
                                return Container(width: 42, height: 42,
                                  decoration: BoxDecoration(
                                    color: _isRecording ? Colors.red : const Color(0xFF1EA75C), shape: BoxShape.circle),
                                  child: IconButton(
                                    icon: Icon(_isRecording ? Icons.stop : Icons.mic, color: Colors.white, size: 20),
                                    onPressed: _isUploading ? null : _toggleRecording,
                                  ),
                                );
                              },
                            ),
                          ],
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

class _AdminAudioPlayer extends StatefulWidget {
  final String url;
  const _AdminAudioPlayer({required this.url});
  @override
  State<_AdminAudioPlayer> createState() => _AdminAudioPlayerState();
}

class _AdminAudioPlayerState extends State<_AdminAudioPlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
    } else {
      await _player.play(UrlSource(widget.url));
      setState(() => _playing = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        icon: Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: const Color(0xFF1EA75C), size: 36),
        onPressed: _toggle,
      ),
      const Text('Audio', style: TextStyle(fontSize: 13)),
    ]);
  }
}
