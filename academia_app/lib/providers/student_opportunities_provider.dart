import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour les opportunités (stages, emplois, autres) côté étudiant
/// Utilise uniquement les RPC validées dans .windsurf (module opportunités)
class StudentOpportunitiesProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _opportunities = [];
  List<Map<String, dynamic>> _applications = [];
  List<Map<String, dynamic>> _types = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get opportunities => _opportunities;
  List<Map<String, dynamic>> get applications => _applications;
  List<Map<String, dynamic>> get types => _types;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadOpportunities({String? type, String? search}) async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_list_opportunities',
        params: {
          'p_type': type,
          'p_search': search,
        },
      );
      final data = response as List<dynamic>? ?? [];
      _opportunities = data.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadTypes() async {
    _setError(null);
    try {
      final dynamic response = await _client.rpc('app_list_opportunity_types');
      final data = response as List<dynamic>? ?? [];
      _types = data.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> loadMyApplications() async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response =
          await _client.rpc('app_student_list_my_opportunity_applications');
      final data = response as List<dynamic>? ?? [];
      _applications = data.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> applyForOpportunity({
    required String opportunityId,
    String? message,
    String? cvUrl,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_apply_for_opportunity',
        params: {
          'p_opportunity_id': opportunityId,
          'p_message': message,
          'p_cv_url': cvUrl,
          'p_extra_data': null,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          "Réponse invalide du serveur lors de la création de la candidature.",
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors de la création de la candidature à l'opportunité.",
        );
        return false;
      }
      await loadMyApplications();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> uploadCvFile({
    required String opportunityId,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    _setError(null);
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        _setError('Utilisateur non authentifié');
        return null;
      }

      final storagePath = '${user.id}/opportunities/$opportunityId/$fileName';

      await _client.storage.from('application-files').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: _normalizeMimeType(mimeType),
            ),
          );

      return storagePath;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  String _normalizeMimeType(String? extensionOrMime) {
    if (extensionOrMime == null || extensionOrMime.isEmpty) {
      return 'application/octet-stream';
    }

    final value = extensionOrMime.toLowerCase();

    if (value.contains('/')) {
      return value;
    }

    switch (value) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }
}
