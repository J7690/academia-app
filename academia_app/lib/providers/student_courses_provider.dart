import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour les cours et exercices de l'étudiant
/// Utilise les RPC app_list_student_courses et app_list_course_exercises
class StudentCoursesProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _exercises = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get courses => _courses;
  List<Map<String, dynamic>> get exercises => _exercises;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadStudentCourses() async {
    _setLoading(true);
    _setError(null);
    try {
      final data = await _client.rpc('app_list_student_courses') as List<dynamic>? ?? [];
      _courses = data.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadCourseExercises(String courseId) async {
    _setLoading(true);
    _setError(null);
    try {
      final data = await _client.rpc(
        'app_list_course_exercises',
        params: {'p_course_id': courseId},
      ) as List<dynamic>? ?? [];
      _exercises = data.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  void clearExercises() {
    _exercises = [];
    notifyListeners();
  }
}
