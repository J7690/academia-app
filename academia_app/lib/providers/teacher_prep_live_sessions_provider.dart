import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for teacher CONCOURS live sessions (distinct from online course live sessions).
/// Uses app_prep_teacher_*_live_session RPCs which target prep_live_sessions table.
class TeacherPrepLiveSessionsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  List<Map<String, dynamic>> _sessions = [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  List<Map<String, dynamic>> get sessions => List.unmodifiable(_sessions);

  void _setLoading(bool v) { _isLoading = v; notifyListeners(); }
  void _setSaving(bool v) { _isSaving = v; notifyListeners(); }
  void _setError(String? v) { _error = v; notifyListeners(); }

  Future<void> loadMySessions() async {
    _setLoading(true);
    _setError(null);
    try {
      final res = await _client.rpc('app_prep_teacher_list_live_sessions');
      if (res is List) {
        _sessions = res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
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

  Future<bool> upsertSession({
    String? sessionId,
    required String title,
    String? description,
    String sessionType = 'revision',
    String? concoursType,
    String? subjectName,
    String provider = 'livekit',
    String? joinUrl,
    required DateTime startAt,
    DateTime? endAt,
    String? replayUrl,
    int maxParticipants = 100,
    String? quizTemplateId,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final res = await _client.rpc('app_prep_teacher_upsert_live_session', params: {
        if (sessionId != null) 'p_session_id': sessionId,
        'p_title': title,
        if (description != null) 'p_description': description,
        'p_session_type': sessionType,
        if (concoursType != null) 'p_concours_type': concoursType,
        if (subjectName != null) 'p_subject_name': subjectName,
        'p_provider': provider,
        if (joinUrl != null) 'p_join_url': joinUrl,
        'p_start_at': startAt.toIso8601String(),
        if (endAt != null) 'p_end_at': endAt.toIso8601String(),
        if (replayUrl != null) 'p_replay_url': replayUrl,
        'p_max_participants': maxParticipants,
        if (quizTemplateId != null) 'p_quiz_template_id': quizTemplateId,
      });
      if (res is Map && res['success'] == true) {
        await loadMySessions();
        return true;
      }
      _setError(res is Map ? res['error']?.toString() : 'Erreur');
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> startSession(String sessionId) async {
    _setSaving(true);
    _setError(null);
    try {
      final res = await _client.rpc('app_prep_teacher_start_live_session', params: {
        'p_session_id': sessionId,
      });
      if (res is Map && res['success'] == true) {
        await loadMySessions();
        return true;
      }
      _setError(res is Map ? res['error']?.toString() : 'Erreur');
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> endSession(String sessionId) async {
    _setSaving(true);
    _setError(null);
    try {
      final res = await _client.rpc('app_prep_teacher_end_live_session', params: {
        'p_session_id': sessionId,
      });
      if (res is Map && res['success'] == true) {
        await loadMySessions();
        return true;
      }
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }
}
