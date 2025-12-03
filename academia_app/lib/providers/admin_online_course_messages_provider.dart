import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour les messages associés à une inscription
/// à un cours en ligne côté administrateur.
///
/// Utilise les RPC app_admin_list_online_course_enrollment_messages et
/// app_admin_add_online_course_enrollment_message_to_student.
class AdminOnlineCourseMessagesProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _messages = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get messages => List.unmodifiable(_messages);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadMessages(String enrollmentId) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_list_online_course_enrollment_messages',
        params: {'p_enrollment_id': enrollmentId},
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement des messages.',
        );
        return;
      }
      final msgs = response['messages'];
      if (msgs is List) {
        _messages = msgs
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false);
      } else {
        _messages = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> sendToStudent({
    required String enrollmentId,
    required String content,
  }) async {
    if (content.trim().isEmpty) {
      _setError('Le message est vide.');
      return false;
    }
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_add_online_course_enrollment_message_to_student',
        params: {
          'p_enrollment_id': enrollmentId,
          'p_content': content.trim(),
        },
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ??
                  'Erreur lors de l\'envoi du message.'
              : 'Erreur lors de l\'envoi du message.',
        );
        return false;
      }
      await loadMessages(enrollmentId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
