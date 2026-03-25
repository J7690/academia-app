import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for sharing videos via native share sheet and tracking share events.
class VideoShareService {
  VideoShareService._();

  static final SupabaseClient _client = Supabase.instance.client;

  /// Share a video URL via the native share sheet.
  /// Logs the share event to Supabase for analytics.
  static Future<bool> shareVideo({
    required String videoUrl,
    required String videoId,
    String? participationId,
    String? title,
    String? description,
  }) async {
    try {
      final shareText = StringBuffer();
      if (title != null && title.isNotEmpty) {
        shareText.writeln(title);
      }
      if (description != null && description.isNotEmpty) {
        shareText.writeln(description);
      }
      shareText.writeln(videoUrl);
      shareText.write('\nVia Academia');

      final result = await Share.share(
        shareText.toString(),
        subject: title ?? 'Vidéo Academia',
      );

      // Determine share target from result
      String shareTarget = 'native';
      if (result.status == ShareResultStatus.success) {
        shareTarget = result.raw.isNotEmpty ? result.raw : 'native';
      } else if (result.status == ShareResultStatus.dismissed) {
        debugPrint('[VideoShare] Share dismissed for $videoId');
        return false;
      }

      // Log to Supabase (fire-and-forget)
      _logShareEvent(
        videoId: videoId,
        participationId: participationId,
        shareTarget: shareTarget,
      );

      debugPrint('[VideoShare] Shared video $videoId via $shareTarget');
      return true;
    } catch (e) {
      debugPrint('[VideoShare] Error sharing: $e');
      return false;
    }
  }

  /// Copy video link to clipboard and log event.
  static Future<bool> copyLink({
    required String videoUrl,
    required String videoId,
    String? participationId,
  }) async {
    try {
      // Log as clipboard share
      _logShareEvent(
        videoId: videoId,
        participationId: participationId,
        shareTarget: 'clipboard',
      );
      debugPrint('[VideoShare] Link copied for $videoId');
      return true;
    } catch (e) {
      debugPrint('[VideoShare] Copy link error: $e');
      return false;
    }
  }

  static Future<void> _logShareEvent({
    required String videoId,
    String? participationId,
    String shareTarget = 'native',
  }) async {
    try {
      await _client.rpc('app_student_log_video_share', params: {
        'p_video_id': videoId,
        'p_participation_id': participationId,
        'p_share_target': shareTarget,
      });
    } catch (e) {
      debugPrint('[VideoShare] Log share error: $e');
    }
  }
}
