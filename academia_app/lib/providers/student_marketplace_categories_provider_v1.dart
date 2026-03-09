import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentMarketplaceCategoriesProviderV1 extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> _rootCategories = [];
  final Map<String, List<Map<String, dynamic>>> _subCategoriesByParentId = {};

  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Map<String, dynamic>> get rootCategories =>
      List.unmodifiable(_rootCategories);

  List<Map<String, dynamic>> subCategories(String parentId) =>
      List.unmodifiable(_subCategoriesByParentId[parentId] ?? const []);

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setError(String? v) {
    _error = v;
    notifyListeners();
  }

  Future<void> loadRootCategories() async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_list_marketplace_categories',
        params: {
          'p_parent_id': null,
        },
      );

      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur serveur.');
        return;
      }

      final data = response['items'];
      if (data is List) {
        _rootCategories = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _rootCategories = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadSubCategories(String parentId) async {
    if (parentId.trim().isEmpty) return;

    _setLoading(true);
    _setError(null);

    try {
      final response = await _client.rpc(
        'app_list_marketplace_categories',
        params: {
          'p_parent_id': parentId,
        },
      );

      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur serveur.');
        return;
      }

      final data = response['items'];
      if (data is List) {
        _subCategoriesByParentId[parentId] = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _subCategoriesByParentId[parentId] = [];
      }

      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
}
