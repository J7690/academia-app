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
}
