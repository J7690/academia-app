import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminCoursesProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _courses = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get courses => List.unmodifiable(_courses);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadCourses() async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc('app_admin_list_all_courses');
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors du chargement des cours.');
        return;
      }
      final data = response['courses'];
      if (data is List) {
        _courses = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _courses = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateCourseStatus({
    required String courseId,
    bool? isActive,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_update_course_status',
        params: {
          'p_course_id': courseId,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ??
                  'Erreur lors de la mise à jour du cours.'
              : 'Erreur lors de la mise à jour du cours.',
        );
        return false;
      }
      await loadCourses();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
