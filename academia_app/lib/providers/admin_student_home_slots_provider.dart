import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminStudentHomeSlotsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _slots = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get slots => List.unmodifiable(_slots);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadSlots() async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc('app_admin_list_student_home_slots');
      if (response is! Map<String, dynamic>) {
        _setError("Réponse invalide du serveur pour les slots d'accueil.");
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors du chargement des slots d'accueil.",
        );
        return;
      }
      final data = response['slots'];
      if (data is List) {
        _slots = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _slots = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> upsertSlot({
    String? slotId,
    required String domain,
    required String objectId,
    required String slot,
    int? sortOrder,
    bool? isActive,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_upsert_student_home_slot',
        params: {
          'p_slot_id': slotId,
          'p_domain': domain,
          'p_object_id': objectId,
          'p_slot': slot,
          'p_sort_order': sortOrder,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ??
                  "Erreur lors de l'enregistrement du slot d'accueil."
              : "Erreur lors de l'enregistrement du slot d'accueil.",
        );
        return false;
      }
      await loadSlots();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteSlot(String slotId) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_delete_student_home_slot',
        params: {
          'p_slot_id': slotId,
        },
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ??
                  "Erreur lors de la suppression du slot d'accueil."
              : "Erreur lors de la suppression du slot d'accueil.",
        );
        return false;
      }
      await loadSlots();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
