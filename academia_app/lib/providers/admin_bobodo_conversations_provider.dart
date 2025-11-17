import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour les conversations Bobodo côté administrateur.
/// Utilise les RPC app_admin_list_bobodo_sessions et app_admin_list_bobodo_messages.
class AdminBobodoConversationsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoadingSessions = false;
  bool _isLoadingMessages = false;
  String? _error;
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _messages = [];

  bool get isLoadingSessions => _isLoadingSessions;
  bool get isLoadingMessages => _isLoadingMessages;
  String? get error => _error;
  List<Map<String, dynamic>> get sessions => List.unmodifiable(_sessions);
  List<Map<String, dynamic>> get messages => List.unmodifiable(_messages);

  void _setSessionsLoading(bool value) {
    _isLoadingSessions = value;
    notifyListeners();
  }

  void _setMessagesLoading(bool value) {
    _isLoadingMessages = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadSessions() async {
    _setSessionsLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_list_bobodo_sessions',
        params: {'p_student_id': null},
      );
      if (response is List) {
        _sessions = response
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false);
      } else {
        _sessions = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setSessionsLoading(false);
    }
  }

  Future<void> loadMessages(String sessionId) async {
    _setMessagesLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_list_bobodo_messages',
        params: {'p_session_id': sessionId},
      );
      if (response is List) {
        _messages = response
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false);
      } else {
        _messages = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setMessagesLoading(false);
    }
  }

  /// Retourne une liste de profils étudiants distincts issus des sessions Bobodo.
  /// Chaque élément contient student_id et student_full_name.
  List<Map<String, String>> get distinctStudents {
    final seen = <String, String>{};
    for (final session in _sessions) {
      final id = session['student_id']?.toString();
      final name = session['student_full_name']?.toString() ?? '';
      if (id != null && id.isNotEmpty) {
        seen[id] = name;
      }
    }
    return seen.entries
        .map((e) => {'student_id': e.key, 'student_full_name': e.value})
        .toList(growable: false);
  }

  /// Sessions filtrées pour un étudiant donné.
  List<Map<String, dynamic>> sessionsForStudent(String? studentId) {
    if (studentId == null) return sessions;
    return _sessions
        .where((s) => s['student_id']?.toString() == studentId)
        .toList(growable: false);
  }
}
