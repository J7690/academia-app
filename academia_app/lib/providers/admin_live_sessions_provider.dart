import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminLiveSessionsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _participants = [];
  String? _participantsSessionId;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  List<Map<String, dynamic>> get sessions => List.unmodifiable(_sessions);
  List<Map<String, dynamic>> get participants => List.unmodifiable(_participants);
  String? get participantsSessionId => _participantsSessionId;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setSaving(bool value) {
    _isSaving = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadSessions({String? status}) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_list_online_course_live_sessions',
        params: {
          'p_status': status,
          'p_course_id': null,
          'p_instructor_id': null,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour les sessions live.');
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement des sessions live.',
        );
        return;
      }
      final data = response['sessions'];
      if (data is List) {
        _sessions = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
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

  Future<bool> updateStatus({required String sessionId, required String status}) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_update_online_course_live_session_status',
        params: {
          'p_session_id': sessionId,
          'p_status': status,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors du changement de statut.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du changement de statut de la session.',
        );
        return false;
      }
      await loadSessions();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<void> loadParticipants(String sessionId) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_list_online_course_live_session_participants',
        params: {
          'p_session_id': sessionId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour les participants.');
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement des participants.',
        );
        return;
      }
      final data = response['participants'];
      if (data is List) {
        _participants = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _participants = [];
      }
      _participantsSessionId = sessionId;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> banUser({required String sessionId, required String userId}) async {
    _setSaving(true);
    _setError(null);
    _setError(
      'La gestion temps réel des participants LiveKit est temporairement désactivée.',
    );
    _setSaving(false);
    return false;
  }
}
