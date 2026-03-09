import 'package:supabase_flutter/supabase_flutter.dart';

/// Service centralisé pour le module TD.
///
/// Il encapsule les appels RPC `app_td_*` vers Supabase et renvoie
/// des structures Dart simples (Map / List<Map>). La logique de
/// présentation reste dans les providers.
class TdService {
  TdService() : _client = Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listPublicPrograms({
    String? fieldId,
    String? level,
  }) async {
    final response = await _client.rpc(
      'app_td_list_public_programs',
      params: {
        if (fieldId != null) 'p_field_id': fieldId,
        if (level != null) 'p_level': level,
      },
    );

    final list = response as List<dynamic>? ?? [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> getProgramDetail(String programId) async {
    final response = await _client.rpc(
      'app_td_get_program_detail',
      params: {'p_program_id': programId},
    );

    final data = response as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      throw Exception(
        data?['error']?.toString() ??
            'Erreur lors du chargement du détail du programme TD.',
      );
    }
    return data;
  }

  Future<Map<String, dynamic>> studentCreateEnrollmentAndPayment({
    required String programId,
    String? collectionId,
    required String accessScope,
    required double amountDue,
    String? studentNotes,
  }) async {
    final response = await _client.rpc(
      'app_td_student_create_enrollment_and_payment',
      params: {
        'p_program_id': programId,
        'p_collection_id': collectionId,
        'p_access_scope': accessScope,
        'p_amount_due': amountDue,
        if (studentNotes != null && studentNotes.isNotEmpty)
          'p_student_notes': studentNotes,
      },
    );

    final data = response as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      throw Exception(
        data?['error']?.toString() ??
            'Erreur lors de la création de l\'inscription TD.',
      );
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> studentListMyEnrollments() async {
    final response = await _client.rpc('app_td_student_list_my_enrollments');
    final list = response as List<dynamic>? ?? [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> teacherListAssignments() async {
    final response = await _client.rpc('app_td_teacher_list_assignments');
    final list = response as List<dynamic>? ?? [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> adminListEnrollmentsWithContext() async {
    final response = await _client.rpc(
      'app_td_admin_list_enrollments_with_context',
    );
    final list = response as List<dynamic>? ?? [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  Future<bool> adminAssignTeacher({
    required String enrollmentId,
    required String tdTeacherId,
  }) async {
    final response = await _client.rpc(
      'app_td_admin_assign_teacher',
      params: {
        'p_enrollment_id': enrollmentId,
        'p_td_teacher_id': tdTeacherId,
      },
    );

    final data = response as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      throw Exception(
        data?['error']?.toString() ??
            'Erreur lors de l\'assignation de l\'enseignant TD.',
      );
    }
    return true;
  }

  Future<List<Map<String, dynamic>>> listMessagesForEnrollment(
    String enrollmentId,
  ) async {
    final response = await _client.rpc(
      'app_td_list_messages_for_enrollment',
      params: {'p_enrollment_id': enrollmentId},
    );

    final list = response as List<dynamic>? ?? [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> sendMessage({
    required String enrollmentId,
    required String threadType,
    required String content,
    String? attachmentUrl,
  }) async {
    final response = await _client.rpc(
      'app_td_send_message',
      params: {
        'p_enrollment_id': enrollmentId,
        'p_thread_type': threadType,
        'p_content': content,
        'p_attachment_url': attachmentUrl,
      },
    );

    final data = response as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      throw Exception(
        data?['error']?.toString() ??
            'Erreur lors de l\'envoi du message TD.',
      );
    }
    return data;
  }

  Future<Map<String, dynamic>> studentCreateRequest({
    String? fieldId,
    String? level,
    required String subject,
    String? description,
    String? preferredModality,
    String? preferredSchedule,
  }) async {
    final response = await _client.rpc(
      'app_td_student_create_request',
      params: {
        'p_field_id': fieldId,
        'p_level': level,
        'p_subject': subject,
        'p_description': description,
        'p_preferred_modality': preferredModality,
        'p_preferred_schedule': preferredSchedule,
      },
    );

    final data = response as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      throw Exception(
        data?['error']?.toString() ??
            'Erreur lors de la création de la demande TD.',
      );
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> studentListMyRequests() async {
    final response = await _client.rpc('app_td_student_list_my_requests');
    final list = response as List<dynamic>? ?? [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> adminListStudentRequests({
    String? status,
    String? fieldId,
    String? level,
  }) async {
    final response = await _client.rpc(
      'app_td_admin_list_student_requests',
      params: {
        if (status != null) 'p_status': status,
        if (fieldId != null) 'p_field_id': fieldId,
        if (level != null) 'p_level': level,
      },
    );

    final list = response as List<dynamic>? ?? [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> adminMarkRequestConverted({
    required String requestId,
    required String programId,
  }) async {
    final response = await _client.rpc(
      'app_td_admin_mark_request_converted',
      params: {
        'p_request_id': requestId,
        'p_program_id': programId,
      },
    );

    final data = response as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      throw Exception(
        data?['error']?.toString() ??
            'Erreur lors de la mise à jour de la demande TD.',
      );
    }
    return data;
  }

  /// Dashboard étudiant TD (inscriptions + prochaines séances + messages non lus).
  Future<Map<String, dynamic>> studentGetDashboard() async {
    final response = await _client.rpc('app_td_student_get_dashboard');
    final data = response as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      throw Exception(
        data?['error']?.toString() ??
            'Erreur lors du chargement du dashboard TD étudiant.',
      );
    }
    return data;
  }

  /// Occurrences de séances TD pour l'étudiant courant.
  Future<List<Map<String, dynamic>>> studentListMySessionOccurrences() async {
    final response =
        await _client.rpc('app_td_student_list_my_session_occurrences');
    final list = response as List<dynamic>? ?? [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  /// Ressources TD accessibles pour une inscription étudiante donnée.
  Future<List<Map<String, dynamic>>> studentListResourcesForEnrollment(
    String enrollmentId,
  ) async {
    final response = await _client.rpc(
      'app_td_student_list_resources_for_enrollment',
      params: {
        'p_enrollment_id': enrollmentId,
      },
    );

    final list = response as List<dynamic>? ?? [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  /// Dashboard enseignant TD (missions + prochaines séances).
  Future<Map<String, dynamic>> teacherGetDashboard() async {
    final response = await _client.rpc('app_td_teacher_get_dashboard');
    final data = response as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      throw Exception(
        data?['error']?.toString() ??
            'Erreur lors du chargement du dashboard TD enseignant.',
      );
    }
    return data;
  }

  /// Prochaines séances TD pour l'enseignant courant.
  Future<List<Map<String, dynamic>>> teacherListUpcomingSessions({
    DateTime? from,
    DateTime? to,
  }) async {
    final params = <String, dynamic>{};
    if (from != null) {
      params['p_from'] = from.toIso8601String();
    }
    if (to != null) {
      params['p_to'] = to.toIso8601String();
    }

    final response = await _client.rpc(
      'app_td_teacher_list_upcoming_sessions',
      params: params.isEmpty ? null : params,
    );

    final list = response as List<dynamic>? ?? [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  /// Mise à jour de la présence pour une séance TD (enseignant).
  Future<Map<String, dynamic>> teacherUpdateAttendance({
    required String occurrenceId,
    required String studentId,
    required String status,
    String? comment,
  }) async {
    final response = await _client.rpc(
      'app_td_teacher_update_attendance',
      params: {
        'p_occurrence_id': occurrenceId,
        'p_student_id': studentId,
        'p_status': status,
        'p_comment': comment,
      },
    );

    final data = response as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      throw Exception(
        data?['error']?.toString() ??
            'Erreur lors de la mise à jour de la présence TD.',
      );
    }
    return data;
  }

  /// Ressources TD pour une inscription vue côté enseignant.
  Future<List<Map<String, dynamic>>> teacherListResourcesForEnrollment(
    String enrollmentId,
  ) async {
    final response = await _client.rpc(
      'app_td_teacher_list_resources_for_enrollment',
      params: {
        'p_enrollment_id': enrollmentId,
      },
    );

    final list = response as List<dynamic>? ?? [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  /// Dashboard admin TD (compteurs clés).
  Future<Map<String, dynamic>> adminGetDashboard() async {
    final response = await _client.rpc('app_td_admin_get_dashboard');
    final data = response as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      throw Exception(
        data?['error']?.toString() ??
            'Erreur lors du chargement du dashboard TD admin.',
      );
    }
    return data;
  }

  /// Création / mise à jour d'une occurrence de séance TD (admin).
  Future<Map<String, dynamic>> adminUpsertSessionOccurrence({
    String? occurrenceId,
    required String sessionId,
    required String enrollmentId,
    required String teacherId,
    required DateTime scheduledAt,
    required int durationMinutes,
    String status = 'planned',
    String? location,
    String? meetingUrl,
  }) async {
    final params = <String, dynamic>{
      'p_occurrence_id': occurrenceId,
      'p_session_id': sessionId,
      'p_enrollment_id': enrollmentId,
      'p_teacher_id': teacherId,
      'p_scheduled_at': scheduledAt.toIso8601String(),
      'p_duration_minutes': durationMinutes,
      'p_status': status,
      'p_location': location,
      'p_meeting_url': meetingUrl,
    };

    final response = await _client.rpc(
      'app_td_admin_upsert_session_occurrence',
      params: params,
    );

    final data = response as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      throw Exception(
        data?['error']?.toString() ??
            'Erreur lors de la création ou mise à jour de la séance TD.',
      );
    }
    return data;
  }

  /// Annulation d'une occurrence de séance TD (admin).
  Future<bool> adminCancelSessionOccurrence(String occurrenceId) async {
    final response = await _client.rpc(
      'app_td_admin_cancel_session_occurrence',
      params: {
        'p_occurrence_id': occurrenceId,
      },
    );

    final data = response as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      throw Exception(
        data?['error']?.toString() ??
            'Erreur lors de l\'annulation de la séance TD.',
      );
    }
    return true;
  }

  /// Liste des occurrences de séances TD (admin) avec filtres optionnels.
  Future<List<Map<String, dynamic>>> adminListSessionOccurrences({
    String? teacherId,
    String? studentId,
    DateTime? from,
    DateTime? to,
  }) async {
    final params = <String, dynamic>{};
    if (teacherId != null && teacherId.isNotEmpty) {
      params['p_teacher_id'] = teacherId;
    }
    if (studentId != null && studentId.isNotEmpty) {
      params['p_student_id'] = studentId;
    }
    if (from != null) {
      params['p_from'] = from.toIso8601String();
    }
    if (to != null) {
      params['p_to'] = to.toIso8601String();
    }

    final response = await _client.rpc(
      'app_td_admin_list_session_occurrences',
      params: params.isEmpty ? null : params,
    );

    final list = response as List<dynamic>? ?? [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  // ═══════════════════════════════════════════════════════════════
  // PREP CONCOURS — Quiz, Flashcards, AI, Progress, Admin
  // ═══════════════════════════════════════════════════════════════

  // ─── Questions ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> prepListQuestions({
    String? bankId,
    String? concoursType,
    String? subject,
    int? difficulty,
    int limit = 20,
  }) async {
    final resp = await _client.rpc('app_prep_list_questions', params: {
      if (bankId != null) 'p_bank_id': bankId,
      if (concoursType != null) 'p_concours_type': concoursType,
      if (subject != null) 'p_subject': subject,
      if (difficulty != null) 'p_difficulty': difficulty,
      'p_limit': limit,
    });
    return _jsonbToList(resp);
  }

  Future<List<Map<String, dynamic>>> prepListQuestionBanks({
    String? concoursType,
    String? subject,
  }) async {
    final resp = await _client.rpc('app_prep_list_question_banks', params: {
      if (concoursType != null) 'p_concours_type': concoursType,
      if (subject != null) 'p_subject': subject,
    });
    return _jsonbToList(resp);
  }

  Future<Map<String, dynamic>> prepCreateQuestionBank({
    required String title,
    String? description,
    String? concoursType,
    String? subject,
  }) async {
    final resp = await _client.rpc('app_prep_create_question_bank', params: {
      'p_title': title,
      if (description != null) 'p_description': description,
      if (concoursType != null) 'p_concours_type': concoursType,
      if (subject != null) 'p_subject': subject,
    });
    return _jsonbToMap(resp);
  }

  Future<Map<String, dynamic>> prepCreateQuestion({
    required String bankId,
    required String content,
    required List<String> options,
    required int correctIndex,
    String? explanation,
    int difficulty = 1,
    String? subject,
    List<String> tags = const [],
    String questionType = 'qcm',
    int points = 10,
    int timeLimitSeconds = 60,
  }) async {
    final resp = await _client.rpc('app_prep_create_question', params: {
      'p_bank_id': bankId,
      'p_content': content,
      'p_options': options,
      'p_correct_index': correctIndex,
      if (explanation != null) 'p_explanation': explanation,
      'p_difficulty': difficulty,
      if (subject != null) 'p_subject': subject,
      'p_tags': tags,
      'p_question_type': questionType,
      'p_points': points,
      'p_time_limit_seconds': timeLimitSeconds,
    });
    return _jsonbToMap(resp);
  }

  // ─── Quiz Attempts ─────────────────────────────────────────────

  Future<Map<String, dynamic>> prepSaveQuizAttempt({
    String? templateId,
    required List<Map<String, dynamic>> questionsJson,
    required List<Map<String, dynamic>> answersJson,
    required double score,
    required int totalPoints,
    required int correctCount,
    required int questionCount,
    int timeSpentSeconds = 0,
    String status = 'completed',
  }) async {
    final resp = await _client.rpc('app_prep_save_quiz_attempt', params: {
      if (templateId != null) 'p_template_id': templateId,
      'p_questions_json': questionsJson,
      'p_answers_json': answersJson,
      'p_score': score,
      'p_total_points': totalPoints,
      'p_correct_count': correctCount,
      'p_question_count': questionCount,
      'p_time_spent_seconds': timeSpentSeconds,
      'p_status': status,
    });
    return _jsonbToMap(resp);
  }

  // ─── Progress ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> prepGetStudentProgress() async {
    final resp = await _client.rpc('app_prep_get_student_progress');
    return _jsonbToMap(resp);
  }

  Future<List<Map<String, dynamic>>> prepGetSubjectStats() async {
    final resp = await _client.rpc('app_prep_get_subject_stats');
    return _jsonbToList(resp);
  }

  Future<List<Map<String, dynamic>>> prepGetLeaderboard({int limit = 20}) async {
    final resp = await _client.rpc('app_prep_get_leaderboard', params: {
      'p_limit': limit,
    });
    return _jsonbToList(resp);
  }

  // ─── Flashcards ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> prepListFlashcardDecks({
    String? subject,
    String? concoursType,
  }) async {
    final resp = await _client.rpc('app_prep_list_flashcard_decks', params: {
      if (subject != null) 'p_subject': subject,
      if (concoursType != null) 'p_concours_type': concoursType,
    });
    return _jsonbToList(resp);
  }

  Future<List<Map<String, dynamic>>> prepListFlashcards(String deckId) async {
    final resp = await _client.rpc('app_prep_list_flashcards', params: {
      'p_deck_id': deckId,
    });
    return _jsonbToList(resp);
  }

  Future<Map<String, dynamic>> prepSaveFlashcardReview({
    required String flashcardId,
    required int quality,
    double easeFactor = 2.5,
    int intervalDays = 1,
    int repetitions = 0,
  }) async {
    final resp = await _client.rpc('app_prep_save_flashcard_review', params: {
      'p_flashcard_id': flashcardId,
      'p_quality': quality,
      'p_ease_factor': easeFactor,
      'p_interval_days': intervalDays,
      'p_repetitions': repetitions,
    });
    return _jsonbToMap(resp);
  }

  Future<Map<String, dynamic>> prepCreateFlashcardDeck({
    required String title,
    String? description,
    String? subject,
    String? concoursType,
  }) async {
    final resp = await _client.rpc('app_prep_create_flashcard_deck', params: {
      'p_title': title,
      if (description != null) 'p_description': description,
      if (subject != null) 'p_subject': subject,
      if (concoursType != null) 'p_concours_type': concoursType,
    });
    return _jsonbToMap(resp);
  }

  Future<Map<String, dynamic>> prepCreateFlashcard({
    required String deckId,
    required String frontText,
    required String backText,
    String? subject,
    List<String> tags = const [],
  }) async {
    final resp = await _client.rpc('app_prep_create_flashcard', params: {
      'p_deck_id': deckId,
      'p_front_text': frontText,
      'p_back_text': backText,
      if (subject != null) 'p_subject': subject,
      'p_tags': tags,
    });
    return _jsonbToMap(resp);
  }

  // ─── Exam Papers ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> prepListExamPapers({
    String? concoursType,
    String? year,
    String? subject,
  }) async {
    final resp = await _client.rpc('app_prep_list_exam_papers', params: {
      if (concoursType != null) 'p_concours_type': concoursType,
      if (year != null) 'p_year': year,
      if (subject != null) 'p_subject': subject,
    });
    return _jsonbToList(resp);
  }

  Future<Map<String, dynamic>> prepCreateExamPaper({
    required String title,
    required String concoursType,
    String? year,
    String? subject,
    String? paperUrl,
    String? correctionUrl,
    int difficulty = 1,
    bool isOfficial = false,
    bool hasCorrection = false,
  }) async {
    final resp = await _client.rpc('app_prep_create_exam_paper', params: {
      'p_title': title,
      'p_concours_type': concoursType,
      if (year != null) 'p_year': year,
      if (subject != null) 'p_subject': subject,
      if (paperUrl != null) 'p_paper_url': paperUrl,
      if (correctionUrl != null) 'p_correction_url': correctionUrl,
      'p_difficulty': difficulty,
      'p_is_official': isOfficial,
      'p_has_correction': hasCorrection,
    });
    return _jsonbToMap(resp);
  }

  // ─── AI Tutor ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> prepCreateAiConversation({
    String? title,
    String? subject,
  }) async {
    final resp = await _client.rpc('app_prep_create_ai_conversation', params: {
      if (title != null) 'p_title': title,
      if (subject != null) 'p_subject': subject,
    });
    return _jsonbToMap(resp);
  }

  Future<Map<String, dynamic>> prepSaveAiMessage({
    required String conversationId,
    required String role,
    required String content,
    int tokensUsed = 0,
  }) async {
    final resp = await _client.rpc('app_prep_save_ai_message', params: {
      'p_conversation_id': conversationId,
      'p_role': role,
      'p_content': content,
      'p_tokens_used': tokensUsed,
    });
    return _jsonbToMap(resp);
  }

  Future<List<Map<String, dynamic>>> prepListAiConversations() async {
    final resp = await _client.rpc('app_prep_list_ai_conversations');
    return _jsonbToList(resp);
  }

  Future<List<Map<String, dynamic>>> prepListAiMessages(String conversationId) async {
    final resp = await _client.rpc('app_prep_list_ai_messages', params: {
      'p_conversation_id': conversationId,
    });
    return _jsonbToList(resp);
  }

  Future<Map<String, dynamic>> prepGetAiConfig() async {
    final resp = await _client.rpc('app_prep_get_ai_config');
    return _jsonbToMap(resp);
  }

  // ─── Quiz Templates ────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> prepListQuizTemplates({
    String? concoursType,
    String? subject,
  }) async {
    final resp = await _client.rpc('app_prep_list_quiz_templates', params: {
      if (concoursType != null) 'p_concours_type': concoursType,
      if (subject != null) 'p_subject': subject,
    });
    return _jsonbToList(resp);
  }

  Future<Map<String, dynamic>> prepCreateQuizTemplate({
    required String title,
    String? bankId,
    String? concoursType,
    String? subject,
    int questionCount = 10,
    int? timeLimitMinutes,
    bool shuffle = true,
    bool isExamMode = false,
    int passingScore = 60,
    String? description,
  }) async {
    final resp = await _client.rpc('app_prep_create_quiz_template', params: {
      'p_title': title,
      if (bankId != null) 'p_bank_id': bankId,
      if (concoursType != null) 'p_concours_type': concoursType,
      if (subject != null) 'p_subject': subject,
      'p_question_count': questionCount,
      if (timeLimitMinutes != null) 'p_time_limit_minutes': timeLimitMinutes,
      'p_shuffle': shuffle,
      'p_is_exam_mode': isExamMode,
      'p_passing_score': passingScore,
      if (description != null) 'p_description': description,
    });
    return _jsonbToMap(resp);
  }

  // ─── Admin ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> prepAdminGetStats() async {
    final resp = await _client.rpc('app_prep_admin_get_stats');
    return _jsonbToMap(resp);
  }

  Future<List<Map<String, dynamic>>> prepAdminListQuestions({
    String? bankId,
    String? subject,
    int limit = 50,
    int offset = 0,
  }) async {
    final resp = await _client.rpc('app_prep_admin_list_questions', params: {
      if (bankId != null) 'p_bank_id': bankId,
      if (subject != null) 'p_subject': subject,
      'p_limit': limit,
      'p_offset': offset,
    });
    return _jsonbToList(resp);
  }

  Future<Map<String, dynamic>> prepAdminToggleQuestion(String questionId, bool isActive) async {
    final resp = await _client.rpc('app_prep_admin_toggle_question', params: {
      'p_question_id': questionId,
      'p_is_active': isActive,
    });
    return _jsonbToMap(resp);
  }

  Future<List<Map<String, dynamic>>> prepAdminListAiConversations({int limit = 50}) async {
    final resp = await _client.rpc('app_prep_admin_list_ai_conversations', params: {
      'p_limit': limit,
    });
    return _jsonbToList(resp);
  }

  Future<Map<String, dynamic>> prepUpdateAiConfig(String key, String value) async {
    final resp = await _client.rpc('app_prep_update_ai_config', params: {
      'p_key': key,
      'p_value': value,
    });
    return _jsonbToMap(resp);
  }

  Future<Map<String, dynamic>> prepAdminUpsertBadge({
    required String code,
    required String title,
    String? description,
    String? emoji,
    int xpReward = 0,
    String? conditionType,
    int conditionValue = 0,
  }) async {
    final resp = await _client.rpc('app_prep_admin_upsert_badge', params: {
      'p_code': code,
      'p_title': title,
      if (description != null) 'p_description': description,
      if (emoji != null) 'p_emoji': emoji,
      'p_xp_reward': xpReward,
      if (conditionType != null) 'p_condition_type': conditionType,
      'p_condition_value': conditionValue,
    });
    return _jsonbToMap(resp);
  }

  // ═══════════════════════════════════════════════════════════════
  // TD Gamification RPCs — Student
  // ═══════════════════════════════════════════════════════════════

  /// Dashboard home data (streak, daily goal, XP, next session)
  Future<Map<String, dynamic>> tdStudentGetHome() async {
    final resp = await _client.rpc('app_td_student_get_home');
    return _jsonbToMap(resp);
  }

  /// Catalog: list programs with enriched data, filters, sort
  Future<Map<String, dynamic>> tdStudentListCatalog({
    String? fieldId,
    String? level,
    String? modality,
    String? search,
    String sort = 'popular',
  }) async {
    final resp = await _client.rpc('app_td_student_list_catalog', params: {
      if (fieldId != null) 'p_field_id': fieldId,
      if (level != null) 'p_level': level,
      if (modality != null) 'p_modality': modality,
      if (search != null && search.isNotEmpty) 'p_search': search,
      'p_sort': sort,
    });
    return _jsonbToMap(resp);
  }

  /// List fields/disciplines with colors
  Future<Map<String, dynamic>> tdStudentListFields() async {
    final resp = await _client.rpc('app_td_student_list_fields');
    return _jsonbToMap(resp);
  }

  /// Record XP gain + update streak
  Future<Map<String, dynamic>> tdStudentEarnXp({
    required int amount,
    required String reason,
    String? refType,
    String? refId,
  }) async {
    final resp = await _client.rpc('app_td_student_earn_xp', params: {
      'p_amount': amount,
      'p_reason': reason,
      if (refType != null) 'p_ref_type': refType,
      if (refId != null) 'p_ref_id': refId,
    });
    return _jsonbToMap(resp);
  }

  /// List resources for a program/enrollment
  Future<Map<String, dynamic>> tdStudentListResources({
    String? programId,
    String? enrollmentId,
  }) async {
    final resp = await _client.rpc('app_td_student_list_resources', params: {
      if (programId != null) 'p_program_id': programId,
      if (enrollmentId != null) 'p_enrollment_id': enrollmentId,
    });
    return _jsonbToMap(resp);
  }

  /// Update resource progress (status, pct, bookmark, time)
  Future<Map<String, dynamic>> tdStudentUpdateResourceProgress({
    required String resourceId,
    String? status,
    int? progressPct,
    String? lastPosition,
    int timeSpentSeconds = 0,
  }) async {
    final resp = await _client.rpc('app_td_student_update_resource_progress', params: {
      'p_resource_id': resourceId,
      if (status != null) 'p_status': status,
      if (progressPct != null) 'p_progress_pct': progressPct,
      if (lastPosition != null) 'p_last_position': lastPosition,
      'p_time_spent_seconds': timeSpentSeconds,
    });
    return _jsonbToMap(resp);
  }

  /// Get weekly leaderboard
  Future<Map<String, dynamic>> tdStudentGetLeaderboard({
    String? programId,
    int limit = 20,
  }) async {
    final resp = await _client.rpc('app_td_student_get_leaderboard', params: {
      if (programId != null) 'p_program_id': programId,
      'p_limit': limit,
    });
    return _jsonbToMap(resp);
  }

  /// Get stats & badges
  Future<Map<String, dynamic>> tdStudentGetStats() async {
    final resp = await _client.rpc('app_td_student_get_stats');
    return _jsonbToMap(resp);
  }

  /// Get my enrollments with progress
  Future<Map<String, dynamic>> tdStudentGetMyEnrollments() async {
    final resp = await _client.rpc('app_td_student_get_my_enrollments');
    return _jsonbToMap(resp);
  }

  // ═══════════════════════════════════════════════════════════════
  // TD Gamification RPCs — Teacher
  // ═══════════════════════════════════════════════════════════════

  /// List students with progress for teacher's enrollments
  Future<Map<String, dynamic>> tdTeacherListStudents() async {
    final resp = await _client.rpc('app_td_teacher_list_students');
    return _jsonbToMap(resp);
  }

  /// Add a resource to a program
  Future<Map<String, dynamic>> tdTeacherAddResource({
    required String programId,
    required String title,
    required String kind,
    required String url,
    String? description,
    bool isRequired = false,
    int position = 0,
    String? thumbnailUrl,
    int? durationSeconds,
    int? fileSizeBytes,
  }) async {
    final resp = await _client.rpc('app_td_teacher_add_resource', params: {
      'p_program_id': programId,
      'p_title': title,
      'p_kind': kind,
      'p_url': url,
      if (description != null) 'p_description': description,
      'p_is_required': isRequired,
      'p_position': position,
      if (thumbnailUrl != null) 'p_thumbnail_url': thumbnailUrl,
      if (durationSeconds != null) 'p_duration_seconds': durationSeconds,
      if (fileSizeBytes != null) 'p_file_size_bytes': fileSizeBytes,
    });
    return _jsonbToMap(resp);
  }

  /// List resources for a program (teacher view)
  Future<Map<String, dynamic>> tdTeacherListResources(String programId) async {
    final resp = await _client.rpc('app_td_teacher_list_resources', params: {
      'p_program_id': programId,
    });
    return _jsonbToMap(resp);
  }

  /// Delete a resource
  Future<Map<String, dynamic>> tdTeacherDeleteResource(String resourceId) async {
    final resp = await _client.rpc('app_td_teacher_delete_resource', params: {
      'p_resource_id': resourceId,
    });
    return _jsonbToMap(resp);
  }

  // ═══════════════════════════════════════════════════════════════
  // TD Gamification RPCs — Admin
  // ═══════════════════════════════════════════════════════════════

  /// Admin analytics dashboard
  Future<Map<String, dynamic>> tdAdminGetAnalytics() async {
    final resp = await _client.rpc('app_td_admin_get_analytics');
    return _jsonbToMap(resp);
  }

  /// Upsert a badge
  Future<Map<String, dynamic>> tdAdminUpsertBadge({
    required String code,
    required String title,
    String? description,
    String? emoji,
    int xpReward = 0,
    String? conditionType,
    int conditionValue = 0,
    bool isActive = true,
  }) async {
    final resp = await _client.rpc('app_td_admin_upsert_badge', params: {
      'p_code': code,
      'p_title': title,
      if (description != null) 'p_description': description,
      if (emoji != null) 'p_emoji': emoji,
      'p_xp_reward': xpReward,
      if (conditionType != null) 'p_condition_type': conditionType,
      'p_condition_value': conditionValue,
      'p_is_active': isActive,
    });
    return _jsonbToMap(resp);
  }

  /// Upsert discipline color
  Future<Map<String, dynamic>> tdAdminUpsertDisciplineColor({
    required String fieldName,
    required String colorHex,
    required String gradientStart,
    required String gradientEnd,
    String iconName = 'school',
    String? fieldId,
  }) async {
    final resp = await _client.rpc('app_td_admin_upsert_discipline_color', params: {
      'p_field_name': fieldName,
      'p_color_hex': colorHex,
      'p_gradient_start': gradientStart,
      'p_gradient_end': gradientEnd,
      'p_icon_name': iconName,
      if (fieldId != null) 'p_field_id': fieldId,
    });
    return _jsonbToMap(resp);
  }

  /// Grant XP to a student manually
  Future<Map<String, dynamic>> tdAdminGrantXp({
    required String studentId,
    required int amount,
    String reason = 'admin_grant',
  }) async {
    final resp = await _client.rpc('app_td_admin_grant_xp', params: {
      'p_student_id': studentId,
      'p_amount': amount,
      'p_reason': reason,
    });
    return _jsonbToMap(resp);
  }

  /// List all badges (admin view with earned_count)
  Future<Map<String, dynamic>> tdAdminListBadges() async {
    final resp = await _client.rpc('app_td_admin_list_badges');
    return _jsonbToMap(resp);
  }

  // ─── Helpers ───────────────────────────────────────────────────

  List<Map<String, dynamic>> _jsonbToList(dynamic resp) {
    if (resp is List) {
      return resp
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
    }
    // JSONB returned as single value
    if (resp is Map) {
      final data = resp as Map<String, dynamic>;
      return [data];
    }
    return [];
  }

  Map<String, dynamic> _jsonbToMap(dynamic resp) {
    if (resp is Map) return Map<String, dynamic>.from(resp);
    return {};
  }
}
