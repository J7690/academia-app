import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour les messages d'une candidature côté université.
/// Utilise les RPC app_list_application_messages_for_university,
/// app_add_application_message_from_university,
/// app_mark_application_messages_read_for_university.
class UniversityApplicationMessagesProvider extends ChangeNotifier {
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

  Future<void> loadMessages(String applicationId) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_list_application_messages_for_university',
        params: {'p_application_id': applicationId},
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return;
      }
      final success = response['success'] == true;
      if (!success) {
        _setError(response['error']?.toString() ?? 'Erreur lors du chargement des messages.');
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
      try {
        await _client.rpc(
          'app_mark_application_messages_read_for_university',
          params: {'p_application_id': applicationId},
        );
      } catch (_) {}
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> sendToAdmin({
    required String applicationId,
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
        'app_add_application_message_from_university',
        params: {
          'p_application_id': applicationId,
          'p_content': content.trim(),
        },
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ?? 'Erreur lors de l\'envoi du message.'
              : 'Erreur lors de l\'envoi du message.',
        );
        return false;
      }
      await loadMessages(applicationId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
