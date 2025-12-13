import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

class PrepAiService {
  PrepAiService._();

  static Future<Map<String, dynamic>> generatePrepQcm({
    required String subjectId,
    String generationType = 'mcq',
    String? prompt,
    int numQuestions = 10,
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

    const supabaseUrl = SupabaseConfig.url;
    final baseUri = Uri.parse(supabaseUrl);
    final backendBase = Uri(
      scheme: baseUri.scheme,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
    );

    final uri = backendBase.replace(path: '/ai/prep/generate');

    final body = <String, dynamic>{
      'subject_id': subjectId,
      'generation_type': generationType,
      'prompt': prompt,
      'num_questions': numQuestions,
    };

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
      String? message;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final detail = decoded['detail'];
          if (detail is String && detail.trim().isNotEmpty) {
            message = detail.trim();
          } else if (detail is Map) {
            final msg = detail['message'];
            if (msg is String && msg.trim().isNotEmpty) {
              message = msg.trim();
            }

            final rpc = detail['rpc'];
            if (rpc is String && rpc.trim().isNotEmpty) {
              message = message == null ? 'RPC: ${rpc.trim()}' : '$message • RPC: ${rpc.trim()}';
            }

            final errObj = detail['error'];
            if (errObj != null) {
              final errText = errObj.toString().trim();
              if (errText.isNotEmpty) {
                message = message == null ? errText : '$message • $errText';
              }
            }

            final err = detail['error'];
            if (message == null && err is String && err.trim().isNotEmpty) {
              message = err.trim();
            }
            final statusCode = detail['status_code'];
            if (message != null && statusCode != null) {
              message = '$message (upstream: $statusCode)';
            }
          }

          final msg = decoded['message'];
          if (message == null && msg is String && msg.trim().isNotEmpty) {
            message = msg.trim();
          }
        }
      } catch (_) {}

      final body = response.body.trim();
      if (message == null && body.isNotEmpty) {
        message = body.length > 600 ? body.substring(0, 600) : body;
      }

      throw Exception(message == null
          ? 'Erreur IA (${response.statusCode}).'
          : 'Erreur IA (${response.statusCode}): $message');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Réponse IA invalide.');
    }
    return decoded;
  }
}
