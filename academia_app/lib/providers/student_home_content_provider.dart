import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/mime_type_helper.dart';

class StudentHomeContentProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _videos = [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  List<Map<String, dynamic>> get announcements => List.unmodifiable(_announcements);
  List<Map<String, dynamic>> get videos => List.unmodifiable(_videos);

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

  Future<Map<String, dynamic>?> fetchPlaybackForDirectUrl(String url) async {
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_videoasset_get_playback_for_direct_url',
        params: {
          'p_direct_url': url,
        },
      );

      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la résolution du playback vidéo.',
        );
        return null;
      }

      if (response['success'] != true) {
        _setError(
          'Erreur lors de la résolution du playback vidéo.',
        );
        return null;
      }

      final manifest = response['manifest'];
      if (manifest is! Map<String, dynamic>) {
        _setError(
          'Manifest de playback manquant ou invalide dans la réponse serveur.',
        );
        return null;
      }

      return Map<String, dynamic>.from(manifest);
    } catch (e) {
      _setError(
        'Erreur lors de la résolution du playback vidéo.',
      );
      return null;
    }
  }

  void _applyResponse(dynamic response) {
    if (response is! Map<String, dynamic>) {
      _setError('Réponse invalide du serveur pour l\'accueil étudiant.');
      return;
    }
    if (response['success'] != true) {
      _setError(
        response['error']?.toString() ?? 'Erreur lors du chargement de l\'accueil étudiant.',
      );
      return;
    }

    final announcements = response['announcements'];
    final videos = response['videos'];

    if (announcements is List) {
      _announcements = announcements
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } else {
      _announcements = [];
    }

    if (videos is List) {
      _videos = videos
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } else {
      _videos = [];
    }

    notifyListeners();
  }

  Future<void> loadPublicStudentHomeContent() async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc('app_public_student_home_content');
      _applyResponse(response);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadAdminStudentHomeContent() async {
    _setLoading(true);
    _setError(null);
    try {
      debugPrint(
        'StudentHomeContentProvider.loadAdminStudentHomeContent: start',
      );
      final dynamic response =
          await _client.rpc('app_admin_get_student_home_content');
      debugPrint(
        'StudentHomeContentProvider.loadAdminStudentHomeContent: response='
        '$response',
      );
      _applyResponse(response);
      debugPrint(
        'StudentHomeContentProvider.loadAdminStudentHomeContent: '
        'videos=${_videos.length} announcements=${_announcements.length}',
      );
    } catch (e) {
      debugPrint(
        'StudentHomeContentProvider.loadAdminStudentHomeContent: '
        'exception=$e',
      );
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> upsertAnnouncement({
    String? announcementId,
    required String text,
    int? sortOrder,
    bool? isActive,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_upsert_student_home_announcement',
        params: {
          'p_announcement_id': announcementId,
          'p_text': text,
          'p_sort_order': sortOrder,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la sauvegarde de l\'annonce.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ?? 'Erreur lors de la sauvegarde de l\'annonce.',
        );
        return false;
      }
      await loadAdminStudentHomeContent();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> deleteAnnouncement(String announcementId) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_delete_student_home_announcement',
        params: {
          'p_announcement_id': announcementId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la suppression de l\'annonce.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ?? 'Erreur lors de la suppression de l\'annonce.',
        );
        return false;
      }
      await loadAdminStudentHomeContent();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> upsertVideo({
    String? videoId,
    String? videoUrl,
    String? title,
    int? sortOrder,
    bool? isActive,
    String mediaType = 'video',
    String? videoAssetId,
    Map<String, dynamic>? playback,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final trimmedUrl = videoUrl?.trim() ?? '';

      String? effectiveVideoAssetId = videoAssetId;
      Map<String, dynamic>? effectivePlayback = playback;

      if (mediaType == 'video' &&
          (effectiveVideoAssetId == null || effectiveVideoAssetId.isEmpty)) {
        if (trimmedUrl.isEmpty) {
          _setError('URL vidéo manquante pour l\'accueil étudiant.');
          return false;
        }

        final manifest = await fetchPlaybackForDirectUrl(trimmedUrl);
        if (manifest == null) {
          return false;
        }

        final rawVideoAssetId = manifest['video_asset_id']?.toString();
        final rawPlayback = manifest['playback'];

        if (rawVideoAssetId == null || rawVideoAssetId.trim().isEmpty ||
            rawPlayback is! Map<String, dynamic>) {
          _setError('Playback vidéo invalide ou incomplet pour l\'accueil étudiant.');
          return false;
        }

        effectiveVideoAssetId = rawVideoAssetId.trim();
        effectivePlayback = Map<String, dynamic>.from(rawPlayback);
      }

      if (mediaType == 'video' &&
          (effectiveVideoAssetId == null || effectiveVideoAssetId.isEmpty)) {
        _setError('VideoAsset manquant pour la vidéo de l\'accueil étudiant.');
        return false;
      }

      debugPrint(
        'StudentHomeContentProvider.upsertVideo: start '
        'videoId=$videoId url=$videoUrl mediaType=$mediaType '
        'sortOrder=$sortOrder isActive=$isActive '
        'videoAssetId=$effectiveVideoAssetId',
      );
      final dynamic response = await _client.rpc(
        'app_admin_upsert_student_home_video',
        params: {
          'p_video_id': videoId,
          'p_video_asset_id': effectiveVideoAssetId,
          'p_playback': effectivePlayback,
          'p_title': title,
          'p_sort_order': sortOrder,
          'p_is_active': isActive,
          'p_media_type': mediaType,
        },
      );
      debugPrint(
        'StudentHomeContentProvider.upsertVideo: response=$response',
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la sauvegarde de la vidéo.');
        debugPrint(
          'StudentHomeContentProvider.upsertVideo: invalid response '
          '(not a Map)',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ?? 'Erreur lors de la sauvegarde de la vidéo.',
        );
        debugPrint(
          'StudentHomeContentProvider.upsertVideo: error='
          "${response['error']}",
        );
        return false;
      }
      await loadAdminStudentHomeContent();
      debugPrint(
        'StudentHomeContentProvider.upsertVideo: success '
        'videos=${_videos.length}',
      );
      return true;
    } catch (e) {
      debugPrint('StudentHomeContentProvider.upsertVideo: exception=$e');
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> deleteVideo(String videoId) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_delete_student_home_video',
        params: {
          'p_video_id': videoId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la suppression de la vidéo.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ?? 'Erreur lors de la suppression de la vidéo.',
        );
        return false;
      }
      await loadAdminStudentHomeContent();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<String?> uploadStudentHomeFile({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    String folder = 'student-home',
  }) async {
    _setError(null);
    final user = _client.auth.currentUser;
    if (user == null) {
      _setError('Utilisateur non authentifié.');
      debugPrint(
        'StudentHomeContentProvider.uploadStudentHomeFile: '
        'user is null (non authentifié)',
      );
      return null;
    }

    final sanitizedFileName =
        fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath = '${user.id}/student-home/$folder/$sanitizedFileName';

    try {
      debugPrint(
        'StudentHomeContentProvider.uploadStudentHomeFile: '
        'uploading fileName=$fileName mimeType=$mimeType '
        'to landing-media at $storagePath',
      );
      await _client.storage.from('landing-media').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: MimeTypeHelper.normalize(mimeType),
              upsert: true,
            ),
          );
    } on StorageException catch (e) {
      debugPrint(
        'StudentHomeContentProvider.uploadStudentHomeFile: '
        'StorageException message=${e.message} '
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
        'StudentHomeContentProvider.uploadStudentHomeFile: '
        'exception=$e',
      );
      _setError(e.toString());
      return null;
    }

    final publicUrl =
        _client.storage.from('landing-media').getPublicUrl(storagePath);
    debugPrint(
      'StudentHomeContentProvider.uploadStudentHomeFile: '
      'success publicUrl=$publicUrl',
    );
    return publicUrl;
  }
}
