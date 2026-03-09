import 'dart:async';
import 'dart:convert' as json;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../utils/mime_type_helper.dart';

/// Provider admin pour la messagerie Support.
/// Liste les conversations de tous les rôles, envoie des réponses, gère les statuts.
class AdminSupportProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _realtimeChannel;

  // Filters
  String? _filterRole;
  String? _filterStatus;
  String? _searchQuery;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  List<Map<String, dynamic>> get conversations => _conversations;
  List<Map<String, dynamic>> get messages => _messages;
  String? get filterRole => _filterRole;
  String? get filterStatus => _filterStatus;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setSaving(bool v) {
    _isSaving = v;
    notifyListeners();
  }

  void _setError(String? v) {
    _error = v;
    if (v != null) notifyListeners();
  }

  void setFilterRole(String? role) {
    _filterRole = role;
    loadConversations();
  }

  void setFilterStatus(String? status) {
    _filterStatus = status;
    loadConversations();
  }

  void setSearch(String? query) {
    _searchQuery = (query ?? '').trim().isEmpty ? null : query!.trim();
    loadConversations();
  }

  Future<void> loadConversations() async {
    _setLoading(true);
    _setError(null);
    try {
      final params = <String, dynamic>{};
      if (_filterStatus != null) params['p_status'] = _filterStatus;
      if (_filterRole != null) params['p_role'] = _filterRole;
      if (_searchQuery != null) params['p_search'] = _searchQuery;

      final dynamic response = await _client.rpc(
        'app_admin_list_support_conversations',
        params: params.isEmpty ? null : params,
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide.');
        return;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur chargement.');
        return;
      }
      final data = response['conversations'];
      if (data is List) {
        _conversations = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _conversations = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMessages(String conversationId) async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_list_support_messages',
        params: {'p_conversation_id': conversationId},
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide.');
        return;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur chargement messages.');
        return;
      }
      final data = response['messages'];
      if (data is List) {
        _messages = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _messages = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> sendMessage(String conversationId, String content, {String type = 'text', String? mediaUrl}) async {
    final text = content.trim();
    if (text.isEmpty && (mediaUrl == null || mediaUrl.trim().isEmpty)) {
      _setError('Message vide.');
      return false;
    }
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_send_support_message',
        params: {
          'p_conversation_id': conversationId,
          'p_content': text,
          'p_type': type,
          'p_media_url': mediaUrl,
        },
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(response is Map ? response['error']?.toString() ?? 'Erreur envoi.' : 'Erreur envoi.');
        return false;
      }
      await loadMessages(conversationId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<String?> uploadSupportMedia({
    required String conversationId,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        _setError('Non authentifi\u00e9.');
        return null;
      }
      final sanitized = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final storagePath = '${user.id}/support/$conversationId/$sanitized';
      final contentType = MimeTypeHelper.normalize(mimeType) ?? 'application/octet-stream';
      final accessToken = _client.auth.currentSession?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        _setError('Session expir\u00e9e.');
        return null;
      }
      final edgeFnUrl = '${SupabaseConfig.url}/functions/v1/setup-storage-policies';
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
      final code = response.statusCode;
      if (code == 200 || code == 201) {
        try {
          final decoded = json.jsonDecode(response.body);
          if (decoded is Map) {
            final url = decoded['url']?.toString();
            if (url != null && url.isNotEmpty) return url;
          }
        } catch (_) {}
        return '${SupabaseConfig.url}/storage/v1/object/public/community-media/$storagePath';
      } else {
        _setError('Erreur upload ($code)');
        return null;
      }
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> setConversationStatus(String conversationId, String status) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_set_support_status',
        params: {
          'p_conversation_id': conversationId,
          'p_status': status,
        },
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(response is Map ? response['error']?.toString() ?? 'Erreur.' : 'Erreur.');
        return false;
      }
      await loadConversations();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<void> markRead(String conversationId) async {
    try {
      await _client.rpc(
        'app_mark_support_read',
        params: {'p_conversation_id': conversationId},
      );
    } catch (e) {
      debugPrint('[AdminSupport] markRead error: $e');
    }
  }

  void subscribeToMessages(String conversationId) {
    unsubscribeFromMessages();
    final channel = _client.channel('app:support_messages:admin:$conversationId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'app',
      table: 'support_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: conversationId,
      ),
      callback: (payload) {
        final newRow = payload.newRecord;
        if (newRow.isEmpty) return;
        final row = Map<String, dynamic>.from(newRow);
        final newId = row['id'];
        if (newId != null && _messages.any((m) => m['id'] == newId)) return;
        _messages = [..._messages, row];
        notifyListeners();
      },
    );
    channel.subscribe();
    _realtimeChannel = channel;
  }

  void unsubscribeFromMessages() {
    if (_realtimeChannel != null) {
      _client.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
  }

  int get totalUnread {
    int count = 0;
    for (final c in _conversations) {
      final u = c['unread_count'];
      if (u is int) count += u;
    }
    return count;
  }

  @override
  void dispose() {
    unsubscribeFromMessages();
    super.dispose();
  }
}
