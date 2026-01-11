import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentHomeSlotsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  final Map<String, List<Map<String, dynamic>>> _itemsBySlot = {};

  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Map<String, dynamic>> getItemsForSlot(String slot) {
    return List.unmodifiable(_itemsBySlot[slot] ?? const []);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadSlotItems(String slot) async {
    if (slot.trim().isEmpty) return;
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_list_student_home_slot_items',
        params: {
          'p_slot': slot,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          "Réponse invalide du serveur pour les éléments du slot d'accueil.",
        );
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors du chargement des éléments du slot d'accueil.",
        );
        return;
      }
      final data = response['items'];
      if (data is List) {
        _itemsBySlot[slot] = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _itemsBySlot[slot] = const [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
}
