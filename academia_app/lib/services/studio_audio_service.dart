import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

class StudioAudioService {
  StudioAudioService._();

  static Future<Map<String, dynamic>> _postWithUserJwt({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) {
      throw Exception('Utilisateur non authentifié.');
    }

    final jwt = session.accessToken;
    if (jwt.isEmpty) {
      throw Exception('Jeton utilisateur invalide.');
    }

    final supabaseUrl = SupabaseConfig.url;
    final baseUri = Uri.parse(supabaseUrl);
    final backendBase = Uri(
      scheme: baseUri.scheme,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
    );

    final uri = backendBase.replace(path: path);

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $jwt',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode >= 400) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final detail = decoded['detail'];
          if (detail is Map && detail['message'] is String) {
            throw Exception(detail['message'] as String);
          }
        }
      } catch (_) {}
      throw Exception('Erreur Studio audio (${response.statusCode}).');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Réponse Studio audio invalide.');
    }
    return decoded;
  }

  static Future<Map<String, dynamic>> render({
    required String participationId,
    required List<Map<String, dynamic>> tracks,
    bool normalize = true,
  }) async {
    if (tracks.isEmpty) {
      throw Exception('Aucune piste audio sélectionnée.');
    }

    final body = <String, dynamic>{
      'participation_id': participationId,
      'tracks': tracks,
      'normalize': normalize,
    };

    return _postWithUserJwt(
      path: '/studio/audio/render',
      body: body,
    );
  }
}
