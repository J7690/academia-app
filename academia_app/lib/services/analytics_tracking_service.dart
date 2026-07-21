import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service de tracking analytics — trace les parcours utilisateurs
/// AVEC ou SANS compte (visitor_id anonyme persistant).
///
/// - `visitor_id` : identifiant anonyme généré au premier lancement et
///   conservé (SharedPreferences / localStorage). À la connexion, les
///   événements portent aussi le user_id (résolu côté serveur via auth.uid()),
///   ce qui permet de relier le parcours anonyme au compte créé.
/// - Envoi par lots via la RPC `app_track_events_batch` (appelable par anon).
/// - Aucune donnée personnelle : uniquement des identifiants techniques.
///
/// Usage :
/// ```dart
/// await AnalyticsTrackingService.instance.init();
/// AnalyticsTrackingService.instance.trackScreen('student_home', tabName: 'Cours');
/// AnalyticsTrackingService.instance.trackEntityView('formation', programId,
///     screenName: 'program_detail', properties: {'university_id': uniId});
/// AnalyticsTrackingService.instance.trackAction('offer_action', 'apply_clicked',
///     entityType: 'formation', entityId: programId);
/// ```
class AnalyticsTrackingService {
  AnalyticsTrackingService._();
  static final AnalyticsTrackingService instance = AnalyticsTrackingService._();

  static const String _visitorIdPrefKey = 'analytics_visitor_id_v1';
  static const int _batchIntervalSeconds = 30;
  static const int _maxBatchSize = 20;

  SupabaseClient get _client => Supabase.instance.client;

  String? _visitorId;
  String? _sessionId;
  String? _currentScreen;
  DateTime? _screenEnteredAt;
  Timer? _batchTimer;
  bool _initialized = false;
  final List<Map<String, dynamic>> _pendingEvents = [];

  String get _platform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return defaultTargetPlatform.name;
    }
  }

  /// Initialise le service : visitor_id persistant + session + timer d'envoi.
  /// Idempotent — peut être appelé plusieurs fois sans effet de bord.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      var visitorId = prefs.getString(_visitorIdPrefKey);
      if (visitorId == null || visitorId.isEmpty) {
        visitorId = _generateId(32);
        await prefs.setString(_visitorIdPrefKey, visitorId);
      }
      _visitorId = visitorId;
    } catch (e) {
      // Stockage indisponible : visitor éphémère pour cette session.
      _visitorId = _generateId(32);
      debugPrint('[Analytics] visitor_id ephemere: $e');
    }

    _sessionId = _generateId(16);
    _startBatchTimer();
  }

  String _generateId(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final randLength = length > ts.length ? length - ts.length : 8;
    final rand =
        List.generate(randLength, (_) => chars[rnd.nextInt(chars.length)])
            .join();
    final id = ts + rand;
    return id.length > length ? id.substring(0, length) : id;
  }

  /// Track l'entrée sur un écran/onglet (screen_view).
  void trackScreen(String screenName, {int? tabIndex, String? tabName}) {
    _flushCurrentScreenDuration();

    _currentScreen = screenName;
    _screenEnteredAt = DateTime.now();

    _enqueue({
      'event_type': 'screen_view',
      'screen_name': screenName,
      'properties': {
        if (tabIndex != null) 'tab_index': tabIndex,
        if (tabName != null) 'tab_name': tabName,
      },
      'duration_seconds': 0,
    });
  }

  /// Compatibilité avec l'existant : changement d'onglet.
  void trackTab(String screenName, int tabIndex, String tabName) {
    trackScreen(screenName, tabIndex: tabIndex, tabName: tabName);
  }

  /// Track la consultation d'une entité métier (offre, formation,
  /// université, produit marketplace, vidéo challenge...).
  void trackEntityView(
    String entityType,
    String entityId, {
    String? screenName,
    Map<String, dynamic>? properties,
  }) {
    _enqueue({
      'event_type': '${entityType}_view',
      'screen_name': screenName ?? _currentScreen,
      'entity_type': entityType,
      'entity_id': entityId,
      'properties': properties ?? const {},
    });
  }

  /// Track une action métier (favori, partage, clic "postuler",
  /// recherche, ajout panier...).
  void trackAction(
    String eventType,
    String action, {
    String? entityType,
    String? entityId,
    Map<String, dynamic>? properties,
  }) {
    _enqueue({
      'event_type': eventType,
      'screen_name': _currentScreen,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      'properties': {'action': action, ...?properties},
    });
  }

  /// Track une recherche.
  void trackSearch(String query, {int? resultCount, String? context}) {
    _enqueue({
      'event_type': 'search',
      'screen_name': _currentScreen,
      'properties': {
        // On tronque : le terme sert à comprendre la demande, pas à profiler.
        'query': query.length > 60 ? query.substring(0, 60) : query,
        if (resultCount != null) 'result_count': resultCount,
        if (context != null) 'context': context,
      },
    });
  }

  void _enqueue(Map<String, dynamic> event) {
    if (!_initialized) {
      // init() pas encore appelé : on initialise en arrière-plan et on garde
      // l'événement (il partira au prochain flush).
      unawaited(init());
    }
    event['session_id'] = _sessionId;
    _pendingEvents.add(event);
    if (_pendingEvents.length >= _maxBatchSize) {
      unawaited(_flushBatch());
    }
  }

  void _flushCurrentScreenDuration() {
    if (_currentScreen == null || _screenEnteredAt == null) return;
    final duration = DateTime.now().difference(_screenEnteredAt!).inSeconds;
    if (duration <= 1) return;
    for (int i = _pendingEvents.length - 1; i >= 0; i--) {
      if (_pendingEvents[i]['event_type'] == 'screen_view' &&
          _pendingEvents[i]['screen_name'] == _currentScreen) {
        _pendingEvents[i]['duration_seconds'] = duration;
        break;
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

  /// Envoie les événements en un seul appel RPC (fonctionne aussi anonyme).
  Future<void> _flushBatch() async {
    if (_pendingEvents.isEmpty) return;
    final visitorId = _visitorId;
    if (visitorId == null) return;

    final batch = List<Map<String, dynamic>>.from(_pendingEvents);
    _pendingEvents.clear();

    try {
      final result = await _client.rpc('app_track_events_batch', params: {
        'p_visitor_id': visitorId,
        'p_platform': _platform,
        'p_events': batch,
      });
      if (result is Map && result['success'] != true) {
        debugPrint('[Analytics] batch rejete: ${result['error']}');
      }
    } catch (e) {
      debugPrint('[Analytics] Error flushing batch: $e');
      // On ne remet pas en file : mieux vaut perdre quelques événements
      // que de gonfler la mémoire en cas de panne réseau prolongée.
    }
  }

  /// Force l'envoi (logout, mise en arrière-plan de l'app).
  Future<void> flush() async {
    _flushCurrentScreenDuration();
    await _flushBatch();
  }

  void dispose() {
    _batchTimer?.cancel();
    _flushBatch();
  }
}
