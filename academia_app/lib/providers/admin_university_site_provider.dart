import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUniversitySiteProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  String? _currentUniversityId;
  Map<String, dynamic>? _university;
  List<Map<String, dynamic>> _blocks = [];
  List<Map<String, dynamic>> _media = [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  String? get currentUniversityId => _currentUniversityId;
  Map<String, dynamic>? get university => _university;
  List<Map<String, dynamic>> get blocks => List.unmodifiable(_blocks);
  List<Map<String, dynamic>> get media => List.unmodifiable(_media);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setSaving(bool value) {
    _isSaving = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadSiteForUniversity(String universityId) async {
    _currentUniversityId = universityId;
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_get_university_site',
        params: {'p_university_id': universityId},
      );
      if (response is! Map<String, dynamic>) {
        _university = null;
        _blocks = [];
        _media = [];
        _setError('Réponse invalide du serveur pour le mini-site (admin).');
        return;
      }
      if (response['success'] != true) {
        _university = null;
        _blocks = [];
        _media = [];
        _setError(response['error']?.toString() ??
            'Erreur lors du chargement du mini-site (admin).');
        return;
      }

      final uni = response['university'];
      final blocks = response['blocks'];
      final media = response['media'];

      if (uni is Map) {
        _university = Map<String, dynamic>.from(uni);
      } else {
        _university = null;
      }

      if (blocks is List) {
        _blocks = blocks
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _blocks = [];
      }

      if (media is List) {
        _media = media
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _media = [];
      }

      notifyListeners();
    } catch (e) {
      _university = null;
      _blocks = [];
      _media = [];
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> upsertBlock({
    String? blockId,
    required String key,
    String? title,
    String? content,
    int? sortOrder,
    bool? isActive,
  }) async {
    final universityId = _currentUniversityId;
    if (universityId == null) {
      _setError('Aucune université sélectionnée.');
      return false;
    }
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_upsert_university_site_block',
        params: {
          'p_university_id': universityId,
          'p_block_id': blockId,
          'p_key': key,
          'p_title': title,
          'p_content': content,
          'p_sort_order': sortOrder,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la sauvegarde du bloc (admin).');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors de la sauvegarde du bloc (admin).');
        return false;
      }
      await loadSiteForUniversity(universityId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> deleteBlock(String blockId) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_delete_university_site_block',
        params: {
          'p_block_id': blockId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la suppression du bloc (admin).');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors de la suppression du bloc (admin).');
        return false;
      }
      final universityId = _currentUniversityId;
      if (universityId != null) {
        await loadSiteForUniversity(universityId);
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> upsertMedia({
    String? mediaId,
    required String mediaType,
    String? title,
    String? description,
    String? url,
    String? storagePath,
    String? thumbnailUrl,
    int? sortOrder,
    bool? isActive,
  }) async {
    final universityId = _currentUniversityId;
    if (universityId == null) {
      _setError('Aucune université sélectionnée.');
      return false;
    }
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_upsert_university_media',
        params: {
          'p_university_id': universityId,
          'p_media_id': mediaId,
          'p_media_type': mediaType,
          'p_title': title,
          'p_description': description,
          'p_url': url,
          'p_storage_path': storagePath,
          'p_thumbnail_url': thumbnailUrl,
          'p_sort_order': sortOrder,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la sauvegarde du média (admin).');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors de la sauvegarde du média (admin).');
        return false;
      }
      await loadSiteForUniversity(universityId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> deleteMedia(String mediaId) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_delete_university_media',
        params: {
          'p_media_id': mediaId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la suppression du média (admin).');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors de la suppression du média (admin).');
        return false;
      }
      final universityId = _currentUniversityId;
      if (universityId != null) {
        await loadSiteForUniversity(universityId);
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  void clear() {
    _currentUniversityId = null;
    _university = null;
    _blocks = [];
    _media = [];
    _error = null;
    notifyListeners();
  }
}
