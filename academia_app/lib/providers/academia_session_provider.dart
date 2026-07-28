import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/academia_session.dart';

/// Provider unifié pour le Learning Engine.
/// Gère toutes les sessions pédagogiques via les RPCs `app_learning_*`.
class AcademiaSessionProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  List<AcademiaSession> _sessions = [];
  List<AcademiaSession> _replays = [];
  bool _isLoadingReplays = false;
  bool _hasMoreReplays = false;
  AcademiaSession? _currentSession;
  List<SessionParticipant> _participants = [];
  Map<String, dynamic>? _presenceStats;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  List<AcademiaSession> get sessions => List.unmodifiable(_sessions);
  List<AcademiaSession> get replays => List.unmodifiable(_replays);
  bool get isLoadingReplays => _isLoadingReplays;
  bool get hasMoreReplays => _hasMoreReplays;
  AcademiaSession? get currentSession => _currentSession;
  List<SessionParticipant> get participants => List.unmodifiable(_participants);
  Map<String, dynamic>? get presenceStats => _presenceStats;

  // ─── Helpers ────────────────────────────────────────────────────────

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setSaving(bool v) {
    _isSaving = v;
    notifyListeners();
  }

  void _setError(String? v) {
    _error = v;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ─── 1. Lister sessions (filtrable) ─────────────────────────────────

  Future<void> loadSessions({
    String? sessionType,
    String? status,
    String? hostId,
    String? courseId,
    int limit = 50,
    int offset = 0,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_learning_list_sessions',
        params: {
          'p_session_type': sessionType,
          'p_status': status,
          'p_host_id': hostId,
          'p_course_id': courseId,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur chargement sessions.');
        return;
      }
      final data = response['sessions'];
      if (data is List) {
        _sessions = data
            .whereType<Map<String, dynamic>>()
            .map(AcademiaSession.fromJson)
            .toList(growable: false);
      } else {
        _sessions = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ─── 2. Mes sessions (enseignant) ──────────────────────────────────

  Future<void> loadMySessions({String? sessionType, String? status}) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_learning_list_my_sessions',
        params: {
          'p_session_type': sessionType,
          'p_status': status,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide.');
        return;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur chargement.');
        return;
      }
      final data = response['sessions'];
      if (data is List) {
        _sessions = data
            .whereType<Map<String, dynamic>>()
            .map(AcademiaSession.fromJson)
            .toList(growable: false);
      } else {
        _sessions = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ─── 3. Sessions disponibles (étudiant) ────────────────────────────

  Future<void> loadAvailableSessions({String? sessionType}) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_learning_list_available_sessions',
        params: {
          'p_session_type': sessionType,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide.');
        return;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur.');
        return;
      }
      final data = response['sessions'];
      if (data is List) {
        _sessions = data
            .whereType<Map<String, dynamic>>()
            .map(AcademiaSession.fromJson)
            .toList(growable: false);
      } else {
        _sessions = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ─── 3 bis. Replays ────────────────────────────────────────────────

  /// Charge les séances terminées disposant d'un replay.
  ///
  /// Appel séparé et paginé (`app_learning_list_replays`) : l'historique des
  /// séances grossit indéfiniment, il ne doit pas peser sur le chargement de
  /// l'onglet Lives. Passer [append] à `true` pour charger la page suivante.
  Future<void> loadReplays({
    String? sessionType,
    int limit = 12,
    bool append = false,
  }) async {
    _isLoadingReplays = true;
    notifyListeners();
    try {
      final response = await _client.rpc(
        'app_learning_list_replays',
        params: {
          'p_session_type': sessionType,
          'p_limit': limit,
          'p_offset': append ? _replays.length : 0,
        },
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        if (!append) _replays = [];
        _hasMoreReplays = false;
        return;
      }
      final data = response['sessions'];
      final page = data is List
          ? data
              .whereType<Map<String, dynamic>>()
              .map(AcademiaSession.fromJson)
              .toList(growable: false)
          : const <AcademiaSession>[];
      _replays = append ? [..._replays, ...page] : page;
      _hasMoreReplays = response['has_more'] == true;
      notifyListeners();
    } catch (_) {
      // Les replays sont un bonus : une erreur ici ne doit pas faire
      // basculer tout l'onglet Lives en état d'erreur.
      if (!append) _replays = [];
      _hasMoreReplays = false;
    } finally {
      _isLoadingReplays = false;
      notifyListeners();
    }
  }

  // ─── 4. Obtenir une session par ID ─────────────────────────────────

  Future<AcademiaSession?> getSession(String sessionId) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_learning_get_session',
        params: {'p_session_id': sessionId},
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide.');
        return null;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Session introuvable.');
        return null;
      }
      final sessionData = response['session'];
      if (sessionData is Map<String, dynamic>) {
        _currentSession = AcademiaSession.fromJson(sessionData);
        notifyListeners();
        return _currentSession;
      }
      return null;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ─── 5. Créer / modifier une session ───────────────────────────────

  Future<String?> upsertSession({
    String? sessionId,
    required String sessionType,
    required String title,
    String? description,
    String? subject,
    String? concoursType,
    String? courseId,
    String? programId,
    String provider = 'livekit',
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    int maxParticipants = 100,
    bool isRecordingEnabled = true,
    bool isWhiteboardEnabled = false,
    bool isQuizEnabled = true,
    bool isChatEnabled = true,
    bool isScreenShareEnabled = true,
    bool isHandRaiseEnabled = true,
    String? thumbnailUrl,
    Map<String, dynamic>? metadata,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_learning_upsert_session',
        params: {
          'p_session_id': sessionId,
          'p_session_type': sessionType,
          'p_title': title,
          'p_description': description,
          'p_subject': subject,
          'p_concours_type': concoursType,
          'p_course_id': courseId,
          'p_program_id': programId,
          'p_provider': provider,
          'p_scheduled_start': scheduledStart?.toIso8601String(),
          'p_scheduled_end': scheduledEnd?.toIso8601String(),
          'p_max_participants': maxParticipants,
          'p_is_recording_enabled': isRecordingEnabled,
          'p_is_whiteboard_enabled': isWhiteboardEnabled,
          'p_is_quiz_enabled': isQuizEnabled,
          'p_is_chat_enabled': isChatEnabled,
          'p_is_screen_share_enabled': isScreenShareEnabled,
          'p_is_hand_raise_enabled': isHandRaiseEnabled,
          'p_thumbnail_url': thumbnailUrl,
          'p_metadata': metadata ?? {},
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide.');
        return null;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur sauvegarde.');
        return null;
      }
      return response['session_id']?.toString();
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setSaving(false);
    }
  }

  // ─── 5 bis. Publier / remettre en brouillon / annuler ──────────────

  /// Fait passer une séance entre `draft`, `scheduled` et `cancelled`.
  ///
  /// Une séance nouvellement créée est en `draft` : l'enseignant la prépare
  /// sans qu'elle apparaisse aux étudiants. La publier (`scheduled`) la rend
  /// visible dans `app_learning_list_available_sessions`.
  ///
  /// Le passage à `running` et `ended` reste réservé à [startSession] et
  /// [endSession], qui posent les horodatages réels.
  Future<bool> setSessionStatus(String sessionId, String status) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_learning_set_session_status',
        params: {'p_session_id': sessionId, 'p_status': status},
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide.');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Changement de statut refusé.');
        return false;
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ─── 6. Démarrer une session ───────────────────────────────────────

  Future<Map<String, dynamic>?> startSession(String sessionId) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_learning_start_session',
        params: {'p_session_id': sessionId},
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide.');
        return null;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Impossible de démarrer.');
        return null;
      }
      // Mettre à jour la session locale
      if (_currentSession?.id == sessionId) {
        _currentSession = _currentSession!.copyWith(
          status: SessionStatus.running,
          actualStart: DateTime.now(),
        );
        notifyListeners();
      }
      return Map<String, dynamic>.from(response);
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setSaving(false);
    }
  }

  // ─── 7. Terminer une session ───────────────────────────────────────

  Future<bool> endSession(String sessionId) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_learning_end_session',
        params: {'p_session_id': sessionId},
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide.');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur fin session.');
        return false;
      }
      if (_currentSession?.id == sessionId) {
        _currentSession = _currentSession!.copyWith(
          status: SessionStatus.ended,
          actualEnd: DateTime.now(),
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ─── 8. Rejoindre une session ──────────────────────────────────────

  Future<Map<String, dynamic>?> joinSession(String sessionId) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_learning_join_session',
        params: {'p_session_id': sessionId},
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide.');
        return null;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Impossible de rejoindre.');
        return null;
      }
      return Map<String, dynamic>.from(response);
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setSaving(false);
    }
  }

  // ─── 9. Quitter une session ────────────────────────────────────────

  Future<bool> leaveSession(String sessionId) async {
    try {
      final response = await _client.rpc(
        'app_learning_leave_session',
        params: {'p_session_id': sessionId},
      );
      if (response is! Map<String, dynamic>) return false;
      return response['success'] == true;
    } catch (e) {
      debugPrint('[AcademiaSession] Leave error: $e');
      return false;
    }
  }

  // ─── 10. Statistiques de présence ──────────────────────────────────

  Future<void> loadPresenceStats(String sessionId) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_learning_get_presence_stats',
        params: {'p_session_id': sessionId},
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide.');
        return;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur.');
        return;
      }
      _presenceStats = response['stats'] is Map<String, dynamic>
          ? response['stats'] as Map<String, dynamic>
          : null;
      final pData = response['participants'];
      if (pData is List) {
        _participants = pData
            .whereType<Map<String, dynamic>>()
            .map(SessionParticipant.fromJson)
            .toList(growable: false);
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ─── 11. Admin: changer statut ─────────────────────────────────────

  Future<bool> adminUpdateStatus(String sessionId, String newStatus) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_learning_update_session_status',
        params: {
          'p_session_id': sessionId,
          'p_new_status': newStatus,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide.');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur admin.');
        return false;
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ─── Convenience getters ───────────────────────────────────────────

  List<AcademiaSession> get liveSessions =>
      _sessions.where((s) => s.isLive).toList(growable: false);

  List<AcademiaSession> get upcomingSessions =>
      _sessions.where((s) => s.isUpcoming).toList(growable: false);

  List<AcademiaSession> get endedWithReplay =>
      _sessions.where((s) => s.hasReplay).toList(growable: false);

  List<AcademiaSession> sessionsByType(SessionType type) =>
      _sessions.where((s) => s.type == type).toList(growable: false);
}
