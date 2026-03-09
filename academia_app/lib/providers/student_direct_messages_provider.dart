import 'dart:async';
import 'dart:convert' as json;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../utils/mime_type_helper.dart';

/// Provider pour les messages directs (1-à-1) entre étudiants
class StudentDirectMessagesProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _dmChannel;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  List<Map<String, dynamic>> get conversations => _conversations;
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

  // ── Conversations list ──

  Future<void> loadConversations() async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_list_dm_conversations',
      );
      if (response is! Map<String, dynamic>) {
        _setError("Réponse invalide du serveur.");
        return;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? "Erreur chargement conversations.");
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

  // ── Get or create conversation ──

  Future<String?> getOrCreateConversation(String otherUserId) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_get_or_create_dm_conversation',
        params: {'p_other_user_id': otherUserId},
      );
      if (response is! Map<String, dynamic>) {
        _setError("Réponse invalide du serveur.");
        return null;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? "Erreur création conversation.");
        return null;
      }
      final convId = response['conversation_id']?.toString();
      await loadConversations();
      return convId;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setSaving(false);
    }
  }

  // ── Messages ──

  Future<void> loadMessages(String conversationId) async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_list_direct_messages',
        params: {'p_conversation_id': conversationId},
      );
      if (response is! Map<String, dynamic>) {
        _setError("Réponse invalide du serveur.");
        return;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? "Erreur chargement messages.");
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

  Future<bool> sendMessage({
    required String conversationId,
    required String content,
    String type = 'text',
    String? mediaUrl,
    String? replyToMessageId,
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
        'app_student_send_direct_message',
        params: {
          'p_conversation_id': conversationId,
          'p_content': text,
          'p_type': type,
          'p_media_url': mediaUrl,
          'p_reply_to_message_id': replyToMessageId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError("Réponse invalide du serveur.");
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? "Erreur envoi message.");
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

  // ── Mark as read ──

  Future<void> markConversationRead(String conversationId) async {
    try {
      await _client.rpc(
        'app_student_mark_dm_read',
        params: {'p_conversation_id': conversationId},
      );
      await loadConversations();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // ── Media upload ──

  Future<String?> uploadDmMedia({
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
        _setError('Utilisateur non authentifié.');
        return null;
      }

      final sanitizedFileName =
          fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final storagePath =
          '${user.id}/dm/$conversationId/$sanitizedFileName';

      final contentType =
          MimeTypeHelper.normalize(mimeType) ?? 'application/octet-stream';
      final accessToken = _client.auth.currentSession?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        _setError('Session expirée. Reconnecte-toi.');
        return null;
      }

      // Upload via Edge Function proxy (bypass RLS avec service_role)
      final edgeFnUrl =
          '${SupabaseConfig.url}/functions/v1/setup-storage-policies';

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

      debugPrint('[uploadDmMedia] Edge Fn → ${response.statusCode}');
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
        debugPrint('[uploadDmMedia] ERROR $code: ${response.body}');
        _setError('Erreur upload ($code): ${response.body}');
        return null;
      }
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setSaving(false);
    }
  }

  // ── Realtime subscription ──

  void subscribeToDmMessages(String conversationId) {
    unsubscribeFromDmMessages();
    final channel = _client.channel('app:direct_messages:$conversationId');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'app',
      table: 'direct_messages',
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
    _dmChannel = channel;
  }

  void unsubscribeFromDmMessages() {
    if (_dmChannel != null) {
      _client.removeChannel(_dmChannel!);
      _dmChannel = null;
    }
  }

  @override
  void dispose() {
    unsubscribeFromDmMessages();
    super.dispose();
  }
}
