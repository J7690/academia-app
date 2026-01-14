import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/mime_type_helper.dart';

class LandingContentProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  Map<String, dynamic>? _config;
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _partners = [];
  List<Map<String, dynamic>> _whyCards = [];
  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _shortTrainingHighlights = [];
  List<Map<String, dynamic>> _opportunityHighlights = [];
  List<Map<String, dynamic>> _onlineCourseHighlights = [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  Map<String, dynamic>? get config => _config;
  List<Map<String, dynamic>> get announcements => List.unmodifiable(_announcements);
  List<Map<String, dynamic>> get partners => List.unmodifiable(_partners);
  List<Map<String, dynamic>> get whyCards => List.unmodifiable(_whyCards);
  List<Map<String, dynamic>> get videos => List.unmodifiable(_videos);
  List<Map<String, dynamic>> get shortTrainingHighlights =>
      List.unmodifiable(_shortTrainingHighlights);
  List<Map<String, dynamic>> get opportunityHighlights =>
      List.unmodifiable(_opportunityHighlights);
  List<Map<String, dynamic>> get onlineCourseHighlights =>
      List.unmodifiable(_onlineCourseHighlights);

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

  Future<void> loadPublicLandingContent() async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc('app_public_landing_content');
      _applyResponse(response);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadAdminLandingContent() async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc('app_admin_get_landing_content');
      _applyResponse(response);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  void _applyResponse(dynamic response) {
    if (response is! Map<String, dynamic>) {
      _setError('Réponse invalide du serveur pour la landing.');
      return;
    }
    if (response['success'] != true) {
      _setError(
        response['error']?.toString() ?? 'Erreur lors du chargement de la landing.',
      );
      return;
    }

    final cfg = response['config'];
    final announcements = response['announcements'];
    final partners = response['partners'];
    final whyCards = response['why_cards'];
    final videos = response['videos'];
    final shortTrainings = response['short_training_highlights'];
    final opportunities = response['opportunity_highlights'];
    final onlineCourses = response['online_course_highlights'];

    if (cfg is Map) {
      _config = Map<String, dynamic>.from(cfg);
    } else {
      _config = null;
    }

    if (announcements is List) {
      _announcements = announcements
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } else {
      _announcements = [];
    }

    if (partners is List) {
      _partners = partners
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } else {
      _partners = [];
    }

    if (whyCards is List) {
      _whyCards = whyCards
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } else {
      _whyCards = [];
    }

    if (videos is List) {
      _videos = videos
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } else {
      _videos = [];
    }

    if (shortTrainings is List) {
      _shortTrainingHighlights = shortTrainings
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } else {
      _shortTrainingHighlights = [];
    }

    if (opportunities is List) {
      _opportunityHighlights = opportunities
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } else {
      _opportunityHighlights = [];
    }

    if (onlineCourses is List) {
      _onlineCourseHighlights = onlineCourses
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } else {
      _onlineCourseHighlights = [];
    }

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

  Future<bool> upsertConfig({
    String? configId,
    String? heroBadgeText,
    String? heroTitle,
    String? heroSubtitle,
    String? videoUrl,
    String? primaryColor,
    String? secondaryColor,
    String? accentColor,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      debugPrint('LandingContentProvider.upsertConfig: start configId='
          '$configId videoUrl=$videoUrl');

      String? trimmedVideoUrl = videoUrl?.trim();
      if (trimmedVideoUrl != null && trimmedVideoUrl.isEmpty) {
        trimmedVideoUrl = null;
      }

      String? videoAssetId;
      Map<String, dynamic>? playback;

      if (trimmedVideoUrl != null) {
        final manifest = await fetchPlaybackForDirectUrl(trimmedVideoUrl);
        if (manifest == null) {
          return false;
        }

        final rawVideoAssetId = manifest['video_asset_id']?.toString();
        final rawPlayback = manifest['playback'];

        if (rawVideoAssetId != null && rawVideoAssetId.trim().isNotEmpty &&
            rawPlayback is Map<String, dynamic>) {
          videoAssetId = rawVideoAssetId.trim();
          playback = Map<String, dynamic>.from(rawPlayback);
        } else {
          debugPrint(
            'LandingContentProvider.upsertConfig: manifest sans video_asset_id ou playback invalide, on continue sans VideoAsset.',
          );
        }
      }

      final dynamic response = await _client.rpc(
        'app_admin_upsert_landing_config',
        params: {
          'p_config_id': configId,
          'p_hero_badge_text': heroBadgeText,
          'p_hero_title': heroTitle,
          'p_hero_subtitle': heroSubtitle,
          'p_video_asset_id': videoAssetId,
          'p_playback': playback,
          'p_primary_color': primaryColor,
          'p_secondary_color': secondaryColor,
          'p_accent_color': accentColor,
        },
      );
      debugPrint('LandingContentProvider.upsertConfig: response=$response');
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la sauvegarde de la configuration.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ?? 'Erreur lors de la sauvegarde de la configuration.',
        );
        return false;
      }
      await loadAdminLandingContent();
      return true;
    } catch (e) {
      debugPrint('LandingContentProvider.upsertConfig: exception=$e');
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
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
        'app_admin_upsert_landing_announcement',
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
      await loadAdminLandingContent();
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
        'app_admin_delete_landing_announcement',
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
      await loadAdminLandingContent();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> upsertPartner({
    String? partnerId,
    String? name,
    String? logoUrl,
    String? websiteUrl,
    int? sortOrder,
    bool? isActive,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_upsert_landing_partner',
        params: {
          'p_partner_id': partnerId,
          'p_name': name,
          'p_logo_url': logoUrl,
          'p_website_url': websiteUrl,
          'p_sort_order': sortOrder,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la sauvegarde du partenaire.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ?? 'Erreur lors de la sauvegarde du partenaire.',
        );
        return false;
      }
      await loadAdminLandingContent();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> deletePartner(String partnerId) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_delete_landing_partner',
        params: {
          'p_partner_id': partnerId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la suppression du partenaire.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ?? 'Erreur lors de la suppression du partenaire.',
        );
        return false;
      }
      await loadAdminLandingContent();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> upsertWhyCard({
    String? whyId,
    required String title,
    String? subtitle,
    String? iconKey,
    int? sortOrder,
    bool? isActive,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_upsert_landing_why_card',
        params: {
          'p_why_id': whyId,
          'p_title': title,
          'p_subtitle': subtitle,
          'p_icon_key': iconKey,
          'p_sort_order': sortOrder,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la sauvegarde de la carte.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ?? 'Erreur lors de la sauvegarde de la carte.',
        );
        return false;
      }
      await loadAdminLandingContent();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> deleteWhyCard(String whyId) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_delete_landing_why_card',
        params: {
          'p_why_id': whyId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la suppression de la carte.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ?? 'Erreur lors de la suppression de la carte.',
        );
        return false;
      }
      await loadAdminLandingContent();
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
          _setError('URL vidéo manquante pour la landing.');
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
          _setError('Playback vidéo invalide ou incomplet pour la landing.');
          return false;
        }

        effectiveVideoAssetId = rawVideoAssetId.trim();
        effectivePlayback = Map<String, dynamic>.from(rawPlayback);
      }

      if (mediaType == 'video' &&
          (effectiveVideoAssetId == null || effectiveVideoAssetId.isEmpty)) {
        _setError('VideoAsset manquant pour la vidéo de la landing.');
        return false;
      }

      final dynamic response = await _client.rpc(
        'app_admin_upsert_landing_video',
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
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la sauvegarde de la vidéo.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ?? 'Erreur lors de la sauvegarde de la vidéo.',
        );
        return false;
      }
      await loadAdminLandingContent();
      return true;
    } catch (e) {
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
        'app_admin_delete_landing_video',
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
      await loadAdminLandingContent();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<String?> uploadLandingFile({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    String folder = 'generic',
  }) async {
    _setError(null);
    debugPrint('LandingContentProvider.uploadLandingFile: start fileName='
        '$fileName folder=$folder mimeType=$mimeType');

    final user = _client.auth.currentUser;
    if (user == null) {
      _setError('Utilisateur non authentifié.');
      debugPrint('LandingContentProvider.uploadLandingFile: user is null');
      return null;
    }

    final sanitizedFileName =
        fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath = '${user.id}/landing/$folder/$sanitizedFileName';

    debugPrint(
        'LandingContentProvider.uploadLandingFile: uploading to landing-media at $storagePath');

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
        debugPrint(
            'LandingContentProvider.uploadLandingFile: storage exception=$e');
        _setError(e.toString());
        return null;
      }

      debugPrint(
          'LandingContentProvider.uploadLandingFile: file already exists, reusing existing object at $storagePath');
    } catch (e) {
      debugPrint('LandingContentProvider.uploadLandingFile: exception=$e');
      _setError(e.toString());
      return null;
    }

    final publicUrl =
        _client.storage.from('landing-media').getPublicUrl(storagePath);
    debugPrint('LandingContentProvider.uploadLandingFile: success publicUrl='
        '$publicUrl');
    return publicUrl;
  }
}
