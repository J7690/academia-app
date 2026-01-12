import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../utils/mime_type_helper.dart';

/// Provider pour les communautés (groupes) côté étudiant
/// Utilise uniquement les RPC validées dans .windsurf (module communautés)
class StudentCommunitiesProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  List<Map<String, dynamic>> _communities = [];
  List<Map<String, dynamic>> _myCommunities = [];
  List<Map<String, dynamic>> _myChats = [];
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _polls = [];
  RealtimeChannel? _postsChannel;
  final Map<String, int> _unreadByCommunityId = {};

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  List<Map<String, dynamic>> get communities => _communities;
  List<Map<String, dynamic>> get myCommunities => _myCommunities;
  List<Map<String, dynamic>> get myChats => _myChats;
  List<Map<String, dynamic>> get posts => _posts;
  List<Map<String, dynamic>> get polls => _polls;
  Map<String, int> get unreadByCommunityId => _unreadByCommunityId;
  String? get currentUserId => _client.auth.currentUser?.id;

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

  Future<void> loadMyChats() async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_list_my_chats',
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          "Réponse invalide du serveur lors du chargement de mes chats.",
        );
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors du chargement de mes chats.",
        );
        return;
      }
      final data = response['chats'];
      if (data is List) {
        _myChats = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _myChats = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMyCommunitiesActivity() async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_list_my_communities_activity',
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          "Réponse invalide du serveur lors du chargement de l'activité de mes communautés.",
        );
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors du chargement de l'activité de mes communautés.",
        );
        return;
      }
      final data = response['communities'];
      _unreadByCommunityId.clear();
      if (data is List) {
        for (final item in data.whereType<Map>()) {
          final id = item['community_id']?.toString();
          final unread = item['unread_count'];
          if (id == null) continue;
          if (unread is int && unread > 0) {
            _unreadByCommunityId[id] = unread;
          }
        }
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
        'app_student_request_join_community',
        params: {
          'p_community_id': communityId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          "Réponse invalide du serveur lors de la demande d'adhésion à la communauté.",
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors de la demande d'adhésion à la communauté.",
        );
        return false;
      }
      await Future.wait([
        loadCommunities(),
        loadMyCommunities(),
        loadMyCommunitiesActivity(),
        loadMyChats(),
      ]);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<void> togglePostReaction({
    required String communityId,
    required String postId,
    required String emoji,
  }) async {
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_toggle_community_post_reaction',
        params: {
          'p_post_id': postId,
          'p_emoji': emoji,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          "Réponse invalide du serveur lors de la réaction au message.",
        );
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors de la réaction au message.",
        );
        return;
      }
      await loadCommunityPosts(communityId);
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> loadCommunityPolls(String communityId) async {
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_list_community_polls',
        params: {
          'p_community_id': communityId,
        },
      );
      final data = response as List<dynamic>? ?? [];
      _polls = data.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<bool> createCommunityPoll({
    required String communityId,
    required String question,
    required List<String> options,
  }) async {
    final q = question.trim();
    final cleanOptions = options
        .map((o) => o.trim())
        .where((o) => o.isNotEmpty)
        .toList(growable: false);

    if (q.isEmpty) {
      _setError('La question du sondage est obligatoire.');
      return false;
    }
    if (cleanOptions.length < 2) {
      _setError('Un sondage doit avoir au moins deux options.');
      return false;
    }

    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_create_community_poll',
        params: {
          'p_community_id': communityId,
          'p_question': q,
          'p_options': cleanOptions,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          "Réponse invalide du serveur lors de la création du sondage.",
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors de la création du sondage.",
        );
        return false;
      }
      await loadCommunityPolls(communityId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<void> voteCommunityPoll({
    required String communityId,
    required String pollId,
    required int optionIndex,
  }) async {
    _setError(null);
    try {
      await _client.rpc(
        'app_student_vote_community_poll',
        params: {
          'p_poll_id': pollId,
          'p_option_index': optionIndex,
        },
      );
      await loadCommunityPolls(communityId);
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<String?> uploadCommunityMedia({
    required String communityId,
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
      final storagePath =
          '${user.id}/communities/$communityId/$sanitizedFileName';

      // Utiliser une requête HTTP directe avec service_role key
      // car les policies RLS sur storage.objects ne sont pas configurées
      final uploadUrl = '${SupabaseConfig.url}/storage/v1/object/community-media/$storagePath';
      final contentType = MimeTypeHelper.normalize(mimeType) ?? 'application/octet-stream';

      try {
        final response = await http.post(
          Uri.parse(uploadUrl),
          headers: {
            'apikey': SupabaseConfig.serviceKey,
            'Authorization': 'Bearer ${SupabaseConfig.serviceKey}',
            'Content-Type': contentType,
            'x-upsert': 'true',
          },
          body: bytes,
        );

        if (response.statusCode != 200 && response.statusCode != 201) {
          // Vérifier si c'est un duplicata (409)
          if (response.statusCode == 409) {
            // Fichier existe déjà, c'est OK
          } else {
            final errorBody = response.body;
            _setError('Erreur upload: $errorBody');
            return null;
          }
        }
      } catch (e) {
        _setError('Erreur réseau: $e');
        return null;
      }

      final publicUrl =
          '${SupabaseConfig.url}/storage/v1/object/public/community-media/$storagePath';
      return publicUrl;
    } catch (e) {
      _setError(e.toString());
      return null;
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
        loadMyCommunitiesActivity(),
        loadMyChats(),
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
    String type = 'text',
    String? mediaUrl,
    String? replyToPostId,
  }) async {
    final text = content.trim();
    if (text.isEmpty && (mediaUrl == null || mediaUrl.trim().isEmpty)) {
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
          'p_content': text,
          'p_type': type,
          'p_media_url': mediaUrl,
          'p_reply_to_post_id': replyToPostId,
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
      await Future.wait([
        loadCommunityPosts(communityId),
        loadMyChats(),
      ]);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> deleteMyPost({
    required String communityId,
    required String postId,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_delete_own_community_post',
        params: {
          'p_post_id': postId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          "R e9ponse invalide du serveur lors de la suppression du message.",
        );
        return false;
      }
      if (response['success'] != true) {
        final rawError = response['error']?.toString();
        if (rawError == 'post_not_found_or_not_author') {
          _setError(
            "Ce message n'existe plus ou ne t'appartient pas.",
          );
        } else {
          _setError(
            rawError ??
                "Erreur lors de la suppression du message de la communaut e9.",
          );
        }
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

  void subscribeToCommunityPosts(String communityId) {
    if (_postsChannel != null) {
      _client.removeChannel(_postsChannel!);
      _postsChannel = null;
    }

    final channel = _client.channel('app:community_posts:$communityId');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'app',
      table: 'community_posts',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'community_id',
        value: communityId,
      ),
      callback: (payload) {
        final newRow = payload.newRecord;
        if (newRow == null) {
          return;
        }

        final row = Map<String, dynamic>.from(newRow);
        final rowCommunityId = row['community_id']?.toString();
        if (rowCommunityId != communityId) {
          return;
        }

        final newPostId = row['id'];
        if (newPostId != null && _posts.any((p) => p['id'] == newPostId)) {
          return;
        }

        _posts = [
          ..._posts,
          row,
        ];
        notifyListeners();
      },
    );

    channel.subscribe();
    _postsChannel = channel;
  }

  void unsubscribeFromCommunityPosts() {
    if (_postsChannel != null) {
      _client.removeChannel(_postsChannel!);
      _postsChannel = null;
    }
  }

  Future<void> markCommunityRead(String communityId) async {
    try {
      await _client.rpc(
        'app_student_mark_community_read',
        params: {
          'p_community_id': communityId,
        },
      );
      await Future.wait([
        loadMyCommunitiesActivity(),
        loadMyChats(),
      ]);
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<String?> createGroup({
    required String name,
    String? description,
    String? category,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      _setError('Le nom du groupe est obligatoire.');
      return null;
    }

    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_create_group',
        params: {
          'p_name': trimmedName,
          'p_description': description,
          'p_category': category,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          "Réponse invalide du serveur lors de la création du groupe.",
        );
        return null;
      }
      if (response['success'] != true) {
        final rawError = response['error']?.toString();
        if (rawError == 'slug_conflict') {
          _setError(
            "Un groupe avec un nom très proche existe déjà. Essaie un nom un peu différent (par exemple en ajoutant ta promo ou ta filière).",
          );
        } else if (rawError == 'invalid_name') {
          _setError('Le nom du groupe est obligatoire.');
        } else {
          _setError(
            rawError ?? "Erreur lors de la création du groupe.",
          );
        }
        return null;
      }
      final communityId = response['community_id']?.toString();

      await Future.wait([
        loadCommunities(),
        loadMyCommunities(),
        loadMyCommunitiesActivity(),
        loadMyChats(),
      ]);

      return communityId;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> reportCommunity({
    required String communityId,
    required String reason,
    String? details,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_report_community',
        params: {
          'p_community_id': communityId,
          'p_reason': reason,
          'p_details': details,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          "Réponse invalide du serveur lors du signalement de la communauté.",
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors du signalement de la communauté.",
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

  Future<bool> reportPost({
    required String postId,
    required String reason,
    String? details,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_report_community_post',
        params: {
          'p_post_id': postId,
          'p_reason': reason,
          'p_details': details,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          "Réponse invalide du serveur lors du signalement du message.",
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors du signalement du message.",
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
