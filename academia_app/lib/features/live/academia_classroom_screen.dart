import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/academia_session.dart' as session_model;
import '../../services/academia_camera_service.dart';
import '../../services/academia_livekit_service.dart' hide AcademiaSessionFeatures;
import '../../services/academia_moderation_service.dart';
import '../../services/academia_presence_service.dart';
import '../../services/app_window_service.dart';
import '../../services/academia_room_options.dart';
import '../../services/screen_share_service.dart';
import '../../services/session_summary_service.dart';
import 'academia_classroom_controls.dart';
import 'session_summary_screen.dart';
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
  /// Droit de publier accordé par le token (`can_publish`). Un spectateur de
  /// cours magistral ne publie pas ; un participant d'entretien, si.
  bool _canPublish = true;

  /// Statut d'hôte — celui que le SERVEUR a calculé, pas celui que l'appelant
  /// a déclaré.
  ///
  /// `widget.isHost` n'est qu'une intention : quinze des seize points d'entrée
  /// le passent en dur, et l'un d'eux se trompait — l'écran admin annonçait
  /// `true` pour une séance dont l'administrateur n'est pas l'hôte, ce qui
  /// faisait appeler `endSession()` à la simple fermeture de l'écran.
  ///
  /// Le jeton, lui, recalcule `is_host` à partir de `host_id`. Tant qu'il n'est
  /// pas arrivé on suit l'intention ; dès qu'il arrive, le serveur tranche.
  bool _isHost = false;

  /// Droit de modérer accordé par le token (`is_moderator`) : l'hôte sur sa
  /// séance, l'administrateur sur toutes. Commande les actions couper /
  /// retirer / arrêter, exécutées par l'Edge Function `livekit-moderate`.
  bool _isModerator = false;

  /// Administrateur en supervision : présent dans une séance dont il n'est pas
  /// l'hôte. Sert à afficher clairement ce statut particulier.
  bool _isAdminSupervisor = false;
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

  /// Journal de séance — la matière première de la fiche.
  ///
  /// `learning-session-summary` refuse de résumer une séance sans message ni
  /// événement. Rien n'alimentait ce journal : sept séances terminées, zéro
  /// événement, zéro fiche.
  ///
  /// Le service `AcademiaObservability` semblait fait pour ça, mais il visait
  /// `public.academia_session_events` — table qui n'existe que dans le schéma
  /// `app` — avec des colonnes qui ne sont pas les siennes (`event_type`,
  /// `metadata`). Chaque insertion aurait échoué en silence. Il a été supprimé
  /// au profit de la RPC `app_learning_log_event`, qui écrit les bonnes
  /// colonnes et calcule l'`offset_ms` depuis le début de la séance.
  final _journal = SessionSummaryService.instance;

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
    _isHost = widget.isHost;
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
      // 1. Host démarre la session, étudiant rejoint.
      //    Ici le jeton n'est pas encore arrivé : on ne dispose que de
      //    l'intention de l'appelant. Les deux RPC revérifient l'hôte de leur
      //    côté, une intention erronée ne peut donc rien casser.
      _step(widget.isHost
          ? 'Ouverture de la salle…'
          : 'Inscription à la séance…');
      if (widget.isHost) {
        await _livekit.startSession(widget.session.id);
      } else {
        // Un refus d'inscription doit ARRÊTER l'entrée. Le résultat était
        // ignoré : une séance complète ou close laissait quand même passer,
        // puisque le jeton, lui, ne vérifie pas la capacité.
        final inscription = await _livekit.joinSession(widget.session.id);
        if (inscription != null && inscription['success'] != true) {
          throw Exception(
            inscription['error']?.toString() ??
                'Impossible de rejoindre la séance.',
          );
        }
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
      // Le serveur décide qui a le droit de parole. Tenter de publier sans ce
      // droit fait échouer la publication et bloquait l'ouverture de la salle.
      // (Absent des anciens tokens : on suppose alors l'hôte seul publieur.)
      _canPublish = tokenData['can_publish'] as bool? ?? widget.isHost;
      final estAdmin = tokenData['is_admin'] as bool? ?? false;
      _isModerator = tokenData['is_moderator'] as bool? ?? widget.isHost;
      // À partir d'ici, c'est le serveur qui dit qui anime. Toute l'interface
      // et, surtout, la fin de séance en découlent.
      _isHost = tokenData['is_host'] as bool? ?? widget.isHost;
      _isAdminSupervisor = estAdmin && !_isHost;

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

      if (!mounted) {
        _roomListener?.dispose();
        room.removeListener(_onRoomChanged);
        room.dispose();
        return;
      }

      // ─────────────────────────────────────────────────────────────────────
      // La salle est OUVERTE dès que la connexion est établie.
      //
      // Correctif 30/07/2026 : le micro et la caméra étaient activés AVANT
      // d'afficher la salle. Pour un étudiant dont le token interdisait la
      // publication, `setMicrophoneEnabled` restait en attente d'une
      // confirmation que le serveur n'envoyait jamais : l'écran restait figé
      // sur « Activation du micro et de la caméra… » alors que la voix du
      // conseiller passait déjà (l'audio distant ne dépend pas de l'interface).
      //
      // Désormais l'affichage ne dépend plus de la publication : le média est
      // un CONFORT, la présence en salle est l'ESSENTIEL.
      // ─────────────────────────────────────────────────────────────────────
      _presence.startTracking(widget.session.id);

      setState(() {
        _room = room;
        _isConnecting = false;
        _isConnected = true;
        _remoteParticipants =
            room.remoteParticipants.values.toList(growable: false);
      });

      // Publication en arrière-plan : n'immobilise jamais l'écran.
      unawaited(_activerMediaLocal(room));

      // Un seul repère d'ouverture, posé par l'animateur. Les entrées et
      // sorties des participants sont déjà dans `academia_session_participants`
      // — les redoubler ici noierait le déroulé sous du bruit.
      if (_isHost) {
        unawaited(_journal.logEvent(widget.session.id, 'seance_demarree'));
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('[AcademiaClassroom] Connexion error: $e');
      setState(() {
        _isConnecting = false;
        _error = _humanReadableError(e);
      });
    }
  }

  /// Active micro et caméra APRÈS l'ouverture de la salle, sans jamais la
  /// bloquer. Trois raisons peuvent empêcher la publication ; aucune ne doit
  /// priver le participant de voir et d'entendre la séance :
  ///   1. le token ne l'autorise pas (spectateur d'un cours magistral) ;
  ///   2. l'utilisateur refuse la permission Android/iOS ;
  ///   3. le matériel échoue (caméra déjà prise par une autre application).
  Future<void> _activerMediaLocal(Room room) async {
    if (!_canPublish) {
      if (!mounted) return;
      setState(() {
        _micEnabled = false;
        _cameraEnabled = false;
      });
      _notify('Vous suivez la séance en spectateur.');
      return;
    }

    // Les permissions sont demandées ICI, pas au démarrage de l'application :
    // c'est le moment où l'utilisateur comprend pourquoi on les demande.
    // Sans cet appel, `setMicrophoneEnabled` déclenche une capture native qui
    // peut rester en attente indéfiniment sur certains appareils Android.
    final statuses = await [Permission.microphone, Permission.camera].request();
    final micOk = statuses[Permission.microphone]?.isGranted ?? false;
    final camOk = statuses[Permission.camera]?.isGranted ?? false;

    if (!mounted) return;

    if (micOk) {
      try {
        await room.localParticipant?.setMicrophoneEnabled(_micEnabled);
      } catch (e) {
        debugPrint('[AcademiaClassroom] Micro indisponible: $e');
        if (mounted) setState(() => _micEnabled = false);
      }
    } else {
      if (mounted) setState(() => _micEnabled = false);
    }

    if (camOk) {
      try {
        await room.localParticipant?.setCameraEnabled(_cameraEnabled);
      } catch (e) {
        debugPrint('[AcademiaClassroom] Caméra indisponible: $e');
        if (mounted) setState(() => _cameraEnabled = false);
      }
    } else {
      if (mounted) setState(() => _cameraEnabled = false);
    }

    if (!mounted) return;
    if (!micOk || !camOk) {
      _notify(
        !micOk && !camOk
            ? 'Micro et caméra refusés. Autorisez-les dans les réglages pour participer.'
            : !micOk
                ? 'Micro refusé : vous entendez la séance mais ne pouvez pas parler.'
                : 'Caméra refusée : vous participez en audio seulement.',
      );
    }
  }

  /// Panneau de modération : couper la parole, la suspendre, retirer un
  /// participant, ou arrêter la séance.
  ///
  /// Les actions ne sont jamais exécutées par l'application : elles sont
  /// demandées à l'Edge Function `livekit-moderate`, qui revérifie le droit et
  /// utilise la clé secrète LiveKit côté serveur.
  Future<void> _ouvrirModeration() async {
    final participants = _remoteParticipants;
    if (participants.isEmpty) {
      _notify('Aucun autre participant à modérer pour l\'instant.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 18, color: Color(0xFF7C3AED)),
                    SizedBox(width: 8),
                    Text('Modération',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: participants.length,
                  itemBuilder: (ctx, i) {
                    final p = participants[i];
                    final nom = p.name.isNotEmpty ? p.name : p.identity;
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFF6B7280),
                        child: Text(
                          nom.isNotEmpty ? nom[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                      title: Text(nom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Couper le micro',
                            icon: const Icon(Icons.mic_off, size: 18),
                            onPressed: () => _actionModeration(
                              () => AcademiaModerationService.mute(
                                  widget.session.id, p.identity),
                              'Micro coupé.',
                            ),
                          ),
                          IconButton(
                            tooltip: 'Suspendre la parole',
                            icon: const Icon(Icons.voice_over_off, size: 18),
                            onPressed: () => _actionModeration(
                              () => AcademiaModerationService.revokePublish(
                                  widget.session.id, p.identity),
                              'Parole suspendue.',
                            ),
                          ),
                          IconButton(
                            tooltip: 'Rendre la parole',
                            icon: const Icon(Icons.record_voice_over, size: 18),
                            onPressed: () => _actionModeration(
                              () => AcademiaModerationService.grantPublish(
                                  widget.session.id, p.identity),
                              'Parole rendue.',
                            ),
                          ),
                          IconButton(
                            tooltip: 'Retirer de la séance',
                            icon: const Icon(Icons.person_remove,
                                size: 18, color: Color(0xFFEF4444)),
                            onPressed: () => _actionModeration(
                              () => AcademiaModerationService.remove(
                                  widget.session.id, p.identity),
                              'Participant retiré.',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.stop_circle, size: 18),
                    label: const Text('Arrêter la séance pour tous'),
                    onPressed: () async {
                      Navigator.of(sheetCtx).pop();
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AdaptiveDialog(
                          maxWidth: 420,
                          title: const Text('Arrêter la séance ?'),
                          child: const Text(
                              'Tous les participants seront déconnectés et la séance sera marquée terminée.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dCtx).pop(false),
                              child: const Text('Annuler'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF4444)),
                              onPressed: () => Navigator.of(dCtx).pop(true),
                              child: const Text('Arrêter'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await _actionModeration(
                          () => AcademiaModerationService.endSession(
                              widget.session.id),
                          'Séance arrêtée.',
                        );
                        if (mounted) Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Exécute une action de modération en rapportant le résultat, succès comme
  /// échec. Une action silencieuse laisserait le modérateur dans le doute.
  Future<void> _actionModeration(
    Future<void> Function() action,
    String messageSucces,
  ) async {
    try {
      await action();
      _notify(messageSucces);
    } catch (e) {
      _notify(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Traduit une exception technique en phrase actionnable.
  ///
  /// Un « Exception: PlatformException(...) » affiché en plein écran à un
  /// étudiant ne lui apprend rien et ne lui dit pas quoi faire.
  String _humanReadableError(Object e) {
    final raw = e.toString().toLowerCase();
    // Les refus d'inscription portent déjà un motif écrit pour l'utilisateur
    // (« Séance complète », « Séance terminée »…). Le reformuler le rendrait
    // plus vague, pas plus clair : on le laisse passer tel quel.
    if (raw.contains('complète') ||
        raw.contains('terminée') ||
        raw.contains('annulée') ||
        raw.contains('pas encore ouverte')) {
      return e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    }
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
      } else if (type == 'quiz' && !_isHost) {
        setState(() => _incomingQuiz = msg);
      } else if (type == 'td_exercise' && !_isHost) {
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
      // L'interface se met à jour AVANT le nettoyage : arrêter une capture peut
      // prendre un instant, et un bouton qui ne réagit pas donne l'impression
      // d'être cassé. On rend la main tout de suite, on nettoie ensuite.
      setState(() => _screenShareEnabled = false);
      _notify('Partage d\'écran arrêté.');
      await ScreenShareService.stop(participant);
      return;
    }

    // Un participant sans droit de publication ne peut pas diffuser son écran :
    // le dire tout de suite vaut mieux qu'un échec technique incompréhensible.
    if (!_canPublish) {
      _notify(
        'Le partage d\'écran est réservé aux participants autorisés à '
        'prendre la parole. Demandez la parole à l\'animateur.',
      );
      return;
    }

    // ── DIVULGATION PRÉALABLE (règle Google Play) ────────────────────────
    // Google Play exige une divulgation DANS l'application, juste avant la
    // demande système, expliquant quelle donnée sensible est captée et à
    // quelle fin. La boîte de dialogue Android ne suffit pas : elle dit
    // « enregistrer l'écran », pas « et le diffuser à ces personnes ».
    // Le refus est le choix par défaut ; aucune case n'est pré-cochée.
    final consentement = await _demanderConsentementPartage();
    if (consentement != true || !mounted) return;

    final error = await ScreenShareService.start(participant);
    if (!mounted) return;
    if (error != null) {
      _notify(error);
      return;
    }
    setState(() => _screenShareEnabled = true);
    unawaited(_journal.logEvent(widget.session.id, 'partage_ecran_demarre'));

    // Le partage n'a d'intérêt que si l'utilisateur peut montrer AUTRE CHOSE.
    // On le renvoie donc à son écran d'accueil : la capture continue (service
    // de premier plan), et il ouvre le document qu'il veut présenter. Sans ce
    // geste, l'application se diffuse elle-même.
    if (AppWindowService.isSupported) {
      _notify('Partage lancé. Ouvrez le document à montrer ; '
          'revenez par la notification pour arrêter.');
      // Laisser le message s'afficher avant de passer en arrière-plan.
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await AppWindowService.minimize();
    } else {
      _notify('Votre écran est partagé. Vous pouvez l\'arrêter à tout moment.');
    }
  }

  /// Divulgation préalable au partage d'écran.
  ///
  /// Trois informations sont obligatoires pour être conforme : **ce qui** est
  /// capté (tout l'écran, notifications comprises), **qui** le voit (les
  /// participants de cette séance), et **comment l'arrêter**. On nomme aussi
  /// ce qui n'est PAS fait — aucun enregistrement à l'insu — car c'est la
  /// crainte réelle de l'utilisateur.
  Future<bool?> _demanderConsentementPartage() {
    final nbAutres = _remoteParticipants.length;
    final qui = nbAutres == 0
        ? 'aux participants de cette séance'
        : nbAutres == 1
            ? 'à l\'autre participant de cette séance'
            : 'aux $nbAutres autres participants de cette séance';

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AdaptiveDialog(
        maxWidth: 460,
        title: const Row(
          children: [
            Icon(Icons.screen_share_outlined, size: 20, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Expanded(child: Text('Partager votre écran ?')),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tout ce qui s\'affiche sur votre écran sera visible en direct $qui, '
              'y compris vos notifications et le contenu de vos autres applications.',
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 12),
            _pointConsentement(
              Icons.visibility_off_outlined,
              'Fermez d\'abord vos messages et documents personnels.',
            ),
            _pointConsentement(
              Icons.stop_circle_outlined,
              'Vous pouvez arrêter le partage à tout moment, depuis le même bouton.',
            ),
            _pointConsentement(
              Icons.lock_outline,
              'Rien n\'est enregistré à votre insu : un enregistrement éventuel '
              'est signalé séparément par un bandeau rouge.',
            ),
            const SizedBox(height: 10),
            const Text(
              'Votre téléphone vous demandera ensuite de confirmer la capture.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.screen_share, size: 16),
            label: const Text('Partager mon écran'),
          ),
        ],
      ),
    );
  }

  Widget _pointConsentement(IconData icone, String texte) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 15, color: const Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texte,
                style: const TextStyle(fontSize: 12, height: 1.4)),
          ),
        ],
      ),
    );
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
        unawaited(
            _journal.logEvent(widget.session.id, 'enregistrement_demarre'));
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
    // Seule la main levée est journalisée, pas la main baissée : ce qui
    // intéresse la fiche, c'est qu'une question ait été demandée.
    if (raised) {
      unawaited(_journal.logEvent(widget.session.id, 'main_levee'));
    }
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
    // Journalisé AVANT le nettoyage : l'`offset_ms` se calcule sur l'horloge
    // du serveur, il doit refléter la fin réelle.
    await _journal.logEvent(widget.session.id, 'seance_terminee');
    await _cleanup();
    if (!mounted) return;

    // La séance se termine SUR la fiche, pas sur un retour en arrière.
    //
    // C'était le maillon manquant : sept séances terminées, zéro fiche — non
    // par manque de code, mais parce qu'aucun chemin n'y menait. L'animateur
    // arrive sur l'écran, relit, publie. Rien n'est généré à son insu : une
    // synthèse coûte un appel au modèle, et une séance sans matière n'a rien
    // à résumer.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SessionSummaryScreen(
          sessionId: widget.session.id,
          sessionTitle: widget.session.title,
          isHost: true,
        ),
      ),
    );
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
    // Le statut du serveur, pas celui de l'appelant : fermer l'écran ne doit terminer la
    // séance que si le SERVEUR reconnaît celui qui part comme son hôte. Un
    // superviseur qui s'en va se contente de quitter.
    if (_isHost) {
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
                    isHost: _isHost,
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
                isHost: _isHost,
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
          if (_showContexte && _estOrientation && _isHost)
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
          if (_showQuiz && _isHost && _features.isQuizEnabled)
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
                // L'énoncé part au journal : c'est la trace la plus dense de
                // ce qui a été travaillé pendant la séance.
                unawaited(_journal.logEvent(
                  widget.session.id,
                  'quiz_envoye',
                  payload: {'question': q['question']?.toString() ?? ''},
                ));
                setState(() => _showQuiz = false);
              },
            ),

          // ── Quiz overlay (étudiant) ───────────────────────────────
          if (_incomingQuiz != null && !_isHost)
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
          if (_incomingTdExercise != null && !_isHost)
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
                isHost: _isHost,
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
            child: _isHost
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
                    screenShareEnabled: _screenShareEnabled,
                    // Un participant ne partage son écran que s'il a le droit
                    // de publier : entretien, TD, atelier. Pas un spectateur.
                    canShareScreen: _canPublish,
                    onToggleScreenShare: _toggleScreenShare,
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
                      child: Text(_isHost
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
              if (_estOrientation && _isHost)
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
              // Un administrateur qui supervise n'est pas un participant comme
              // les autres : le dire franchement évite qu'on le prenne pour un
              // élève silencieux.
              if (_isAdminSupervisor)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'SUPERVISION',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              // Commandes de modération : hôte sur sa séance, administrateur
              // sur toutes.
              if (_isModerator)
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: _ouvrirModeration,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Icon(Icons.shield_outlined,
                        color: Colors.white70, size: 18),
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
      // Celui qui partage voit un bandeau, pas son propre flux : il doit
      // pouvoir arrêter directement depuis ce bandeau.
      onStopSharing: _screenShareEnabled ? _toggleScreenShare : null,
    );

    final all = <Widget>[
      if (local != null)
        AcademiaParticipantTile(
          participant: local,
          isLocal: true,
          isHost: _isHost,
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
