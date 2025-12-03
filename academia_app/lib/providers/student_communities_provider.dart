import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour les communautés (groupes) côté étudiant
/// Utilise uniquement les RPC validées dans .windsurf (module communautés)
class StudentCommunitiesProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  List<Map<String, dynamic>> _communities = [];
  List<Map<String, dynamic>> _myCommunities = [];
  List<Map<String, dynamic>> _posts = [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  List<Map<String, dynamic>> get communities => _communities;
  List<Map<String, dynamic>> get myCommunities => _myCommunities;
  List<Map<String, dynamic>> get posts => _posts;

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

  Future<void> loadCommunities({String? search, String? category}) async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_list_communities',
        params: {
          'p_search': search,
          'p_category': category,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          "Réponse invalide du serveur lors du chargement des communautés.",
        );
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

  Future<void> loadMyCommunities() async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_list_my_communities',
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          "Réponse invalide du serveur lors du chargement de mes communautés.",
        );
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors du chargement de mes communautés.",
        );
        return;
      }
      final data = response['communities'];
      if (data is List) {
        _myCommunities = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _myCommunities = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> joinCommunity({required String communityId}) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_join_community',
        params: {
          'p_community_id': communityId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          "Réponse invalide du serveur lors de l'adhésion à la communauté.",
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors de l'adhésion à la communauté.",
        );
        return false;
      }
      await Future.wait([
        loadCommunities(),
        loadMyCommunities(),
      ]);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> leaveCommunity({required String communityId}) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_leave_community',
        params: {
          'p_community_id': communityId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          "Réponse invalide du serveur lors de la sortie de la communauté.",
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors de la sortie de la communauté.",
        );
        return false;
      }
      await Future.wait([
        loadCommunities(),
        loadMyCommunities(),
      ]);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<void> loadCommunityPosts(String communityId) async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_list_community_posts',
        params: {
          'p_community_id': communityId,
        },
      );
      final data = response as List<dynamic>? ?? [];
      _posts = data.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addPost({
    required String communityId,
    required String content,
  }) async {
    if (content.trim().isEmpty) {
      _setError('Le message est vide.');
      return false;
    }

    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_add_community_post',
        params: {
          'p_community_id': communityId,
          'p_content': content.trim(),
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          "Réponse invalide du serveur lors de l'envoi du message.",
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors de l'envoi du message à la communauté.",
        );
        return false;
      }
      await loadCommunityPosts(communityId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }
}
