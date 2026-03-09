import 'dart:async';
import 'dart:convert' as json;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../utils/mime_type_helper.dart';

/// Provider pour la messagerie Support (admin-only).
/// Utilisé par tous les rôles (sauf admin) pour échanger avec l'administrateur.
class SupportMessagesProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  String? _conversationId;
  List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _realtimeChannel;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  String? get conversationId => _conversationId;
  List<Map<String, dynamic>> get messages => _messages;
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
    if (value != null) notifyListeners();
  }

  /// Get or create the support conversation for the current user.
  Future<String?> getOrCreateConversation() async {
    if (_conversationId != null) return _conversationId;
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_get_or_create_support_conversation',
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return null;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur création conversation support.');
        return null;
      }
      _conversationId = response['conversation_id']?.toString();
      notifyListeners();
      return _conversationId;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Load messages for the current support conversation.
  Future<void> loadMessages() async {
    final convId = _conversationId;
    if (convId == null) return;
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_list_support_messages',
        params: {'p_conversation_id': convId},
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
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

  /// Send a message to the admin.
  Future<bool> sendMessage(String content, {String type = 'text', String? mediaUrl}) async {
    final convId = _conversationId;
    if (convId == null) {
      _setError('Aucune conversation active.');
      return false;
    }
    final text = content.trim();
    if (text.isEmpty && (mediaUrl == null || mediaUrl.trim().isEmpty)) {
      _setError('Le message est vide.');
      return false;
    }
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_send_support_message',
        params: {
          'p_conversation_id': convId,
          'p_content': text,
          'p_type': type,
          'p_media_url': mediaUrl,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur envoi message.');
        return false;
      }
      await loadMessages();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  /// Upload a media file for support chat.
  Future<String?> uploadSupportMedia({
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
      final convId = _conversationId ?? 'general';
      final sanitized = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final storagePath = '${user.id}/support/$convId/$sanitized';
      final contentType = MimeTypeHelper.normalize(mimeType) ?? 'application/octet-stream';
      final accessToken = _client.auth.currentSession?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        _setError('Session expirée.');
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

  /// Mark conversation as read.
  Future<void> markRead() async {
    final convId = _conversationId;
    if (convId == null) return;
    try {
      await _client.rpc(
        'app_mark_support_read',
        params: {'p_conversation_id': convId},
      );
    } catch (e) {
      debugPrint('[SupportMessages] markRead error: $e');
    }
  }

  /// Subscribe to realtime for new messages.
  void subscribeToMessages() {
    final convId = _conversationId;
    if (convId == null) return;
    unsubscribeFromMessages();

    final channel = _client.channel('app:support_messages:$convId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'app',
      table: 'support_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: convId,
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

  /// Convenience: open conversation + load messages + subscribe.
  Future<bool> openSupportChat() async {
    final convId = await getOrCreateConversation();
    if (convId == null) return false;
    await loadMessages();
    subscribeToMessages();
    await markRead();
    return true;
  }

  /// Fetch unread count for the current user's support conversation.
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  Future<void> loadUnreadCount() async {
    try {
      final dynamic response = await _client.rpc('app_get_support_unread_count');
      if (response is Map<String, dynamic> && response['success'] == true) {
        final count = response['unread_count'];
        _unreadCount = count is int ? count : 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[SupportMessages] loadUnreadCount error: $e');
    }
  }

  @override
  void dispose() {
    unsubscribeFromMessages();
    super.dispose();
  }
}
