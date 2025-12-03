import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour les formations courtes Nexium Group côté étudiant.
/// Utilise les RPC app_list_public_short_training_sessions,
/// app_list_my_short_trainings et app_register_short_training.
class StudentShortTrainingsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _publicSessions = [];
  List<Map<String, dynamic>> _myTrainings = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get publicSessions => _publicSessions;
  List<Map<String, dynamic>> get myTrainings => _myTrainings;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadPublicSessions() async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc('app_list_public_short_training_sessions');
      final data = response as List<dynamic>? ?? [];
      _publicSessions = data.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMyTrainings() async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc('app_list_my_short_trainings');
      final data = response as List<dynamic>? ?? [];
      _myTrainings = data.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> registerForSession(String sessionId) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_register_short_training',
        params: {
          'p_session_id': sessionId,
        },
      );
      final data = response as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        _setError(
          data?['error']?.toString() ??
              'Erreur lors de l\'inscription à la formation courte.',
        );
        return false;
      }
      await loadMyTrainings();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> registerForSessionWithDetails({
    required String sessionId,
    String? contactPhone,
    String? preferredChannel,
    String? paymentMethod,
    bool? wantsInvoice,
    String? companyName,
    String? notes,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_register_short_training_full',
        params: {
          'p_session_id': sessionId,
          'p_contact_phone': contactPhone,
          'p_preferred_channel': preferredChannel,
          'p_payment_method': paymentMethod,
          'p_wants_invoice': wantsInvoice,
          'p_company_name': companyName,
          'p_notes': notes,
        },
      );
      final data = response as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        _setError(
          data?['error']?.toString() ??
              'Erreur lors de l\'inscription à la formation courte.',
        );
        return false;
      }
      await loadMyTrainings();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
