import 'package:flutter/material.dart';
import 'package:flame/flame.dart';
import 'package:flame_audio/flame_audio.dart';

class PerformanceManager {
  static const int targetFPS = 60;
  static const int maxMemoryMB = 100;
  
  static void optimizeForDevice() {
    // Adapter qualité graphique selon device
    final deviceInfo = _getDeviceInfo();
    
    if (deviceInfo.isLowEnd) {
      // Réduire qualité pour vieux appareils
      Flame.images.prefix = 'low_res/';
      FlameAudio.audioCache.clearAll();
      print('Performance: Optimisé pour appareil bas de gamme');
    } else if (deviceInfo.isHighEnd) {
      // Activer haute qualité pour appareils performants
      Flame.images.prefix = 'high_res/';
      print('Performance: Haute qualité activée');
    } else {
      // Qualité standard
      print('Performance: Qualité standard');
    }
  }
  
  static void monitorPerformance() {
    FlutterError.onError = (details) {
      // Log erreurs performance
      print('Performance error: ${details.exception}');
      print('Stack trace: ${details.stack}');
      
      // Envoyer à service monitoring
      _sendErrorToMonitoring(details.exception, details.stack);
    };
  }
  
  static void trackGameStart(String gameType) {
    print('Performance: Game started - $gameType');
    _sendAnalytics('game_start', {'game_type': gameType});
  }
  
  static void trackGameComplete(String gameType, int score, double duration) {
    print('Performance: Game completed - $gameType, Score: $score, Duration: ${duration}s');
    _sendAnalytics('game_complete', {
      'game_type': gameType,
      'score': score,
      'duration': duration,
    });
  }
  
  static void trackMultiplayerMatch(String result, int duration) {
    print('Performance: Multiplayer match - $result, Duration: ${duration}s');
    _sendAnalytics('multiplayer_match', {
      'result': result,
      'duration': duration,
    });
  }
  
  static DeviceInfo _getDeviceInfo() {
    // Simulation détection device
    // En production, utiliser device_info_plus
    return DeviceInfo(
      isLowEnd: false, // À implémenter avec vraie détection
      isHighEnd: true,  // À implémenter avec vraie détection
      memoryMB: 4096,  // À implémenter avec vraie détection
    );
  }
  
  static void _sendErrorToMonitoring(dynamic error, StackTrace? stack) {
    // Envoyer à service monitoring
    // Sentry, Crashlytics, etc.
    print('Monitoring: Error sent to service');
  }
  
  static void _sendAnalytics(String event, Map<String, dynamic> params) {
    // Envoyer analytics
    // Firebase Analytics, Amplitude, etc.
    print('Analytics: Event sent - $event with params: $params');
  }
}

class DeviceInfo {
  final bool isLowEnd;
  final bool isHighEnd;
  final int memoryMB;
  
  DeviceInfo({
    required this.isLowEnd,
    required this.isHighEnd,
    required this.memoryMB,
  });
}
