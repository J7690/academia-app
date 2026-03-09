import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/mime_type_helper.dart';

/// Provider pour la gestion des challenges côté étudiant
/// Utilise uniquement les RPC validées dans .windsurf (module challenges)
class StudentChallengesProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isLoadingVideos = false;
  bool _isSaving = false;
  String? _error;

  List<Map<String, dynamic>> _challenges = [];
  List<Map<String, dynamic>> _participations = [];
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _leaderboard = [];
  List<Map<String, dynamic>> _videos = [];
  final Map<String, Map<String, dynamic>> _videoByParticipationId = {};
  final Map<String, Map<String, dynamic>> _freeVideoById = {};

  bool get isLoading => _isLoading;
  bool get isLoadingVideos => _isLoadingVideos;
  bool get isSaving => _isSaving;
  String? get error => _error;

  List<Map<String, dynamic>> get challenges => List.unmodifiable(_challenges);
  List<Map<String, dynamic>> get participations => List.unmodifiable(_participations);
  Map<String, dynamic>? get stats => _stats == null ? null : Map<String, dynamic>.from(_stats!);
  List<Map<String, dynamic>> get leaderboard => List.unmodifiable(_leaderboard);
  List<Map<String, dynamic>> get videos => List.unmodifiable(_videos);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<bool> softDeleteVideo({
    required String videoType,
    required String videoId,
  }) async {
    final vt = videoType.trim();
    final vid = videoId.trim();
    if (vt.isEmpty || vid.isEmpty) {
      _setError('Impossible d\'identifier cette vidéo pour la suppression.');
      return false;
    }

    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_soft_delete_video',
        params: {
          'p_video_type': vt,
          'p_video_id': vid,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la suppression.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la suppression de la vidéo.',
        );
        return false;
      }

      final normalizedType = vt.toLowerCase();
      _videos = _videos.where((v) {
        final t = v['video_type']?.toString().toLowerCase();
        final id = v['video_id']?.toString();
        return !(t == normalizedType && id == vid);
      }).toList(growable: false);

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<Map<String, dynamic>?> getVideoExportWatermarkedStatus({
    required String videoAssetId,
  }) async {
    final id = videoAssetId.trim();
    if (id.isEmpty) {
      _setError('Identifiant vidéo manquant.');
      return null;
    }

    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_get_video_export_watermarked_status',
        params: {
          'p_video_asset_id': id,
        },
      );

      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return null;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la vérification de l\'export.',
        );
        return null;
      }

      return Map<String, dynamic>.from(response);
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  Future<bool> setVideoAllowDownload({
    required String videoType,
    required String videoId,
    required bool allowDownload,
  }) async {
    final vt = videoType.trim();
    final vid = videoId.trim();
    if (vt.isEmpty || vid.isEmpty) {
      _setError('Impossible d\'identifier cette vidéo.');
      return false;
    }

    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_set_video_allow_download',
        params: {
          'p_video_type': vt,
          'p_video_id': vid,
          'p_allow_download': allowDownload,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la mise à jour des téléchargements.',
        );
        return false;
      }

      final normalizedType = vt.toLowerCase();
      _videos = _videos.map((v) {
        final t = v['video_type']?.toString().toLowerCase();
        final id = v['video_id']?.toString();
        if (t == normalizedType && id == vid) {
          final updated = Map<String, dynamic>.from(v);
          updated['allow_download'] = allowDownload;
          return updated;
        }
        return v;
      }).toList(growable: false);

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<Map<String, dynamic>?> requestVideoExportWatermarked({
    required String videoAssetId,
  }) async {
    final id = videoAssetId.trim();
    if (id.isEmpty) {
      _setError('Identifiant vidéo manquant.');
      return null;
    }

    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_request_video_export_watermarked',
        params: {
          'p_video_asset_id': id,
        },
      );

      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return null;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la préparation du téléchargement.',
        );
        return null;
      }

      return Map<String, dynamic>.from(response);
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setSaving(false);
    }
  }

  Future<List<Map<String, dynamic>>> listRecentlyDeletedVideos({
    int limit = 50,
  }) async {
    final safeLimit = limit <= 0 ? 50 : limit;
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_list_recently_deleted_videos',
        params: {
          'p_limit': safeLimit,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour les vidéos supprimées.');
        return [];
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement des vidéos supprimées.',
        );
        return [];
      }
      final items = response['videos'];
      if (items is! List) return [];
      return items
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  Future<bool> restoreVideo({
    required String videoType,
    required String videoId,
  }) async {
    final vt = videoType.trim();
    final vid = videoId.trim();
    if (vt.isEmpty || vid.isEmpty) {
      _setError('Impossible d\'identifier cette vidéo pour la restauration.');
      return false;
    }

    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_restore_video',
        params: {
          'p_video_type': vt,
          'p_video_id': vid,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la restauration.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la restauration de la vidéo.',
        );
        return false;
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> addVideoComment({
    required String videoType,
    required String videoId,
    required String content,
  }) async {
    final text = content.trim();
    if (text.isEmpty) {
      _setError('Le commentaire est vide.');
      return false;
    }

    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_add_video_comment',
        params: {
          'p_video_type': videoType,
          'p_video_id': videoId,
          'p_content': text,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de l\'ajout du commentaire.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de l\'ajout du commentaire.',
        );
        return false;
      }
      _incrementGenericVideoCommentsCount(videoType, videoId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> deleteVideoComment({
    required String commentId,
    required String videoType,
    required String videoId,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_delete_video_comment',
        params: {
          'p_comment_id': commentId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la suppression.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la suppression du commentaire.',
        );
        return false;
      }
      _decrementGenericVideoCommentsCount(videoType, videoId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> deleteChallengeVideoComment({
    required String commentId,
    required String participationId,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_delete_video_comment',
        params: {
          'p_comment_id': commentId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la suppression.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la suppression du commentaire.',
        );
        return false;
      }
      _decrementVideoCommentsCount(participationId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> addChallengeVideo({
    required String participationId,
    required String videoAssetId,
    required Map<String, dynamic> playback,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_add_challenge_video',
        params: {
          'p_participation_id': participationId,
          'p_video_asset_id': videoAssetId,
          'p_playback': playback,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de l\'ajout de la vidéo de challenge.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de l\'ajout de la vidéo de challenge.',
        );
        return false;
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<Map<String, dynamic>?> startDuoVideo({
    required String videoType,
    required String videoId,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_start_duo_video',
        params: {
          'p_video_type': videoType,
          'p_video_id': videoId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la préparation du duo.',
        );
        return null;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la préparation de la vidéo en duo.',
        );
        return null;
      }
      return Map<String, dynamic>.from(response);
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> unfavoriteVideo({
    required String videoType,
    required String videoId,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_video_unfavorite',
        params: {
          'p_video_type': videoType,
          'p_video_id': videoId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors du retrait du favori.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du retrait du favori de la vidéo.',
        );
        return false;
      }
      _updateGenericVideoFavoriteState(videoType, videoId, favorited: false);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> favoriteVideo({
    required String videoType,
    required String videoId,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_video_favorite',
        params: {
          'p_video_type': videoType,
          'p_video_id': videoId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de l\'ajout du favori.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de l\'ajout du favori sur la vidéo.',
        );
        return false;
      }
      _updateGenericVideoFavoriteState(videoType, videoId, favorited: true);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> reportVideo({
    required String videoType,
    required String videoId,
    required String reason,
    String? details,
  }) async {
    final r = reason.trim();
    if (r.isEmpty) {
      _setError('Le motif du signalement est vide.');
      return false;
    }

    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_report_video',
        params: {
          'p_video_type': videoType,
          'p_video_id': videoId,
          'p_reason': r,
          'p_details': details?.trim(),
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors du signalement de la vidéo.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du signalement de la vidéo.',
        );
        return false;
      }
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

  Future<String?> uploadChallengeVideo({
    required Uint8List bytes,
    required String fileName,
    required String challengeId,
    String? mimeType,
  }) async {
    debugPrint('[ChallengesProvider] uploadChallengeVideo: fileName=$fileName, challengeId=$challengeId, bytes=${bytes.length}');
    _setError(null);
    final user = _client.auth.currentUser;
    if (user == null) {
      _setError('Utilisateur non authentifié.');
      return null;
    }

    final sanitizedFileName =
        fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath =
        '${user.id}/challenges/$challengeId/$sanitizedFileName';

    try {
      await _client.storage.from('challenge-media').uploadBinary(
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

    final publicUrl =
        _client.storage.from('challenge-media').getPublicUrl(storagePath);
    debugPrint('[ChallengesProvider] uploadChallengeVideo: publicUrl=$publicUrl');
    return publicUrl;
  }

  Future<Map<String, dynamic>?> fetchPlaybackForDirectUrl(String url) async {
    debugPrint('[ChallengesProvider] fetchPlaybackForDirectUrl: url=$url');
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_videoasset_get_playback_for_direct_url',
        params: {
          'p_direct_url': url,
        },
      );

      debugPrint('[ChallengesProvider] fetchPlaybackForDirectUrl response type=${response.runtimeType}');
      if (response is Map) {
        final map = Map<String, dynamic>.from(response);
        debugPrint('[ChallengesProvider] fetchPlaybackForDirectUrl response keys=${map.keys.toList()}');
        debugPrint('[ChallengesProvider] fetchPlaybackForDirectUrl response success=${map['success']} error=${map['error']}');
        final manifestAny = map['manifest'];
        if (manifestAny is Map) {
          final manifest = Map<String, dynamic>.from(manifestAny);
          debugPrint('[ChallengesProvider] fetchPlaybackForDirectUrl manifest keys=${manifest.keys.toList()}');
          final best = manifest['best_url']?.toString();
          debugPrint('[ChallengesProvider] fetchPlaybackForDirectUrl manifest best_url=$best');
        }
      }

      if (response is! Map<String, dynamic>) {
        debugPrint('[ChallengesProvider] fetchPlaybackForDirectUrl: invalid response type, falling back to direct URL');
        return _buildFallbackPlayback(url);
      }

      if (response['success'] != true) {
        debugPrint('[ChallengesProvider] fetchPlaybackForDirectUrl: success!=true, error=${response['error']}, falling back');
        return _buildFallbackPlayback(url);
      }

      final manifest = response['manifest'];
      if (manifest is! Map<String, dynamic>) {
        debugPrint('[ChallengesProvider] fetchPlaybackForDirectUrl: manifest missing/invalid, falling back');
        return _buildFallbackPlayback(url);
      }

      debugPrint('[ChallengesProvider] fetchPlaybackForDirectUrl: manifest OK');
      return Map<String, dynamic>.from(manifest);
    } catch (e) {
      debugPrint('[ChallengesProvider] fetchPlaybackForDirectUrl: exception=$e, falling back');
      return _buildFallbackPlayback(url);
    }
  }

  /// Fetch playback manifest for a video_asset by its ID.
  /// Tries the RPC `app_videoasset_get_playback_manifest` first, then falls
  /// back to querying the video_rendition table directly.
  Future<Map<String, dynamic>?> fetchPlaybackForVideoAsset(String videoAssetId) async {
    debugPrint('[ChallengesProvider] fetchPlaybackForVideoAsset: videoAssetId=$videoAssetId');
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_videoasset_get_playback_manifest',
        params: {'p_video_asset_id': videoAssetId},
      );

      debugPrint('[ChallengesProvider] fetchPlaybackForVideoAsset response type=${response.runtimeType}');
      if (response is Map) {
        final map = Map<String, dynamic>.from(response);
        debugPrint('[ChallengesProvider] fetchPlaybackForVideoAsset response keys=${map.keys.toList()}');
        debugPrint('[ChallengesProvider] fetchPlaybackForVideoAsset response success=${map['success']} error=${map['error']}');
        final legacyManifestAny = map['manifest'];
        if (legacyManifestAny is Map) {
          final legacyManifest = Map<String, dynamic>.from(legacyManifestAny);
          debugPrint('[ChallengesProvider] fetchPlaybackForVideoAsset legacy manifest keys=${legacyManifest.keys.toList()}');
          debugPrint('[ChallengesProvider] fetchPlaybackForVideoAsset legacy best_url=${legacyManifest['best_url']}');
        }
        debugPrint('[ChallengesProvider] fetchPlaybackForVideoAsset new-shape best_url=${map['best_url']} poster_url=${map['poster_url']}');
      }

      if (response is! Map<String, dynamic> || response['success'] != true) {
        debugPrint('[ChallengesProvider] fetchPlaybackForVideoAsset: RPC returned non-success or invalid response');
        return null;
      }

      // Legacy shape: { success: true, manifest: { ... } }
      final legacyManifest = response['manifest'];
      if (legacyManifest is Map<String, dynamic>) {
        debugPrint('[ChallengesProvider] fetchPlaybackForVideoAsset: legacy manifest OK');
        return Map<String, dynamic>.from(legacyManifest);
      }

      // New shape (after backend fix): { success: true, best_url, poster_url, renditions, ... }
      final bestUrl = response['best_url']?.toString();
      final posterUrl = response['poster_url']?.toString();
      final renditions = response['renditions'];

      if (bestUrl != null && bestUrl.isNotEmpty) {
        debugPrint('[ChallengesProvider] fetchPlaybackForVideoAsset: normalized new-shape manifest');
        return {
          'video_asset_id': videoAssetId,
          'best_url': bestUrl,
          'poster_url': (posterUrl != null && posterUrl.isNotEmpty) ? posterUrl : null,
          'playback': {
            'best_url': bestUrl,
            'poster_url': (posterUrl != null && posterUrl.isNotEmpty) ? posterUrl : null,
            'renditions': renditions,
          },
        };
      }

      debugPrint('[ChallengesProvider] fetchPlaybackForVideoAsset: RPC success but no usable best_url/manifest');
      return null;
    } catch (e) {
      debugPrint('[ChallengesProvider] fetchPlaybackForVideoAsset: exception=$e — RPC may not exist yet');
      return null;
    }
  }

  Future<String?> fetchPublicUrlForVideoAssetSource(String videoAssetId) async {
    debugPrint('[ChallengesProvider] fetchPublicUrlForVideoAssetSource: videoAssetId=$videoAssetId');
    _setError(null);
    try {
      final dynamic raw = await _client
          .schema('app')
          .from('video_sources')
          .select('storage_bucket, storage_path')
          .eq('video_asset_id', videoAssetId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      debugPrint('[ChallengesProvider] fetchPublicUrlForVideoAssetSource response type=${raw.runtimeType}');

      if (raw is! Map) {
        return null;
      }

      final map = Map<String, dynamic>.from(raw);
      final bucket = map['storage_bucket']?.toString() ?? '';
      final path = map['storage_path']?.toString() ?? '';

      if (bucket.isEmpty || path.isEmpty) {
        debugPrint('[ChallengesProvider] fetchPublicUrlForVideoAssetSource: missing bucket/path bucket=$bucket path=$path');
        return null;
      }

      final publicUrl = _client.storage.from(bucket).getPublicUrl(path);
      debugPrint('[ChallengesProvider] fetchPublicUrlForVideoAssetSource publicUrl=${publicUrl.isNotEmpty ? '${publicUrl.substring(0, publicUrl.length > 80 ? 80 : publicUrl.length)}...' : ''}');

      if (publicUrl.trim().isEmpty) {
        return null;
      }

      return publicUrl.trim();
    } catch (e) {
      debugPrint('[ChallengesProvider] fetchPublicUrlForVideoAssetSource error: $e');
      return null;
    }
  }

  /// Fallback: build a minimal playback manifest from the direct URL so the
  /// studio can still work even when the RPC is missing or fails.
  Map<String, dynamic> _buildFallbackPlayback(String directUrl) {
    debugPrint('[ChallengesProvider] _buildFallbackPlayback: using directUrl as best_url (NO video_asset_id)');
    return {
      'video_asset_id': null,
      'playback': {
        'best_url': directUrl,
        'renditions': [
          {'label': 'original', 'url': directUrl},
        ],
      },
    };
  }

  Future<String?> createFreeVideo({
    String? videoAssetId,
    required Map<String, dynamic> playback,
    String? title,
    String? description,
  }) async {
    debugPrint('[ChallengesProvider] createFreeVideo: videoAssetId=$videoAssetId, playback=$playback');
    _setSaving(true);
    _setError(null);
    try {
      final params = {
        'p_video_asset_id': videoAssetId,
        'p_playback': playback,
        'p_title': title,
        'p_description': description,
      };
      debugPrint('[ChallengesProvider] createFreeVideo RPC params=$params');
      final dynamic response = await _client.rpc(
        'app_student_create_free_video',
        params: params,
      );
      debugPrint('[ChallengesProvider] createFreeVideo RPC response type=${response.runtimeType}, response=$response');

      if (response is! Map<String, dynamic>) {
        debugPrint('[ChallengesProvider] createFreeVideo: response is NOT Map');
        _setError(
          'Réponse invalide du serveur lors de la création de la vidéo libre.',
        );
        return null;
      }

      if (response['success'] != true) {
        debugPrint('[ChallengesProvider] createFreeVideo: success!=true, error=${response['error']}');
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la création de la vidéo libre.',
        );
        return null;
      }

      final rawId = response['video_id'];
      debugPrint('[ChallengesProvider] createFreeVideo: video_id=$rawId (type=${rawId.runtimeType})');
      if (rawId is String && rawId.trim().isNotEmpty) {
        return rawId.trim();
      }

      debugPrint('[ChallengesProvider] createFreeVideo: video_id missing or empty');
      _setError(
        'Identifiant de vidéo libre manquant dans la réponse du serveur.',
      );
      return null;
    } catch (e, st) {
      debugPrint('[ChallengesProvider] createFreeVideo EXCEPTION: $e');
      debugPrint('[ChallengesProvider] createFreeVideo STACK: $st');
      _setError(e.toString());
      return null;
    } finally {
      _setSaving(false);
    }
  }

  Future<String?> uploadFreeVideo({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    debugPrint('[ChallengesProvider] uploadFreeVideo: fileName=$fileName, bytes=${bytes.length}');
    _setError(null);
    final user = _client.auth.currentUser;
    if (user == null) {
      _setError('Utilisateur non authentifié.');
      return null;
    }

    final sanitizedFileName =
        fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath = '${user.id}/free_videos/$sanitizedFileName';

    try {
      await _client.storage.from('challenge-media').uploadBinary(
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

    final publicUrl =
        _client.storage.from('challenge-media').getPublicUrl(storagePath);
    debugPrint('[ChallengesProvider] uploadFreeVideo: publicUrl=$publicUrl');
    return publicUrl;
  }

  /// Upload a thumbnail image to Storage and return its public URL.
  Future<String?> uploadThumbnail({
    required Uint8List bytes,
    required String videoFileName,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final sanitized = videoFileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final thumbName = 'thumb_$sanitized.jpg';
    final storagePath = '${user.id}/thumbnails/$thumbName';

    try {
      await _client.storage.from('challenge-media').uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
    } on StorageException catch (e) {
      final statusCode = e.statusCode?.toString() ?? '';
      if (statusCode != '409' && !e.message.toLowerCase().contains('already exists')) {
        debugPrint('[ChallengesProvider] uploadThumbnail error: $e');
        return null;
      }
    } catch (e) {
      debugPrint('[ChallengesProvider] uploadThumbnail error: $e');
      return null;
    }

    final publicUrl = _client.storage.from('challenge-media').getPublicUrl(storagePath);
    debugPrint('[ChallengesProvider] uploadThumbnail: $publicUrl');
    return publicUrl;
  }

  Future<void> loadChallenges({
    String? type,
    String? search,
    bool onlyJoined = false,
  }) async {
    debugPrint('[ChallengesProvider] loadChallenges: type=$type, search=$search, onlyJoined=$onlyJoined');
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_list_challenges',
        params: {
          'p_type': type,
          'p_search': search,
          'p_only_joined': onlyJoined,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors du chargement des challenges.');
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement des challenges.',
        );
        return;
      }
      final data = response['challenges'];
      if (data is List) {
        _challenges = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _challenges = [];
      }
      debugPrint('[ChallengesProvider] loadChallenges: loaded ${_challenges.length} challenges');
      notifyListeners();
    } catch (e) {
      debugPrint('[ChallengesProvider] loadChallenges: error=$e');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadChallengeVideos({
    String? challengeId,
    DateTime? cursor,
    int limit = 20,
    bool append = false,
  }) async {
    debugPrint('[ChallengesProvider] loadChallengeVideos: challengeId=$challengeId, limit=$limit, append=$append');
    _isLoadingVideos = true;
    notifyListeners();
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_unified_video_feed',
        params: {
          'p_cursor': cursor?.toIso8601String(),
          'p_limit': limit,
        },
      );
      debugPrint('[ChallengesProvider] loadChallengeVideos RAW response type=${response.runtimeType}');
      debugPrint('[ChallengesProvider] loadChallengeVideos RAW response=$response');
      if (response is! Map<String, dynamic>) {
        debugPrint('[ChallengesProvider] loadChallengeVideos: response is NOT Map, it is ${response.runtimeType}');
        _setError('Réponse invalide du serveur pour les vidéos de challenges.');
        return;
      }
      if (response['success'] != true) {
        debugPrint('[ChallengesProvider] loadChallengeVideos: success=${response['success']}, error=${response['error']}');
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement des vidéos de challenges.',
        );
        return;
      }
      final data = response['videos'];
      debugPrint('[ChallengesProvider] loadChallengeVideos: videos data type=${data.runtimeType}, length=${data is List ? data.length : "N/A"}');
      List<Map<String, dynamic>> newVideos;
      if (data is List) {
        newVideos = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        newVideos = [];
      }

      if (append && _videos.isNotEmpty) {
        _videos = [
          ..._videos,
          ...newVideos,
        ];
      } else {
        _videos = newVideos;
      }

      // Met à jour le cache par participation pour un accès direct (duos, détails...)
      for (final v in _videos) {
        final id = v['participation_id']?.toString();
        if (id != null && id.isNotEmpty) {
          _videoByParticipationId[id] = Map<String, dynamic>.from(v);
        }
      }

      debugPrint('[ChallengesProvider] loadChallengeVideos: loaded ${_videos.length} videos total');
      notifyListeners();
    } catch (e) {
      debugPrint('[ChallengesProvider] loadChallengeVideos: error=$e');
      _setError(e.toString());
    } finally {
      _isLoadingVideos = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> loadUserVideos(String userId) async {
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_list_user_videos',
        params: {'p_user_id': userId},
      );
      if (response is! Map<String, dynamic>) return const [];
      if (response['success'] != true) return const [];
      final data = response['videos'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }
      return const [];
    } catch (e) {
      debugPrint('[ChallengesProvider] loadUserVideos error: $e');
      return const [];
    }
  }

  void _updateVideoLikeState(
    String participationId, {
    required bool liked,
  }) {
    final index = _videos.indexWhere(
      (v) => v['participation_id']?.toString() == participationId,
    );
    if (index == -1) {
      return;
    }
    final current = Map<String, dynamic>.from(_videos[index]);
    final currentLikes = current['likes_count'] is int
        ? current['likes_count'] as int
        : 0;
    current['has_liked'] = liked;
    if (liked) {
      current['likes_count'] = currentLikes + 1;
    } else {
      current['likes_count'] = currentLikes > 0 ? currentLikes - 1 : 0;
    }

    _videos = [
      ..._videos.sublist(0, index),
      current,
      ..._videos.sublist(index + 1),
    ];
    notifyListeners();
  }

  void _updateGenericVideoFavoriteState(
    String videoType,
    String videoId, {
    required bool favorited,
  }) {
    final index = _videos.indexWhere(
      (v) =>
          (v['video_type']?.toString() ?? '') == videoType &&
          (v['video_id']?.toString() ?? '') == videoId,
    );
    if (index == -1) {
      return;
    }
    final current = Map<String, dynamic>.from(_videos[index]);
    final currentFavorites = current['favorites_count'] is int
        ? current['favorites_count'] as int
        : 0;
    current['has_favorited'] = favorited;
    if (favorited) {
      current['favorites_count'] = currentFavorites + 1;
    } else {
      current['favorites_count'] =
          currentFavorites > 0 ? currentFavorites - 1 : 0;
    }

    _videos = [
      ..._videos.sublist(0, index),
      current,
      ..._videos.sublist(index + 1),
    ];
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> loadVideoComments(
    String videoType,
    String videoId,
  ) async {
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_list_video_comments',
        params: {
          'p_video_type': videoType,
          'p_video_id': videoId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour les commentaires.');
        return const [];
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement des commentaires.',
        );
        return const [];
      }
      final data = response['comments'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }
      return const [];
    } catch (e) {
      _setError(e.toString());
      return const [];
    }
  }

  void _updateVideoFavoriteState(
    String participationId, {
    required bool favorited,
  }) {
    final index = _videos.indexWhere(
      (v) => v['participation_id']?.toString() == participationId,
    );
    if (index == -1) {
      return;
    }
    final current = Map<String, dynamic>.from(_videos[index]);
    final currentFavorites = current['favorites_count'] is int
        ? current['favorites_count'] as int
        : 0;
    current['has_favorited'] = favorited;
    if (favorited) {
      current['favorites_count'] = currentFavorites + 1;
    } else {
      current['favorites_count'] =
          currentFavorites > 0 ? currentFavorites - 1 : 0;
    }

    _videos = [
      ..._videos.sublist(0, index),
      current,
      ..._videos.sublist(index + 1),
    ];
    notifyListeners();
  }

  void _incrementVideoCommentsCount(String participationId) {
    final index = _videos.indexWhere(
      (v) => v['participation_id']?.toString() == participationId,
    );
    if (index == -1) {
      return;
    }
    final current = Map<String, dynamic>.from(_videos[index]);
    final currentComments = current['comments_count'] is int
        ? current['comments_count'] as int
        : 0;
    current['comments_count'] = currentComments + 1;

    _videos = [
      ..._videos.sublist(0, index),
      current,
      ..._videos.sublist(index + 1),
    ];
    notifyListeners();
  }

  void _updateGenericVideoLikeState(
    String videoType,
    String videoId, {
    required bool liked,
  }) {
    final index = _videos.indexWhere(
      (v) =>
          (v['video_type']?.toString() ?? '') == videoType &&
          (v['video_id']?.toString() ?? '') == videoId,
    );
    if (index == -1) {
      return;
    }
    final current = Map<String, dynamic>.from(_videos[index]);
    final currentLikes = current['likes_count'] is int
        ? current['likes_count'] as int
        : 0;
    current['has_liked'] = liked;
    if (liked) {
      current['likes_count'] = currentLikes + 1;
    } else {
      current['likes_count'] = currentLikes > 0 ? currentLikes - 1 : 0;
    }

    _videos = [
      ..._videos.sublist(0, index),
      current,
      ..._videos.sublist(index + 1),
    ];
    notifyListeners();
  }

  void _incrementGenericVideoCommentsCount(String videoType, String videoId) {
    final index = _videos.indexWhere(
      (v) =>
          (v['video_type']?.toString() ?? '') == videoType &&
          (v['video_id']?.toString() ?? '') == videoId,
    );
    if (index == -1) {
      return;
    }
    final current = Map<String, dynamic>.from(_videos[index]);
    final currentComments = current['comments_count'] is int
        ? current['comments_count'] as int
        : 0;
    current['comments_count'] = currentComments + 1;

    _videos = [
      ..._videos.sublist(0, index),
      current,
      ..._videos.sublist(index + 1),
    ];
    notifyListeners();
  }

  void _decrementGenericVideoCommentsCount(String videoType, String videoId) {
    final index = _videos.indexWhere(
      (v) =>
          (v['video_type']?.toString() ?? '') == videoType &&
          (v['video_id']?.toString() ?? '') == videoId,
    );
    if (index == -1) return;
    final current = Map<String, dynamic>.from(_videos[index]);
    final c = current['comments_count'] is int ? current['comments_count'] as int : 0;
    current['comments_count'] = c > 0 ? c - 1 : 0;
    _videos = [..._videos.sublist(0, index), current, ..._videos.sublist(index + 1)];
    notifyListeners();
  }

  void _decrementVideoCommentsCount(String participationId) {
    final index = _videos.indexWhere(
      (v) => v['participation_id']?.toString() == participationId,
    );
    if (index == -1) return;
    final current = Map<String, dynamic>.from(_videos[index]);
    final c = current['comments_count'] is int ? current['comments_count'] as int : 0;
    current['comments_count'] = c > 0 ? c - 1 : 0;
    _videos = [..._videos.sublist(0, index), current, ..._videos.sublist(index + 1)];
    notifyListeners();
  }

  Future<bool> likeVideo({
    required String videoType,
    required String videoId,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_video_like',
        params: {
          'p_video_type': videoType,
          'p_video_id': videoId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors du like de la vidéo.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du like de la vidéo.',
        );
        return false;
      }
      _updateGenericVideoLikeState(videoType, videoId, liked: true);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> updateFreeVideoOverlays({
    required String freeVideoId,
    required Map<String, dynamic> layers,
  }) async {
    debugPrint('[ChallengesProvider] updateFreeVideoOverlays: freeVideoId=$freeVideoId');
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_update_free_video_overlays',
        params: {
          'p_free_video_id': freeVideoId,
          'p_layers': layers,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la sauvegarde des overlays.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la sauvegarde des overlays vidéo.',
        );
        return false;
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> unlikeVideo({
    required String videoType,
    required String videoId,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_video_unlike',
        params: {
          'p_video_type': videoType,
          'p_video_id': videoId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors du retrait du like.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du retrait du like de la vidéo.',
        );
        return false;
      }
      _updateGenericVideoLikeState(videoType, videoId, liked: false);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> likeChallengeVideo({required String participationId}) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_like_challenge_video',
        params: {
          'p_participation_id': participationId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors du like de la vidéo.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du like de la vidéo de challenge.',
        );
        return false;
      }
      _updateVideoLikeState(participationId, liked: true);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> favoriteChallengeVideo({required String participationId}) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_favorite_challenge_video',
        params: {
          'p_participation_id': participationId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de l\'ajout du favori.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de l\'ajout du favori sur la vidéo de challenge.',
        );
        return false;
      }
      _updateVideoFavoriteState(participationId, favorited: true);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<Map<String, String>?> startDuoChallengeVideo({
    required String parentParticipationId,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_start_duo_challenge_video',
        params: {
          'p_parent_participation_id': parentParticipationId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la préparation du duo.');
        return null;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la préparation de la vidéo en duo.',
        );
        return null;
      }
      final participationId = response['participation_id']?.toString() ?? '';
      final challengeId = response['challenge_id']?.toString() ?? '';
      if (participationId.isEmpty || challengeId.isEmpty) {
        _setError('Réponse incomplète du serveur pour la vidéo en duo.');
        return null;
      }
      return {
        'participation_id': participationId,
        'challenge_id': challengeId,
      };
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setSaving(false);
    }
  }

  Future<Map<String, dynamic>?> getChallengeVideoById(String participationId) async {
    final cached = _videoByParticipationId[participationId];
    if (cached != null) {
      return Map<String, dynamic>.from(cached);
    }

    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_get_challenge_video',
        params: {
          'p_participation_id': participationId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour la vidéo de challenge.');
        return null;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement de la vidéo de challenge.',
        );
        return null;
      }
      final video = response['video'];
      if (video is Map<String, dynamic>) {
        final normalized = Map<String, dynamic>.from(video);
        final id = normalized['participation_id']?.toString();
        if (id != null && id.isNotEmpty) {
          _videoByParticipationId[id] = normalized;
        }
        return normalized;
      }
      return null;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  Future<bool> updateFreeVideoMainRenditions({
    required String freeVideoId,
    String? videoAssetId,
    required Map<String, dynamic> playback,
  }) async {
    debugPrint('[ChallengesProvider] updateFreeVideoMainRenditions: freeVideoId=$freeVideoId, videoAssetId=$videoAssetId');
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_set_free_video_main_renditions',
        params: {
          'p_free_video_id': freeVideoId,
          'p_video_asset_id': videoAssetId,
          'p_playback': playback,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la mise à jour de la vidéo libre.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la mise à jour de la vidéo libre.',
        );
        return false;
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<Map<String, dynamic>?> getFreeVideoById(String freeVideoId) async {
    final cached = _freeVideoById[freeVideoId];
    if (cached != null) {
      return Map<String, dynamic>.from(cached);
    }

    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_get_free_video',
        params: {
          'p_free_video_id': freeVideoId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour la vidéo libre.');
        return null;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement de la vidéo libre.',
        );
        return null;
      }
      final video = response['video'];
      if (video is Map<String, dynamic>) {
        final normalized = Map<String, dynamic>.from(video);
        final id = normalized['free_video_id']?.toString();
        if (id != null && id.isNotEmpty) {
          _freeVideoById[id] = normalized;
        }
        return normalized;
      }
      return null;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  Future<bool> unlikeChallengeVideo({required String participationId}) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_unlike_challenge_video',
        params: {
          'p_participation_id': participationId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors du retrait du like.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du retrait du like de la vidéo de challenge.',
        );
        return false;
      }
      _updateVideoLikeState(participationId, liked: false);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> unfavoriteChallengeVideo({required String participationId}) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_unfavorite_challenge_video',
        params: {
          'p_participation_id': participationId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors du retrait du favori.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du retrait du favori de la vidéo de challenge.',
        );
        return false;
      }
      _updateVideoFavoriteState(participationId, favorited: false);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<List<Map<String, dynamic>>> loadChallengeVideoComments(
    String participationId,
  ) async {
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_list_challenge_comments',
        params: {
          'p_participation_id': participationId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour les commentaires.');
        return const [];
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement des commentaires.',
        );
        return const [];
      }
      final data = response['comments'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }
      return const [];
    } catch (e) {
      _setError(e.toString());
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> listFreeVideoRenderJobs(
    String freeVideoId,
  ) async {
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_list_free_video_render_jobs',
        params: {
          'p_free_video_id': freeVideoId,
        },
      );

      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur pour les jobs de rendu audio/vidéo.',
        );
        return const [];
      }

      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement des jobs de rendu audio/vidéo.',
        );
        return const [];
      }

      final data = response['jobs'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }

      return const [];
    } catch (e) {
      _setError(e.toString());
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> listChallengeVideoRenderJobs(
    String participationId,
  ) async {
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_list_challenge_video_render_jobs',
        params: {
          'p_participation_id': participationId,
        },
      );

      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur pour les jobs de rendu audio/vidéo.',
        );
        return const [];
      }

      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement des jobs de rendu audio/vidéo.',
        );
        return const [];
      }

      final data = response['jobs'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }

      return const [];
    } catch (e) {
      _setError(e.toString());
      return const [];
    }
  }

  Future<bool> addChallengeVideoComment({
    required String participationId,
    required String content,
  }) async {
    final text = content.trim();
    if (text.isEmpty) {
      _setError('Le commentaire est vide.');
      return false;
    }

    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_add_challenge_comment',
        params: {
          'p_participation_id': participationId,
          'p_content': text,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de l\'ajout du commentaire.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de l\'ajout du commentaire.',
        );
        return false;
      }
      _incrementVideoCommentsCount(participationId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> reportChallengeVideo({
    required String participationId,
    required String reason,
    String? details,
  }) async {
    final r = reason.trim();
    if (r.isEmpty) {
      _setError('Le motif du signalement est vide.');
      return false;
    }

    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_report_challenge_video',
        params: {
          'p_participation_id': participationId,
          'p_reason': r,
          'p_details': details?.trim(),
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors du signalement de la vidéo.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du signalement de la vidéo.',
        );
        return false;
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }
  Future<List<Map<String, dynamic>>> listMyChallengeVideos(
    String participationId,
  ) async {
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_list_my_challenge_videos',
        params: {
          'p_participation_id': participationId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur pour les vidéos de ce challenge.',
        );
        return const [];
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement des vidéos de ce challenge.',
        );
        return const [];
      }
      final data = response['videos'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }
      return const [];
    } catch (e) {
      _setError(e.toString());
      return const [];
    }
  }

  Future<bool> updateChallengeVideoOverlays({
    required String participationId,
    required Map<String, dynamic> layers,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_update_challenge_video_overlays',
        params: {
          'p_participation_id': participationId,
          'p_layers': layers,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la sauvegarde des overlays.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la sauvegarde des overlays vidéo.',
        );
        return false;
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<void> loadMyParticipations() async {
    debugPrint('[ChallengesProvider] loadMyParticipations');
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_list_my_challenge_participations',
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors du chargement de mes participations aux challenges.',
        );
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement de mes participations aux challenges.',
        );
        return;
      }
      final data = response['participations'];
      if (data is List) {
        _participations = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _participations = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadStats() async {
    debugPrint('[ChallengesProvider] loadStats');
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_get_my_challenge_stats',
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour les statistiques de challenges.');
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement des statistiques de challenges.',
        );
        return;
      }
      final stats = response['stats'];
      if (stats is Map<String, dynamic>) {
        _stats = Map<String, dynamic>.from(stats);
      } else {
        _stats = null;
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> joinChallenge({required String challengeId}) async {
    debugPrint('[ChallengesProvider] joinChallenge: challengeId=$challengeId');
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_join_challenge',
        params: {
          'p_challenge_id': challengeId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la participation au challenge.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la participation au challenge.',
        );
        return false;
      }
      await Future.wait([
        loadChallenges(),
        loadMyParticipations(),
        loadStats(),
      ]);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> submitChallenge({
    required String participationId,
    String? submissionText,
    String? submissionUrl,
  }) async {
    debugPrint('[ChallengesProvider] submitChallenge: participationId=$participationId');
    final text = submissionText?.trim() ?? '';
    final url = submissionUrl?.trim() ?? '';
    if (text.isEmpty && url.isEmpty) {
      _setError('La soumission est vide. Ajoute un texte ou un lien.');
      return false;
    }

    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_submit_challenge',
        params: {
          'p_participation_id': participationId,
          'p_submission_text': text.isEmpty ? null : text,
          'p_submission_url': url.isEmpty ? null : url,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la soumission du challenge.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la soumission du challenge.',
        );
        return false;
      }
      await Future.wait([
        loadChallenges(),
        loadMyParticipations(),
        loadStats(),
      ]);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> markChallengeCompleted({
    required String participationId,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_mark_challenge_completed',
        params: {
          'p_participation_id': participationId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la complétion du challenge.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la complétion du challenge.',
        );
        return false;
      }
      await Future.wait([
        loadChallenges(),
        loadMyParticipations(),
        loadStats(),
      ]);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<void> loadLeaderboard(String challengeId) async {
    debugPrint('[ChallengesProvider] loadLeaderboard: challengeId=$challengeId');
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_public_get_challenge_leaderboard',
        params: {
          'p_challenge_id': challengeId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour le classement du challenge.');
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement du classement du challenge.',
        );
        return;
      }
      final data = response['leaderboard'];
      if (data is List) {
        _leaderboard = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _leaderboard = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
}
