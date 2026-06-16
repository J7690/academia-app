import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service de chat académique persistant.
///
/// Gère l'envoi, le chargement paginé et la suppression de messages
/// via les RPCs Supabase `app_learning_send_message`, `app_learning_list_messages`,
/// `app_learning_delete_message`.
class AcademiaChatService {
  AcademiaChatService._();
  static final instance = AcademiaChatService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Envoie un message et retourne son UUID.
  Future<String?> sendMessage({
    required String sessionId,
    required String content,
    String messageType = 'text',
  }) async {
    try {
      final res = await _client.rpc('app_learning_send_message', params: {
        'p_session_id': sessionId,
        'p_content': content,
        'p_message_type': messageType,
      });
      return res?.toString();
    } catch (e) {
      debugPrint('[AcademiaChatService] sendMessage error: $e');
      return null;
    }
  }

  /// Charge les messages d'une session (paginé, plus récents en premier).
  Future<List<Map<String, dynamic>>> loadMessages({
    required String sessionId,
    int limit = 50,
    DateTime? before,
  }) async {
    try {
      final params = <String, dynamic>{
        'p_session_id': sessionId,
        'p_limit': limit,
      };
      if (before != null) {
        params['p_before'] = before.toIso8601String();
      }
      final res = await _client.rpc('app_learning_list_messages', params: params);
      if (res is List) {
        return res.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('[AcademiaChatService] loadMessages error: $e');
      return [];
    }
  }

  /// Supprime un message (propre ou admin).
  Future<bool> deleteMessage(String messageId) async {
    try {
      final res = await _client.rpc('app_learning_delete_message', params: {
        'p_message_id': messageId,
      });
      return res == true;
    } catch (e) {
      debugPrint('[AcademiaChatService] deleteMessage error: $e');
      return false;
    }
  }

  /// Souscrit au Supabase Realtime pour les nouveaux messages de la session.
  RealtimeChannel subscribeToMessages({
    required String sessionId,
    required void Function(Map<String, dynamic> payload) onInsert,
  }) {
    final channel = _client
        .channel('chat:$sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'app',
          table: 'academia_session_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
          callback: (payload) {
            onInsert(payload.newRecord);
          },
        )
        .subscribe();
    return channel;
  }

  /// Désinscrit du canal Realtime.
  Future<void> unsubscribe(RealtimeChannel channel) async {
    await _client.removeChannel(channel);
  }
}
