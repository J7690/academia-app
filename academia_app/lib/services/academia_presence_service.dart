import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service de tracking de présence pour les sessions AcademiaClassroom.
///
/// Envoie un heartbeat toutes les 30 secondes et gère les états
/// online/offline via les RPCs Supabase.
class AcademiaPresenceService {
  AcademiaPresenceService._();
  static final instance = AcademiaPresenceService._();

  SupabaseClient get _client => Supabase.instance.client;

  Timer? _heartbeatTimer;
  String? _activeSessionId;

  /// Démarre le heartbeat pour une session.
  void startTracking(String sessionId) {
    _activeSessionId = sessionId;
    _sendHeartbeat();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _sendHeartbeat(),
    );
  }

  /// Arrête le heartbeat et marque offline.
  Future<void> stopTracking() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (_activeSessionId != null) {
      await markOffline(_activeSessionId!);
      _activeSessionId = null;
    }
  }

  Future<void> _sendHeartbeat() async {
    if (_activeSessionId == null) return;
    try {
      await _client.rpc('app_learning_presence_heartbeat', params: {
        'p_session_id': _activeSessionId,
      });
    } catch (e) {
      debugPrint('[AcademiaPresence] heartbeat error: $e');
    }
  }

  /// Marque un utilisateur offline pour une session.
  Future<void> markOffline(String sessionId) async {
    try {
      await _client.rpc('app_learning_presence_offline', params: {
        'p_session_id': sessionId,
      });
    } catch (e) {
      debugPrint('[AcademiaPresence] offline error: $e');
    }
  }

  /// Charge la liste des participants présents.
  Future<List<Map<String, dynamic>>> listPresence(String sessionId) async {
    try {
      final res = await _client.rpc('app_learning_presence_list', params: {
        'p_session_id': sessionId,
      });
      if (res is List) return res.cast<Map<String, dynamic>>();
      return [];
    } catch (e) {
      debugPrint('[AcademiaPresence] listPresence error: $e');
      return [];
    }
  }

  /// Nettoie les heartbeats stale.
  Future<int> cleanup() async {
    try {
      final res = await _client.rpc('app_learning_presence_cleanup');
      return (res as int?) ?? 0;
    } catch (e) {
      debugPrint('[AcademiaPresence] cleanup error: $e');
      return 0;
    }
  }
}
