import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider admin pour la gestion du calendrier académique global.
/// Utilise les RPC :
/// - app_admin_list_academic_events
/// - app_admin_upsert_academic_event
/// - app_admin_delete_academic_event
class AdminAcademicEventsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _events = <Map<String, dynamic>>[];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get events =>
      List<Map<String, dynamic>>.unmodifiable(_events);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadEvents() async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_list_academic_events',
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        _events = <Map<String, dynamic>>[];
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement des événements académiques.',
        );
        _events = <Map<String, dynamic>>[];
        return;
      }
      final data = response['events'];
      if (data is List) {
        _events = data
            .whereType<Map>()
            .map(
              (dynamic e) =>
                  Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
            )
            .toList(growable: false);
      } else {
        _events = <Map<String, dynamic>>[];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      _events = <Map<String, dynamic>>[];
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> upsertEvent({
    String? eventId,
    required String title,
    String? description,
    String eventType = 'other',
    String? country,
    String? city,
    String? location,
    String? level,
    List<String>? tags,
    bool? isAllDay,
    DateTime? startAt,
    DateTime? endAt,
    DateTime? registrationOpenAt,
    DateTime? registrationDeadlineAt,
    bool? isPublished,
    bool? isHighlighted,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final Map<String, dynamic> params = <String, dynamic>{
        'p_event_id': eventId,
        'p_title': title,
        'p_description': description,
        'p_event_type': eventType,
        'p_country': country,
        'p_city': city,
        'p_location': location,
        'p_university_id': null,
        'p_program_id': null,
        'p_level': level,
        'p_tags': tags,
        'p_is_all_day': isAllDay,
        'p_start_at': startAt?.toIso8601String(),
        'p_end_at': endAt?.toIso8601String(),
        'p_registration_open_at': registrationOpenAt?.toIso8601String(),
        'p_registration_deadline_at':
            registrationDeadlineAt?.toIso8601String(),
        'p_is_published': isPublished,
        'p_is_highlighted': isHighlighted,
      };

      final dynamic response = await _client.rpc(
        'app_admin_upsert_academic_event',
        params: params,
      );

      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la sauvegarde de l\'événement.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors de la sauvegarde de l'événement académique.",
        );
        return false;
      }
      await loadEvents();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteEvent(String eventId) async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_delete_academic_event',
        params: <String, dynamic>{
          'p_event_id': eventId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la suppression de l\'événement.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors de la suppression de l'événement.",
        );
        return false;
      }
      await loadEvents();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
