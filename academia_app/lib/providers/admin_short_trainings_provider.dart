import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour la gestion des formations courtes Nexium Group côté admin.
/// Utilise les RPC app_admin_list_short_trainings,
/// app_admin_upsert_short_training,
/// app_admin_upsert_short_training_session et
/// app_admin_list_short_training_registrations.
class AdminShortTrainingsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _trainings = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get trainings => List.unmodifiable(_trainings);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadTrainings() async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc('app_admin_list_short_trainings');
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement des formations courtes.',
        );
        return;
      }
      final data = response['trainings'];
      if (data is List) {
        _trainings = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _trainings = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> upsertTraining({
    String? trainingId,
    required String title,
    String? shortDescription,
    String? fullDescription,
    String? category,
    String? modality,
    int? durationDays,
    double? price,
    bool? isActive,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_upsert_short_training',
        params: {
          'p_training_id': trainingId,
          'p_title': title,
          'p_short_description': shortDescription,
          'p_full_description': fullDescription,
          'p_category': category,
          'p_modality': modality,
          'p_duration_days': durationDays,
          'p_price': price,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ??
                  'Erreur lors de l\'enregistrement de la formation courte.'
              : 'Erreur lors de l\'enregistrement de la formation courte.',
        );
        return false;
      }
      await loadTrainings();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> upsertSession({
    String? sessionId,
    required String trainingId,
    required DateTime startAt,
    DateTime? endAt,
    String? location,
    int? capacity,
    String? status,
    bool? isActive,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_upsert_short_training_session',
        params: {
          'p_session_id': sessionId,
          'p_training_id': trainingId,
          'p_start_at': startAt.toIso8601String(),
          'p_end_at': endAt?.toIso8601String(),
          'p_location': location,
          'p_capacity': capacity,
          'p_status': status,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ??
                  'Erreur lors de l\'enregistrement de la session.'
              : 'Erreur lors de l\'enregistrement de la session.',
        );
        return false;
      }
      await loadTrainings();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<Map<String, dynamic>>> loadRegistrations(String sessionId) async {
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_list_short_training_registrations',
        params: {'p_session_id': sessionId},
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ??
                  'Erreur lors du chargement des inscriptions.'
              : 'Erreur lors du chargement des inscriptions.',
        );
        return const [];
      }
      final data = response['registrations'];
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
