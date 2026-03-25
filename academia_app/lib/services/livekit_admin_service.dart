import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LivekitAdminService {
  LivekitAdminService._();

  /// Exclut un participant d'une session live via l'Edge Function.
  /// Nécessite que l'utilisateur soit admin ou hôte de la session.
  static Future<bool> kickParticipant({
    required String sessionId,
    required String userId,
  }) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) {
      throw Exception('Administrateur non authentifié.');
    }

    debugPrint('[LivekitAdmin] Kick participant=$userId from session=$sessionId');

    // Utiliser la RPC admin existante pour bannir
    try {
      final response = await client.rpc(
        'app_admin_ban_user_from_online_course_live_session',
        params: {
          'p_session_id': sessionId,
          'p_user_id': userId,
        },
      );

      if (response is Map<String, dynamic> && response['success'] == true) {
        debugPrint('[LivekitAdmin] Kick OK');
        return true;
      }

      debugPrint('[LivekitAdmin] Kick failed: $response');
      return false;
    } catch (e) {
      debugPrint('[LivekitAdmin] Kick error: $e');
      throw Exception('Erreur lors de l\'exclusion du participant.');
    }
  }
}
