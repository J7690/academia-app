import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour les candidatures étudiant
/// Utilise les RPC app_list_student_applications et app_create_application
class StudentApplicationsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _applications = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get applications => _applications;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadApplications() async {
    _setLoading(true);
    _setError(null);
    try {
      final data = await _client.rpc('app_list_student_applications') as List<dynamic>? ?? [];
      _applications = data.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createApplication({
    required String programId,
    String? motivationText,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_create_application',
        params: {
          'p_program_id': programId,
          'p_motivation_text': motivationText,
        },
      );
      final data = response as Map<String, dynamic>?;
      final success = data != null && (data['success'] == true);
      if (success) {
        await loadApplications();
      }
      return success;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
