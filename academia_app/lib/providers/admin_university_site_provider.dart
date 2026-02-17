import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/mime_type_helper.dart';

class AdminUniversitySiteProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  String? _currentUniversityId;
  Map<String, dynamic>? _university;
  Map<String, dynamic>? _config;
  List<Map<String, dynamic>> _blocks = [];
  List<Map<String, dynamic>> _media = [];
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _news = [];
  List<Map<String, dynamic>> _staff = [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  String? get currentUniversityId => _currentUniversityId;
  Map<String, dynamic>? get university => _university;
  Map<String, dynamic>? get config => _config;
  List<Map<String, dynamic>> get blocks => List.unmodifiable(_blocks);
  List<Map<String, dynamic>> get media => List.unmodifiable(_media);
  List<Map<String, dynamic>> get events => List.unmodifiable(_events);
  List<Map<String, dynamic>> get news => List.unmodifiable(_news);
  List<Map<String, dynamic>> get staff => List.unmodifiable(_staff);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<bool> upsertConfig({
    required String heroTitle,
    String? heroSubtitle,
    String? heroPrimaryColor,
    String? heroSecondaryColor,
    String? heroPosterMediaId,
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
        'app_admin_upsert_university_site_config',
        params: {
          'p_university_id': universityId,
          'p_hero_title': heroTitle,
          'p_hero_subtitle': heroSubtitle,
          'p_hero_primary_color': heroPrimaryColor,
          'p_hero_secondary_color': heroSecondaryColor,
          'p_hero_poster_media_id':
              (heroPosterMediaId != null && heroPosterMediaId.trim().isNotEmpty)
                  ? heroPosterMediaId
                  : null,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la sauvegarde de la configuration du mini-site (admin).',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la sauvegarde de la configuration du mini-site (admin).',
        );
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
      final cfg = response['config'];
      final blocks = response['blocks'];
      final media = response['media'];
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

  Future<Map<String, dynamic>?> _fetchPlaybackForDirectUrl(String url) async {
    try {
      final dynamic response = await _client.rpc(
        'app_videoasset_get_playback_for_direct_url',
        params: {
          'p_direct_url': url,
        },
      );
      if (response is! Map<String, dynamic>) {
        debugPrint(
            '[AdminUniversitySiteProvider._fetchPlaybackForDirectUrl] invalid response type: ${response.runtimeType}');
        return null;
      }
      if (response['success'] != true) {
        final error = response['error']?.toString();
        debugPrint(
            '[AdminUniversitySiteProvider._fetchPlaybackForDirectUrl] error from RPC: $error');
        return null;
      }
      final manifest = response['manifest'];
      if (manifest is! Map<String, dynamic>) {
        debugPrint(
            '[AdminUniversitySiteProvider._fetchPlaybackForDirectUrl] manifest manquant ou invalide dans la réponse: $manifest');
        return null;
      }
      return Map<String, dynamic>.from(manifest);
    } catch (e) {
      debugPrint(
          '[AdminUniversitySiteProvider._fetchPlaybackForDirectUrl] exception: $e');
      return null;
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
      final lowerType = mediaType.toLowerCase().trim();
      String? effectiveVideoAssetId;
      Map<String, dynamic>? effectivePlayback;

      if (lowerType.contains('video')) {
        final pathTrim = (storagePath ?? '').trim();
        if (pathTrim.isEmpty) {
          _setError(
              'VideoAsset manquant pour le média vidéo du mini-site (admin).');
          return false;
        }

        final publicUrl = _client.storage
            .from('university-media')
            .getPublicUrl(pathTrim);
        debugPrint(
            '[AdminUniversitySiteProvider.upsertMedia] resolving VideoAsset for publicUrl=$publicUrl');

        final manifest = await _fetchPlaybackForDirectUrl(publicUrl);
        if (manifest == null) {
          debugPrint(
              '[AdminUniversitySiteProvider.upsertMedia] aucun manifest résolu pour publicUrl=$publicUrl, on continue sans VideoAsset.');
        } else {
          final rawVideoAssetId = manifest['video_asset_id']?.toString();
          final rawPlayback = manifest['playback'];

          if (rawVideoAssetId != null &&
              rawVideoAssetId.trim().isNotEmpty &&
              rawPlayback is Map<String, dynamic>) {
            effectiveVideoAssetId = rawVideoAssetId.trim();
            effectivePlayback = Map<String, dynamic>.from(rawPlayback);
          } else {
            debugPrint(
              '[AdminUniversitySiteProvider.upsertMedia] manifest sans video_asset_id ou playback invalide, on continue sans VideoAsset. manifest=$manifest',
            );
          }
        }
      }

      debugPrint(
          '[AdminUniversitySiteProvider.upsertMedia] universityId=$universityId, mediaId=$mediaId, mediaType=$mediaType, title=$title, description=$description, url=$url, storagePath=$storagePath, thumbnailUrl=$thumbnailUrl, sortOrder=$sortOrder, isActive=$isActive, videoAssetId=$effectiveVideoAssetId, hasPlayback=${effectivePlayback != null}');

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
          'p_video_asset_id': effectiveVideoAssetId,
          'p_playback': effectivePlayback,
        },
      );
      if (response is! Map<String, dynamic>) {
        debugPrint(
            '[AdminUniversitySiteProvider.upsertMedia] invalid response type: ${response.runtimeType}');
        _setError(
            'Réponse invalide du serveur lors de la sauvegarde du média (admin).');
        return false;
      }
      if (response['success'] != true) {
        final error = response['error']?.toString();
        debugPrint(
            '[AdminUniversitySiteProvider.upsertMedia] error from RPC: $error');
        _setError(error ?? 'Erreur lors de la sauvegarde du média (admin).');
        return false;
      }
      await loadSiteForUniversity(universityId);
      debugPrint(
          '[AdminUniversitySiteProvider.upsertMedia] success response=$response');
      return true;
    } catch (e) {
      debugPrint(
          '[AdminUniversitySiteProvider.upsertMedia] exception: $e');
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
    final universityId = _currentUniversityId;
    if (universityId == null) {
      _setError('Aucune université sélectionnée.');
      return false;
    }
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_upsert_university_event',
        params: {
          'p_university_id': universityId,
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
        _setError("Réponse invalide du serveur lors de la sauvegarde de l'événement (admin).");
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            "Erreur lors de la sauvegarde de l'événement (admin).");
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

  Future<bool> deleteEvent(String eventId) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_delete_university_event',
        params: {
          'p_event_id': eventId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError("Réponse invalide du serveur lors de la suppression de l'événement (admin).");
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            "Erreur lors de la suppression de l'événement (admin).");
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
    final universityId = _currentUniversityId;
    if (universityId == null) {
      _setError('Aucune université sélectionnée.');
      return false;
    }
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_upsert_university_news',
        params: {
          'p_university_id': universityId,
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
        _setError("Réponse invalide du serveur lors de la sauvegarde de l'actualité (admin).");
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            "Erreur lors de la sauvegarde de l'actualité (admin).");
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

  Future<bool> deleteNews(String newsId) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_delete_university_news',
        params: {
          'p_news_id': newsId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError("Réponse invalide du serveur lors de la suppression de l'actualité (admin).");
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            "Erreur lors de la suppression de l'actualité (admin).");
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
    final universityId = _currentUniversityId;
    if (universityId == null) {
      _setError('Aucune université sélectionnée.');
      return false;
    }
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_upsert_university_staff',
        params: {
          'p_university_id': universityId,
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
        _setError(
            "Réponse invalide du serveur lors de la sauvegarde du membre de l'équipe (admin).");
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            "Erreur lors de la sauvegarde du membre de l'équipe (admin).");
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

  Future<bool> deleteStaff(String staffId) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_delete_university_staff',
        params: {
          'p_staff_id': staffId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
            "Réponse invalide du serveur lors de la suppression du membre de l'équipe (admin).");
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            "Erreur lors de la suppression du membre de l'équipe (admin).");
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

  Future<String?> uploadMediaFile({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    _setSaving(true);
    _setError(null);
    debugPrint(
        '[AdminUniversitySiteProvider.uploadMediaFile] fileName=$fileName, mimeType=$mimeType, bytesLength=${bytes.length}');
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        _setError('Utilisateur non authentifié.');
        return null;
      }

      debugPrint(
          '[AdminUniversitySiteProvider.uploadMediaFile] currentUser=${user.id}');

      final sanitizedFileName =
          fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final storagePath = '${user.id}/mini-site/$sanitizedFileName';

      debugPrint(
          '[AdminUniversitySiteProvider.uploadMediaFile] uploading to bucket=university-media, storagePath=$storagePath');

      try {
        await _client.storage.from('university-media').uploadBinary(
              storagePath,
              bytes,
              fileOptions: FileOptions(
                contentType: MimeTypeHelper.normalize(mimeType),
                upsert: true,
              ),
            );
      } on StorageException catch (e) {
        debugPrint(
          '[AdminUniversitySiteProvider.uploadMediaFile] StorageException message=${e.message} '
          'status=${e.statusCode} error=${e.error}',
        );
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
        debugPrint(
            '[AdminUniversitySiteProvider.uploadMediaFile] exception=$e');
        _setError(e.toString());
        return null;
      }

      return storagePath;
    } finally {
      _setSaving(false);
    }
  }

  void clear() {
    _currentUniversityId = null;
    _university = null;
    _blocks = [];
    _media = [];
    _events = [];
    _news = [];
    _staff = [];
    _error = null;
    notifyListeners();
  }
}
