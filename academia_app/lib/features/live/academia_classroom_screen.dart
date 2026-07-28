import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../models/academia_session.dart' as session_model;
import '../../services/academia_camera_service.dart';
import '../../services/academia_livekit_service.dart' hide AcademiaSessionFeatures;
import '../../services/academia_presence_service.dart';
import '../../services/academia_room_options.dart';
import '../../services/screen_share_service.dart';
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
import '../orientation/orientation_context_panel.dart';
import '../orientation/orientation_recording_banner.dart';
import '../../widgets/adaptive_dialog.dart';

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
  bool _showContexte = false;

  /// Le panneau contexte n'a de sens que dans une consultation d'orientation.
  bool get _estOrientation =>
      widget.session.type == session_model.SessionType.orientation;
  bool _showParticipants = false;
  bool _isHandRaised = false;
  int _unreadChat = 0;

  // ─── Caméra ────────────────────────────────────────────────────────
  CameraPosition _cameraPosition = CameraPosition.front;
  AcademiaCameraMode _cameraMode = AcademiaCameraMode.visage;
  bool get _isDocumentMode => _cameraMode == AcademiaCameraMode.document;

  String? _egressId;
  // La qualité était auparavant figée sur `excellent` et n'était jamais
  // recalculée : l'indicateur affichait donc en permanence une pastille verte,
  // y compris quand la connexion s'écroulait. Elle est désormais alimentée par
  // les événements du SDK.
  ConnectionQuality _connectionQuality = ConnectionQuality.unknown;
  bool _isReconnecting = false;
  String _connectionStep = 'Préparation de la séance…';
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

  void _step(String label) {
    if (!mounted) return;
    setState(() => _connectionStep = label);
  }

  Future<void> _connectToRoom() async {
    try {
      // 1. Host démarre la session, étudiant rejoint
      _step(widget.isHost
          ? 'Ouverture de la salle…'
          : 'Inscription à la séance…');
      if (widget.isHost) {
        await _livekit.startSession(widget.session.id);
      } else {
        await _livekit.joinSession(widget.session.id);
      }

      // 2. Obtenir le token LiveKit
      _step('Autorisation d\'accès…');
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
      _step('Connexion au serveur vidéo…');
      // Le profil suit le format de la séance : un tête-à-tête n'a personne à
      // qui servir une couche basse, le simulcast y coûterait sans rien rendre.
      final room = Room(
        roomOptions: AcademiaRoomOptions.pourSeance(
          maxParticipants: widget.session.maxParticipants ?? 100,
        ),
      );
      room.addListener(_onRoomChanged);
      _roomListener = room.createListener();
      _roomListener!.on<DataReceivedEvent>(_handleDataMessage);
      _bindConnectionEvents();

      await room.connect(url, token);
      _step('Activation du micro et de la caméra…');

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
        _error = _humanReadableError(e);
      });
    }
  }

  /// Traduit une exception technique en phrase actionnable.
  ///
  /// Un « Exception: PlatformException(...) » affiché en plein écran à un
  /// étudiant ne lui apprend rien et ne lui dit pas quoi faire.
  String _humanReadableError(Object e) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('introuvable') || raw.contains('404')) {
      return 'Cette séance n\'existe plus ou a été annulée.';
    }
    if (raw.contains('statut')) {
      return 'La séance n\'est pas encore ouverte. Réessayez à l\'heure prévue.';
    }
    if (raw.contains('non configuré')) {
      return 'Le service vidéo n\'est pas disponible pour le moment. '
          'Prévenez un administrateur.';
    }
    if (raw.contains('authentifié') || raw.contains('token invalide')) {
      return 'Votre session a expiré. Reconnectez-vous à l\'application.';
    }
    if (raw.contains('socket') ||
        raw.contains('network') ||
        raw.contains('timeout') ||
        raw.contains('connexion')) {
      return 'Connexion impossible. Vérifiez votre réseau et réessayez.';
    }
    return 'Impossible de rejoindre la séance. Réessayez dans un instant.';
  }

  /// Branche les événements qui décrivent l'état réel du lien réseau.
  void _bindConnectionEvents() {
    final listener = _roomListener;
    if (listener == null) return;

    listener.on<ParticipantConnectionQualityUpdatedEvent>((event) {
      // Seule la qualité de notre propre lien nous renseigne sur ce que
      // l'utilisateur peut corriger de son côté.
      if (event.participant.identity !=
          _room?.localParticipant?.identity) {
        return;
      }
      if (!mounted) return;
      setState(() => _connectionQuality = event.connectionQuality);
    });

    listener.on<RoomReconnectingEvent>((_) {
      if (!mounted) return;
      setState(() => _isReconnecting = true);
    });

    listener.on<RoomReconnectedEvent>((_) {
      if (!mounted) return;
      setState(() => _isReconnecting = false);
    });
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

  // ─── Caméra ────────────────────────────────────────────────────────

  /// Bascule avant / arrière, sans changer de mode.
  Future<void> _switchCamera() async {
    if (!_cameraEnabled) {
      _notify('Allumez d\'abord votre caméra.');
      return;
    }
    final position = await AcademiaCameraService.togglePosition(
      _room?.localParticipant,
      _cameraPosition,
    );
    if (!mounted) return;
    if (position == null) {
      _notify('Impossible de changer de caméra sur cet appareil.');
      return;
    }
    setState(() {
      _cameraPosition = position;
      // Une bascule manuelle vers l'avant sort du mode document : on ne
      // filme plus une feuille, on refilme un visage.
      if (position == CameraPosition.front) {
        _cameraMode = AcademiaCameraMode.visage;
      }
    });
  }

  /// Active ou quitte le mode caméra-document.
  ///
  /// En l'activant, on bascule sur la caméra arrière et on épingle le flux
  /// en grand pour tout le monde — ce qui est filmé, une copie ou un tableau,
  /// n'a aucun sens réduit à une vignette.
  Future<void> _toggleDocumentMode() async {
    if (!_cameraEnabled) {
      _notify('Allumez d\'abord votre caméra.');
      return;
    }
    final target = _isDocumentMode
        ? AcademiaCameraMode.visage
        : AcademiaCameraMode.document;

    final error =
        await AcademiaCameraService.applyMode(_room?.localParticipant, target);
    if (!mounted) return;
    if (error != null) {
      _notify(error);
      return;
    }
    setState(() {
      _cameraMode = target;
      _cameraPosition = target == AcademiaCameraMode.document
          ? CameraPosition.back
          : CameraPosition.front;
    });
    _notify(target == AcademiaCameraMode.document
        ? 'Mode document activé — cadrez votre feuille.'
        : 'Retour à la caméra frontale.');
  }

  // ─── Partage d'écran ───────────────────────────────────────────────

  Future<void> _toggleScreenShare() async {
    final participant = _room?.localParticipant;

    if (_screenShareEnabled) {
      await ScreenShareService.stop(participant);
      if (!mounted) return;
      setState(() => _screenShareEnabled = false);
      return;
    }

    final error = await ScreenShareService.start(participant);
    if (!mounted) return;
    if (error != null) {
      _notify(error);
      return;
    }
    setState(() => _screenShareEnabled = true);
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
      useSafeArea: true,
      builder: (ctx) => AdaptiveDialog(
        maxWidth: 420,
        title: const Text('Terminer la session ?'),
        child: const Text(
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.videocam_outlined,
                    color: Color(0xFF8B7DF0), size: 28),
              ),
              const SizedBox(height: 20),
              Text(
                widget.session.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.session.hostDisplayName != null &&
                  widget.session.hostDisplayName!.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  widget.session.hostDisplayName!,
                  style: const TextStyle(color: Colors.white54, fontSize: 13.5),
                ),
              ],
              const SizedBox(height: 26),
              // Étape nommée plutôt qu'un indicateur nu : quand la connexion
              // traîne, savoir où elle en est évite de croire à un blocage.
              SizedBox(
                width: 190,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor:
                      const AlwaysStoppedAnimation(Color(0xFF8B7DF0)),
                  minHeight: 3,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _connectionStep,
                style: const TextStyle(color: Colors.white70, fontSize: 13.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              _PreflightHints(features: _features),
            ],
          ),
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
            child: Column(
              children: [
                _buildFloatingAppBar(),
                // Consentement à l'enregistrement : permanent tant qu'il
                // manque un accord, et permanent aussi quand il tourne.
                if (_estOrientation)
                  OrientationRecordingBanner(
                    sessionId: widget.session.id,
                    isHost: widget.isHost,
                  ),
                // Le SDK retente la connexion tout seul. Sans ce bandeau,
                // l'utilisateur voit une image figée et croit à un plantage.
                if (_isReconnecting)
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFF0A020),
                    padding:
                        const EdgeInsets.symmetric(vertical: 7, horizontal: 14),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 9),
                        Text(
                          'Connexion interrompue — reconnexion en cours',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
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
              // Doit refléter exactement la largeur réelle du panneau chat
              // (voir _chatPanelWidth) pour ne jamais laisser un espace vide
              // ni chevaucher le chat sur petit écran.
              right: _showChat ? _chatPanelWidth(context) + 4 : 4,
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
              // Sur un téléphone de 320 dp, une largeur figée à 280 ne
              // laissait que 40 dp de vidéo. On plafonne à 85 % de l'écran.
              width: _chatPanelWidth(context),
              child: AcademiaPersistentChatPanel(
                sessionId: widget.session.id,
                localUserId:
                    _room?.localParticipant?.identity ?? '',
                localDisplayName:
                    _room?.localParticipant?.name ?? 'Moi',
              ),
            ),

          // ── Panneau contexte d'orientation ─────────────────────────
          // Largeur adaptative : sur un téléphone étroit il prend presque
          // tout l'écran, sur une tablette il reste une colonne latérale.
          if (_showContexte && _estOrientation && widget.isHost)
            LayoutBuilder(
              builder: (context, contraintes) {
                final largeur = contraintes.maxWidth < 420
                    ? contraintes.maxWidth - 16
                    : 320.0;
                return Positioned(
                  right: 8,
                  top: 60,
                  bottom: 90,
                  width: largeur,
                  child: OrientationContextPanel(
                    sessionId: widget.session.id,
                    onClose: () => setState(() => _showContexte = false),
                  ),
                );
              },
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
                    onSwitchCamera: AcademiaCameraService.supportsSwitching
                        ? _switchCamera
                        : null,
                    onToggleDocumentMode:
                        AcademiaCameraService.supportsSwitching
                            ? _toggleDocumentMode
                            : null,
                    isDocumentMode: _isDocumentMode,
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

  /// Largeur du panneau chat — utilisée à la fois par le chat lui-même et
  /// par le tableau blanc (pour ne jamais se chevaucher ni laisser de vide).
  double _chatPanelWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width < 360 ? width * 0.85 : 280.0;
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
                    useSafeArea: true,
                    builder: (ctx) => AdaptiveDialog(
                      maxWidth: 420,
                      title: const Text('Quitter la session ?'),
                      child: Text(widget.isHost
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
              // Panneau contexte : dossier de l'élève et fiche d'orientation,
              // sans quitter la salle. Réservé au conseiller qui anime.
              if (_estOrientation && widget.isHost)
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  // Les deux panneaux occupent la même colonne : ouvrir
                  // l'un referme l'autre plutôt que de les superposer.
                  onTap: () => setState(() {
                    _showContexte = !_showContexte;
                    if (_showContexte) _showChat = false;
                  }),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Icon(
                      Icons.folder_shared_outlined,
                      size: 18,
                      color: _showContexte
                          ? const Color(0xFF6C5CE7)
                          : Colors.white70,
                    ),
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


/// Rappel des fonctionnalités de la séance, affiché pendant la connexion.
///
/// L'écran d'attente était auparavant un indicateur de chargement nu. C'est le
/// premier écran que voit un participant : autant qu'il lui apprenne ce qui
/// l'attend plutôt que de le laisser devant un cercle qui tourne.
class _PreflightHints extends StatelessWidget {
  final AcademiaSessionFeatures features;
  const _PreflightHints({required this.features});

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String)>[
      if (features.isChatEnabled) (Icons.chat_bubble_outline, 'Chat'),
      if (features.isQuizEnabled) (Icons.quiz_outlined, 'Quiz'),
      if (features.isWhiteboardEnabled) (Icons.draw_outlined, 'Tableau blanc'),
      if (features.isScreenShareEnabled)
        (Icons.screen_share_outlined, 'Partage d\'écran'),
      if (features.isHandRaiseEnabled) (Icons.back_hand_outlined, 'Main levée'),
    ];
    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: items
          .map((e) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(e.$1, size: 14, color: Colors.white54),
                    const SizedBox(width: 6),
                    Text(e.$2,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
