import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';

/// Service pour le monitoring et le déploiement en production
class MonitoringService {
  static final Uuid _uuid = Uuid();
  static final Map<String, Timer> _timers = {};
  static final Map<String, DateTime> _sessionStarts = {};
  static final Map<String, Map<String, dynamic>> _metrics = {};
  static final List<PerformanceMetric> _metricBuffer = [];
  static const int _maxBufferSize = 100;
  
  static bool _isInitialized = false;
  static String? _sessionId;
  static String? _userId;
  static PackageInfo? _packageInfo;
  static DeviceInfoPlugin? _deviceInfo;
  
  /// Initialiser le service de monitoring
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialiser Sentry
      await SentryFlutter.init(
        dsn: 'https://your-sentry-dsn@sentry.io/project-id',
        options: const SentryOptions(
          tracesSampleRate: 1.0,
          profilesSampleRate: 1.0,
          environment: 'production',
        ),
      );
      
      // Initialiser Firebase
      await FirebaseAnalytics.instance.logAppOpen();
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      
      // Obtenir les infos device
      _packageInfo = await PackageInfo.fromPlatform();
      _deviceInfo = DeviceInfoPlugin();
      
      // Générer un ID de session
      _sessionId = _uuid.v4();
      _userId = Supabase.instance.client.auth.currentUser?.id;
      
      // Enregistrer le début de session
      await _recordSessionStart();
      
      _isInitialized = true;
      print('MonitoringService initialisé avec succès');
    } catch (e) {
      print('Erreur initialisation MonitoringService: $e');
      await _recordError('initialization_error', e.toString(), StackTrace.current);
    }
  }
  
  /// Enregistrer une métrique de performance
  static Future<void> recordMetric({
    required String metricType,
    required String metricName,
    required double metricValue,
    String? unit,
    String? screenName,
    String? actionName,
    Map<String, dynamic>? contextData,
  }) async {
    try {
      final metric = PerformanceMetric(
        id: _uuid.v4(),
        metricType: metricType,
        metricName: metricName,
        metricValue: metricValue,
        unit: unit,
        platform: Platform.operatingSystem,
        appVersion: _packageInfo?.version,
        deviceModel: await _getDeviceModel(),
        osVersion: await _getOSVersion(),
        networkType: await _getNetworkType(),
        batteryLevel: await _getBatteryLevel(),
        memoryUsageMb: await _getMemoryUsage(),
        cpuUsage: await _getCPUUsage(),
        sessionId: _sessionId,
        userId: _userId,
        screenName: screenName,
        actionName: actionName,
        contextData: contextData ?? {},
        createdAt: DateTime.now(),
      );
      
      // Ajouter au buffer
      _metricBuffer.add(metric);
      
      // Envoyer à Sentry si le buffer est plein
      if (_metricBuffer.length >= _maxBufferSize) {
        await _flushMetricBuffer();
      }
      
      // Sauvegarder dans Supabase
      await _saveMetricToSupabase(metric);
      
      // Envoyer à Firebase Performance
      await _recordFirebasePerformance(metric);
      
    } catch (e) {
      print('Erreur enregistrement métrique: $e');
    }
  }
  
  /// Démarrer un timer pour mesurer la durée
  static String startTimer(String timerName) {
    final timerId = _uuid.v4();
    _timers[timerId] = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Timer actif
    });
    _sessionStarts[timerId] = DateTime.now();
    
    return timerId;
  }
  
  /// Arrêter un timer et enregistrer la durée
  static Future<void> stopTimer(String timerId, String metricName) async {
    final startTime = _sessionStarts[timerId];
    final timer = _timers[timerId];
    
    if (startTime != null && timer != null) {
      timer.cancel();
      _timers.remove(timerId);
      _sessionStarts.remove(timerId);
      
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      
      await recordMetric(
        metricType: 'timer',
        metricName: metricName,
        metricValue: duration.toDouble(),
        unit: 'ms',
      );
    }
  }
  
  /// Enregistrer une erreur
  static Future<void> recordError(
    String errorType,
    String errorMessage,
    StackTrace? stackTrace, {
    String? screenName,
    String? actionName,
    Map<String, dynamic>? contextData,
  }) async {
    try {
      // Envoyer à Sentry
      await Sentry.captureException(
        Exception(errorMessage),
        stackTrace: stackTrace,
        hint: errorType,
      );
      
      // Envoyer à Firebase Crashlytics
      await FirebaseCrashlytics.instance.recordError(
        Exception(errorMessage),
        stackTrace,
        fatal: errorType == 'crash',
        information: [
          DiagnosticsProperty('error_type', errorType),
          DiagnosticsProperty('screen_name', screenName),
          DiagnosticsProperty('action_name', actionName),
          if (contextData != null) ...contextData.entries.map((e) => DiagnosticsProperty(e.key, e.value)),
        ],
      );
      
      // Sauvegarder dans Supabase
      await _saveErrorToSupabase(
        errorType: errorType,
        errorMessage: errorMessage,
        stackTrace: stackTrace?.toString(),
        screenName: screenName,
        actionName: actionName,
        contextData: contextData,
      );
      
    } catch (e) {
      print('Erreur enregistrement erreur: $e');
    }
  }
  
  /// Enregistrer un crash d'application
  static Future<void> recordCrash({
    required String crashType,
    required String errorMessage,
    required String stackTrace,
    String? screenName,
    String? actionName,
    Map<String, dynamic>? contextData,
  }) async {
    try {
      final crashId = _uuid.v4();
      
      // Envoyer à Sentry
      await Sentry.captureMessage(
        'App Crash: $crashType',
        level: SentryLevel.fatal,
      );
      
      // Envoyer à Firebase Crashlytics
      await FirebaseCrashlytics.instance.recordError(
        Exception(errorMessage),
        null,
        fatal: true,
        information: [
          DiagnosticsProperty('crash_type', crashType),
          DiagnosticsProperty('crash_id', crashId),
          DiagnosticsProperty('screen_name', screenName),
          DiagnosticsProperty('action_name', actionName),
          if (contextData != null) ...contextData.entries.map((e) => DiagnosticsProperty(e.key, e.value)),
        ],
      );
      
      // Sauvegarder dans Supabase
      await _saveCrashToSupabase(
        crashId: crashId,
        crashType: crashType,
        errorMessage: errorMessage,
        stackTrace: stackTrace,
        screenName: screenName,
        actionName: actionName,
        contextData: contextData,
      );
      
    } catch (e) {
      print('Erreur enregistrement crash: $e');
    }
  }
  
  /// Enregistrer une métrique API
  static Future<void> recordAPIMetric({
    required String endpoint,
    required String method,
    required int statusCode,
    required int responseTimeMs,
    int? requestSizeBytes,
    int? responseSizeBytes,
    String? errorMessage,
    bool? cacheHit,
    Map<String, dynamic>? contextData,
  }) async {
    try {
      await recordMetric(
        metricType: 'api_response',
        metricName: '${method} ${endpoint}',
        metricValue: responseTimeMs.toDouble(),
        unit: 'ms',
        contextData: {
          'endpoint': endpoint,
          'method': method,
          'status_code': statusCode,
          'request_size_bytes': requestSizeBytes,
          'response_size_bytes': responseSizeBytes,
          'cache_hit': cacheHit,
          'error_message': errorMessage,
          ...?contextData,
        },
      );
      
      // Sauvegarder dans Supabase
      await _saveAPIMetricToSupabase(
        endpoint: endpoint,
        method: method,
        statusCode: statusCode,
        responseTimeMs: responseTimeMs,
        requestSizeBytes: requestSizeBytes,
        responseSizeBytes: responseSizeBytes,
        errorMessage: errorMessage,
        cacheHit: cacheHit,
        contextData: contextData,
      );
      
    } catch (e) {
      print('Erreur enregistrement métrique API: $e');
    }
  }
  
  /// Enregistrer un événement utilisateur
  static Future<void> recordUserEvent({
    required String eventName,
    Map<String, dynamic>? parameters,
    String? screenName,
    String? actionName,
  }) async {
    try {
      // Envoyer à Firebase Analytics
      await FirebaseAnalytics.instance.logEvent(
        eventName,
        parameters,
      );
      
      // Sauvegarder dans Supabase
      await _saveUserEventToSupabase(
        eventName: eventName,
        parameters: parameters,
        screenName: screenName,
        actionName: actionName,
      );
      
    } catch (e) {
      print('Erreur enregistrement événement utilisateur: $e');
    }
  }
  
  /// Vérifier si un feature flag est activé
  static Future<bool> isFeatureEnabled(String flagKey) async {
    try {
      final result = await Supabase.instance.client
          .from('feature_flags')
          .select('is_enabled, rollout_percentage, target_users, target_platforms, target_versions, conditions')
          .eq('flag_key', flagKey)
          .maybeSingle();
      
      if (result == null) return false;
      
      final isEnabled = result['is_enabled'] ?? false;
      final rolloutPercentage = (result['rollout_percentage'] ?? 0.0).toDouble();
      final targetUsers = List<String>.from(jsonDecode(result['target_users'] ?? '[]'));
      final targetPlatforms = List<String>.from(jsonDecode(result['target_platforms'] ?? '[]'));
      final targetVersions = List<String>.from(jsonDecode(result['target_versions'] ?? '[]'));
      final conditions = jsonDecode(result['conditions'] ?? '{}');
      
      if (!isEnabled) return false;
      
      // Vérifier si l'utilisateur est dans la cible
      if (_userId != null && targetUsers.contains(_userId)) {
        return true;
      }
      
      // Vérifier si la plateforme est dans la cible
      final currentPlatform = Platform.operatingSystem;
      if (targetPlatforms.isNotEmpty && !targetPlatforms.contains(currentPlatform)) {
        return false;
      }
      
      // Vérifier si la version est dans la cible
      if (targetVersions.isNotEmpty && _packageInfo != null) {
        if (!targetVersions.contains(_packageInfo!.version)) {
          return false;
        }
      }
      
      // Vérifier les conditions personnalisées
      if (!_evaluateConditions(conditions)) {
        return false;
      }
      
      // Vérifier le pourcentage de rollout
      if (rolloutPercentage < 100.0) {
        final hash = _generateUserHash(flagKey);
        return (hash % 100) < rolloutPercentage;
      }
      
      return true;
    } catch (e) {
      print('Erreur vérification feature flag: $e');
      return false;
    }
  }
  
  /// Assigner un utilisateur à un test A/B
  static Future<String?> assignABTest(String testName) async {
    try {
      final result = await Supabase.instance.client
          .from('a_b_tests')
          .select('id, variant_a, variant_b, traffic_split, target_audience, is_active')
          .eq('test_name', testName)
          .eq('is_active', true)
          .maybeSingle();
      
      if (result == null) return null;
      
      final trafficSplit = (result['traffic_split'] ?? 50.0).toDouble();
      final hash = _generateUserHash(testName);
      
      final variant = (hash % 100) < trafficSplit ? 'control' : 'variant_b';
      
      // Sauvegarder l'assignation
      await Supabase.instance.client
          .from('ab_test_results')
          .insert({
            'test_id': result['id'],
            'user_id': _userId,
            'variant': variant,
            'session_id': _sessionId,
            'platform': Platform.operatingSystem,
            'app_version': _packageInfo?.version,
            'assigned_at': DateTime.now().toIso8601String(),
          });
      
      return variant;
    } catch (e) {
      print('Erreur assignation A/B test: $e');
      return null;
    }
  }
  
  /// Enregistrer une conversion A/B test
  static Future<void> recordABTestConversion({
    required String testId,
    required String conversionEvent,
    double? conversionValue,
    Map<String, dynamic>? engagementMetrics,
    Map<String, dynamic>? performanceMetrics,
  }) async {
    try {
      await Supabase.instance.client
          .from('ab_test_results')
          .update({
            'conversion_event': conversionEvent,
            'conversion_value': conversionValue,
            'engagement_metrics': jsonEncode(engagementMetrics ?? {}),
            'performance_metrics': jsonEncode(performanceMetrics ?? {}),
            'created_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', _userId)
          .eq('test_id', testId);
      
      // Envoyer à Firebase Analytics
      await FirebaseAnalytics.instance.logEvent(
        'ab_test_conversion',
        parameters: {
          'test_id': testId,
          'conversion_event': conversionEvent,
          'conversion_value': conversionValue,
        },
      );
      
    } catch (e) {
      print('Erreur enregistrement conversion A/B test: $e');
    }
  }
  
  /// Obtenir les métriques de santé système
  static Future<List<SystemHealthMetric>> getSystemHealth() async {
    try {
      final result = await Supabase.instance.client
          .from('system_health')
          .select()
          .order('health_status')
          .order('response_time_ms');
      
      return result.map((json) => SystemHealthMetric.fromJson(json)).toList();
    } catch (e) {
      print('Erreur récupération santé système: $e');
      return [];
    }
  }
  
  /// Obtenir les métriques de performance
  static Future<List<PerformanceMetric>> getPerformanceMetrics({
    String? metricType,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      var query = Supabase.instance.client
          .from('performance_metrics')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      
      if (metricType != null) {
        query = query.eq('metric_type', metricType);
      }
      
      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }
      
      final result = await query;
      return result.map((json) => PerformanceMetric.fromJson(json)).toList();
    } catch (e) {
      print('Erreur récupération métriques performance: $e');
      return [];
    }
  }
  
  /// Obtenir les logs de déploiement
  static Future<List<DeploymentLog>> getDeploymentLogs({int limit = 50}) async {
    try {
      final result = await Supabase.instance.client
          .from('deployment_logs')
          .select()
          .order('started_at', ascending: false)
          .limit(limit);
      
      return result.map((json) => DeploymentLog.fromJson(json)).toList();
    } catch (e) {
      print('Erreur récupération logs de déploiement: $e');
      return [];
    }
  }
  
  /// Obtenir les statistiques de monitoring
  static Future<MonitoringStats> getMonitoringStats() async {
    try {
      final systemHealth = await getSystemHealth();
      final performanceMetrics = await getPerformanceMetrics();
      final deploymentLogs = await getDeploymentLogs(limit: 10);
      
      final healthyServices = systemHealth.where((h) => h.healthStatus == 'healthy').length;
      final totalServices = systemHealth.length;
      
      final avgResponseTime = systemHealth.isNotEmpty
          ? systemHealth.map((h) => h.responseTimeMs).reduce((a, b) => a + b) / systemHealth.length
          : 0.0;
      
      final totalErrors = performanceMetrics.where((m) => m.metricType == 'error').length;
      final totalMetrics = performanceMetrics.length;
      
      return MonitoringStats(
        healthyServices: healthyServices,
        totalServices: totalServices,
        avgResponseTime: avgResponseTime,
        totalErrors: totalErrors,
        totalMetrics: totalMetrics,
        recentDeployments: deploymentLogs.length,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      print('Erreur statistiques monitoring: $e');
      rethrow;
    }
  }
  
  /// Vider le buffer de métriques
  static Future<void> _flushMetricBuffer() async {
    try {
      for (final metric in _metricBuffer) {
        await _saveMetricToSupabase(metric);
      }
      _metricBuffer.clear();
    } catch (e) {
      print('Erreur vidange buffer métriques: $e');
    }
  }
  
  /// Enregistrer le début de session
  static Future<void> _recordSessionStart() async {
    try {
      await recordUserEvent(
        eventName: 'session_start',
        parameters: {
          'session_id': _sessionId,
          'platform': Platform.operatingSystem,
          'app_version': _packageInfo?.version,
        },
      );
    } catch (e) {
      print('Erreur enregistrement début session: $e');
    }
  }
  
  /// Enregistrer une métrique Firebase Performance
  static Future<void> _recordFirebasePerformance(PerformanceMetric metric) async {
    try {
      final trace = FirebasePerformance.instance.newTrace(metric.metricName);
      
      await trace.putMetric(
        metric.metricName,
        metric.metricValue.toInt(),
        metric.unit ?? 'ms',
      );
      
      await trace.stop();
    } catch (e) {
      print('Erreur Firebase Performance: $e');
    }
  }
  
  /// Sauvegarder une métrique dans Supabase
  static Future<void> _saveMetricToSupabase(PerformanceMetric metric) async {
    try {
      await Supabase.instance.client
          .from('performance_metrics')
          .insert(metric.toJson());
    } catch (e) {
      print('Erreur sauvegarde métrique Supabase: $e');
    }
  }
  
  /// Sauvegarder une erreur dans Supabase
  static Future<void> _saveErrorToSupabase({
    required String errorType,
    required String errorMessage,
    String? stackTrace,
    String? screenName,
    String? actionName,
    Map<String, dynamic>? contextData,
  }) async {
    try {
      await Supabase.instance.client
          .from('error_logs')
          .insert({
            'error_type': errorType,
            'error_message': errorMessage,
            'stack_trace': stackTrace,
            'platform': Platform.operatingSystem,
            'app_version': _packageInfo?.version,
            'device_model': await _getDeviceModel(),
            'os_version': await _getOSVersion(),
            'user_id': _userId,
            'session_id': _sessionId,
            'screen_name': screenName,
            'action_name': actionName,
            'context_data': jsonEncode(contextData ?? {}),
            'created_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      print('Erreur sauvegarde erreur Supabase: $e');
    }
  }
  
  /// Sauvegarder un crash dans Supabase
  static Future<void> _saveCrashToSupabase({
    required String crashId,
    required String crashType,
    required String errorMessage,
    required String stackTrace,
    String? screenName,
    String? actionName,
    Map<String, dynamic>? contextData,
  }) async {
    try {
      await Supabase.instance.client
          .from('app_crashes')
          .insert({
            'crash_id': crashId,
            'platform': Platform.operatingSystem,
            'app_version': _packageInfo?.version,
            'device_model': await _getDeviceModel(),
            'os_version': await _getOSVersion(),
            'crash_type': crashType,
            'error_message': errorMessage,
            'stack_trace': stackTrace,
            'user_id': _userId,
            'session_id': _sessionId,
            'screen_name': screenName,
            'action_name': actionName,
            'memory_usage_mb': await _getMemoryUsage(),
            'cpu_usage': await _getCPUUsage(),
            'battery_level': await _getBatteryLevel(),
            'network_type': await _getNetworkType(),
            'context_data': jsonEncode(contextData ?? {}),
            'created_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      print('Erreur sauvegarde crash Supabase: $e');
    }
  }
  
  /// Sauvegarder une métrique API dans Supabase
  static Future<void> _saveAPIMetricToSupabase({
    required String endpoint,
    required String method,
    required int statusCode,
    required int responseTimeMs,
    int? requestSizeBytes,
    int? responseSizeBytes,
    String? errorMessage,
    bool? cacheHit,
    Map<String, dynamic>? contextData,
  }) async {
    try {
      await Supabase.instance.client
          .from('api_metrics')
          .insert({
            'endpoint_path': endpoint,
            'method': method,
            'status_code': statusCode,
            'response_time_ms': responseTimeMs,
            'request_size_bytes': requestSizeBytes,
            'response_size_bytes': responseSizeBytes,
            'platform': Platform.operatingSystem,
            'app_version': _packageInfo?.version,
            'user_id': _userId,
            'session_id': _sessionId,
            'ip_address': null, // TODO: Obtenir l'IP
            'user_agent': null, // TODO: Obtenir le user agent
            'error_message': errorMessage,
            'cache_hit': cacheHit,
            'context_data': jsonEncode(contextData ?? {}),
            'created_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      print('Erreur sauvegarde métrique API Supabase: $e');
    }
  }
  
  /// Sauvegarder un événement utilisateur dans Supabase
  static Future<void> _saveUserEventToSupabase({
    required String eventName,
    Map<String, dynamic>? parameters,
    String? screenName,
    String? actionName,
  }) async {
    try {
      await Supabase.instance.client
          .from('user_behavior_tracking')
          .insert({
            'user_id': _userId,
            'session_id': _sessionId,
            'event_type': 'user_event',
            'event_name': eventName,
            'properties': jsonEncode(parameters ?? {}),
            'timestamp': DateTime.now().toIso8601String(),
            'device_info': jsonEncode({
              'platform': Platform.operatingSystem,
              'app_version': _packageInfo?.version,
              'device_model': await _getDeviceModel(),
              'os_version': await _getOSVersion(),
            }),
            'created_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      print('Erreur sauvegarde événement utilisateur Supabase: $e');
    }
  }
  
  /// Évaluer les conditions de feature flag
  static bool _evaluateConditions(Map<String, dynamic> conditions) {
    // Implémentation simplifiée - à étendre selon les besoins
    if (conditions.isEmpty) return true;
    
    // Exemple: condition basée sur l'heure de la journée
    if (conditions.containsKey('hour_range')) {
      final hourRange = conditions['hour_range'] as List<int>;
      final currentHour = DateTime.now().hour;
      return currentHour >= hourRange[0] && currentHour <= hourRange[1];
    }
    
    // Exemple: condition basée sur la date
    if (conditions.containsKey('date_range')) {
      final dateRange = conditions['date_range'] as List<String>;
      final today = DateTime.now();
      final startDate = DateTime.parse(dateRange[0]);
      final endDate = DateTime.parse(dateRange[1]);
      return today.isAfter(startDate) && today.isBefore(endDate);
    }
    
    return true;
  }
  
  /// Générer un hash utilisateur pour les tests A/B
  static int _generateUserHash(String input) {
    final bytes = utf8.encode('${_userId}_$input');
    final digest = sha256.convert(bytes);
    return digest.fold<int>(0, (sum, byte) => sum + byte) % 100;
  }
  
  /// Obtenir le modèle de device
  static Future<String> _getDeviceModel() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo!.androidInfo;
        return '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo!.iosInfo;
        return '${iosInfo.model} ${iosInfo.systemVersion}';
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }
  
  /// Obtenir la version OS
  static Future<String> _getOSVersion() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo!.androidInfo;
        return androidInfo.version.release;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo!.iosInfo;
        return iosInfo.systemVersion;
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }
  
  /// Obtenir le type de réseau
  static Future<String> _getNetworkType() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      return connectivity.name;
    } catch (e) {
      return 'unknown';
    }
  }
  
  /// Obtenir le niveau de batterie
  static Future<int> _getBatteryLevel() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo!.androidInfo;
        return androidInfo.batteryLevel ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }
  
  /// Obtenir l'utilisation mémoire
  static Future<double> _getMemoryUsage() async {
    try {
      // Simulation - à implémenter avec des packages spécifiques
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }
  
  /// Obtenir l'utilisation CPU
  static Future<double> _getCPUUsage() async {
    try {
      // Simulation - à implémenter avec des packages spécifiques
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }
  
  /// Nettoyer les ressources
  static Future<void> cleanup() async {
    try {
      // Arrêter tous les timers
      for (final timer in _timers.values) {
        timer.cancel();
      }
      _timers.clear();
      _sessionStarts.clear();
      
      // Vider le buffer
      await _flushMetricBuffer();
      
      print('MonitoringService nettoyé');
    } catch (e) {
      print('Erreur nettoyage MonitoringService: $e');
    }
  }
}

/// Métrique de performance
class PerformanceMetric {
  final String id;
  final String metricType;
  final String metricName;
  final double metricValue;
  final String? unit;
  final String platform;
  final String? appVersion;
  final String? deviceModel;
  final String? osVersion;
  final String? networkType;
  final int? batteryLevel;
  final double? memoryUsageMb;
  final double? cpuUsage;
  final String? sessionId;
  final String? userId;
  final String? screenName;
  final String? actionName;
  final Map<String, dynamic> contextData;
  final DateTime createdAt;
  
  PerformanceMetric({
    required this.id,
    required this.metricType,
    required this.metricName,
    required this.metricValue,
    this.unit,
    required this.platform,
    this.appVersion,
    this.deviceModel,
    this.osVersion,
    this.networkType,
    this.batteryLevel,
    this.memoryUsageMb,
    this.cpuUsage,
    this.sessionId,
    this.userId,
    this.screenName,
    this.actionName,
    required this.contextData,
    required this.createdAt,
  });
  
  factory PerformanceMetric.fromJson(Map<String, dynamic> json) {
    return PerformanceMetric(
      id: json['id'],
      metricType: json['metric_type'],
      metricName: json['metric_name'],
      metricValue: json['metric_value']?.toDouble() ?? 0.0,
      unit: json['unit'],
      platform: json['platform'],
      appVersion: json['app_version'],
      deviceModel: json['device_model'],
      osVersion: json['os_version'],
      networkType: json['network_type'],
      batteryLevel: json['battery_level'],
      memoryUsageMb: json['memory_usage_mb']?.toDouble(),
      cpuUsage: json['cpu_usage']?.toDouble(),
      sessionId: json['session_id'],
      userId: json['user_id'],
      screenName: json['screen_name'],
      actionName: json['action_name'],
      contextData: jsonDecode(json['context_data'] ?? '{}'),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'metric_type': metricType,
      'metric_name': metricName,
      'metric_value': metricValue,
      'unit': unit,
      'platform': platform,
      'app_version': appVersion,
      'device_model': deviceModel,
      'os_version': osVersion,
      'network_type': networkType,
      'battery_level': batteryLevel,
      'memory_usage_mb': memoryUsageMb,
      'cpu_usage': cpuUsage,
      'session_id': sessionId,
      'user_id': userId,
      'screen_name': screenName,
      'action_name': actionName,
      'context_data': jsonEncode(contextData),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Log de déploiement
class DeploymentLog {
  final String id;
  final String deploymentId;
  final String environment;
  final String version;
  final String? buildNumber;
  final String? gitCommit;
  final String deploymentType;
  final String status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int? durationSeconds;
  final String? deployedBy;
  final String? rollbackVersion;
  final String? errorMessage;
  final Map<String, dynamic> affectedModules;
  final Map<String, dynamic> deploymentMetadata;
  final DateTime createdAt;
  
  DeploymentLog({
    required this.id,
    required this.deploymentId,
    required this.environment,
    required this.version,
    this.buildNumber,
    this.gitCommit,
    required this.deploymentType,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.durationSeconds,
    this.deployedBy,
    this.rollbackVersion,
    this.errorMessage,
    required this.affectedModules,
    required this.deploymentMetadata,
    required this.createdAt,
  });
  
  factory DeploymentLog.fromJson(Map<String, dynamic> json) {
    return DeploymentLog(
      id: json['id'],
      deploymentId: json['deployment_id'],
      environment: json['environment'],
      version: json['version'],
      buildNumber: json['build_number'],
      gitCommit: json['git_commit'],
      deploymentType: json['deployment_type'],
      status: json['status'],
      startedAt: DateTime.parse(json['started_at']),
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      durationSeconds: json['duration_seconds'],
      deployedBy: json['deployed_by'],
      rollbackVersion: json['rollback_version'],
      errorMessage: json['error_message'],
      affectedModules: jsonDecode(json['affected_modules'] ?? '{}'),
      deploymentMetadata: jsonDecode(json['deployment_metadata'] ?? '{}'),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deployment_id': deploymentId,
      'environment': environment,
      'version': version,
      'build_number': buildNumber,
      'git_commit': gitCommit,
      'deployment_type': deploymentType,
      'status': status,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'duration_seconds': durationSeconds,
      'deployed_by': deployedBy,
      'rollback_version': rollbackVersion,
      'error_message': errorMessage,
      'affected_modules': jsonEncode(affectedModules),
      'deployment_metadata': jsonEncode(deploymentMetadata),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Métrique de santé système
class SystemHealthMetric {
  final String serviceName;
  final String healthStatus;
  final int responseTimeMs;
  final double errorRate;
  final double uptimePercentage;
  final double? memoryUsageMb;
  final double? cpuUsage;
  final double? diskUsageMb;
  final int? activeConnections;
  final int? databaseConnections;
  final double? cacheHitRate;
  final DateTime lastCheckAt;
  final Map<String, dynamic> healthDetails;
  final DateTime createdAt;
  
  SystemHealthMetric({
    required this.serviceName,
    required this.healthStatus,
    required this.responseTimeMs,
    required this.errorRate,
    required this.uptimePercentage,
    this.memoryUsageMb,
    this.cpuUsage,
    this.diskUsageMb,
    this.activeConnections,
    this.databaseConnections,
    this.cacheHitRate,
    required this.lastCheckAt,
    required this.healthDetails,
    required this.createdAt,
  });
  
  factory SystemHealthMetric.fromJson(Map<String, dynamic> json) {
    return SystemHealthMetric(
      serviceName: json['service_name'],
      healthStatus: json['health_status'],
      responseTimeMs: json['response_time_ms'],
      errorRate: json['error_rate']?.toDouble() ?? 0.0,
      uptimePercentage: json['uptime_percentage']?.toDouble() ?? 0.0,
      memoryUsageMb: json['memory_usage_mb']?.toDouble(),
      cpuUsage: json['cpu_usage']?.toDouble(),
      diskUsageMb: json['disk_usage_mb']?.toDouble(),
      activeConnections: json['active_connections'],
      databaseConnections: json['database_connections'],
      cacheHitRate: json['cache_hit_rate']?.toDouble(),
      lastCheckAt: DateTime.parse(json['last_check_at']),
      healthDetails: jsonDecode(json['health_details'] ?? '{}'),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'service_name': serviceName,
      'health_status': healthStatus,
      'response_time_ms': responseTimeMs,
      'error_rate': errorRate,
      'uptime_percentage': uptimePercentage,
      'memory_usage_mb': memoryUsageMb,
      'cpu_usage': cpuUsage,
      'disk_usage_mb': diskUsageMb,
      'active_connections': activeConnections,
      'database_connections': databaseConnections,
      'cache_hit_rate': cacheHitRate,
      'last_check_at': lastCheckAt.toIso8601String(),
      'health_details': jsonEncode(healthDetails),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Statistiques de monitoring
class MonitoringStats {
  final int healthyServices;
  final int totalServices;
  final double avgResponseTime;
  final int totalErrors;
  final int totalMetrics;
  final int recentDeployments;
  final DateTime lastUpdated;
  
  MonitoringStats({
    required this.healthyServices,
    required this.totalServices,
    required this.avgResponseTime,
    required this.totalErrors,
    required this.totalMetrics,
    required this.recentDeployments,
    required this.lastUpdated,
  });
}
