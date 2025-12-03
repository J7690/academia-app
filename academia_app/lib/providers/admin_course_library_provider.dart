import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/mime_type_helper.dart';

class AdminCourseLibraryProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _domains = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get domains => List.unmodifiable(_domains);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadLibrary() async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc('app_admin_list_course_library');
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement de la bibliothèque de cours.',
        );
        return;
      }
      final data = response['domains'];
      if (data is List) {
        _domains = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _domains = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> upsertDomain({
    String? domainId,
    required String title,
    String? description,
    int? sortOrder,
    bool? isActive,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_upsert_course_domain',
        params: {
          'p_domain_id': domainId,
          'p_title': title,
          'p_description': description,
          'p_sort_order': sortOrder,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ??
                  'Erreur lors de l\'enregistrement du domaine.'
              : 'Erreur lors de l\'enregistrement du domaine.',
        );
        return false;
      }
      await loadLibrary();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> upsertUnit({
    String? unitId,
    required String domainId,
    required String title,
    String? description,
    int? sortOrder,
    bool? isActive,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_upsert_course_unit',
        params: {
          'p_unit_id': unitId,
          'p_domain_id': domainId,
          'p_title': title,
          'p_description': description,
          'p_sort_order': sortOrder,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ??
                  'Erreur lors de l\'enregistrement de la sous-matière.'
              : 'Erreur lors de l\'enregistrement de la sous-matière.',
        );
        return false;
      }
      await loadLibrary();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> upsertResource({
    String? resourceId,
    required String unitId,
    required String title,
    String? description,
    required String resourceType,
    String? storageBucket,
    String? storagePath,
    String? externalUrl,
    int? sortOrder,
    bool? isActive,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_upsert_course_resource',
        params: {
          'p_resource_id': resourceId,
          'p_unit_id': unitId,
          'p_title': title,
          'p_description': description,
          'p_resource_type': resourceType,
          'p_storage_bucket': storageBucket,
          'p_storage_path': storagePath,
          'p_external_url': externalUrl,
          'p_sort_order': sortOrder,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ??
                  'Erreur lors de l\'enregistrement de la ressource.'
              : 'Erreur lors de l\'enregistrement de la ressource.',
        );
        return false;
      }
      await loadLibrary();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, String>?> uploadCourseFile({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    String folder = 'course-library',
  }) async {
    _setError(null);
    final user = _client.auth.currentUser;
    if (user == null) {
      _setError('Utilisateur non authentifié.');
      return null;
    }

    final sanitizedFileName =
        fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath = '${user.id}/$folder/$sanitizedFileName';

    try {
      await _client.storage.from('landing-media').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: MimeTypeHelper.normalize(mimeType),
              upsert: true,
            ),
          );
    } on StorageException catch (e) {
      final message = e.message.toLowerCase();
      final error = (e.error ?? '').toLowerCase();
      final statusCode = e.statusCode?.toString() ?? '';
      final isDuplicate = statusCode == '409' ||
          message.contains('already exists') ||
          error.contains('duplicate');

      if (!isDuplicate) {
        _setError(e.toString());
        return null;
      }
    } catch (e) {
      _setError(e.toString());
      return null;
    }

    return {
      'bucket': 'landing-media',
      'path': storagePath,
    };
  }
}
