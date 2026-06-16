/// Academia Learning Engine — Entité session unifiée.
///
/// Représente toute activité pédagogique temps-réel :
/// cours, TD, orientation, concours, conférence, masterclass, live pédagogique.
library;

enum SessionType {
  course,
  td,
  prepConcours,
  orientation,
  conference,
  masterclass,
  livePedagogique,
  revisionCollective,
  examBlanc,
  gameChallenge,
}

enum SessionStatus {
  draft,
  scheduled,
  pendingApproval,
  approved,
  running,
  paused,
  ended,
  cancelled,
  rejected,
}

enum SessionProvider {
  livekit,
  zoom,
  meet,
  external,
}

/// Modèle unifié de session pédagogique.
class AcademiaSession {
  final String id;
  final SessionType type;
  final SessionStatus status;
  final SessionProvider provider;

  // Identité
  final String title;
  final String? description;
  final String? subject; // matière
  final String? concoursType; // cat_a, cat_b, etc.

  // Relations
  final String hostId; // user_id de l'hôte (enseignant/admin)
  final String? courseId; // lien vers online_courses si applicable
  final String? programId; // lien vers td_programs si applicable

  // Planification
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final DateTime? actualStart;
  final DateTime? actualEnd;

  // Capacité
  final int? maxParticipants;
  final int currentParticipants;

  // Configuration
  final bool isRecordingEnabled;
  final bool isWhiteboardEnabled;
  final bool isQuizEnabled;
  final bool isChatEnabled;
  final bool isScreenShareEnabled;
  final bool isHandRaiseEnabled;

  // Replay
  final String? replayUrl;
  final String? replayVideoAssetId;
  final List<SessionChapter>? chapters;

  // LiveKit
  final String? livekitRoomName;

  // Métadonnées
  final String? hostDisplayName;
  final String? thumbnailUrl;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AcademiaSession({
    required this.id,
    required this.type,
    required this.status,
    required this.provider,
    required this.title,
    this.description,
    this.subject,
    this.concoursType,
    required this.hostId,
    this.courseId,
    this.programId,
    this.scheduledStart,
    this.scheduledEnd,
    this.actualStart,
    this.actualEnd,
    this.maxParticipants,
    this.currentParticipants = 0,
    this.isRecordingEnabled = true,
    this.isWhiteboardEnabled = false,
    this.isQuizEnabled = true,
    this.isChatEnabled = true,
    this.isScreenShareEnabled = true,
    this.isHandRaiseEnabled = true,
    this.replayUrl,
    this.replayVideoAssetId,
    this.chapters,
    this.livekitRoomName,
    this.hostDisplayName,
    this.thumbnailUrl,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Crée depuis une réponse JSON Supabase.
  factory AcademiaSession.fromJson(Map<String, dynamic> json) {
    return AcademiaSession(
      id: json['id'] as String,
      type: _parseSessionType(json['session_type'] as String?),
      status: _parseStatus(json['status'] as String?),
      provider: _parseProvider(json['provider'] as String?),
      title: (json['title'] ?? '') as String,
      description: json['description'] as String?,
      subject: json['subject'] as String?,
      concoursType: json['concours_type'] as String?,
      hostId: (json['host_id'] ?? '') as String,
      courseId: json['course_id'] as String?,
      programId: json['program_id'] as String?,
      scheduledStart: _parseDateTime(json['scheduled_start']),
      scheduledEnd: _parseDateTime(json['scheduled_end']),
      actualStart: _parseDateTime(json['actual_start']),
      actualEnd: _parseDateTime(json['actual_end']),
      maxParticipants: json['max_participants'] as int?,
      currentParticipants: (json['current_participants'] as int?) ?? 0,
      isRecordingEnabled: json['is_recording_enabled'] == true,
      isWhiteboardEnabled: json['is_whiteboard_enabled'] == true,
      isQuizEnabled: json['is_quiz_enabled'] != false,
      isChatEnabled: json['is_chat_enabled'] != false,
      isScreenShareEnabled: json['is_screen_share_enabled'] != false,
      isHandRaiseEnabled: json['is_hand_raise_enabled'] != false,
      replayUrl: json['replay_url'] as String?,
      replayVideoAssetId: json['replay_video_asset_id'] as String?,
      chapters: _parseChapters(json['chapters']),
      livekitRoomName: json['livekit_room_name'] as String?,
      hostDisplayName: json['host_display_name'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : null,
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),
    );
  }

  /// Sérialise pour envoi à Supabase (upsert).
  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'session_type': type.name,
      'status': _statusToString(status),
      'provider': provider.name,
      'title': title,
      'description': description,
      'subject': subject,
      'concours_type': concoursType,
      'host_id': hostId,
      'course_id': courseId,
      'program_id': programId,
      'scheduled_start': scheduledStart?.toIso8601String(),
      'scheduled_end': scheduledEnd?.toIso8601String(),
      'max_participants': maxParticipants,
      'is_recording_enabled': isRecordingEnabled,
      'is_whiteboard_enabled': isWhiteboardEnabled,
      'is_quiz_enabled': isQuizEnabled,
      'is_chat_enabled': isChatEnabled,
      'is_screen_share_enabled': isScreenShareEnabled,
      'is_hand_raise_enabled': isHandRaiseEnabled,
      'thumbnail_url': thumbnailUrl,
      'metadata': metadata,
    };
  }

  /// Copie avec modifications.
  AcademiaSession copyWith({
    SessionStatus? status,
    DateTime? actualStart,
    DateTime? actualEnd,
    int? currentParticipants,
    String? replayUrl,
    String? replayVideoAssetId,
    List<SessionChapter>? chapters,
    String? livekitRoomName,
  }) {
    return AcademiaSession(
      id: id,
      type: type,
      status: status ?? this.status,
      provider: provider,
      title: title,
      description: description,
      subject: subject,
      concoursType: concoursType,
      hostId: hostId,
      courseId: courseId,
      programId: programId,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      actualStart: actualStart ?? this.actualStart,
      actualEnd: actualEnd ?? this.actualEnd,
      maxParticipants: maxParticipants,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      isRecordingEnabled: isRecordingEnabled,
      isWhiteboardEnabled: isWhiteboardEnabled,
      isQuizEnabled: isQuizEnabled,
      isChatEnabled: isChatEnabled,
      isScreenShareEnabled: isScreenShareEnabled,
      isHandRaiseEnabled: isHandRaiseEnabled,
      replayUrl: replayUrl ?? this.replayUrl,
      replayVideoAssetId: replayVideoAssetId ?? this.replayVideoAssetId,
      chapters: chapters ?? this.chapters,
      livekitRoomName: livekitRoomName ?? this.livekitRoomName,
      hostDisplayName: hostDisplayName,
      thumbnailUrl: thumbnailUrl,
      metadata: metadata,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  bool get isLive => status == SessionStatus.running;
  bool get isUpcoming =>
      status == SessionStatus.scheduled || status == SessionStatus.approved;
  bool get hasReplay => replayUrl != null && replayUrl!.isNotEmpty;
  bool get isLiveKit => provider == SessionProvider.livekit;

  // ─── Parsing helpers ────────────────────────────────────────────

  static SessionType _parseSessionType(String? value) {
    switch (value) {
      case 'course':
        return SessionType.course;
      case 'td':
        return SessionType.td;
      case 'prep_concours':
        return SessionType.prepConcours;
      case 'orientation':
        return SessionType.orientation;
      case 'conference':
        return SessionType.conference;
      case 'masterclass':
        return SessionType.masterclass;
      case 'live_pedagogique':
        return SessionType.livePedagogique;
      case 'revision_collective':
        return SessionType.revisionCollective;
      case 'exam_blanc':
        return SessionType.examBlanc;
      case 'game_challenge':
        return SessionType.gameChallenge;
      default:
        return SessionType.course;
    }
  }

  static SessionStatus _parseStatus(String? value) {
    switch (value) {
      case 'draft':
        return SessionStatus.draft;
      case 'scheduled':
        return SessionStatus.scheduled;
      case 'pending_approval':
        return SessionStatus.pendingApproval;
      case 'approved':
        return SessionStatus.approved;
      case 'running':
        return SessionStatus.running;
      case 'paused':
        return SessionStatus.paused;
      case 'ended':
        return SessionStatus.ended;
      case 'cancelled':
        return SessionStatus.cancelled;
      case 'rejected':
        return SessionStatus.rejected;
      default:
        return SessionStatus.draft;
    }
  }

  static SessionProvider _parseProvider(String? value) {
    switch (value?.toLowerCase()) {
      case 'livekit':
        return SessionProvider.livekit;
      case 'zoom':
        return SessionProvider.zoom;
      case 'meet':
        return SessionProvider.meet;
      default:
        return SessionProvider.livekit;
    }
  }

  static String _statusToString(SessionStatus s) {
    switch (s) {
      case SessionStatus.draft:
        return 'draft';
      case SessionStatus.scheduled:
        return 'scheduled';
      case SessionStatus.pendingApproval:
        return 'pending_approval';
      case SessionStatus.approved:
        return 'approved';
      case SessionStatus.running:
        return 'running';
      case SessionStatus.paused:
        return 'paused';
      case SessionStatus.ended:
        return 'ended';
      case SessionStatus.cancelled:
        return 'cancelled';
      case SessionStatus.rejected:
        return 'rejected';
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static List<SessionChapter>? _parseChapters(dynamic value) {
    if (value is! List) return null;
    return value
        .whereType<Map<String, dynamic>>()
        .map(SessionChapter.fromJson)
        .toList(growable: false);
  }
}

/// Un chapitre dans un replay (chapitrage intelligent).
class SessionChapter {
  final String title;
  final Duration startOffset;
  final Duration? endOffset;
  final String? type; // 'intro', 'content', 'quiz', 'qa', 'summary'

  const SessionChapter({
    required this.title,
    required this.startOffset,
    this.endOffset,
    this.type,
  });

  factory SessionChapter.fromJson(Map<String, dynamic> json) {
    return SessionChapter(
      title: (json['title'] ?? '') as String,
      startOffset: Duration(seconds: (json['start_seconds'] as num?)?.toInt() ?? 0),
      endOffset: json['end_seconds'] != null
          ? Duration(seconds: (json['end_seconds'] as num).toInt())
          : null,
      type: json['type'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'start_seconds': startOffset.inSeconds,
        if (endOffset != null) 'end_seconds': endOffset!.inSeconds,
        if (type != null) 'type': type,
      };
}

/// Un participant à une session.
class SessionParticipant {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String role; // 'host', 'co_host', 'participant', 'observer'
  final DateTime joinedAt;
  final DateTime? leftAt;
  final bool isHandRaised;
  final bool isMuted;
  final bool isCameraOn;

  const SessionParticipant({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
    this.leftAt,
    this.isHandRaised = false,
    this.isMuted = false,
    this.isCameraOn = false,
  });

  factory SessionParticipant.fromJson(Map<String, dynamic> json) {
    return SessionParticipant(
      userId: (json['user_id'] ?? '') as String,
      displayName: (json['display_name'] ?? '') as String,
      avatarUrl: json['avatar_url'] as String?,
      role: (json['role'] ?? 'participant') as String,
      joinedAt: DateTime.tryParse(json['joined_at']?.toString() ?? '') ??
          DateTime.now(),
      leftAt: json['left_at'] != null
          ? DateTime.tryParse(json['left_at'].toString())
          : null,
      isHandRaised: json['is_hand_raised'] == true,
      isMuted: json['is_muted'] == true,
      isCameraOn: json['is_camera_on'] == true,
    );
  }

  Duration? get presenceDuration {
    final end = leftAt ?? DateTime.now();
    return end.difference(joinedAt);
  }
}
