import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour gérer les documents globaux du dossier de candidature (2.1)
/// d'un étudiant.
///
/// Utilise Supabase Storage (bucket "application-files") et les RPC
/// app_list_student_dossier_documents / app_add_student_dossier_document.
class StudentDossierDocumentsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _documents = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get documents => List.unmodifiable(_documents);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadDocuments() async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc('app_list_student_dossier_documents');
      if (response is Map) {
        final map = Map<String, dynamic>.from(response);
        if (map['success'] == true && map['documents'] is List) {
          _documents = List<Map<String, dynamic>>.from(
            (map['documents'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
          );
        } else {
          _setError(map['error']?.toString() ??
              'Erreur lors du chargement des documents de dossier.');
        }
      } else {
        _setError('Réponse inattendue lors du chargement des documents de dossier.');
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addDocument({
    required Uint8List bytes,
    required String fileName,
    required String documentType,
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

      // Chemin global pour le dossier étudiant : userId/dossier/type/nom_fichier
      final storagePath = '${user.id}/dossier/$documentType/$fileName';

      await _client.storage.from('application-files').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: mimeType),
          );

      final response = await _client.rpc(
        'app_add_student_dossier_document',
        params: {
          'p_document_type': documentType,
          'p_storage_path': storagePath,
        },
      );

      final data = response as Map<String, dynamic>?;
      final success = data != null && (data['success'] == true);
      if (success) {
        await loadDocuments();
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
}
