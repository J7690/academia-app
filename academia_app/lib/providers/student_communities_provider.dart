import 'dart:async';
import 'dart:convert' as json;

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
  RealtimeChannel? _presenceChannel;
  final Map<String, int> _unreadByCommunityId = {};
  List<Map<String, dynamic>> _typingUsers = [];
  Timer? _typingDebounce;
  Map<String, int> _postReadCounts = {};

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
  List<Map<String, dynamic>> get typingUsers => _typingUsers;
  Map<String, int> get postReadCounts => _postReadCounts;

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

      final contentType = MimeTypeHelper.normalize(mimeType) ?? 'application/octet-stream';
      final accessToken = _client.auth.currentSession?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        _setError('Session expirée. Reconnecte-toi.');
        return null;
      }

      // Upload via Edge Function proxy (bypass RLS avec service_role)
      final edgeFnUrl =
          '${SupabaseConfig.url}/functions/v1/setup-storage-policies';

      try {
        final response = await http.post(
          Uri.parse(edgeFnUrl),
          headers: {
            'apikey': SupabaseConfig.anonKey,
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/octet-stream',
            'x-file-path': storagePath,
            'x-content-type': contentType,
          },
          body: bytes,
        );

        debugPrint('[uploadCommunityMedia] Edge Fn → ${response.statusCode}');
        if (response.statusCode == 200 || response.statusCode == 201) {
          // Extraire l'URL publique de la réponse JSON
          try {
            final decoded = json.jsonDecode(response.body);
            if (decoded is Map) {
              final url = decoded['url']?.toString();
              if (url != null && url.isNotEmpty) return url;
            }
          } catch (_) {}
          // Fallback: construire l'URL manuellement
          return '${SupabaseConfig.url}/storage/v1/object/public/community-media/$storagePath';
        } else {
          final errorBody = response.body;
          debugPrint('[uploadCommunityMedia] ERROR ${response.statusCode}: $errorBody');
          _setError('Erreur upload (${response.statusCode}): $errorBody');
          return null;
        }
      } catch (e) {
        debugPrint('[uploadCommunityMedia] Network error: $e');
        _setError('Erreur réseau: $e');
        return null;
      }
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
      // Send push notifications for @mentions
      final postId = response['post_id']?.toString();
      if (text.contains('@[') && postId != null) {
        try {
          await _client.rpc(
            'app_notify_community_mention',
            params: {
              'p_community_id': communityId,
              'p_post_id': postId,
              'p_content': text,
            },
          );
        } catch (e) {
          debugPrint('[Communities] mention notification error: $e');
        }
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
    _unsubscribePresence();
  }

  // ── Typing indicator via Supabase Realtime broadcast ──

  void subscribeToTypingIndicator(String communityId) {
    _unsubscribePresence();
    final channel = _client.channel('typing:$communityId');

    channel.onBroadcast(
      event: 'typing',
      callback: (payload) {
        final userId = payload['user_id']?.toString();
        final displayName = payload['display_name']?.toString() ?? '';
        if (userId == null || userId == currentUserId) return;

        final existing = _typingUsers.indexWhere((u) => u['user_id'] == userId);
        if (existing >= 0) {
          _typingUsers[existing] = {
            'user_id': userId,
            'display_name': displayName,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          };
        } else {
          _typingUsers.add({
            'user_id': userId,
            'display_name': displayName,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        }
        _cleanStaleTypers();
        notifyListeners();
      },
    );

    channel.onBroadcast(
      event: 'stop_typing',
      callback: (payload) {
        final userId = payload['user_id']?.toString();
        if (userId == null) return;
        _typingUsers.removeWhere((u) => u['user_id'] == userId);
        notifyListeners();
      },
    );

    channel.subscribe();
    _presenceChannel = channel;
  }

  void _unsubscribePresence() {
    _typingDebounce?.cancel();
    _typingDebounce = null;
    if (_presenceChannel != null) {
      _client.removeChannel(_presenceChannel!);
      _presenceChannel = null;
    }
    _typingUsers = [];
  }

  void _cleanStaleTypers() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _typingUsers.removeWhere(
      (u) => (now - (u['timestamp'] as int? ?? 0)) > 4000,
    );
  }

  void broadcastTyping(String communityId, String displayName) {
    _presenceChannel?.sendBroadcastMessage(
      event: 'typing',
      payload: {
        'user_id': currentUserId,
        'display_name': displayName,
      },
    );
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 3), () {
      broadcastStopTyping(communityId);
    });
  }

  void broadcastStopTyping(String communityId) {
    _typingDebounce?.cancel();
    _typingDebounce = null;
    _presenceChannel?.sendBroadcastMessage(
      event: 'stop_typing',
      payload: {'user_id': currentUserId},
    );
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

  // ── Edit message (15 min window) ──

  Future<bool> editPost({
    required String communityId,
    required String postId,
    required String newContent,
  }) async {
    final text = newContent.trim();
    if (text.isEmpty) {
      _setError('Le message ne peut pas être vide.');
      return false;
    }
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_edit_community_post',
        params: {
          'p_post_id': postId,
          'p_new_content': text,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError("Réponse invalide du serveur.");
        return false;
      }
      if (response['success'] != true) {
        final err = response['error']?.toString();
        if (err == 'edit_window_expired') {
          _setError('Tu ne peux modifier un message que dans les 15 minutes suivant son envoi.');
        } else if (err == 'not_author') {
          _setError('Tu ne peux modifier que tes propres messages.');
        } else {
          _setError(err ?? 'Erreur lors de la modification.');
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

  // ── Pin / unpin message ──

  Future<bool> pinPost({
    required String communityId,
    required String postId,
    bool isPinned = true,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_pin_community_post',
        params: {
          'p_post_id': postId,
          'p_is_pinned': isPinned,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError("Réponse invalide du serveur.");
        return false;
      }
      if (response['success'] != true) {
        final err = response['error']?.toString();
        if (err == 'not_authorized') {
          _setError('Seul le créateur du groupe ou un admin peut épingler un message.');
        } else {
          _setError(err ?? 'Erreur lors de l\'épinglage.');
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

  // ── List community members (for @mentions) ──

  List<Map<String, dynamic>> _communityMembers = [];
  List<Map<String, dynamic>> get communityMembers => _communityMembers;

  Future<void> loadCommunityMembers(String communityId) async {
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_list_community_members',
        params: {
          'p_community_id': communityId,
        },
      );
      if (response is! Map<String, dynamic>) {
        return;
      }
      if (response['success'] != true) {
        return;
      }
      final data = response['members'];
      if (data is List) {
        _communityMembers = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _communityMembers = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // ── Read receipts ──

  /// Load read counts for all my posts in a community (batch)
  Future<void> loadMyPostsReadStatus(String communityId) async {
    try {
      final result = await _client.rpc(
        'app_student_get_my_posts_read_status',
        params: {'p_community_id': communityId},
      );
      if (result is Map) {
        _postReadCounts = {};
        for (final entry in result.entries) {
          final key = entry.key.toString();
          final val = entry.value;
          _postReadCounts[key] = val is int ? val : 0;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Communities] loadMyPostsReadStatus error: $e');
    }
  }

  /// Get read count for a specific post (from cached data)
  int readCountForPost(String postId) => _postReadCounts[postId] ?? 0;

  // ── Online Presence (broadcast-based heartbeat) ──

  RealtimeChannel? _onlineChannel;
  Timer? _heartbeatTimer;
  final Map<String, Map<String, dynamic>> _onlineMembersMap = {};
  List<Map<String, dynamic>> get onlineMembers => _onlineMembersMap.values.toList();
  int get onlineMembersCount => _onlineMembersMap.length;

  /// Join presence channel for a community
  void joinPresenceChannel(String communityId) {
    leavePresenceChannel();
    final uid = currentUserId;
    if (uid == null) return;

    String displayName = 'Utilisateur';
    for (final m in _communityMembers) {
      if (m['user_id']?.toString() == uid) {
        displayName = m['display_name']?.toString() ?? 'Utilisateur';
        break;
      }
    }

    final channel = _client.channel('online:$communityId');

    channel.onBroadcast(
      event: 'heartbeat',
      callback: (payload) {
        final memberId = payload['user_id']?.toString();
        if (memberId == null) return;
        _onlineMembersMap[memberId] = {
          'user_id': memberId,
          'display_name': payload['display_name']?.toString() ?? '',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        _cleanStaleOnlineMembers();
        notifyListeners();
      },
    );

    channel.onBroadcast(
      event: 'leave',
      callback: (payload) {
        final memberId = payload['user_id']?.toString();
        if (memberId == null) return;
        _onlineMembersMap.remove(memberId);
        notifyListeners();
      },
    );

    channel.subscribe();
    _onlineChannel = channel;

    // Send heartbeat every 10 seconds
    void sendHeartbeat() {
      _onlineChannel?.sendBroadcastMessage(
        event: 'heartbeat',
        payload: {'user_id': uid, 'display_name': displayName},
      );
    }

    sendHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      sendHeartbeat();
      _cleanStaleOnlineMembers();
    });
  }

  void _cleanStaleOnlineMembers() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _onlineMembersMap.removeWhere(
      (_, v) => (now - (v['timestamp'] as int? ?? 0)) > 25000,
    );
  }

  /// Leave presence channel
  void leavePresenceChannel() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (_onlineChannel != null) {
      _onlineChannel!.sendBroadcastMessage(
        event: 'leave',
        payload: {'user_id': currentUserId},
      );
      _client.removeChannel(_onlineChannel!);
      _onlineChannel = null;
    }
    _onlineMembersMap.clear();
    notifyListeners();
  }

  /// Check if a specific user is online
  bool isUserOnline(String userId) {
    return _onlineMembersMap.containsKey(userId);
  }

  // ── Media Gallery ──

  /// Get all media posts (images/files) from current posts list
  List<Map<String, dynamic>> get mediaPosts {
    return _posts.where((p) {
      final type = (p['type'] ?? '').toString();
      final mediaUrl = (p['media_url'] ?? '').toString();
      return mediaUrl.isNotEmpty && (type == 'image' || type == 'file' || type == 'audio');
    }).toList();
  }

  /// Get only image posts for gallery grid
  List<Map<String, dynamic>> get imagePosts {
    return _posts.where((p) {
      final type = (p['type'] ?? '').toString();
      final mediaUrl = (p['media_url'] ?? '').toString();
      return mediaUrl.isNotEmpty && type == 'image';
    }).toList();
  }
}
