import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LivekitTokenService {
  LivekitTokenService._();

  /// Appelle l'Edge Function `livekit-token` pour obtenir un token
  /// d'accès LiveKit pour la session donnée.
  ///
  /// Retourne un Map contenant :
  /// - `token` : le JWT LiveKit
  /// - `url` : l'URL WebSocket du serveur LiveKit (wss://...)
  /// - `room_name` : le nom de la room
  /// - `identity` : l'identité du participant
  /// - `display_name` : le nom affiché
  /// - `is_host` : true si l'utilisateur est l'hôte (enseignant)
  static Future<Map<String, dynamic>> getTokenForSession(String sessionId) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) {
      throw Exception('Utilisateur non authentifié.');
    }

    debugPrint('[LivekitToken] Requesting token for session=$sessionId');

    final response = await client.functions.invoke(
      'livekit-token',
      body: {
        'session_id': sessionId,
      },
    );

    if (response.status != 200) {
      debugPrint('[LivekitToken] HTTP ${response.status}: ${response.data}');
      throw Exception(
        'Erreur LiveKit (${response.status}).',
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Réponse LiveKit invalide.');
    }

    if (data['success'] != true) {
      final error = data['error']?.toString() ?? 'Erreur inconnue';
      debugPrint('[LivekitToken] Error: $error');
      throw Exception(error);
    }

    debugPrint('[LivekitToken] Token obtained: room=${data['room_name']}, host=${data['is_host']}');
    return data;
  }
}
