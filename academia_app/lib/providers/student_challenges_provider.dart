import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/mime_type_helper.dart';

/// Provider pour la gestion des challenges côté étudiant
/// Utilise uniquement les RPC validées dans .windsurf (module challenges)
class StudentChallengesProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
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
    return publicUrl;
  }

  Future<String?> createFreeVideo({
    required String videoUrl,
    Map<String, dynamic>? videoRenditions,
    String? thumbnailUrl,
    String? title,
    String? description,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_create_free_video',
        params: {
          'p_video_url': videoUrl,
          'p_video_renditions': videoRenditions,
          'p_thumbnail_url': thumbnailUrl,
          'p_title': title,
          'p_description': description,
        },
      );

      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la création de la vidéo libre.',
        );
        return null;
      }

      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la création de la vidéo libre.',
        );
        return null;
      }

      final rawId = response['video_id'];
      if (rawId is String && rawId.trim().isNotEmpty) {
        return rawId.trim();
      }

      _setError(
        'Identifiant de vidéo libre manquant dans la réponse du serveur.',
      );
      return null;
    } catch (e) {
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
    return publicUrl;
  }

  Future<void> loadChallenges({
    String? type,
    String? search,
    bool onlyJoined = false,
  }) async {
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
      notifyListeners();
    } catch (e) {
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
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_unified_video_feed',
        params: {
          'p_cursor': cursor?.toIso8601String(),
          'p_limit': limit,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour les vidéos de challenges.');
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement des vidéos de challenges.',
        );
        return;
      }
      final data = response['videos'];
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

      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
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
    required String videoUrl,
    Map<String, dynamic>? videoRenditions,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_set_free_video_main_renditions',
        params: {
          'p_free_video_id': freeVideoId,
          'p_video_url': videoUrl,
          'p_video_renditions': videoRenditions,
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

  Future<bool> addChallengeVideo({
    required String participationId,
    required String videoUrl,
    String? thumbnailUrl,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_add_challenge_video',
        params: {
          'p_participation_id': participationId,
          'p_video_url': videoUrl,
          'p_thumbnail_url': thumbnailUrl,
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
