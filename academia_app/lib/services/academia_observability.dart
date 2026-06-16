import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service d'observabilité pour le Learning Engine.
///
/// Enregistre les événements de session (connexion, déconnexion, erreurs,
/// qualité réseau) pour le monitoring et l'analyse.
class AcademiaObservability {
  AcademiaObservability._();
  static final instance = AcademiaObservability._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Log un événement de session.
  Future<void> logEvent({
    required String sessionId,
    required String eventType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _client.from('academia_session_events').insert({
        'session_id': sessionId,
        'user_id': _client.auth.currentUser?.id,
        'event_type': eventType,
        'metadata': metadata,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[Observability] logEvent error: $e');
    }
  }

  /// Log une connexion réussie.
  Future<void> logConnection(String sessionId) async {
    await logEvent(
      sessionId: sessionId,
      eventType: 'connected',
      metadata: {'platform': defaultTargetPlatform.name},
    );
  }

  /// Log une déconnexion.
  Future<void> logDisconnection(String sessionId, {String? reason}) async {
    await logEvent(
      sessionId: sessionId,
      eventType: 'disconnected',
      metadata: {'reason': reason ?? 'normal'},
    );
  }

  /// Log une erreur.
  Future<void> logError(String sessionId, String error) async {
    await logEvent(
      sessionId: sessionId,
      eventType: 'error',
      metadata: {'error': error},
    );
  }

  /// Log la qualité de connexion.
  Future<void> logQuality(String sessionId, String quality) async {
    await logEvent(
      sessionId: sessionId,
      eventType: 'quality_change',
      metadata: {'quality': quality},
    );
  }

  /// Récupère les statistiques d'une session (admin).
  Future<Map<String, dynamic>> getSessionStats(String sessionId) async {
    try {
      final events = await _client
          .from('academia_session_events')
          .select('event_type')
          .eq('session_id', sessionId);

      final list = (events as List?) ?? [];
      final counts = <String, int>{};
      for (final e in list) {
        final type = e['event_type']?.toString() ?? 'unknown';
        counts[type] = (counts[type] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      debugPrint('[Observability] getSessionStats error: $e');
      return {};
    }
  }
}
