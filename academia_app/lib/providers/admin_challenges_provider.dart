import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminChallengesProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  List<Map<String, dynamic>> _challenges = [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  List<Map<String, dynamic>> get challenges => List.unmodifiable(_challenges);

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

  Future<void> loadChallenges() async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc('app_admin_list_challenges');
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour les challenges.');
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

  Future<bool> upsertChallenge({
    String? challengeId,
    String? slug,
    required String title,
    String? description,
    String? challengeType,
    String? difficulty,
    int? points,
    DateTime? startAt,
    DateTime? endAt,
    int? maxParticipants,
    bool? requiresSubmission,
    bool? requiresAdminReview,
    bool? isActive,
    bool? isFeatured,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_upsert_challenge',
        params: {
          'p_challenge_id': challengeId,
          'p_slug': slug,
          'p_title': title,
          'p_description': description,
          'p_challenge_type': challengeType,
          'p_difficulty': difficulty,
          'p_points': points,
          'p_start_at': startAt,
          'p_end_at': endAt,
          'p_max_participants': maxParticipants,
          'p_requires_submission': requiresSubmission,
          'p_requires_admin_review': requiresAdminReview,
          'p_is_active': isActive,
          'p_is_featured': isFeatured,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la sauvegarde du challenge.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la sauvegarde du challenge.',
        );
        return false;
      }
      await loadChallenges();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> updateChallengeStatus({
    required String challengeId,
    bool? isActive,
    bool? isFeatured,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_update_challenge_status',
        params: {
          'p_challenge_id': challengeId,
          'p_is_active': isActive,
          'p_is_featured': isFeatured,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la mise à jour du challenge.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la mise à jour du challenge.',
        );
        return false;
      }
      await loadChallenges();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<List<Map<String, dynamic>>> loadParticipations(String challengeId) async {
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_list_challenge_participations',
        params: {
          'p_challenge_id': challengeId,
        },
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ??
                  'Erreur lors du chargement des participations au challenge.'
              : 'Erreur lors du chargement des participations au challenge.',
        );
        return const [];
      }
      final data = response['participations'];
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

  Future<List<Map<String, dynamic>>> loadParticipationExtraVideos({
    String? challengeId,
    String? participationId,
  }) async {
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_list_challenge_participation_videos',
        params: {
          'p_challenge_id': challengeId,
          'p_participation_id': participationId,
        },
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ??
                  'Erreur lors du chargement des vidéos supplémentaires de participation.'
              : 'Erreur lors du chargement des vidéos supplémentaires de participation.',
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

  Future<bool> deleteParticipationExtraVideo({
    required String videoId,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_delete_challenge_participation_video',
        params: {
          'p_video_id': videoId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la suppression de la vidéo supplémentaire.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la suppression de la vidéo supplémentaire.',
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

  Future<bool> reviewParticipation({
    required String participationId,
    required String status,
    int? score,
    int? rank,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_review_challenge_participation',
        params: {
          'p_participation_id': participationId,
          'p_status': status,
          'p_score': score,
          'p_rank': rank,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la revue de la participation.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la revue de la participation.',
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

  Future<List<Map<String, dynamic>>> loadLeaderboard(String challengeId) async {
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_public_get_challenge_leaderboard',
        params: {
          'p_challenge_id': challengeId,
        },
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ??
                  'Erreur lors du chargement du classement du challenge.'
              : 'Erreur lors du chargement du classement du challenge.',
        );
        return const [];
      }
      final data = response['leaderboard'];
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

  Future<List<Map<String, dynamic>>> loadChallengeVideos({
    String? challengeId,
    String? moderationStatus,
    bool? hasPendingReports,
  }) async {
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_list_challenge_videos',
        params: {
          'p_challenge_id': challengeId,
          'p_moderation_status': moderationStatus,
          'p_has_pending_reports': hasPendingReports,
        },
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ??
                  'Erreur lors du chargement des vidéos de challenges.'
              : 'Erreur lors du chargement des vidéos de challenges.',
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

  Future<bool> reviewChallengeVideo({
    required String participationId,
    required String moderationStatus,
    String? reason,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_review_challenge_video',
        params: {
          'p_participation_id': participationId,
          'p_moderation_status': moderationStatus,
          'p_reason': reason,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la revue de la vidéo de challenge.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la revue de la vidéo de challenge.',
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

  Future<bool> deleteChallengeVideo({
    required String participationId,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_delete_challenge_video',
        params: {
          'p_participation_id': participationId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la suppression de la vidéo de challenge.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la suppression de la vidéo de challenge.',
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

  Future<bool> banUserFromChallenges({
    required String userId,
    required String reason,
    DateTime? bannedUntil,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_ban_user_from_challenges',
        params: {
          'p_user_id': userId,
          'p_reason': reason,
          'p_banned_until': bannedUntil,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors du bannissement de l\'utilisateur des challenges.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du bannissement de l\'utilisateur des challenges.',
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

  Future<List<Map<String, dynamic>>> loadChallengeReports({
    String? status,
  }) async {
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_list_challenge_reports',
        params: {
          'p_status': status,
        },
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ??
                  'Erreur lors du chargement des signalements de challenges.'
              : 'Erreur lors du chargement des signalements de challenges.',
        );
        return const [];
      }
      final data = response['reports'];
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

  Future<bool> updateChallengeReportStatus({
    required String reportId,
    required String status,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_update_challenge_report_status',
        params: {
          'p_report_id': reportId,
          'p_status': status,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la mise à jour du signalement.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la mise à jour du signalement.',
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

  Future<List<Map<String, dynamic>>> loadChallengeVideoAssets() async {
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_list_challenge_video_assets',
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ??
                  'Erreur lors du chargement des assets vidéo de challenges.'
              : 'Erreur lors du chargement des assets vidéo de challenges.',
        );
        return const [];
      }
      final data = response['assets'];
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

  Future<bool> upsertChallengeVideoAsset({
    String? assetId,
    required String category,
    required String label,
    required String assetUrl,
    bool? isActive,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_upsert_challenge_video_asset',
        params: {
          'p_asset_id': assetId,
          'p_category': category,
          'p_label': label,
          'p_asset_url': assetUrl,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la sauvegarde de l\'asset vidéo.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la sauvegarde de l\'asset vidéo.',
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

  Future<bool> deleteChallengeVideoAsset({
    required String assetId,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_delete_challenge_video_asset',
        params: {
          'p_asset_id': assetId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la suppression de l\'asset vidéo.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la suppression de l\'asset vidéo.',
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
}
