import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnlineCourseDetailProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  Map<String, dynamic>? _course;
  List<Map<String, dynamic>> _sections = [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  Map<String, dynamic>? get course => _course == null
      ? null
      : Map<String, dynamic>.unmodifiable(_course!);
  List<Map<String, dynamic>> get sections => List.unmodifiable(_sections);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setSaving(bool value) {
    _isSaving = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadCourseDetail(String courseId) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_public_get_online_course_detail',
        params: {'p_course_id': courseId},
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour le détail du cours.');
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement du détail du cours.',
        );
        return;
      }
      final rawCourse = response['course'];
      final rawSections = response['sections'];
      if (rawCourse is Map) {
        _course = Map<String, dynamic>.from(rawCourse);
      } else {
        _course = null;
      }
      if (rawSections is List) {
        _sections = rawSections
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _sections = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateLessonProgress({
    required String lessonId,
    int? lastPositionSeconds,
    bool completed = false,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_student_update_lesson_progress',
        params: {
          'p_lesson_id': lessonId,
          'p_last_position_seconds': lastPositionSeconds,
          'p_completed': completed,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la mise à jour de la progression.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la mise à jour de la progression.',
        );
        return false;
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }
}
