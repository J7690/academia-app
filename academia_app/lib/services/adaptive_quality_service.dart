import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Selects the optimal video quality based on network conditions.
/// Monitors connectivity changes and adjusts preferred rendition accordingly.
class AdaptiveQualityService {
  AdaptiveQualityService._();

  static VideoQuality _currentQuality = VideoQuality.auto;
  static VideoQuality _networkBasedQuality = VideoQuality.medium;
  static StreamSubscription<List<ConnectivityResult>>? _subscription;
  static bool _initialized = false;

  /// Initialize the service and start monitoring connectivity.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Check initial connectivity
    await _updateQualityFromConnectivity();

    // Listen for changes
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      _updateQualityFromResults(results);
    });

    debugPrint('[AdaptiveQuality] Initialized: quality=$_networkBasedQuality');
  }

  /// Dispose the service.
  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }

  /// Get the current preferred quality.
  static VideoQuality get currentQuality =>
      _currentQuality == VideoQuality.auto ? _networkBasedQuality : _currentQuality;

  /// Override the automatic quality selection.
  static void setManualQuality(VideoQuality quality) {
    _currentQuality = quality;
    debugPrint('[AdaptiveQuality] Manual quality set: $quality');
  }

  /// Reset to automatic quality selection.
  static void setAutoQuality() {
    _currentQuality = VideoQuality.auto;
    debugPrint('[AdaptiveQuality] Auto quality enabled');
  }

  /// Select the best URL from a video's renditions map based on current quality.
  static String? selectBestUrl(Map<String, dynamic> renditions) {
    final quality = currentQuality;

    // Priority order based on quality preference
    final List<String> keys;
    switch (quality) {
      case VideoQuality.high:
        keys = ['1080p', '720p', '480p', 'default', 'legacy_primary'];
      case VideoQuality.medium:
        keys = ['480p', '720p', 'default', 'legacy_primary', '240p'];
      case VideoQuality.low:
        keys = ['240p', '480p', 'default', 'legacy_primary'];
      case VideoQuality.auto:
        keys = ['480p', '720p', 'default', 'legacy_primary', '240p'];
    }

    for (final key in keys) {
      final url = renditions[key]?.toString() ?? '';
      if (url.isNotEmpty && url.startsWith('http')) {
        debugPrint('[AdaptiveQuality] Selected $key for quality=$quality');
        return url;
      }
    }

    // Fallback: use any available URL
    for (final value in renditions.values) {
      final url = value?.toString() ?? '';
      if (url.isNotEmpty && url.startsWith('http')) {
        return url;
      }
    }

    return null;
  }

  /// Select the best URL from a video feed item map.
  static String selectBestUrlFromVideo(Map<String, dynamic> video) {
    // 1. Try playback.best_url
    final playback = video['playback'];
    if (playback is Map) {
      final bestUrl = playback['best_url']?.toString().trim() ?? '';
      if (bestUrl.isNotEmpty) return bestUrl;
    }

    // 2. Try video_renditions with adaptive selection
    final renditions = video['video_renditions'];
    if (renditions is Map) {
      final selected = selectBestUrl(Map<String, dynamic>.from(renditions));
      if (selected != null && selected.isNotEmpty) return selected;
    }

    // 3. Fallback to direct video_url
    return video['video_url']?.toString().trim() ?? '';
  }

  static Future<void> _updateQualityFromConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _updateQualityFromResults(results);
    } catch (e) {
      debugPrint('[AdaptiveQuality] Connectivity check failed: $e');
    }
  }

  static void _updateQualityFromResults(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      _networkBasedQuality = VideoQuality.high;
    } else if (results.contains(ConnectivityResult.mobile)) {
      _networkBasedQuality = VideoQuality.medium;
    } else if (results.contains(ConnectivityResult.none)) {
      _networkBasedQuality = VideoQuality.low;
    } else {
      _networkBasedQuality = VideoQuality.medium;
    }
    debugPrint('[AdaptiveQuality] Network quality updated: $_networkBasedQuality (from $results)');
  }
}

enum VideoQuality {
  auto,
  high,
  medium,
  low,
}
