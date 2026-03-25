import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for tracking video analytics: views, watch time, heatmaps, retention.
/// Fires events to Supabase RPCs in a non-blocking manner.
class VideoAnalyticsService {
  VideoAnalyticsService._();

  static final SupabaseClient _client = Supabase.instance.client;

  // Heatmap: batch position events to reduce RPC calls
  static const int _heatmapIntervalMs = 5000; // Report every 5 seconds
  static Timer? _heatmapTimer;
  static String? _activeVideoId;
  static int _lastReportedPositionMs = -1;
  static int _watchStartMs = 0;
  static DateTime? _watchStartTime;

  /// Call when a video starts playing in the feed.
  static void onVideoStarted({
    required String videoId,
    String videoType = 'challenge',
    String? participationId,
    String? qualitySelected,
    String source = 'feed',
  }) {
    // End previous tracking if any
    if (_activeVideoId != null && _activeVideoId != videoId) {
      onVideoStopped();
    }

    _activeVideoId = videoId;
    _watchStartMs = 0;
    _lastReportedPositionMs = -1;
    _watchStartTime = DateTime.now();

    // Start heatmap timer
    _heatmapTimer?.cancel();
    _heatmapTimer = Timer.periodic(
      const Duration(milliseconds: _heatmapIntervalMs),
      (_) => _reportHeatmapTick(),
    );

    debugPrint('[VideoAnalytics] Started tracking: videoId=$videoId type=$videoType');
  }

  /// Call periodically to update the current watch position.
  static void updatePosition(int positionMs) {
    _watchStartMs = positionMs;
  }

  /// Call when a video stops playing (swipe, pause, leave).
  static void onVideoStopped({
    int? totalDurationMs,
    String? qualitySelected,
  }) {
    _heatmapTimer?.cancel();
    _heatmapTimer = null;

    final videoId = _activeVideoId;
    if (videoId == null) return;

    final watchDurationMs = _watchStartTime != null
        ? DateTime.now().difference(_watchStartTime!).inMilliseconds
        : 0;

    // Log view event (fire-and-forget)
    _logVideoView(
      videoId: videoId,
      watchDurationMs: watchDurationMs,
      totalDurationMs: totalDurationMs ?? 0,
      qualitySelected: qualitySelected,
    );

    debugPrint('[VideoAnalytics] Stopped tracking: videoId=$videoId watchMs=$watchDurationMs');

    _activeVideoId = null;
    _watchStartTime = null;
    _lastReportedPositionMs = -1;
  }

  /// Log a video view event to Supabase.
  static Future<void> _logVideoView({
    required String videoId,
    required int watchDurationMs,
    int totalDurationMs = 0,
    String videoType = 'challenge',
    String? participationId,
    String? qualitySelected,
    String source = 'feed',
  }) async {
    // Skip very short views (< 1 second)
    if (watchDurationMs < 1000) return;

    try {
      await _client.rpc('app_student_log_video_view', params: {
        'p_video_id': videoId,
        'p_video_type': videoType,
        'p_participation_id': participationId,
        'p_watch_duration_ms': watchDurationMs,
        'p_total_duration_ms': totalDurationMs,
        'p_quality_selected': qualitySelected,
        'p_source': source,
      });
    } catch (e) {
      debugPrint('[VideoAnalytics] Failed to log view: $e');
    }
  }

  /// Report heatmap position tick.
  static void _reportHeatmapTick() {
    final videoId = _activeVideoId;
    if (videoId == null) return;

    final positionMs = _watchStartMs;
    // Skip if position hasn't changed significantly
    if ((_lastReportedPositionMs - positionMs).abs() < 2000) return;
    _lastReportedPositionMs = positionMs;

    _logHeatmapEvent(videoId: videoId, positionMs: positionMs);
  }

  /// Log a heatmap position event.
  static Future<void> _logHeatmapEvent({
    required String videoId,
    required int positionMs,
    String eventType = 'watch',
  }) async {
    try {
      await _client.rpc('app_student_log_heatmap_event', params: {
        'p_video_id': videoId,
        'p_position_ms': positionMs,
        'p_event_type': eventType,
      });
    } catch (e) {
      debugPrint('[VideoAnalytics] Failed to log heatmap: $e');
    }
  }

  /// Log a seek event (user scrubbed to a position).
  static Future<void> logSeekEvent({
    required String videoId,
    required int positionMs,
  }) async {
    await _logHeatmapEvent(
      videoId: videoId,
      positionMs: positionMs,
      eventType: 'seek',
    );
  }

  /// Fetch analytics for a specific video.
  static Future<Map<String, dynamic>?> getVideoAnalytics(String videoId) async {
    try {
      final response = await _client.rpc(
        'app_student_get_video_analytics',
        params: {'p_video_id': videoId},
      );

      if (response is Map<String, dynamic> && response['success'] == true) {
        return response;
      }
      return null;
    } catch (e) {
      debugPrint('[VideoAnalytics] Failed to get analytics: $e');
      return null;
    }
  }

  /// Cleanup on app disposal.
  static void dispose() {
    onVideoStopped();
  }
}
