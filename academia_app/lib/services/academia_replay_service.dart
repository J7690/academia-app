import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Modèle de replay pour une session terminée.
class AcademiaReplay {
  final String sessionId;
  final String title;
  final String replayUrl;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final String hostName;
  final int participantCount;
  final int quizCount;
  final int messageCount;

  AcademiaReplay({
    required this.sessionId,
    required this.title,
    required this.replayUrl,
    this.startedAt,
    this.endedAt,
    required this.durationSeconds,
    required this.hostName,
    required this.participantCount,
    required this.quizCount,
    required this.messageCount,
  });

  factory AcademiaReplay.fromJson(Map<String, dynamic> json) {
    return AcademiaReplay(
      sessionId: json['session_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      replayUrl: json['replay_url']?.toString() ?? '',
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'].toString())
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.tryParse(json['ended_at'].toString())
          : null,
      durationSeconds: (json['duration_seconds'] as int?) ?? 0,
      hostName: json['host_name']?.toString() ?? '',
      participantCount: (json['participant_count'] as int?) ?? 0,
      quizCount: (json['quiz_count'] as int?) ?? 0,
      messageCount: (json['message_count'] as int?) ?? 0,
    );
  }
}

/// Événement sur la timeline du replay.
class ReplayTimelineEvent {
  final String type;
  final DateTime time;
  final int offsetSeconds;
  final Map<String, dynamic> data;

  ReplayTimelineEvent({
    required this.type,
    required this.time,
    required this.offsetSeconds,
    required this.data,
  });

  factory ReplayTimelineEvent.fromJson(Map<String, dynamic> json) {
    final data = json['event_data'] is Map<String, dynamic>
        ? json['event_data'] as Map<String, dynamic>
        : <String, dynamic>{};
    return ReplayTimelineEvent(
      type: json['event_type']?.toString() ?? '',
      time: DateTime.tryParse(json['event_time']?.toString() ?? '') ??
          DateTime.now(),
      offsetSeconds: (data['offset_seconds'] as int?) ?? 0,
      data: data,
    );
  }
}

/// Service de replay intelligent pour AcademiaSession.
class AcademiaReplayService {
  AcademiaReplayService._();
  static final instance = AcademiaReplayService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Charge les infos de replay d'une session.
  Future<AcademiaReplay?> getReplay(String sessionId) async {
    try {
      final res = await _client.rpc('app_learning_get_replay', params: {
        'p_session_id': sessionId,
      });
      if (res is List && res.isNotEmpty) {
        return AcademiaReplay.fromJson(res.first as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('[AcademiaReplay] getReplay error: $e');
      return null;
    }
  }

  /// Charge la timeline des événements.
  Future<List<ReplayTimelineEvent>> getTimeline(String sessionId) async {
    try {
      final res = await _client.rpc('app_learning_replay_timeline', params: {
        'p_session_id': sessionId,
      });
      if (res is List) {
        return res
            .map((e) =>
                ReplayTimelineEvent.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.offsetSeconds.compareTo(b.offsetSeconds));
      }
      return [];
    } catch (e) {
      debugPrint('[AcademiaReplay] getTimeline error: $e');
      return [];
    }
  }
}
