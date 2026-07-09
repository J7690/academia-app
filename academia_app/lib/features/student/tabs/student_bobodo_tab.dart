import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers/bobodo_provider.dart';
import '../../../theme/prep_theme.dart';
import '../../share/share_service.dart';
import '../../share/share_mode_provider.dart';
import '../../share/widgets/share_signature.dart';
import '../../../services/bobodo_vocal_service.dart';
import '../../../services/voice_provider.dart';

enum ConversationState {
  idle,           // En attente
  listening,      // Écoute utilisateur
  processing,     // Traitement transcription
  thinking,       // Bobodo réfléchit
  responding,     // Bobodo répond
  playing,        // Lecture audio
  paused,         // Pause
  ended,          // Fin session
}

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
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  bool _showEmojiPicker = false;
  int _prevMessageCount = 0;

  // Mode vocal
  bool _isRecordingMode = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isSending = false;
  bool _isSpeaking = false;

  // Mode conversation
  bool _isConversationMode = false;
  bool _isProcessingConversation = false; // P1-3: protection contre double envoi
  ConversationState _conversationState = ConversationState.idle;
  Timer? _inactivityTimer;

  // Mémoire conversationnelle (10 derniers échanges)
  final List<Map<String, String>> _conversationMemory = [];
  static const int _maxMemorySize = 10;

  // Enregistrement
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  // Audio
  StreamController<Uint8List>? _audioStreamController;
  List<Uint8List> _audioBuffer = [];

  // Speech-to-Text natif
  final SpeechToText _speechToText = SpeechToText();
  bool _speechAvailable = false;
  String _lastRecognizedWords = '';

  // WebSocket vocal
  BobodoVocalService _vocalService = BobodoVocalService(
    'ws://185.167.97.144:8000/ws',
  );
  bool _isVocalConnected = false;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _errorSubscription;

  // Animation audio
  List<double> _audioLevels = [0.0, 0.0, 0.0, 0.0, 0.0];
  Timer? _audioLevelTimer;

  // VAD (Voice Activity Detection)
  static const double _vadThreshold = 0.3; // Seuil de détection vocale
  static const Duration _vadSilenceDuration = Duration(milliseconds: 800); // Durée de silence avant arrêt
  Timer? _vadSilenceTimer;
  bool _isVoiceDetected = false;

  // TTS UX
  bool _autoTtsEnabled = true;
  Uint8List? _lastAudioResponse;
  bool _useLocalTtsFallback = false; // Flag pour fallback TTS local

  // Guide première utilisation
  bool _hasSeenConversationGuide = false;

  static const _suggestedPrompts = [
    "Qu'est-ce qu'Academia ?",
    'Aide à l\'orientation',
    'Universités partenaires',
    'Comment postuler ?',
  ];

  @override
  void initState() {
    super.initState();

    // Restaurer la dernière conversation active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BobodoProvider>().restoreLastSession();
    });

    // Réactivité bouton envoi
    _controller.addListener(() => setState(() {}));

    // Audio vocal
    _audioStreamController = StreamController<Uint8List>();
    _audioStreamController?.stream.listen(_onAudioData);
    _initRecorder();
    _connectVocalWebSocket();
    _initFlutterTts();

    // Charger le guide de première utilisation
    _loadConversationGuideStatus();
  }

  @override
  void dispose() {
    // Vocal
    _recorder.closeRecorder();
    _vocalService.disconnect();
    _vocalService.dispose();
    _messageSubscription?.cancel();
    _errorSubscription?.cancel();
    _audioStreamController?.close();
    _recordingTimer?.cancel();
    _audioLevelTimer?.cancel();
    _inactivityTimer?.cancel();
    _vadSilenceTimer?.cancel();

    // Existant
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _audioPlayer.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initFlutterTts() async {
    await _flutterTts.setLanguage('fr-FR');
    await _flutterTts.setSpeechRate(0.9);
    await _flutterTts.setVolume(1.0);
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
              // Scroll after loading messages (session restoration)
              if (provider.shouldScrollToBottom) {
                _scrollToBottom();
                provider.resetScrollFlag();
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
                    // ─── Bandeau mode conversation vocale ───
                    if (_isConversationMode)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        color: PrepTheme.primary.withValues(alpha: 0.08),
                        child: Row(
                          children: [
                            Icon(Icons.record_voice_over, size: 16, color: PrepTheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Conversation vocale — Parlez naturellement, Bobodo comprend quand vous avez fini.',
                                style: TextStyle(fontSize: 12, color: PrepTheme.primary, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // ─── Conversation controls ───
                    if (_isConversationMode)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: _buildConversationControls(),
                      ),
                    // ─── Input bar ───
                    if (!_isConversationMode)
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
      child: Column(
        children: [
          Row(
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
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
              // Toggle mode conversation vocale
              Container(
                decoration: _isConversationMode
                    ? BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      )
                    : null,
                child: IconButton(
                  icon: Icon(
                    Icons.record_voice_over,
                    color: _isConversationMode ? PrepTheme.primary : Colors.white,
                    size: 22,
                  ),
                  tooltip: _isConversationMode ? 'Arrêter la conversation' : 'Conversation vocale',
                  onPressed: _toggleVoiceMode,
                ),
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
          // Indicateur d'état conversation
          if (_isConversationMode)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildConversationStateIndicator(),
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
                                const SnackBar(content: Text('Copié')),
                              );
                            },
                          ),
                          // TTS controls for bot messages
                          if (!isUser && _isSpeaking) ...[
                            const SizedBox(width: 2),
                            _FeedbackButton(
                              icon: Icons.stop_circle_outlined,
                              isActive: false,
                              isUser: isUser,
                              onTap: _stopAudioPlayback,
                            ),
                          ],
                          if (!isUser && !_isSpeaking && _lastAudioResponse != null) ...[
                            const SizedBox(width: 2),
                            _FeedbackButton(
                              icon: Icons.play_circle_outline,
                              isActive: false,
                              isUser: isUser,
                              onTap: _replayAudio,
                            ),
                          ],
                          if (!isUser) ...[
                            const SizedBox(width: 2),
                            _FeedbackButton(
                              icon: _autoTtsEnabled
                                  ? Icons.volume_up
                                  : Icons.volume_off,
                              isActive: _autoTtsEnabled,
                              isUser: isUser,
                              onTap: _toggleAutoTts,
                            ),
                          ],
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
                color: _isRecordingMode ? PrepTheme.textTertiary : PrepTheme.textTertiary,
                size: 22,
              ),
              onPressed: _isRecordingMode ? null : () {
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
            // Zone de saisie (texte ou vocal)
            Expanded(
              child: _isRecordingMode
                  ? _buildVocalInputInterface()
                  : _buildTextInputInterface(),
            ),
            const SizedBox(width: 6),
            // Bouton vocal ou envoi
            _isRecordingMode
                ? _buildVocalActionButtons()
                : _buildTextActionButtons(provider),
          ],
        ),
      ),
    );
  }

  // ─── Interface texte ────────────────────────────────────────────────

  Widget _buildTextInputInterface() {
    return Container(
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
    );
  }

  Widget _buildTextActionButtons(BobodoProvider provider) {
    return Row(
      children: [
        // Bouton micro
        IconButton(
          icon: Icon(
            Icons.mic,
            color: PrepTheme.primary,
            size: 22,
          ),
          onPressed: _startVocalRecording,
        ),
        const SizedBox(width: 4),
        // Bouton envoi
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
            onPressed: provider.isLoading || _controller.text.trim().isEmpty
                ? null
                : () => _send(context),
          ),
        ),
      ],
    );
  }

  // ─── Interface vocale ──────────────────────────────────────────────

  // ─── Mode dictée : Interface vocale style WhatsApp ──────────────────

  Widget _buildVocalInputInterface() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PrepTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PrepTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Indicateur enregistrement (point rouge pulsant + durée)
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: PrepTheme.danger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatRecordingDuration(_recordingDuration),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: PrepTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          // Transcription partielle visible
          Expanded(
            child: Text(
              _lastRecognizedWords.isNotEmpty
                  ? _lastRecognizedWords
                  : 'Parlez...',
              style: TextStyle(
                fontSize: 13,
                color: _lastRecognizedWords.isNotEmpty
                    ? PrepTheme.textPrimary
                    : PrepTheme.textTertiary,
                fontStyle: _lastRecognizedWords.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVocalActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bouton annuler (❌)
        GestureDetector(
          onTap: _cancelVocalRecording,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: PrepTheme.danger.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.close, size: 18, color: PrepTheme.danger),
          ),
        ),
        const SizedBox(width: 8),
        // Bouton ENVOYER — fonctionne toujours (stop + envoi forcé)
        GestureDetector(
          onTap: _forceStopAndSend,
          child: Container(
            width: 44,
            height: 44,
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
            child: const Icon(Icons.send, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  /// Force l'arrêt de l'enregistrement et envoie le texte transcrit (mode dictée)
  void _forceStopAndSend() {
    // IMPORTANT: Lire le texte AVANT d'arrêter le STT
    final text = _lastRecognizedWords.trim();
    debugPrint('[DICTEE_SEND] Texte à envoyer: "$text"');

    // Arrêter le STT (cancel pour éviter le callback final)
    _speechToText.cancel();
    _recordingTimer?.cancel();
    _audioLevelTimer?.cancel();
    _lastRecognizedWords = '';

    setState(() {
      _isRecordingMode = false;
      _isRecording = false;
      _recordingDuration = Duration.zero;
    });

    if (text.isNotEmpty) {
      // Placer dans le champ et envoyer
      _controller.text = text;
      _send(context);
    }
  }

  Future<void> _send(BuildContext context) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() => _showEmojiPicker = false);
    final provider = context.read<BobodoProvider>();
    await provider.sendUserMessage(text);
  }

  /// Envoyer le message vocal en mode conversation.
  /// Fonctionne que le STT soit encore actif ou déjà terminé.
  void _sendConversationMessage() {
    // IMPORTANT: Lire le texte AVANT d'arrêter le STT
    // car .stop() peut déclencher un callback qui modifie _lastRecognizedWords
    final text = _lastRecognizedWords.trim();
    debugPrint('[CONVERSATION_SEND] Texte à envoyer: "$text"');

    // Arrêter le STT et les timers
    _speechToText.cancel(); // cancel au lieu de stop pour éviter le callback final
    _recordingTimer?.cancel();
    _audioLevelTimer?.cancel();

    if (text.isEmpty) {
      debugPrint('[CONVERSATION_SEND] Texte vide, ignoré');
      return;
    }

    // Réinitialiser
    _lastRecognizedWords = '';
    setState(() {
      _isRecording = false;
      _recordingDuration = Duration.zero;
    });

    // Envoyer via le flux conversation
    _onTranscriptionReceived(text);
  }

  // ─── Méthodes vocales ───────────────────────────────────────────────

  Future<void> _initRecorder() async {
    try {
      await _recorder.openRecorder();
    } catch (e) {
      debugPrint('[VOICE_RECORDER_INIT_ERROR] $e');
    }
    // Initialiser Speech-to-Text natif
    try {
      _speechAvailable = await _speechToText.initialize(
        onError: (error) => debugPrint('[SPEECH_ERROR] $error'),
        onStatus: (status) => debugPrint('[SPEECH_STATUS] $status'),
      );
      debugPrint('[SPEECH_INIT] Available: $_speechAvailable');
    } catch (e) {
      debugPrint('[SPEECH_INIT_ERROR] $e');
    }
  }

  Future<void> _connectVocalWebSocket() async {
    try {
      final provider = context.read<BobodoProvider>();
      final sessionId = provider.currentSessionId;
      debugPrint('[VOICE_WS_CONNECT] Session ID actuel: $sessionId');

      if (sessionId == null) {
        debugPrint('[VOICE_WS_CONNECT] Création nouvelle session...');
        await provider.createSession(title: 'Conversation vocale');
        debugPrint('[VOICE_WS_CONNECT] Session créée: ${provider.currentSessionId}');
      }

      final finalSessionId = provider.currentSessionId ?? '';
      debugPrint('[VOICE_WS_CONNECT] Connexion avec session ID: $finalSessionId');

      await _vocalService.connect(finalSessionId);
      setState(() => _isVocalConnected = true);

      _messageSubscription = _vocalService.messageStream.listen((message) {
        _onVocalMessage(message);
      });

      _errorSubscription = _vocalService.errorStream.listen((error) {
        debugPrint('[VOICE_WS_ERROR] $error');
      });
    } catch (e) {
      debugPrint('[VOICE_WS_CONNECT_ERROR] $e');
    }
  }

  Future<bool> _requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> _startVocalRecording() async {
    final granted = await _requestPermission();
    if (!granted) return;

    if (!_speechAvailable) {
      debugPrint('[SPEECH] Speech-to-text not available');
      return;
    }

    try {
      _lastRecognizedWords = '';
      await _speechToText.listen(
        onResult: (result) {
          debugPrint('[STT_RESULT] words="${result.recognizedWords}" final=${result.finalResult} confidence=${result.confidence}');
          // Toujours mettre à jour avec le dernier texte non vide
          if (result.recognizedWords.isNotEmpty) {
            _lastRecognizedWords = result.recognizedWords;
            setState(() {});
          }
          // NE PAS traiter finalResult — l'envoi est TOUJOURS manuel via bouton
        },
        listenFor: Duration(seconds: 60),
        pauseFor: Duration(seconds: 5),
        localeId: 'fr_FR',
        cancelOnError: false,
        partialResults: true,
      );

      setState(() {
        _isRecordingMode = true;
        _isRecording = true;
        _recordingDuration = Duration.zero;
        _isVoiceDetected = true;
      });

      _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration = Duration(seconds: _recordingDuration.inSeconds + 1);
        });
      });
    } catch (e) {
      debugPrint('[SPEECH_LISTEN_ERROR] $e');
    }
  }

  // _handleSpeechResult supprimé — l'envoi est TOUJOURS manuel via bouton ➤.
  // Le STT accumule le texte dans _lastRecognizedWords via le callback onResult.
  // L'utilisateur voit le texte en temps réel et appuie sur ➤ quand il est prêt.

  Future<void> _stopVocalRecording() async {
    if (!_isRecording) return;

    await _speechToText.stop();
    _recordingTimer?.cancel();
    _audioLevelTimer?.cancel();
    _vadSilenceTimer?.cancel();

    setState(() {
      _isRecording = false;
      _isVoiceDetected = false;
    });

    // Si on a un résultat final non traité, le traiter
    if (_lastRecognizedWords.trim().isNotEmpty) {
      final text = _lastRecognizedWords;
      _lastRecognizedWords = '';
      _onTranscriptionReceived(text);
    }
  }

  Future<void> _cancelVocalRecording() async {
    await _speechToText.cancel();
    _recordingTimer?.cancel();
    _audioLevelTimer?.cancel();
    _vadSilenceTimer?.cancel();
    _lastRecognizedWords = '';

    setState(() {
      _isRecordingMode = false;
      _isRecording = false;
      _recordingDuration = Duration.zero;
      _isVoiceDetected = false;
    });
  }

  void _onAudioData(Uint8List data) {
    if (_isRecording) {
      _audioBuffer.add(data);
    }
  }

  void _onVocalMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    if (type == 'transcription') {
      final text = message['text'] as String?;
      _onTranscriptionReceived(text ?? '');
    } else if (type == 'audio_response') {
      final audioBase64 = message['audio'] as String?;
      _onAudioResponseReceived(audioBase64 ?? '');
    } else if (type == 'error') {
      final errorMessage = message['message'] as String?;
      _onVocalError(errorMessage ?? 'Erreur vocale');
    }
  }

  Future<void> _onTranscriptionReceived(String text) async {
    if (_isConversationMode) {
      // P1-3: Protection contre double envoi concurrent
      if (_isProcessingConversation) {
        debugPrint('[CONVERSATION] Envoi ignoré (déjà en cours): $text');
        return;
      }
      _isProcessingConversation = true;

      // Barge-in: si Bobodo parle, arrêter la lecture
      if (_isSpeaking) {
        _stopAudioPlayback();
        setState(() {
          _conversationState = ConversationState.thinking;
        });
      }

      // P2-2: Accusé de réception — montrer brièvement "Message reçu"
      setState(() {
        _isTranscribing = false;
        _conversationState = ConversationState.processing;
      });
      await Future.delayed(const Duration(milliseconds: 800));

      // Passage à l'état "Bobodo réfléchit..."
      setState(() {
        _conversationState = ConversationState.thinking;
      });

      // Ajouter à la mémoire
      _addToConversationMemory(text, '');

      final provider = context.read<BobodoProvider>();
      await provider.sendUserMessage(text);

      // Mode 2 : lecture vocale de la réponse Bobodo
      if (_isConversationMode && provider.messages.isNotEmpty) {
        final lastMsg = provider.messages.last;
        if (lastMsg['sender'] != 'student') {
          final botText = lastMsg['content']?.toString() ?? '';
          if (botText.isNotEmpty) {
            setState(() {
              _conversationState = ConversationState.playing;
            });
            await _speakWithLocalTts(botText);
          } else {
            // Réponse vide : relancer l'écoute directement
            if (_isConversationMode) {
              setState(() {
                _conversationState = ConversationState.listening;
              });
              _resetInactivityTimer();
              _startVocalRecording();
            }
          }
        } else {
          // Dernier message est celui de l'utilisateur (erreur backend)
          // Relancer l'écoute après un court délai pour permettre de reparler
          if (_isConversationMode) {
            setState(() {
              _conversationState = ConversationState.listening;
            });
            _resetInactivityTimer();
            _startVocalRecording();
          }
        }
      } else if (_isConversationMode) {
        // Pas de messages ou erreur : relancer l'écoute
        setState(() {
          _conversationState = ConversationState.listening;
        });
        _resetInactivityTimer();
        _startVocalRecording();
      }
      _isProcessingConversation = false; // P1-3: libérer le verrou
    } else {
      // Mode dictée : affichage dans champ
      setState(() {
        _isTranscribing = false;
        _isRecordingMode = false;
      });
      _controller.text = text;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: text.length),
      );
    }
  }

  void _onAudioResponseReceived(String audioBase64) async {
    try {
      final audioBytes = base64Decode(audioBase64);
      _lastAudioResponse = audioBytes;

      if (_isConversationMode) {
        setState(() {
          _conversationState = ConversationState.playing;
        });
      }

      if (_autoTtsEnabled) {
        await _audioPlayer.setSourceBytes(audioBytes);
        await _audioPlayer.resume();

        setState(() => _isSpeaking = true);

        _audioPlayer.onPlayerComplete.listen((_) {
          setState(() => _isSpeaking = false);
          if (_isConversationMode) {
            _onAudioPlaybackComplete();
          }
        });
      }
    } catch (e) {
      debugPrint('[VOICE_AUDIO_ERROR] $e');
      // Fallback: utiliser FlutterTts local
      if (_isConversationMode && _useLocalTtsFallback) {
        _useLocalTtsFallback = false;
        // Récupérer le dernier message de Bobodo
        final provider = context.read<BobodoProvider>();
        final messages = provider.messages;
        if (messages.isNotEmpty) {
          final lastMessage = messages.last;
          if (lastMessage['sender'] == 'bobodo') {
            final text = lastMessage['content']?.toString() ?? '';
            await _speakWithLocalTts(text);
          }
        }
      }
    }
  }

  Future<void> _speakWithLocalTts(String text) async {
    try {
      setState(() => _isSpeaking = true);
      await _flutterTts.speak(text);
      await _flutterTts.awaitSpeakCompletion(true);
      setState(() => _isSpeaking = false);
      if (_isConversationMode) {
        _onAudioPlaybackComplete();
      }
    } catch (e) {
      debugPrint('[LOCAL_TTS_ERROR] $e');
      setState(() => _isSpeaking = false);
    }
  }

  void _stopAudioPlayback() {
    _audioPlayer.stop();
    setState(() => _isSpeaking = false);
  }

  void _replayAudio() {
    if (_lastAudioResponse != null) {
      _audioPlayer.setSourceBytes(_lastAudioResponse!);
      _audioPlayer.resume();
      setState(() => _isSpeaking = true);

      _audioPlayer.onPlayerComplete.listen((_) {
        setState(() => _isSpeaking = false);
      });
    }
  }

  void _toggleAutoTts() {
    setState(() => _autoTtsEnabled = !_autoTtsEnabled);
  }

  void _onVocalError(String error) {
    setState(() {
      _isTranscribing = false;
      _isRecordingMode = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
  }

  String _formatRecordingDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // ─── Mode Conversation ───────────────────────────────────────────────

  void _toggleVoiceMode() {
    setState(() {
      _isConversationMode = !_isConversationMode;
      if (_isConversationMode) {
        _startConversationMode();
        // Afficher le guide au premier lancement
        if (!_hasSeenConversationGuide) {
          _showConversationGuide();
        }
      } else {
        _stopConversationMode();
      }
    });
    if (_isConversationMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conversation vocale activée. Parlez, Bobodo vous répondra.'),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  void _startConversationMode() {
    setState(() {
      _conversationState = ConversationState.listening;
    });
    _resetInactivityTimer();
    _startVocalRecording();
  }

  void _stopConversationMode() {
    setState(() {
      _conversationState = ConversationState.ended;
    });
    _stopVocalRecording();
    _stopAudioPlayback();
    _inactivityTimer?.cancel();
  }

  void _quitConversation() {
    setState(() {
      _isConversationMode = false;
      _conversationState = ConversationState.ended;
    });
    _stopVocalRecording();
    _stopAudioPlayback();
    _inactivityTimer?.cancel();
  }

  void _cutBobodo() {
    _stopAudioPlayback();
    setState(() {
      _conversationState = ConversationState.paused;
    });
  }

  void _resumeConversation() {
    setState(() {
      _conversationState = ConversationState.listening;
    });
    _resetInactivityTimer();
    _startVocalRecording();
  }

  // ─── Guide première utilisation ───────────────────────────────────────────

  Future<void> _loadConversationGuideStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasSeenConversationGuide = prefs.getBool('has_seen_conversation_guide') ?? false;
    });
  }

  Future<void> _showConversationGuide() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.mic, color: PrepTheme.primary, size: 24),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Mode conversation vocale',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Comment utiliser le mode conversation :',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              _buildGuideStep('1. Parlez naturellement'),
              const SizedBox(height: 8),
              _buildGuideStep('2. Appuyez sur le bouton ENVOYER (➤)'),
              const SizedBox(height: 8),
              _buildGuideStep('3. Bobodo vous répondra vocalement'),
              const SizedBox(height: 16),
              Text(
                'Vous pouvez interrompre Bobodo en parlant à nouveau.',
                style: TextStyle(fontSize: 13, color: PrepTheme.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('has_seen_conversation_guide', true);
                  setState(() {
                    _hasSeenConversationGuide = true;
                  });
                  Navigator.of(context).pop();
                },
                child: const Text('Compris', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: PrepTheme.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
      ],
    );
  }

  void _onAudioPlaybackComplete() {
    if (_isConversationMode && _conversationState != ConversationState.ended) {
      // P2-4: Signal de retour de tour de parole
      HapticFeedback.mediumImpact();
      setState(() {
        _lastRecognizedWords = '';
        _conversationState = ConversationState.listening;
      });
      _resetInactivityTimer();
      _startVocalRecording();
    }
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(Duration(seconds: 30), () {
      if (_isConversationMode && _conversationState == ConversationState.listening) {
        setState(() {
          _conversationState = ConversationState.idle;
        });
        _stopVocalRecording();
      }
    });
  }

  void _addToConversationMemory(String userMessage, String botResponse) {
    _conversationMemory.add({
      'user': userMessage,
      'bot': botResponse,
    });
    
    // Garder seulement les 10 derniers échanges
    if (_conversationMemory.length > _maxMemorySize) {
      _conversationMemory.removeAt(0);
    }
  }

  String _getConversationContext() {
    if (_conversationMemory.isEmpty) return '';
    
    final context = _conversationMemory.map((exchange) {
      return 'Utilisateur: ${exchange['user']}\nBobodo: ${exchange['bot']}';
    }).join('\n\n');
    
    return context;
  }

  Widget _buildConversationStateIndicator() {
    if (!_isConversationMode) return SizedBox.shrink();

    String stateText;
    IconData stateIcon;
    Color stateColor;

    switch (_conversationState) {
      case ConversationState.idle:
        stateText = 'En attente';
        stateIcon = Icons.hourglass_empty;
        stateColor = PrepTheme.textTertiary;
        break;
      case ConversationState.listening:
        stateText = 'Parlez maintenant';
        stateIcon = Icons.mic;
        stateColor = PrepTheme.primary;
        break;
      case ConversationState.processing:
        stateText = '✓ Message reçu';
        stateIcon = Icons.check;
        stateColor = PrepTheme.success;
        break;
      case ConversationState.thinking:
        stateText = 'Bobodo réfléchit...';
        stateIcon = Icons.psychology;
        stateColor = PrepTheme.primary;
        break;
      case ConversationState.responding:
        stateText = 'Réponse...';
        stateIcon = Icons.chat;
        stateColor = PrepTheme.primary;
        break;
      case ConversationState.playing:
        stateText = 'Bobodo parle...';
        stateIcon = Icons.volume_up;
        stateColor = PrepTheme.primary;
        break;
      case ConversationState.paused:
        stateText = 'Pause';
        stateIcon = Icons.pause;
        stateColor = PrepTheme.accent;
        break;
      case ConversationState.ended:
        stateText = 'Session terminée';
        stateIcon = Icons.check_circle;
        stateColor = PrepTheme.success;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: stateColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: stateColor, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(stateIcon, size: 28, color: stateColor),
              SizedBox(width: 12),
              Text(
                stateText,
                style: TextStyle(
                  color: stateColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          // P2-1: Afficher la transcription partielle en temps réel
          if (_conversationState == ConversationState.listening && _lastRecognizedWords.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _lastRecognizedWords,
                style: TextStyle(
                  fontSize: 16,
                  color: PrepTheme.textPrimary,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConversationControls() {
    if (!_isConversationMode) return SizedBox.shrink();

    return Column(
      children: [
        // Indicateur visuel central selon l'état
        if (_conversationState == ConversationState.listening)
          _buildListeningVisual(),
        if (_conversationState == ConversationState.thinking)
          _buildThinkingVisual(),
        if (_conversationState == ConversationState.playing)
          _buildPlayingVisual(),
        const SizedBox(height: 12),
        // Contrôles
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Bouton Quitter (toujours visible)
            TextButton.icon(
              icon: Icon(Icons.close, color: PrepTheme.danger, size: 18),
              label: Text('Quitter', style: TextStyle(color: PrepTheme.danger, fontSize: 12)),
              onPressed: _quitConversation,
            ),
            SizedBox(width: 16),
            // Bouton Couper (si en lecture)
            if (_isSpeaking)
              TextButton.icon(
                icon: Icon(Icons.stop, color: PrepTheme.accent, size: 18),
                label: Text('Couper', style: TextStyle(color: PrepTheme.accent, fontSize: 12)),
                onPressed: _cutBobodo,
              ),
            // Bouton Reprendre (si en pause)
            if (_conversationState == ConversationState.paused)
              TextButton.icon(
                icon: Icon(Icons.play_arrow, color: PrepTheme.primary, size: 18),
                label: Text('Reprendre', style: TextStyle(color: PrepTheme.primary, fontSize: 12)),
                onPressed: _resumeConversation,
              ),
          ],
        ),
      ],
    );
  }

  // ─── Indicateurs visuels mode conversation (style ChatGPT Voice) ────

  Widget _buildListeningVisual() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          // Indicateur d'enregistrement : point rouge + durée
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: PrepTheme.danger,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatRecordingDuration(_recordingDuration),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: PrepTheme.danger),
              ),
              const SizedBox(width: 16),
              Text(
                'Enregistrement...',
                style: TextStyle(fontSize: 12, color: PrepTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Grand cercle micro + bouton FIN
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Cercle micro (indicateur écoute active)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: PrepTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: PrepTheme.primary, width: 2),
                ),
                child: Icon(Icons.mic, color: PrepTheme.primary, size: 28),
              ),
              const SizedBox(width: 24),
              // Bouton ENVOYER (envoyer le message vocal à Bobodo)
              Column(
                children: [
                  GestureDetector(
                    onTap: _sendConversationMessage,
                    child: Container(
                      width: 56,
                      height: 56,
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
                      child: const Icon(Icons.send, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ENVOYER',
                    style: TextStyle(
                      fontSize: 14,
                      color: PrepTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Transcription en direct
          if (_lastRecognizedWords.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _lastRecognizedWords,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: PrepTheme.textPrimary,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            Text(
              'Parlez, Bobodo écoute...',
              style: TextStyle(fontSize: 13, color: PrepTheme.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _buildThinkingVisual() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: PrepTheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bobodo réfléchit...',
            style: TextStyle(fontSize: 13, color: PrepTheme.primary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayingVisual() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: PrepTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.volume_up, color: PrepTheme.primary, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            'Bobodo parle...',
            style: TextStyle(fontSize: 13, color: PrepTheme.primary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
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
