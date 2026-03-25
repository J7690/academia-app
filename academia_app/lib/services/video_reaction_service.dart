import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Emoji reaction types available on videos.
enum VideoReactionType {
  like('like', '\u2764\uFE0F'),
  fire('fire', '\uD83D\uDD25'),
  clap('clap', '\uD83D\uDC4F'),
  brain('brain', '\uD83E\uDDE0'),
  rocket('rocket', '\uD83D\uDE80'),
  eyes('eyes', '\uD83D\uDE0D');

  final String value;
  final String emoji;
  const VideoReactionType(this.value, this.emoji);
}

/// Service for managing emoji reactions on videos.
class VideoReactionService {
  VideoReactionService._();

  static final SupabaseClient _client = Supabase.instance.client;

  /// Toggle a reaction on a video (add or remove).
  /// Returns the updated reaction counts and action taken.
  static Future<Map<String, dynamic>?> toggleReaction({
    required String videoId,
    required VideoReactionType reactionType,
    String? participationId,
  }) async {
    try {
      final response = await _client.rpc(
        'app_student_toggle_video_reaction',
        params: {
          'p_video_id': videoId,
          'p_reaction_type': reactionType.value,
          'p_participation_id': participationId,
        },
      );

      if (response is Map<String, dynamic> && response['success'] == true) {
        debugPrint('[VideoReaction] ${response['action']} ${reactionType.value} on $videoId (count=${response['count']})');
        return response;
      }
      return null;
    } catch (e) {
      debugPrint('[VideoReaction] Toggle error: $e');
      return null;
    }
  }

  /// Get all reactions for a video.
  static Future<Map<String, dynamic>?> getReactions(String videoId) async {
    try {
      final response = await _client.rpc(
        'app_student_get_video_reactions',
        params: {'p_video_id': videoId},
      );

      if (response is Map<String, dynamic> && response['success'] == true) {
        return response;
      }
      return null;
    } catch (e) {
      debugPrint('[VideoReaction] Get reactions error: $e');
      return null;
    }
  }

  /// Log a share event.
  static Future<bool> logShare({
    required String videoId,
    String? participationId,
    String shareTarget = 'native',
  }) async {
    try {
      final response = await _client.rpc(
        'app_student_log_video_share',
        params: {
          'p_video_id': videoId,
          'p_participation_id': participationId,
          'p_share_target': shareTarget,
        },
      );

      if (response is Map<String, dynamic> && response['success'] == true) {
        debugPrint('[VideoReaction] Share logged for $videoId ($shareTarget)');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[VideoReaction] Log share error: $e');
      return false;
    }
  }
}
