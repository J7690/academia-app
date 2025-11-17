import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UniversityApplicationDetailProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _details;

  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get details => _details;

  Map<String, dynamic>? get application {
    final raw = _details?['application'];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  Map<String, dynamic>? get studentProfile {
    final raw = _details?['student_profile'];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  Map<String, dynamic>? get studentDossierStatus {
    final raw = _details?['student_dossier_status'];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }
  List<Map<String, dynamic>> get applicationFiles {
    final raw = _details?['application_files'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }
    return const [];
  }

  List<Map<String, dynamic>> get dossierDocuments {
    final raw = _details?['dossier_documents'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }
    return const [];
  }

  Map<String, dynamic>? get programInfo {
    final raw = _details?['program'];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  Map<String, dynamic>? get universityInfo {
    final raw = _details?['university'];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  Future<void> loadDetails(String applicationId) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_get_university_application_detail',
        params: {'p_application_id': applicationId},
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors du chargement de la candidature.');
        return;
      }
      _details = response;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateStatus({
    required String applicationId,
    required String newStatus,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_university_update_application_status',
        params: {
          'p_application_id': applicationId,
          'p_new_status': newStatus,
        },
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ??
                  'Erreur lors de la mise à jour du statut.'
              : 'Erreur lors de la mise à jour du statut.',
        );
        return false;
      }
      await loadDetails(applicationId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }
}
