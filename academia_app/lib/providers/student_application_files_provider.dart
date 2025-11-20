import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour gérer les fichiers liés aux candidatures d'un étudiant.
///
/// Utilise Supabase Storage (bucket "application-files") et les RPC
/// app_list_application_files / app_add_application_file.
class StudentApplicationFilesProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _files = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get files => List.unmodifiable(_files);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadFiles(String applicationId) async {
    _setLoading(true);
    _setError(null);
    try {
      final data = await _client.rpc(
        'app_list_application_files',
        params: {'p_application_id': applicationId},
      ) as List<dynamic>? ?? [];
      _files = data.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addFile({
    required String applicationId,
    required Uint8List bytes,
    required String fileName,
    String fileType = 'document',
    String? mimeType,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        _setError('Utilisateur non authentifié');
        return false;
      }

      // Construire un chemin de stockage structuré : userId/applicationId/nom_fichier
      final storagePath = '${user.id}/$applicationId/$fileName';

      await _client.storage.from('application-files').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: _normalizeMimeType(mimeType),
            ),
          );

      final response = await _client.rpc(
        'app_add_application_file',
        params: {
          'p_application_id': applicationId,
          'p_file_type': fileType,
          'p_storage_path': storagePath,
        },
      );

      final data = response as Map<String, dynamic>?;
      final success = data != null && (data['success'] == true);
      if (success) {
        await loadFiles(applicationId);
      } else {
        _setError(data != null ? data['error']?.toString() : 'Erreur inconnue');
      }

      return success;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> createSignedUrl(String storagePath) async {
    _setError(null);
    try {
      final url = await _client.storage
          .from('application-files')
          .createSignedUrl(storagePath, 60 * 60);
      return url;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  Future<bool> deleteFile({
    required String fileId,
    required String storagePath,
    required String applicationId,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      await _client.storage.from('application-files').remove([storagePath]);

      final response = await _client.rpc(
        'app_delete_application_file',
        params: {
          'p_file_id': fileId,
        },
      );

      final data = response as Map<String, dynamic>?;
      final success = data != null && (data['success'] == true);
      if (success) {
        await loadFiles(applicationId);
      } else {
        _setError(data != null ? data['error']?.toString() : 'Erreur inconnue');
      }

      return success;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
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
