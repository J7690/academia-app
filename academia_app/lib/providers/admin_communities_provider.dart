import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminCommunitiesProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  List<Map<String, dynamic>> _communities = [];
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _moderationEvents = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _joinRequests = [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  List<Map<String, dynamic>> get communities => List.unmodifiable(_communities);
  List<Map<String, dynamic>> get posts => List.unmodifiable(_posts);
  List<Map<String, dynamic>> get moderationEvents =>
      List.unmodifiable(_moderationEvents);
  List<Map<String, dynamic>> get members => List.unmodifiable(_members);
  List<Map<String, dynamic>> get joinRequests => List.unmodifiable(_joinRequests);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> loadMembers(String communityId) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_list_community_members',
        params: {
          'p_community_id': communityId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur pour les membres de la communauté.',
        );
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors du chargement des membres de la communauté.",
        );
        return;
      }
      final data = response['members'];
      if (data is List) {
        _members = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _members = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadJoinRequests(String communityId) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_list_community_join_requests',
        params: {
          'p_community_id': communityId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur pour les demandes d\'adhésion.',
        );
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors du chargement des demandes d'adhésion.",
        );
        return;
      }
      final data = response['requests'];
      if (data is List) {
        _joinRequests = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _joinRequests = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
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

  Future<void> loadCommunities() async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc('app_admin_list_communities');
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour les communautés.');
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors du chargement des communautés.",
        );
        return;
      }
      final data = response['communities'];
      if (data is List) {
        _communities = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _communities = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadModerationEvents(String communityId) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_list_community_moderation_events',
        params: {
          'p_community_id': communityId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur pour les événements de modération.',
        );
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors du chargement des événements de modération.",
        );
        return;
      }
      final data = response['events'];
      if (data is List) {
        _moderationEvents = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _moderationEvents = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> upsertCommunity({
    String? communityId,
    String? slug,
    required String name,
    String? description,
    String? category,
    String? visibility,
    bool? isActive,
    bool? isFeatured,
    String? kind,
    String? status,
    String? moderationState,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_upsert_community',
        params: {
          'p_community_id': communityId,
          'p_slug': slug,
          'p_name': name,
          'p_description': description,
          'p_category': category,
          'p_visibility': visibility,
          'p_is_active': isActive,
          'p_is_featured': isFeatured,
          'p_kind': kind,
          'p_status': status,
          'p_moderation_state': moderationState,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la sauvegarde de la communauté.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors de la sauvegarde de la communauté.",
        );
        return false;
      }
      await loadCommunities();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> handleJoinRequest({
    required String communityId,
    required String requestId,
    required String action,
    String role = 'member',
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_handle_community_join_request',
        params: {
          'p_request_id': requestId,
          'p_action': action,
          'p_role': role,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors du traitement de la demande d\'adhésion.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors du traitement de la demande d'adhésion.",
        );
        return false;
      }
      await Future.wait([
        loadJoinRequests(communityId),
        loadMembers(communityId),
        loadCommunities(),
      ]);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> pinPost({
    required String postId,
    required bool isPinned,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_pin_community_post',
        params: {
          'p_post_id': postId,
          'p_is_pinned': isPinned,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors du changement d\'état épinglé.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors du changement d'état épinglé.",
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

  Future<bool> updateCommunityStatus({
    required String communityId,
    bool? isActive,
    bool? isFeatured,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_update_community_status',
        params: {
          'p_community_id': communityId,
          'p_is_active': isActive,
          'p_is_featured': isFeatured,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la mise à jour de la communauté.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors de la mise à jour de la communauté.",
        );
        return false;
      }
      await loadCommunities();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> deleteCommunity({
    required String communityId,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_delete_community',
        params: {
          'p_community_id': communityId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la suppression de la communauté.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la suppression de la communauté.',
        );
        return false;
      }
      await loadCommunities();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<void> loadPosts(String communityId) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_list_community_posts',
        params: {
          'p_community_id': communityId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour les messages de la communauté.');
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors du chargement des messages de la communauté.",
        );
        return;
      }
      final data = response['posts'];
      if (data is List) {
        _posts = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _posts = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deletePost(String postId) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_delete_community_post',
        params: {
          'p_post_id': postId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la suppression du message.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors de la suppression du message de communauté.",
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

  Future<bool> banUser({
    required String communityId,
    required String userId,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_ban_user_from_community',
        params: {
          'p_community_id': communityId,
          'p_user_id': userId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors du bannissement de l\'utilisateur.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors du bannissement de l\'utilisateur de la communauté.",
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

  Future<bool> resolveModerationEvent({
    required String eventId,
    required String resolution,
    String? newModerationState,
    String? newStatus,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_resolve_moderation_event',
        params: {
          'p_event_id': eventId,
          'p_resolution': resolution,
          'p_new_moderation_state': newModerationState,
          'p_new_status': newStatus,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la résolution de l\'événement.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors de la résolution de l\'événement de modération.",
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
