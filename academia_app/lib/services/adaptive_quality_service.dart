import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'video_orientation_service.dart';

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
  /// Supports both legacy keys (720p, 480p, 240p) and new worker keys (mp4_main, mp4_480p, etc.).
  static String? selectBestUrl(Map<String, dynamic> renditions) {
    final quality = currentQuality;

    // Priority order based on quality preference — includes both old and new key formats
    final List<String> keys;
    switch (quality) {
      case VideoQuality.high:
        keys = ['mp4_main', '1080p', '720p', 'mp4_480p', '480p', 'legacy_primary'];
      case VideoQuality.medium:
        keys = ['mp4_480p', '480p', 'mp4_main', '720p', 'mp4_360p', 'legacy_primary', 'mp4_240p', '240p'];
      case VideoQuality.low:
        keys = ['mp4_240p', '240p', 'mp4_360p', 'mp4_480p', '480p', 'legacy_primary'];
      case VideoQuality.auto:
        keys = ['mp4_480p', '480p', 'mp4_main', '720p', 'mp4_360p', 'legacy_primary', 'mp4_240p', '240p'];
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
  
  /// Select the best URL from a video's renditions map based on current quality and video orientation.
  /// This is P1-3: orientation-aware rendition selection.
  /// For vertical videos, prioritizes vertical-specific renditions if available.
  static String? selectBestUrlWithOrientation(
    Map<String, dynamic> renditions, 
    double videoAspectRatio,
  ) {
    final quality = currentQuality;
    final orientation = VideoOrientationService.detectFromRatio(videoAspectRatio);
    
    // For vertical videos, prioritize vertical-specific renditions
    if (orientation == VideoOrientation.vertical) {
      final verticalKeys = _getVerticalRenditionKeys(quality);
      for (final key in verticalKeys) {
        final url = renditions[key]?.toString() ?? '';
        if (url.isNotEmpty && url.startsWith('http')) {
          debugPrint('[AdaptiveQuality] Selected vertical $key for quality=$quality');
          return url;
        }
      }
    }
    
    // Fallback to standard selection
    return selectBestUrl(renditions);
  }
  
  /// Get vertical-specific rendition keys for a given quality level
  static List<String> _getVerticalRenditionKeys(VideoQuality quality) {
    switch (quality) {
      case VideoQuality.high:
        return ['mp4_vertical_1080', 'vertical_1080p', 'mp4_main', '1080p', '720p'];
      case VideoQuality.medium:
        return ['mp4_vertical_720', 'vertical_720p', 'mp4_480p', '480p', 'mp4_main'];
      case VideoQuality.low:
        return ['mp4_vertical_480', 'vertical_480p', 'mp4_240p', '240p', 'mp4_360p'];
      case VideoQuality.auto:
        return ['mp4_vertical_720', 'vertical_720p', 'mp4_480p', '480p', 'mp4_main'];
    }
  }

  /// Select the best URL from a video feed item map.
  static String selectBestUrlFromVideo(Map<String, dynamic> video) {
    final videoId = video['participation_id']?.toString() ??
        video['video_id']?.toString() ?? '?';

    // 1. Try playback.best_url
    final playback = video['playback'];
    if (playback is Map) {
      final bestUrl = playback['best_url']?.toString().trim() ?? '';
      if (bestUrl.isNotEmpty) {
        debugPrint('[AdaptiveQuality] video=$videoId → playback.best_url');
        return bestUrl;
      }
    }

    // 2. Try video_renditions with adaptive selection
    final renditions = video['video_renditions'];
    if (renditions is Map && renditions.isNotEmpty) {
      final renditionKeys = (renditions as Map).keys.toList();
      debugPrint('[AdaptiveQuality] video=$videoId renditions=$renditionKeys quality=${currentQuality}');
      final selected = selectBestUrl(Map<String, dynamic>.from(renditions));
      if (selected != null && selected.isNotEmpty) return selected;
    }

    // 3. Fallback to direct video_url
    final fallback = video['video_url']?.toString().trim() ?? '';
    if (fallback.isNotEmpty) {
      debugPrint('[AdaptiveQuality] video=$videoId → FALLBACK video_url (no renditions)');
    }
    return fallback;
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
      // WiFi: serve 720p (mp4_main)
      _networkBasedQuality = VideoQuality.high;
    } else if (results.contains(ConnectivityResult.mobile)) {
      // Mobile: serve 480p — crisp enough, fast enough (like TikTok)
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
