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
}
