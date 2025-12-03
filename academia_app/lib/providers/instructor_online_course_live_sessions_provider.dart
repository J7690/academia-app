import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InstructorOnlineCourseLiveSessionsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  List<Map<String, dynamic>> _sessions = [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  List<Map<String, dynamic>> get sessions => List.unmodifiable(_sessions);

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

  Future<void> loadMySessions() async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc('app_ci_list_my_online_course_live_sessions');
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour mes sessions live.');
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement de mes sessions live.',
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

  Future<bool> upsertSession({
    String? sessionId,
    required String courseId,
    String? lessonId,
    required String title,
    String? description,
    String? provider,
    required String joinUrl,
    required DateTime startAt,
    DateTime? endAt,
    String? replayVideoUrl,
    bool? isActive,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_ci_upsert_online_course_live_session',
        params: {
          'p_session_id': sessionId,
          'p_course_id': courseId,
          'p_lesson_id': lessonId,
          'p_title': title,
          'p_description': description,
          'p_provider': provider,
          'p_join_url': joinUrl,
          'p_start_at': startAt.toIso8601String(),
          'p_end_at': endAt?.toIso8601String(),
          'p_replay_video_url': replayVideoUrl,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la sauvegarde de la session.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la sauvegarde de la session live.',
        );
        return false;
      }
      await loadMySessions();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> submitSession(String sessionId) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_ci_submit_online_course_live_session',
        params: {
          'p_session_id': sessionId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la soumission de la session.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la soumission de la session live.',
        );
        return false;
      }
      await loadMySessions();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<Map<String, dynamic>?> startSession(String sessionId) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_ci_start_online_course_live_session',
        params: {
          'p_session_id': sessionId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors du démarrage de la session.');
        return null;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du démarrage de la session live.',
        );
        return null;
      }
      await loadMySessions();
      return Map<String, dynamic>.from(response);
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setSaving(false);
    }
  }
}
