import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour les candidatures étudiant
/// Utilise les RPC app_list_student_applications et app_create_application
class StudentApplicationsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _applications = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get applications => _applications;
  int get unreadCount =>
      _applications.where((app) => app['has_unread_for_student'] == true).length;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadApplications() async {
    _setLoading(true);
    _setError(null);
    try {
      final data = await _client.rpc('app_list_student_applications') as List<dynamic>? ?? [];
      _applications = data.cast<Map<String, dynamic>>();
      _sortApplicationsByActivity();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  void _sortApplicationsByActivity() {
    DateTime _parseDate(dynamic value) {
      if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
      if (value is DateTime) return value;
      final s = value.toString();
      return DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    DateTime _activityFor(Map<String, dynamic> app) {
      final createdAt = _parseDate(app['created_at']);
      final updatedAt = _parseDate(app['updated_at']);
      final lastMessageAt = _parseDate(app['last_message_at']);
      final base = updatedAt.isAfter(createdAt) ? updatedAt : createdAt;
      return lastMessageAt.isAfter(base) ? lastMessageAt : base;
    }

    _applications.sort((a, b) {
      final aDate = _activityFor(a);
      final bDate = _activityFor(b);
      return bDate.compareTo(aDate);
    });
  }

  Future<bool> createApplication({
    required String programId,
    String? motivationText,
    String? requestedDegreeLevel,
    String? requestedStudyMode,
    String? requestedSchedule,
    bool? discountRequested,
    String? discountDetails,
    String? studentComment,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      String? _normalizeText(String? value) {
        if (value == null) return null;
        final trimmed = value.trim();
        if (trimmed.isEmpty) return null;
        return trimmed;
      }

      final response = await _client.rpc(
        'app_create_application',
        params: {
          'p_program_id': programId,
          'p_motivation_text': _normalizeText(motivationText),
          'p_requested_degree_level': _normalizeText(requestedDegreeLevel),
          'p_requested_study_mode': _normalizeText(requestedStudyMode),
          'p_requested_schedule': _normalizeText(requestedSchedule),
          'p_discount_requested': discountRequested,
          'p_discount_details': _normalizeText(discountDetails),
          'p_student_comment': _normalizeText(studentComment),
        },
      );
      final data = response as Map<String, dynamic>?;
      if (data == null) {
        _setError('Réponse invalide du serveur lors de la création de la candidature.');
        return false;
      }

      final success = data['success'] == true;
      if (!success) {
        final errorCode = data['error']?.toString();

        if (errorCode == 'dossier_incomplete') {
          final details = data['details'];
          List<dynamic> missingFields = const [];
          if (details is Map && details['missing_fields'] is List) {
            missingFields = List<dynamic>.from(details['missing_fields'] as List);
          }

          if (missingFields.isNotEmpty) {
            _setError(
              'Votre dossier de candidature n\'est pas complet. '
              'Champs manquants : ${missingFields.join(', ')}.',
            );
          } else {
            _setError(
              'Votre dossier de candidature n\'est pas complet. '
              'Veuillez compléter votre profil académique avant de candidater.',
            );
          }
        } else {
          _setError(
            data['error']?.toString() ??
                'Erreur lors de la création de la candidature.',
          );
        }

        return false;
      }

      await loadApplications();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
