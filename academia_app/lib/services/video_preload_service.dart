import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Preloads video data for adjacent items in a feed to reduce buffering.
/// Downloads the first ~256KB of each video to warm the HTTP cache.
class VideoPreloadService {
  VideoPreloadService._();

  static const int _preloadBytes = 1024 * 1024; // 1 MB — enough for ~2s of 480p video
  static const int _maxConcurrent = 3;
  static const Duration _timeout = Duration(seconds: 8);

  static final Set<String> _preloadedUrls = {};
  static final Set<String> _inProgress = {};

  /// Preload a list of video URLs (typically the next 2-3 items in a feed).
  /// Only preloads URLs that haven't been preloaded yet.
  static Future<void> preloadUrls(List<String> urls) async {
    final toPreload = urls
        .where((url) => url.isNotEmpty && !_preloadedUrls.contains(url) && !_inProgress.contains(url))
        .take(_maxConcurrent)
        .toList();

    if (toPreload.isEmpty) return;

    debugPrint('[VideoPreload] Preloading ${toPreload.length} URLs');

    await Future.wait(
      toPreload.map((url) => _preloadSingle(url)),
      eagerError: false,
    );
  }

  /// Preload a single video URL by fetching the first bytes.
  static Future<void> _preloadSingle(String url) async {
    if (_inProgress.contains(url)) return;
    _inProgress.add(url);

    try {
      final uri = Uri.parse(url);
      final request = http.Request('GET', uri);
      request.headers['Range'] = 'bytes=0-${_preloadBytes - 1}';

      final streamedResponse = await request.send().timeout(_timeout);

      // Read partial response to warm cache
      int bytesRead = 0;
      await for (final chunk in streamedResponse.stream) {
        bytesRead += chunk.length;
        if (bytesRead >= _preloadBytes) break;
      }

      _preloadedUrls.add(url);
      debugPrint('[VideoPreload] Preloaded ${(bytesRead / 1024).toStringAsFixed(0)}KB from ${url.length > 60 ? '${url.substring(0, 60)}...' : url}');
    } catch (e) {
      debugPrint('[VideoPreload] Failed to preload: $e');
    } finally {
      _inProgress.remove(url);
    }
  }

  /// Check if a URL has been preloaded.
  static bool isPreloaded(String url) => _preloadedUrls.contains(url);

  /// Clear preload cache (e.g. on feed refresh).
  static void clear() {
    _preloadedUrls.clear();
    _inProgress.clear();
    debugPrint('[VideoPreload] Cache cleared');
  }

  /// Stats for debugging.
  static Map<String, int> get stats => {
    'preloaded': _preloadedUrls.length,
    'inProgress': _inProgress.length,
  };
}
