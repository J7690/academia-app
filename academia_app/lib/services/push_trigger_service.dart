import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Service qui déclenche le traitement des notifications push en attente.
/// Appelle l'Edge Function send-push-notifications pour traiter la file
/// d'événements dans notification_events et envoyer les push FCM.
class PushTriggerService {
  PushTriggerService._();
  static final PushTriggerService instance = PushTriggerService._();

  DateTime? _lastTrigger;
  static const _minInterval = Duration(seconds: 30);

  /// Déclenche le traitement des push en attente.
  /// Throttle: max 1 appel toutes les 30 secondes.
  Future<void> triggerPendingPush() async {
    final now = DateTime.now();
    if (_lastTrigger != null && now.difference(_lastTrigger!) < _minInterval) {
      return;
    }
    _lastTrigger = now;

    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      if (session == null) return;

      final url = '${SupabaseConfig.url}/functions/v1/send-push-notifications';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'apikey': SupabaseConfig.anonKey,
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
        body: '{}',
      );

      if (response.statusCode == 200) {
        debugPrint('[PushTrigger] OK — processed pending push');
      } else {
        debugPrint('[PushTrigger] HTTP ${response.statusCode}: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');
      }
    } catch (e) {
      debugPrint('[PushTrigger] Error: $e');
    }
  }
}
