import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Provider for teacher CONCOURS assignments (distinct from TD assignments).
/// Uses app_prep_teacher_* RPCs which target prep_assignments tables.
class TeacherPrepAssignmentsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _submissions = [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  List<Map<String, dynamic>> get assignments => List.unmodifiable(_assignments);
  List<Map<String, dynamic>> get submissions => List.unmodifiable(_submissions);

  void _setLoading(bool v) { _isLoading = v; notifyListeners(); }
  void _setSaving(bool v) { _isSaving = v; notifyListeners(); }
  void _setError(String? v) { _error = v; notifyListeners(); }

  /// Load all assignments created by this teacher for CONCOURS.
  Future<void> loadMyAssignments() async {
    _setLoading(true);
    _setError(null);
    try {
      final res = await _client.rpc('app_prep_teacher_list_assignments');
      if (res is List) {
        _assignments = res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        _assignments = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Create or update a CONCOURS assignment.
  Future<bool> upsertAssignment({
    String? assignmentId,
    required String title,
    String? description,
    String? concoursType,
    String? subjectName,
    String assignmentType = 'qcm',
    Map<String, dynamic>? content,
    DateTime? deadline,
    int maxScore = 20,
    bool isPublished = false,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final res = await _client.rpc('app_prep_teacher_upsert_assignment', params: {
        if (assignmentId != null) 'p_assignment_id': assignmentId,
        'p_title': title,
        if (description != null) 'p_description': description,
        if (concoursType != null) 'p_concours_type': concoursType,
        if (subjectName != null) 'p_subject_name': subjectName,
        'p_assignment_type': assignmentType,
        if (content != null) 'p_content': content,
        if (deadline != null) 'p_deadline': deadline.toIso8601String(),
        'p_max_score': maxScore,
        'p_is_published': isPublished,
      });
      if (res is Map && res['success'] == true) {
        await loadMyAssignments();
        return true;
      }
      _setError(res is Map ? res['error']?.toString() : 'Erreur inconnue');
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  /// Load submissions for a specific assignment.
  Future<void> loadSubmissions(String assignmentId) async {
    _setLoading(true);
    _setError(null);
    try {
      final res = await _client.rpc('app_prep_teacher_list_submissions', params: {
        'p_assignment_id': assignmentId,
      });
      if (res is Map && res['success'] == true) {
        final subs = res['submissions'];
        if (subs is List) {
          _submissions = subs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      } else {
        _submissions = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Grade a submission manually.
  Future<bool> gradeSubmission({
    required String submissionId,
    required int score,
    String? comment,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final res = await _client.rpc('app_prep_teacher_grade_submission', params: {
        'p_submission_id': submissionId,
        'p_score': score,
        if (comment != null) 'p_comment': comment,
      });
      if (res is Map && res['success'] == true) {
        return true;
      }
      _setError(res is Map ? res['error']?.toString() : 'Erreur');
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  /// Trigger AI-assisted grading via Edge Function.
  Future<Map<String, dynamic>?> triggerAiGrading(String submissionId) async {
    _setSaving(true);
    _setError(null);
    try {
      final session = _client.auth.currentSession;
      if (session == null) {
        _setError('Non authentifié.');
        return null;
      }
      final uri = Uri.parse('${SupabaseConfig.url}/functions/v1/prep-grade-assignment');
      final response = await http.post(uri, headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
        'apikey': SupabaseConfig.anonKey,
      }, body: jsonEncode({'submission_id': submissionId}));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['success'] == true) {
          return data;
        }
        _setError(data['error']?.toString() ?? 'Erreur IA');
      } else {
        _setError('Erreur (${response.statusCode})');
      }
      return null;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setSaving(false);
    }
  }
}
