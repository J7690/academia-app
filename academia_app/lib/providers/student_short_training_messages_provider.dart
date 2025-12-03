import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour les messages associés à une inscription
/// à une formation courte côté étudiant.
///
/// Utilise les RPC app_list_short_training_messages_for_student et
/// app_add_short_training_message_from_student.
class StudentShortTrainingMessagesProvider extends ChangeNotifier {
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

  Future<void> loadMessages(String registrationId) async {
    _setLoading(true);
    _setError(null);
    try {
      final data = await _client.rpc(
        'app_list_short_training_messages_for_student',
        params: {'p_registration_id': registrationId},
      );
      if (data is List) {
        _messages = data
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false);
      } else {
        _setError('Réponse inattendue lors du chargement des messages.');
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> sendMessage({
    required String registrationId,
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
        'app_add_short_training_message_from_student',
        params: {
          'p_registration_id': registrationId,
          'p_content': content.trim(),
        },
      );

      final map = response as Map<String, dynamic>?;
      final success = map != null && map['success'] == true;
      if (!success) {
        _setError(map != null
            ? map['error']?.toString() ?? 'Erreur lors de l\'envoi du message.'
            : 'Erreur lors de l\'envoi du message.');
        return false;
      }

      await loadMessages(registrationId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
