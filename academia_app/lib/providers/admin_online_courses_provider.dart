import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminOnlineCoursesProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  List<Map<String, dynamic>> _courses = [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  List<Map<String, dynamic>> get courses => List.unmodifiable(_courses);

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

  Future<void> loadOnlineCourses() async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc('app_admin_list_online_courses');
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour les cours en ligne.');
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement des cours en ligne.',
        );
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

  Future<bool> upsertOnlineCourse({
    String? courseId,
    required String title,
    String? shortDescription,
    String? fullDescription,
    String? category,
    String? level,
    String? language,
    int? estimatedHours,
    String? coverImageUrl,
    num? price,
    String? contactPhone,
    String? contactWhatsapp,
    String? contactEmail,
    String? contactWebsite,
    String? contactNotes,
    bool? isPublished,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_upsert_online_course',
        params: {
          'p_course_id': courseId,
          'p_title': title,
          'p_short_description': shortDescription,
          'p_full_description': fullDescription,
          'p_category': category,
          'p_level': level,
          'p_language': language,
          'p_estimated_hours': estimatedHours,
          'p_cover_image_url': coverImageUrl,
          'p_price': price,
          'p_contact_phone': contactPhone,
          'p_contact_whatsapp': contactWhatsapp,
          'p_contact_email': contactEmail,
          'p_contact_website': contactWebsite,
          'p_contact_notes': contactNotes,
          'p_is_published': isPublished,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la sauvegarde du cours.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la sauvegarde du cours en ligne.',
        );
        return false;
      }
      await loadOnlineCourses();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<List<Map<String, dynamic>>> loadEnrollments(String courseId) async {
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_list_online_course_enrollments',
        params: {'p_course_id': courseId},
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ??
                  'Erreur lors du chargement des inscriptions au cours en ligne.'
              : 'Erreur lors du chargement des inscriptions au cours en ligne.',
        );
        return const [];
      }
      final data = response['enrollments'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }
      return const [];
    } catch (e) {
      _setError(e.toString());
      return const [];
    }
  }
}
