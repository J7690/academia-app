import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

class StudioVideoService {
  StudioVideoService._();

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

    // Logs de debug pour comprendre comment le rendu vidéo est appelé côté Flutter.
    print('[StudioVideoService] POST $uri body=${jsonEncode(body)}');

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $jwt',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(body),
    );

    print(
      '[StudioVideoService] RESPONSE status=${response.statusCode} body=${response.body}',
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
      throw Exception('Erreur Studio vidéo (${response.statusCode}).');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Réponse Studio vidéo invalide.');
    }
    return decoded;
  }

  static Future<Map<String, dynamic>> render({
    required String participationId,
    String videoType = 'challenge',
    String? freeVideoId,
  }) async {
    final body = <String, dynamic>{
      'participation_id': participationId,
      'video_type': videoType,
    };

    if (videoType == 'free' && freeVideoId != null && freeVideoId.trim().isNotEmpty) {
      body['free_video_id'] = freeVideoId.trim();
    }

    print(
      '[StudioVideoService] render START participation_id=$participationId',
    );

    final result = await _postWithUserJwt(
      path: '/studio/video/render',
      body: body,
    );

    print('[StudioVideoService] render RESULT participation_id=$participationId result=$result');

    return result;
  }

  // -----------------------------------------------------------------------
  // Challenge TikTok Studio — backend Docker endpoints
  // -----------------------------------------------------------------------

  /// Base URL for the backend (Docker local or Railway).
  /// Override via environment or config when deploying.
  static String get _backendBaseUrl {
    // In production, this would be the Railway URL.
    // Locally, Docker exposes the backend on port 8000.
    // The app running on an Android emulator uses 10.0.2.2 to reach host.
    return const String.fromEnvironment(
      'BACKEND_URL',
      defaultValue: 'http://10.0.2.2:8000',
    );
  }

  static Future<Map<String, dynamic>> _postToBackend({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    final serviceKey = SupabaseConfig.serviceKey;
    final uri = Uri.parse('$_backendBaseUrl$path');

    print('[StudioVideoService] POST $uri');

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $serviceKey',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(body),
    );

    print('[StudioVideoService] RESPONSE status=${response.statusCode}');

    if (response.statusCode >= 400) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final detail = decoded['detail'];
          if (detail is String) throw Exception(detail);
          if (detail is Map && detail['message'] is String) {
            throw Exception(detail['message'] as String);
          }
        }
      } catch (e) {
        if (e is Exception) rethrow;
      }
      throw Exception('Erreur backend (${response.statusCode}).');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Réponse backend invalide.');
    }
    return decoded;
  }

  /// Burn scientific overlays (annotations) onto a video via FFmpeg backend.
  static Future<Map<String, dynamic>> burnOverlays({
    required String videoUrl,
    required Map<String, dynamic> overlays,
    required String participationId,
    int videoWidth = 1080,
    int videoHeight = 1920,
  }) async {
    return _postToBackend(
      path: '/challenge/burn-overlays',
      body: {
        'video_url': videoUrl,
        'overlays': overlays,
        'participation_id': participationId,
        'video_width': videoWidth,
        'video_height': videoHeight,
      },
    );
  }

  /// Generate a JPEG thumbnail from a video at a given position.
  static Future<String> generateThumbnail({
    required String videoUrl,
    required String participationId,
    double positionSeconds = 1.0,
  }) async {
    final result = await _postToBackend(
      path: '/challenge/generate-thumbnail',
      body: {
        'video_url': videoUrl,
        'participation_id': participationId,
        'position_seconds': positionSeconds,
      },
    );
    return result['thumbnail_url']?.toString() ?? '';
  }
}
