import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour la liste des programmes côté université (gestion interne).
/// Utilise la RPC app_list_university_programs_for_management.
class UniversityProgramsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _programs = [];
  List<Map<String, dynamic>> _courses = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get programs => List.unmodifiable(_programs);
  List<Map<String, dynamic>> get courses => List.unmodifiable(_courses);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadPrograms() async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc('app_list_university_programs_for_management');
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors du chargement des programmes.');
        return;
      }
      final data = response['programs'];
      if (data is List) {
        _programs = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _programs = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadCourses() async {
    _setLoading(true);
    _setError(null);
    try {
      final response =
          await _client.rpc('app_list_university_courses_for_management');
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour les cours.');
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

  Future<bool> upsertProgram({
    String? programId,
    required String title,
    String? description,
    String? degreeLevel,
    String? mode,
    int? durationMonths,
    num? tuitionFees,
    bool? highlighted,
    bool? isActive,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_upsert_university_program',
        params: {
          'p_program_id': programId,
          'p_title': title,
          'p_description': description,
          'p_degree_level': degreeLevel,
          'p_mode': mode,
          'p_duration_months': durationMonths,
          'p_tuition_fees': tuitionFees,
          'p_highlighted': highlighted,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la sauvegarde du programme.');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors de la sauvegarde du programme.');
        return false;
      }
      await loadPrograms();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> upsertCourse({
    String? courseId,
    required String programId,
    required String title,
    String? description,
    int? credits,
    String? prerequisites,
    String? instructor,
    bool? isActive,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_upsert_university_course',
        params: {
          'p_course_id': courseId,
          'p_program_id': programId,
          'p_title': title,
          'p_description': description,
          'p_credits': credits,
          'p_prerequisites': prerequisites,
          'p_instructor': instructor,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la sauvegarde du cours.');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors de la sauvegarde du cours.');
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
