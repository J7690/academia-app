import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminProgramsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _programs = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get programs => List.unmodifiable(_programs);

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
      final response = await _client.rpc('app_admin_list_all_programs');
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

  /// Crée (programId == null) ou met à jour un programme pour n'importe quel
  /// établissement partenaire. Permet à l'admin de gérer directement les
  /// formations d'un partenaire sans compte dédié (ex: auto-écoles).
  Future<bool> upsertProgram({
    required String universityId,
    String? programId,
    String? title,
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
        'app_admin_upsert_program',
        params: {
          'p_university_id': universityId,
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
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ??
                  'Erreur lors de l\'enregistrement du programme.'
              : 'Erreur lors de l\'enregistrement du programme.',
        );
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

  Future<bool> deleteProgram(String programId) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_delete_program',
        params: {'p_program_id': programId},
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ??
                  'Erreur lors de la suppression du programme.'
              : 'Erreur lors de la suppression du programme.',
        );
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

  Future<bool> updateProgramStatus({
    required String programId,
    bool? isActive,
    bool? highlighted,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_update_program_status',
        params: {
          'p_program_id': programId,
          'p_is_active': isActive,
          'p_highlighted': highlighted,
        },
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ??
                  'Erreur lors de la mise à jour du programme.'
              : 'Erreur lors de la mise à jour du programme.',
        );
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
}
