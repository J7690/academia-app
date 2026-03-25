import 'dart:collection';

import 'package:flutter/foundation.dart';

/// In-memory LRU cache for video playback manifests and resolved URLs.
/// Avoids repeated RPC calls for the same video asset or direct URL.
class VideoCacheService {
  VideoCacheService._();

  static const int _maxManifestEntries = 100;
  static const int _maxUrlEntries = 200;
  static const Duration _manifestTtl = Duration(minutes: 15);
  static const Duration _urlTtl = Duration(minutes: 30);

  // Manifest cache: videoAssetId -> { manifest, timestamp }
  static final LinkedHashMap<String, _CacheEntry<Map<String, dynamic>>> _manifestCache =
      LinkedHashMap<String, _CacheEntry<Map<String, dynamic>>>();

  // URL resolution cache: rawUrl -> { resolvedUrl, timestamp }
  static final LinkedHashMap<String, _CacheEntry<String>> _urlCache =
      LinkedHashMap<String, _CacheEntry<String>>();

  // Best URL cache: participationId/videoId -> best playback URL
  static final LinkedHashMap<String, _CacheEntry<String>> _bestUrlCache =
      LinkedHashMap<String, _CacheEntry<String>>();

  /// Get cached manifest for a video asset ID.
  static Map<String, dynamic>? getManifest(String videoAssetId) {
    final entry = _manifestCache[videoAssetId];
    if (entry == null) return null;
    if (_isExpired(entry.timestamp, _manifestTtl)) {
      _manifestCache.remove(videoAssetId);
      return null;
    }
    // Move to end (LRU)
    _manifestCache.remove(videoAssetId);
    _manifestCache[videoAssetId] = entry;
    return entry.value;
  }

  /// Cache a manifest for a video asset ID.
  static void putManifest(String videoAssetId, Map<String, dynamic> manifest) {
    _manifestCache[videoAssetId] = _CacheEntry(manifest, DateTime.now());
    _evictIfNeeded(_manifestCache, _maxManifestEntries);
    debugPrint('[VideoCacheService] Cached manifest for $videoAssetId');
  }

  /// Get cached resolved URL for a raw URL.
  static String? getResolvedUrl(String rawUrl) {
    final entry = _urlCache[rawUrl];
    if (entry == null) return null;
    if (_isExpired(entry.timestamp, _urlTtl)) {
      _urlCache.remove(rawUrl);
      return null;
    }
    _urlCache.remove(rawUrl);
    _urlCache[rawUrl] = entry;
    return entry.value;
  }

  /// Cache a resolved URL.
  static void putResolvedUrl(String rawUrl, String resolvedUrl) {
    _urlCache[rawUrl] = _CacheEntry(resolvedUrl, DateTime.now());
    _evictIfNeeded(_urlCache, _maxUrlEntries);
  }

  /// Get the best playback URL for a video identifier (participationId or videoId).
  static String? getBestUrl(String videoId) {
    final entry = _bestUrlCache[videoId];
    if (entry == null) return null;
    if (_isExpired(entry.timestamp, _urlTtl)) {
      _bestUrlCache.remove(videoId);
      return null;
    }
    _bestUrlCache.remove(videoId);
    _bestUrlCache[videoId] = entry;
    return entry.value;
  }

  /// Cache the best playback URL for a video identifier.
  static void putBestUrl(String videoId, String url) {
    _bestUrlCache[videoId] = _CacheEntry(url, DateTime.now());
    _evictIfNeeded(_bestUrlCache, _maxUrlEntries);
  }

  /// Clear all caches.
  static void clearAll() {
    _manifestCache.clear();
    _urlCache.clear();
    _bestUrlCache.clear();
    debugPrint('[VideoCacheService] All caches cleared');
  }

  /// Get cache stats for debugging.
  static Map<String, int> get stats => {
    'manifests': _manifestCache.length,
    'urls': _urlCache.length,
    'bestUrls': _bestUrlCache.length,
  };

  static bool _isExpired(DateTime timestamp, Duration ttl) {
    return DateTime.now().difference(timestamp) > ttl;
  }

  static void _evictIfNeeded<T>(LinkedHashMap<String, _CacheEntry<T>> cache, int maxSize) {
    while (cache.length > maxSize) {
      cache.remove(cache.keys.first);
    }
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime timestamp;
  const _CacheEntry(this.value, this.timestamp);
}
