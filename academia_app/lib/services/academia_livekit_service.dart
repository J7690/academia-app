import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/academia_session.dart';

/// Service LiveKit unifié pour le Learning Engine.
/// Point d'entrée unique pour toutes les opérations LiveKit
/// sur les sessions AcademiaSession.
///
/// Remplace les appels directs à [LivekitTokenService] et
/// [LivekitRecordingService] pour les nouvelles sessions.
class AcademiaLivekitService {
  AcademiaLivekitService._();

  static final AcademiaLivekitService instance = AcademiaLivekitService._();

  final SupabaseClient _client = Supabase.instance.client;

  // ─── Token ──────────────────────────────────────────────────────────

  /// Obtient un token LiveKit pour rejoindre une session unifiée.
  ///
  /// Retourne un Map contenant :
  /// - `token` : JWT LiveKit
  /// - `url` : URL WebSocket du serveur
  /// - `room_name` : nom de la room
  /// - `identity` : identité participant
  /// - `display_name` : nom affiché
  /// - `is_host` : true si hôte
  /// - `session_type` : 'academia' (ou 'legacy' si fallback)
  Future<Map<String, dynamic>> getToken({
    required String sessionId,
    bool forceAcademia = true,
  }) async {
    final authSession = _client.auth.currentSession;
    if (authSession == null) {
      throw Exception('Utilisateur non authentifié.');
    }

    debugPrint('[AcademiaLivekit] Requesting token for session=$sessionId');

    final response = await _client.functions.invoke(
      'livekit-token',
      body: {
        'session_id': sessionId,
        'session_source': forceAcademia ? 'academia' : 'auto',
      },
    );

    if (response.status != 200) {
      debugPrint('[AcademiaLivekit] HTTP ${response.status}: ${response.data}');
      throw Exception('Erreur LiveKit (${response.status}).');
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Réponse LiveKit invalide.');
    }

    if (data['success'] != true) {
      final error = data['error']?.toString() ?? 'Erreur inconnue';
      debugPrint('[AcademiaLivekit] Error: $error');
      throw Exception(error);
    }

    debugPrint(
      '[AcademiaLivekit] Token OK: room=${data['room_name']}, '
      'host=${data['is_host']}, type=${data['session_type']}',
    );
    return data;
  }

  // ─── Enregistrement ─────────────────────────────────────────────────

  /// Démarre l'enregistrement d'une session (Egress LiveKit).
  Future<String?> startRecording({required String sessionId}) async {
    debugPrint('[AcademiaLivekit] Start recording for session=$sessionId');

    try {
      final response = await _client.functions.invoke(
        'livekit-recording',
        body: {
          'action': 'start',
          'session_id': sessionId,
          'session_type': 'academia',
        },
      );

      if (response.status != 200) {
        throw Exception('Erreur enregistrement (${response.status}).');
      }

      final data = response.data;
      if (data is! Map<String, dynamic> || data['success'] != true) {
        throw Exception(data is Map ? data['error']?.toString() : 'Erreur inconnue');
      }

      final egressId = data['egress_id']?.toString();
      debugPrint('[AcademiaLivekit] Recording started: egress_id=$egressId');
      return egressId;
    } catch (e) {
      debugPrint('[AcademiaLivekit] Start recording error: $e');
      rethrow;
    }
  }

  /// Arrête l'enregistrement d'une session.
  /// Retourne l'URL du fichier replay ou null.
  Future<String?> stopRecording({
    required String sessionId,
    required String egressId,
  }) async {
    debugPrint('[AcademiaLivekit] Stop recording egress=$egressId');

    try {
      final response = await _client.functions.invoke(
        'livekit-recording',
        body: {
          'action': 'stop',
          'session_id': sessionId,
          'session_type': 'academia',
          'egress_id': egressId,
        },
      );

      if (response.status != 200) {
        throw Exception('Erreur arrêt enregistrement (${response.status}).');
      }

      final data = response.data;
      if (data is! Map<String, dynamic> || data['success'] != true) {
        throw Exception(data is Map ? data['error']?.toString() : 'Erreur inconnue');
      }

      final fileUrl = data['file_url']?.toString();
      debugPrint('[AcademiaLivekit] Recording stopped: file_url=$fileUrl');

      if (fileUrl != null && fileUrl.isNotEmpty) {
        await _saveReplayUrl(sessionId: sessionId, replayUrl: fileUrl);
      }

      return fileUrl;
    } catch (e) {
      debugPrint('[AcademiaLivekit] Stop recording error: $e');
      rethrow;
    }
  }

  // ─── Présence ────────────────────────────────────────────────────────

  /// Enregistre l'entrée en session (côté base de données).
  /// À appeler AVANT d'obtenir le token.
  /// Inscrit le participant à la séance.
  ///
  /// Renvoie la réponse COMPLÈTE, refus compris. La version précédente rendait
  /// `null` dans tous les cas d'échec et se contentait d'un `debugPrint` :
  /// l'appelant ne pouvait pas distinguer « séance complète » d'une panne
  /// réseau, et n'avait aucun motif à afficher. Comme il ignorait aussi le
  /// résultat, un refus n'empêchait rien — le participant obtenait son jeton
  /// et entrait quand même.
  Future<Map<String, dynamic>?> joinSession(String sessionId) async {
    try {
      final response = await _client.rpc(
        'app_learning_join_session',
        params: {'p_session_id': sessionId},
      );
      if (response is Map<String, dynamic>) {
        if (response['success'] != true) {
          debugPrint('[AcademiaLivekit] Join refusé: ${response['error']}');
        }
        return response;
      }
      debugPrint('[AcademiaLivekit] Join failed: $response');
      return null;
    } catch (e) {
      debugPrint('[AcademiaLivekit] Join error: $e');
      return null;
    }
  }

  /// Enregistre la sortie de session (côté base de données).
  /// À appeler dans dispose() de l'écran.
  Future<void> leaveSession(String sessionId) async {
    try {
      await _client.rpc(
        'app_learning_leave_session',
        params: {'p_session_id': sessionId},
      );
    } catch (e) {
      debugPrint('[AcademiaLivekit] Leave error: $e');
    }
  }

  // ─── Lifecycle session ────────────────────────────────────────────────

  /// Démarre une session (statut → running).
  /// Doit être appelé par l'hôte avant d'obtenir le token.
  Future<Map<String, dynamic>?> startSession(String sessionId) async {
    try {
      final response = await _client.rpc(
        'app_learning_start_session',
        params: {'p_session_id': sessionId},
      );
      if (response is Map<String, dynamic> && response['success'] == true) {
        debugPrint('[AcademiaLivekit] Session started: $sessionId');
        return response;
      }
      return null;
    } catch (e) {
      debugPrint('[AcademiaLivekit] Start session error: $e');
      return null;
    }
  }

  /// Termine une session (statut → ended).
  /// Doit être appelé par l'hôte à la fermeture.
  Future<bool> endSession(String sessionId) async {
    try {
      final response = await _client.rpc(
        'app_learning_end_session',
        params: {'p_session_id': sessionId},
      );
      if (response is Map<String, dynamic> && response['success'] == true) {
        debugPrint('[AcademiaLivekit] Session ended: $sessionId');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[AcademiaLivekit] End session error: $e');
      return false;
    }
  }

  // ─── Config room ─────────────────────────────────────────────────────

  /// Retourne la config features d'une session (whiteboard, quiz, chat…).
  Future<AcademiaSessionFeatures?> getSessionFeatures(String sessionId) async {
    try {
      final response = await _client.rpc(
        'app_learning_get_session',
        params: {'p_session_id': sessionId},
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        return null;
      }
      final session = response['session'];
      if (session is! Map<String, dynamic>) return null;
      return AcademiaSessionFeatures.fromJson(session);
    } catch (e) {
      debugPrint('[AcademiaLivekit] Get features error: $e');
      return null;
    }
  }

  // ─── Modération hôte (contrôles distants) ───────────────────────────

  /// Liste les participants LiveKit actifs dans la room (via RoomService).
  Future<List<Map<String, dynamic>>> listParticipants(String sessionId) async {
    try {
      final response = await _client.functions.invoke(
        'livekit-admin',
        body: {
          'action': 'list_participants',
          'session_id': sessionId,
          'session_source': 'academia',
        },
      );
      final data = response.data;
      if (response.status != 200 || data is! Map<String, dynamic> || data['success'] != true) {
        return [];
      }
      final list = data['participants'];
      if (list is! List) return [];
      return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('[AcademiaLivekit] listParticipants error: $e');
      return [];
    }
  }

  /// Coupe (ou réactive) à distance le micro d'un participant.
  /// Utilise l'API RoomService de LiveKit côté serveur (MutePublishedTrack) :
  /// fonctionne aussi bien avec un LiveKit self-hosted que LiveKit Cloud,
  /// aucune différence de code entre les deux (Option A).
  Future<bool> muteParticipantAudio({
    required String sessionId,
    required String participantIdentity,
    bool muted = true,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'livekit-admin',
        body: {
          'action': 'mute_participant',
          'session_id': sessionId,
          'session_source': 'academia',
          'participant_identity': participantIdentity,
          'track_type': 'audio',
          'muted': muted,
        },
      );
      final data = response.data;
      if (response.status != 200 || data is! Map<String, dynamic>) return false;
      return data['success'] == true;
    } catch (e) {
      debugPrint('[AcademiaLivekit] muteParticipantAudio error: $e');
      return false;
    }
  }

  /// Exclut un participant de la session en cours.
  Future<bool> removeParticipant({
    required String sessionId,
    required String participantIdentity,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'livekit-admin',
        body: {
          'action': 'remove_participant',
          'session_id': sessionId,
          'session_source': 'academia',
          'participant_identity': participantIdentity,
        },
      );
      final data = response.data;
      if (response.status != 200 || data is! Map<String, dynamic>) return false;
      return data['success'] == true;
    } catch (e) {
      debugPrint('[AcademiaLivekit] removeParticipant error: $e');
      return false;
    }
  }

  // ─── Privé ────────────────────────────────────────────────────────────

  Future<void> _saveReplayUrl({
    required String sessionId,
    required String replayUrl,
  }) async {
    try {
      await _client.rpc(
        'app_learning_upsert_session',
        params: {
          'p_session_id': sessionId,
          'p_title': '',
          'p_session_type': 'course',
          'p_metadata': {'replay_url': replayUrl},
        },
      );
    } catch (_) {}
  }
}

/// Configuration des features d'une session.
class AcademiaSessionFeatures {
  final bool isRecordingEnabled;
  final bool isWhiteboardEnabled;
  final bool isQuizEnabled;
  final bool isChatEnabled;
  final bool isScreenShareEnabled;
  final bool isHandRaiseEnabled;

  const AcademiaSessionFeatures({
    required this.isRecordingEnabled,
    required this.isWhiteboardEnabled,
    required this.isQuizEnabled,
    required this.isChatEnabled,
    required this.isScreenShareEnabled,
    required this.isHandRaiseEnabled,
  });

  factory AcademiaSessionFeatures.fromJson(Map<String, dynamic> json) {
    return AcademiaSessionFeatures(
      isRecordingEnabled: json['is_recording_enabled'] == true,
      isWhiteboardEnabled: json['is_whiteboard_enabled'] == true,
      isQuizEnabled: json['is_quiz_enabled'] != false,
      isChatEnabled: json['is_chat_enabled'] != false,
      isScreenShareEnabled: json['is_screen_share_enabled'] != false,
      isHandRaiseEnabled: json['is_hand_raise_enabled'] != false,
    );
  }

  factory AcademiaSessionFeatures.fromSession(AcademiaSession session) {
    return AcademiaSessionFeatures(
      isRecordingEnabled: session.isRecordingEnabled,
      isWhiteboardEnabled: session.isWhiteboardEnabled,
      isQuizEnabled: session.isQuizEnabled,
      isChatEnabled: session.isChatEnabled,
      isScreenShareEnabled: session.isScreenShareEnabled,
      isHandRaiseEnabled: session.isHandRaiseEnabled,
    );
  }
}
