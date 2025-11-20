import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/mime_type_helper.dart';

class UniversitySiteProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  Map<String, dynamic>? _university;
  Map<String, dynamic>? _config;
  List<Map<String, dynamic>> _blocks = [];
  List<Map<String, dynamic>> _media = [];
  List<Map<String, dynamic>> _banners = [];
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _news = [];
  List<Map<String, dynamic>> _staff = [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  Map<String, dynamic>? get university => _university;
  Map<String, dynamic>? get config => _config;
  List<Map<String, dynamic>> get blocks => List.unmodifiable(_blocks);
  List<Map<String, dynamic>> get media => List.unmodifiable(_media);
  List<Map<String, dynamic>> get banners => List.unmodifiable(_banners);
  List<Map<String, dynamic>> get events => List.unmodifiable(_events);
  List<Map<String, dynamic>> get news => List.unmodifiable(_news);
  List<Map<String, dynamic>> get staff => List.unmodifiable(_staff);

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

  Future<void> loadSite() async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc('app_list_university_site_for_management');
      if (response is! Map<String, dynamic>) {
        _university = null;
        _config = null;
        _blocks = [];
        _media = [];
        _banners = [];
        _setError('Réponse invalide du serveur pour le mini-site.');
        return;
      }
      if (response['success'] != true) {
        _university = null;
        _config = null;
        _blocks = [];
        _media = [];
        _banners = [];
        _setError(response['error']?.toString() ??
            'Erreur lors du chargement du mini-site.');
        return;
      }
      final uni = response['university'];
      final cfg = response['config'];
      final blocks = response['blocks'];
      final media = response['media'];
      final banners = response['banners'];
      final events = response['events'];
      final news = response['news'];
      final staff = response['staff'];

      if (uni is Map) {
        _university = Map<String, dynamic>.from(uni);
      } else {
        _university = null;
      }

      if (cfg is Map) {
        _config = Map<String, dynamic>.from(cfg);
      } else {
        _config = null;
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

      if (banners is List) {
        _banners = banners
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _banners = [];
      }

      if (events is List) {
        _events = events
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _events = [];
      }

      if (news is List) {
        _news = news
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _news = [];
      }

      if (staff is List) {
        _staff = staff
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _staff = [];
      }

      notifyListeners();
    } catch (e) {
      _university = null;
      _config = null;
      _blocks = [];
      _media = [];
      _banners = [];
      _events = [];
      _news = [];
      _staff = [];
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
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_upsert_university_site_block',
        params: {
          'p_block_id': blockId,
          'p_key': key,
          'p_title': title,
          'p_content': content,
          'p_sort_order': sortOrder,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la sauvegarde du bloc.');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors de la sauvegarde du bloc.');
        return false;
      }
      await loadSite();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> upsertEvent({
    String? eventId,
    required String title,
    String? description,
    String? eventType,
    DateTime? startAt,
    DateTime? endAt,
    String? location,
    bool? isHighlighted,
    bool? isActive,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_upsert_university_event',
        params: {
          'p_event_id': eventId,
          'p_title': title,
          'p_description': description,
          'p_event_type': eventType,
          'p_start_at': startAt?.toIso8601String(),
          'p_end_at': endAt?.toIso8601String(),
          'p_location': location,
          'p_is_highlighted': isHighlighted,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la sauvegarde de l\'événement.');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors de la sauvegarde de l\'événement.');
        return false;
      }
      await loadSite();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> deleteEvent(String eventId) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_delete_university_event',
        params: {
          'p_event_id': eventId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la suppression de l\'événement.');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors de la suppression de l\'événement.');
        return false;
      }
      await loadSite();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> upsertNews({
    String? newsId,
    required String title,
    String? slug,
    String? summary,
    String? content,
    DateTime? publishedAt,
    String? heroMediaId,
    bool? isActive,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_upsert_university_news',
        params: {
          'p_news_id': newsId,
          'p_title': title,
          'p_slug': slug,
          'p_summary': summary,
          'p_content': content,
          'p_published_at': publishedAt?.toIso8601String(),
          'p_hero_media_id': heroMediaId,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la sauvegarde de l\'actualité.');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors de la sauvegarde de l\'actualité.');
        return false;
      }
      await loadSite();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> deleteNews(String newsId) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_delete_university_news',
        params: {
          'p_news_id': newsId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la suppression de l\'actualité.');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors de la suppression de l\'actualité.');
        return false;
      }
      await loadSite();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> upsertStaff({
    String? staffId,
    required String fullName,
    String? role,
    String? bio,
    String? photoMediaId,
    String? email,
    String? phone,
    int? sortOrder,
    bool? isActive,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_upsert_university_staff',
        params: {
          'p_staff_id': staffId,
          'p_full_name': fullName,
          'p_role': role,
          'p_bio': bio,
          'p_photo_media_id': photoMediaId,
          'p_email': email,
          'p_phone': phone,
          'p_sort_order': sortOrder,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la sauvegarde du membre de l\'équipe.');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors de la sauvegarde du membre de l\'équipe.');
        return false;
      }
      await loadSite();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> deleteStaff(String staffId) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_delete_university_staff',
        params: {
          'p_staff_id': staffId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la suppression du membre de l\'équipe.');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors de la suppression du membre de l\'équipe.');
        return false;
      }
      await loadSite();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> upsertConfig({
    required String heroTitle,
    String? heroSubtitle,
    String? heroPrimaryColor,
    String? heroSecondaryColor,
    String? heroPosterMediaId,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_upsert_university_site_config',
        params: {
          'p_hero_title': heroTitle,
          'p_hero_subtitle': heroSubtitle,
          'p_hero_primary_color': heroPrimaryColor,
          'p_hero_secondary_color': heroSecondaryColor,
          'p_hero_poster_media_id': heroPosterMediaId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la sauvegarde de la configuration.');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors de la sauvegarde de la configuration.');
        return false;
      }
      await loadSite();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> upsertBanner({
    String? bannerId,
    required String position,
    required String title,
    String? subtitle,
    String? mediaId,
    int? sortOrder,
    bool? isActive,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_upsert_university_site_banner',
        params: {
          'p_banner_id': bannerId,
          'p_position': position,
          'p_title': title,
          'p_subtitle': subtitle,
          'p_media_id': mediaId,
          'p_sort_order': sortOrder,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la sauvegarde de la bannière.');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors de la sauvegarde de la bannière.');
        return false;
      }
      await loadSite();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> deleteBanner(String bannerId) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_delete_university_site_banner',
        params: {
          'p_banner_id': bannerId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la suppression de la bannière.');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors de la suppression de la bannière.');
        return false;
      }
      await loadSite();
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
        'app_delete_university_site_block',
        params: {
          'p_block_id': blockId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la suppression du bloc.');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors de la suppression du bloc.');
        return false;
      }
      await loadSite();
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
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_upsert_university_media',
        params: {
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
        _setError('Réponse invalide du serveur lors de la sauvegarde du média.');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors de la sauvegarde du média.');
        return false;
      }
      await loadSite();
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
        'app_delete_university_media',
        params: {
          'p_media_id': mediaId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la suppression du média.');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors de la suppression du média.');
        return false;
      }
      await loadSite();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<String?> uploadMediaFile({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        _setError('Utilisateur non authentifié.');
        return null;
      }

      final sanitizedFileName =
          fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final storagePath = '${user.id}/mini-site/$sanitizedFileName';

      await _client.storage.from('university-media').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: MimeTypeHelper.normalize(mimeType),
            ),
          );

      return storagePath;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setSaving(false);
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
