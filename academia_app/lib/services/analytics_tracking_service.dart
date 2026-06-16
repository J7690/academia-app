import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service de tracking analytics — enregistre les navigations utilisateur.
/// Permet à l'admin de savoir quels onglets/écrans sont les plus visités.
///
/// Usage:
/// ```dart
/// AnalyticsTrackingService.instance.trackScreen('student_home', tabIndex: 2, tabName: 'Cours');
/// ```
class AnalyticsTrackingService {
  AnalyticsTrackingService._();
  static final AnalyticsTrackingService instance = AnalyticsTrackingService._();

  final SupabaseClient _client = Supabase.instance.client;
  String? _sessionId;
  String? _currentScreen;
  DateTime? _screenEnteredAt;
  Timer? _batchTimer;
  final List<Map<String, dynamic>> _pendingEvents = [];

  static const int _batchIntervalSeconds = 30;
  static const int _maxBatchSize = 20;

  /// Initialise le service avec un session ID unique.
  void init() {
    _sessionId = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    _startBatchTimer();
  }

  /// Track l'entrée sur un écran/onglet.
  void trackScreen(String screenName, {int? tabIndex, String? tabName}) {
    // Flush previous screen duration
    _flushCurrentScreen();

    _currentScreen = screenName;
    _screenEnteredAt = DateTime.now();

    _pendingEvents.add({
      'screen_name': screenName,
      'tab_index': tabIndex,
      'tab_name': tabName,
      'session_id': _sessionId,
      'duration_seconds': 0,
    });

    // Auto-flush if batch full
    if (_pendingEvents.length >= _maxBatchSize) {
      _flushBatch();
    }
  }

  /// Track un changement d'onglet dans le même écran.
  void trackTab(String screenName, int tabIndex, String tabName) {
    trackScreen(screenName, tabIndex: tabIndex, tabName: tabName);
  }

  /// Met à jour la durée de l'écran courant avant de naviguer ailleurs.
  void _flushCurrentScreen() {
    if (_currentScreen != null && _screenEnteredAt != null) {
      final duration = DateTime.now().difference(_screenEnteredAt!).inSeconds;
      if (duration > 1 && _pendingEvents.isNotEmpty) {
        // Update last event for this screen with duration
        for (int i = _pendingEvents.length - 1; i >= 0; i--) {
          if (_pendingEvents[i]['screen_name'] == _currentScreen) {
            _pendingEvents[i]['duration_seconds'] = duration;
            break;
          }
        }
      }
    }
  }

  void _startBatchTimer() {
    _batchTimer?.cancel();
    _batchTimer = Timer.periodic(
      const Duration(seconds: _batchIntervalSeconds),
      (_) => _flushBatch(),
    );
  }

  /// Envoie les événements en batch vers Supabase.
  Future<void> _flushBatch() async {
    if (_pendingEvents.isEmpty) return;
    if (_client.auth.currentUser == null) return;

    final batch = List<Map<String, dynamic>>.from(_pendingEvents);
    _pendingEvents.clear();

    for (final event in batch) {
      try {
        await _client.rpc('app_track_navigation_event', params: {
          'p_screen_name': event['screen_name'],
          'p_tab_index': event['tab_index'],
          'p_tab_name': event['tab_name'],
          'p_session_id': event['session_id'],
          'p_duration_seconds': event['duration_seconds'] ?? 0,
        });
      } catch (e) {
        debugPrint('[Analytics] Error flushing event: $e');
      }
    }
  }

  /// Force l'envoi des événements (à appeler au logout ou app background).
  Future<void> flush() async {
    _flushCurrentScreen();
    await _flushBatch();
  }

  /// Dispose du service.
  void dispose() {
    _batchTimer?.cancel();
    _flushBatch();
  }
}
