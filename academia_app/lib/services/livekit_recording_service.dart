import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LivekitRecordingService {
  LivekitRecordingService._();

  static Future<Map<String, dynamic>> startRecording({
    required String sessionId,
    String sessionType = 'course',
  }) async {
    final client = Supabase.instance.client;
    debugPrint('[Recording] Starting for session=$sessionId type=$sessionType');

    final response = await client.functions.invoke(
      'livekit-recording',
      body: {
        'action': 'start',
        'session_id': sessionId,
        'session_type': sessionType,
      },
    );

    if (response.status != 200) {
      debugPrint('[Recording] Start failed: ${response.status} ${response.data}');
      throw Exception('Erreur enregistrement (${response.status}).');
    }

    final data = response.data;
    if (data is! Map<String, dynamic> || data['success'] != true) {
      final error = data is Map ? data['error']?.toString() : 'Erreur inconnue';
      throw Exception(error ?? 'Erreur enregistrement.');
    }

    debugPrint('[Recording] Started: egress_id=${data['egress_id']}');
    return data;
  }

  static Future<Map<String, dynamic>> stopRecording({
    required String sessionId,
    required String egressId,
    String sessionType = 'course',
  }) async {
    final client = Supabase.instance.client;
    debugPrint('[Recording] Stopping egress=$egressId session=$sessionId');

    final response = await client.functions.invoke(
      'livekit-recording',
      body: {
        'action': 'stop',
        'session_id': sessionId,
        'session_type': sessionType,
        'egress_id': egressId,
      },
    );

    if (response.status != 200) {
      debugPrint('[Recording] Stop failed: ${response.status} ${response.data}');
      throw Exception('Erreur arrêt enregistrement (${response.status}).');
    }

    final data = response.data;
    if (data is! Map<String, dynamic> || data['success'] != true) {
      final error = data is Map ? data['error']?.toString() : 'Erreur inconnue';
      throw Exception(error ?? 'Erreur arrêt enregistrement.');
    }

    debugPrint('[Recording] Stopped: file_url=${data['file_url']}');
    return data;
  }
}
