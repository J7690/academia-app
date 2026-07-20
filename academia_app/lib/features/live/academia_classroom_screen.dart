import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../models/academia_session.dart' as session_model;
import '../../services/academia_livekit_service.dart' hide AcademiaSessionFeatures;
import '../../services/academia_presence_service.dart';
import 'academia_classroom_controls.dart';
import 'widgets/academia_participant_tile.dart';
import 'widgets/academia_participants_panel.dart';
import 'widgets/academia_persistent_chat_panel.dart';
import 'widgets/academia_quiz_overlay.dart';
import 'widgets/academia_quiz_student_overlay.dart';
import 'widgets/academia_reactions_overlay.dart';
import 'widgets/academia_td_exercise_overlay.dart';
import 'widgets/academia_screen_share_view.dart';
import 'whiteboard/academia_whiteboard_panel.dart';

/// Salle de classe virtuelle AcademiaClassroom.
///
/// Remplace LivekitRoomScreen pour les sessions issues de [session_model.AcademiaSession].
/// Features pilotées par [AcademiaSessionFeatures].
class AcademiaClassroomScreen extends StatefulWidget {
  final session_model.AcademiaSession session;
  final bool isHost;

  const AcademiaClassroomScreen({
    super.key,
    required this.session,
    required this.isHost,
  });

  @override
  State<AcademiaClassroomScreen> createState() =>
      _AcademiaClassroomScreenState();
}

class _AcademiaClassroomScreenState extends State<AcademiaClassroomScreen>
    with WidgetsBindingObserver {
  // ─── LiveKit ────────────────────────────────────────────────────────
  Room? _room;
  EventsListener<RoomEvent>? _roomListener;

  // ─── State ─────────────────────────────────────────────────────────
  bool _isConnecting = true;
  bool _isConnected = false;
  String? _error;
  bool _micEnabled = true;
  bool _cameraEnabled = true;
  bool _screenShareEnabled = false;
  bool _isRecording = false;
  bool _showChat = false;
  bool _showQuiz = false;
  bool _showWhiteboard = false;
  bool _showReactions = false;
  bool _showParticipants = false;
  bool _isHandRaised = false;
  int _unreadChat = 0;
  String? _egressId;
  final ConnectionQuality _connectionQuality = ConnectionQuality.excellent;
  List<RemoteParticipant> _remoteParticipants = [];

  // ─── Services ───────────────────────────────────────────────────────
  final _livekit = AcademiaLivekitService.instance;
  final _presence = AcademiaPresenceService.instance;

  // ─── Features ───────────────────────────────────────────────────────
  late AcademiaSessionFeatures _features;

  // ─── Chat (Data Channel) ───────────────────────────────────────────
  final List<Map<String, dynamic>> _chatMessages = [];

  // ─── Quiz entrant (étudiant) ───────────────────────────────────────
  Map<String, dynamic>? _incomingQuiz;

  // ─── TD exercice entrant (étudiant) ────────────────────────────────
  Map<String, dynamic>? _incomingTdExercise;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _features = AcademiaSessionFeatures(
      isRecordingEnabled: widget.session.isRecordingEnabled,
      isWhiteboardEnabled: widget.session.isWhiteboardEnabled,
      isQuizEnabled: widget.session.isQuizEnabled,
      isChatEnabled: widget.session.isChatEnabled,
      isScreenShareEnabled: widget.session.isScreenShareEnabled,
      isHandRaiseEnabled: widget.session.isHandRaiseEnabled,
    );
    _connectToRoom();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanup();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _room?.localParticipant?.setCameraEnabled(false);
    } else if (state == AppLifecycleState.resumed && _cameraEnabled) {
      _room?.localParticipant?.setCameraEnabled(true);
    }
  }

  // ─── Connexion ──────────────────────────────────────────────────────

  Future<void> _connectToRoom() async {
    try {
      // 1. Host démarre la session, étudiant rejoint
      if (widget.isHost) {
        await _livekit.startSession(widget.session.id);
      } else {
        await _livekit.joinSession(widget.session.id);
      }

      // 2. Obtenir le token LiveKit
      final tokenData = await _livekit.getToken(
        sessionId: widget.session.id,
        forceAcademia: true,
      );

      final token = tokenData['token'] as String? ?? '';
      final url = tokenData['url'] as String? ?? '';
      if (token.isEmpty || url.isEmpty) {
        throw Exception('Token ou URL LiveKit invalide.');
      }

      // 3. Connecter la room
      final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultVideoPublishOptions: VideoPublishOptions(
            simulcast: true,
          ),
        ),
      );
      room.addListener(_onRoomChanged);
      _roomListener = room.createListener();
      _roomListener!.on<DataReceivedEvent>(_handleDataMessage);

      await room.connect(url, token);

      if (!mounted) {
        _roomListener?.dispose();
        room.removeListener(_onRoomChanged);
        room.dispose();
        return;
      }

      // Active micro + caméra après connexion
      await room.localParticipant?.setMicrophoneEnabled(_micEnabled);
      await room.localParticipant?.setCameraEnabled(_cameraEnabled);

      // Démarrer le tracking de présence
      _presence.startTracking(widget.session.id);

      setState(() {
        _room = room;
        _isConnecting = false;
        _isConnected = true;
        _remoteParticipants =
            room.remoteParticipants.values.toList(growable: false);
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('[AcademiaClassroom] Connexion error: $e');
      setState(() {
        _isConnecting = false;
        _error = 'Impossible de rejoindre la session.\n$e';
      });
    }
  }

  void _onRoomChanged() {
    if (!mounted) return;
    setState(() {
      _remoteParticipants =
          (_room?.remoteParticipants.values.toList(growable: false)) ?? [];
    });
  }

  // ─── Data Channel (chat + signaux) ──────────────────────────────────

  void _handleDataMessage(DataReceivedEvent event) {
    try {
      final raw = utf8.decode(event.data);
      final msg = jsonDecode(raw) as Map<String, dynamic>;
      final type = msg['type']?.toString() ?? '';

      if (type == 'chat') {
        setState(() {
          _chatMessages.add(msg);
          if (!_showChat) _unreadChat++;
        });
      } else if (type == 'quiz' && !widget.isHost) {
        setState(() => _incomingQuiz = msg);
      } else if (type == 'td_exercise' && !widget.isHost) {
        setState(() => _incomingTdExercise = msg);
      } else if (type == 'hand_raise') {
        setState(() {});
      } else if (type == 'reaction') {
        setState(() => _showReactions = true);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showReactions = false);
        });
      }
    } catch (_) {}
  }

  Future<void> _sendDataMessage(Map<String, dynamic> msg) async {
    try {
      final data = utf8.encode(jsonEncode(msg));
      await _room?.localParticipant?.publishData(
        Uint8List.fromList(data),
        reliable: msg['type'] == 'chat',
      );
    } catch (_) {}
  }

  // ─── Contrôles ──────────────────────────────────────────────────────

  Future<void> _toggleMic() async {
    final enabled = !_micEnabled;
    await _room?.localParticipant?.setMicrophoneEnabled(enabled);
    setState(() => _micEnabled = enabled);
  }

  Future<void> _toggleCamera() async {
    final enabled = !_cameraEnabled;
    await _room?.localParticipant?.setCameraEnabled(enabled);
    setState(() => _cameraEnabled = enabled);
  }

  Future<void> _toggleScreenShare() async {
    try {
      final enabled = !_screenShareEnabled;
      await _room?.localParticipant?.setScreenShareEnabled(enabled);
      setState(() => _screenShareEnabled = enabled);
    } catch (_) {}
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      if (_egressId == null) return;
      final url = await _livekit.stopRecording(
        sessionId: widget.session.id,
        egressId: _egressId!,
      );
      setState(() {
        _isRecording = false;
        _egressId = null;
      });
      if (mounted && url != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Replay sauvegardé : $url')),
        );
      }
    } else {
      final egress = await _livekit.startRecording(sessionId: widget.session.id);
      if (egress != null) {
        setState(() {
          _isRecording = true;
          _egressId = egress;
        });
      }
    }
  }

  void _toggleHandRaise() {
    final raised = !_isHandRaised;
    setState(() => _isHandRaised = raised);
    _sendDataMessage({
      'type': 'hand_raise',
      'user_id': _room?.localParticipant?.identity ?? '',
      'raised': raised,
    });
  }

  void _sendReaction(String emoji) {
    _sendDataMessage({
      'type': 'reaction',
      'user_id': _room?.localParticipant?.identity ?? '',
      'emoji': emoji,
    });
  }

  Future<void> _endSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminer la session ?'),
        content: const Text(
          'Tous les participants seront déconnectés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Terminer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    if (_isRecording && _egressId != null) {
      await _livekit.stopRecording(
        sessionId: widget.session.id,
        egressId: _egressId!,
      );
    }
    await _cleanup();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _leaveSession() async {
    await _cleanup();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _cleanup() async {
    await _presence.stopTracking();
    _roomListener?.dispose();
    _room?.removeListener(_onRoomChanged);
    await _room?.disconnect();
    _room?.dispose();
    if (widget.isHost) {
      await _livekit.endSession(widget.session.id);
    } else {
      await _livekit.leaveSession(widget.session.id);
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isConnecting) return _buildLoading();
    if (_error != null) return _buildError();
    return _buildRoom();
  }

  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Connexion…', style: TextStyle(color: Colors.white70, fontSize: 14)),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF60A5FA)),
            const SizedBox(height: 16),
            Text(
              widget.isHost
                  ? 'Démarrage de la session…'
                  : 'Connexion à la salle…',
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              widget.session.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
              const SizedBox(height: 16),
              const Text(
                'Impossible de rejoindre la salle',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? '',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Retour'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoom() {
    final local = _room?.localParticipant;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // ── Grille vidéo ──────────────────────────────────────────
          _buildVideoGrid(local),

          // ── AppBar flottant ───────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildFloatingAppBar(),
          ),

          // ── Overlay réactions ─────────────────────────────────────
          if (_showReactions)
            const AcademiaReactionsOverlay(),

          // ── Tableau blanc ──────────────────────────────────────────
          if (_showWhiteboard && _features.isWhiteboardEnabled)
            Positioned(
              left: 4,
              top: 64,
              bottom: 94,
              right: _showChat ? 284 : 4,
              child: AcademiaWhiteboardPanel(
                room: _room,
                isHost: widget.isHost,
              ),
            ),

          // ── Chat latéral (persistant Supabase) ─────────────────────
          if (_showChat && _features.isChatEnabled)
            Positioned(
              right: 0,
              top: 60,
              bottom: 90,
              width: 280,
              child: AcademiaPersistentChatPanel(
                sessionId: widget.session.id,
                localUserId:
                    _room?.localParticipant?.identity ?? '',
                localDisplayName:
                    _room?.localParticipant?.name ?? 'Moi',
              ),
            ),

          // ── Quiz overlay (host uniquement) ────────────────────────
          if (_showQuiz && widget.isHost && _features.isQuizEnabled)
            AcademiaQuizOverlay(
              onClose: () => setState(() => _showQuiz = false),
              onSendQuestion: (q) {
                _sendDataMessage({
                  'type': 'quiz',
                  'question': q['question'],
                  'options': q['options'],
                  'correct_index': q['correct_index'],
                  'duration_seconds': q['duration_seconds'],
                });
                setState(() => _showQuiz = false);
              },
            ),

          // ── Quiz overlay (étudiant) ───────────────────────────────
          if (_incomingQuiz != null && !widget.isHost)
            AcademiaQuizStudentOverlay(
              questionId: _incomingQuiz!['question_id']?.toString(),
              question: (_incomingQuiz!['question'] ?? '').toString(),
              options: (_incomingQuiz!['options'] is List)
                  ? (_incomingQuiz!['options'] as List)
                      .map((e) => e.toString())
                      .toList()
                  : [],
              durationSeconds:
                  (_incomingQuiz!['duration_seconds'] as int?) ?? 30,
              onDismiss: () => setState(() => _incomingQuiz = null),
            ),

          // ── TD exercice overlay (étudiant) ──────────────────────────
          if (_incomingTdExercise != null && !widget.isHost)
            AcademiaTdExerciseOverlay(
              exercise: _incomingTdExercise!,
              sessionId: widget.session.id,
              onDismiss: () => setState(() => _incomingTdExercise = null),
            ),

          // ── Panneau participants (présence + modération host) ──────
          if (_showParticipants)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AcademiaParticipantsPanel(
                sessionId: widget.session.id,
                isHost: widget.isHost,
                localParticipant: local,
                remoteParticipants: _remoteParticipants,
                onClose: () => setState(() => _showParticipants = false),
              ),
            ),

          // ── Contrôles bas ─────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: widget.isHost
                ? AcademiaHostControls(
                    micEnabled: _micEnabled,
                    cameraEnabled: _cameraEnabled,
                    screenShareEnabled: _screenShareEnabled,
                    isRecording: _isRecording,
                    showQuiz: _showQuiz,
                    showWhiteboard: _showWhiteboard,
                    connectionQuality: _connectionQuality,
                    onToggleMic: _toggleMic,
                    onToggleCamera: _toggleCamera,
                    onToggleScreenShare: _toggleScreenShare,
                    onToggleRecording: _toggleRecording,
                    onToggleQuiz: () =>
                        setState(() => _showQuiz = !_showQuiz),
                    onToggleWhiteboard: () =>
                        setState(() => _showWhiteboard = !_showWhiteboard),
                    onEndSession: _endSession,
                    features: _features,
                  )
                : AcademiaStudentControls(
                    micEnabled: _micEnabled,
                    cameraEnabled: _cameraEnabled,
                    isHandRaised: _isHandRaised,
                    unreadChat: _unreadChat,
                    connectionQuality: _connectionQuality,
                    onToggleMic: _toggleMic,
                    onToggleCamera: _toggleCamera,
                    onToggleHandRaise: _toggleHandRaise,
                    onOpenChat: () => setState(() {
                      _showChat = !_showChat;
                      if (_showChat) _unreadChat = 0;
                    }),
                    onOpenReactions: () {
                      _sendReaction('👏');
                    },
                    onLeave: _leaveSession,
                    features: _features,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingAppBar() {
    return Container(
      color: const Color(0xFF111827).withValues(alpha: 0.85),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              // ── Bouton retour ──
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                tooltip: 'Quitter la session',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Quitter la session ?'),
                      content: Text(widget.isHost
                          ? 'Vous êtes l\'hôte. La session restera active pour les participants.'
                          : 'Vous allez quitter la salle de classe.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Annuler'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Quitter'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _isConnected
                      ? const Color(0xFF059669)
                      : const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isConnected ? 'EN DIRECT' : 'Connexion…',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.session.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => setState(() => _showParticipants = !_showParticipants),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline, color: Colors.white70, size: 16),
                      const SizedBox(width: 3),
                      Text(
                        '${_remoteParticipants.length + 1}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isRecording) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.fiber_manual_record,
                  color: Color(0xFFEF4444),
                  size: 12,
                ),
                const Text(
                  'REC',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoGrid(LocalParticipant? local) {
    final screenShareView = AcademiaScreenShareView(
      room: _room,
      remoteParticipants: _remoteParticipants,
    );

    final all = <Widget>[
      if (local != null)
        AcademiaParticipantTile(
          participant: local,
          isLocal: true,
          isHost: widget.isHost,
          isHandRaised: _isHandRaised,
        ),
      ..._remoteParticipants.map(
        (p) => AcademiaParticipantTile(
          participant: p,
          isLocal: false,
          isHost: false,
          isHandRaised: false,
        ),
      ),
    ];

    if (all.isEmpty) {
      return const Center(
        child: Text(
          'En attente des participants…',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    // ── Mode présentation (screen share actif) ───────────────────────
    if (screenShareView.isActive) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 64, 4, 94),
        child: Column(
          children: [
            // Screen share en vue principale (75% de l'espace)
            Expanded(
              flex: 3,
              child: screenShareView,
            ),
            const SizedBox(height: 4),
            // Participants en bande basse (25%)
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: all.length,
                separatorBuilder: (_, __) => const SizedBox(width: 4),
                itemBuilder: (_, i) => SizedBox(width: 100, child: all[i]),
              ),
            ),
          ],
        ),
      );
    }

    // ── Mode grille (pas de screen share) ───────────────────────────
    if (all.length == 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 60, 0, 90),
        child: all.first,
      );
    }

    final count = all.length;
    final crossCount = count <= 2 ? 1 : count <= 6 ? 2 : 3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 64, 4, 94),
      child: GridView.builder(
        itemCount: all.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossCount,
          childAspectRatio: 4 / 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemBuilder: (_, i) => all[i],
      ),
    );
  }
}

