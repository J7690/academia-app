import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminActorBalancesProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _balances = [];
  String _typeFilter = '';

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get balances => _balances;
  String get typeFilter => _typeFilter;

  void setTypeFilter(String type) {
    _typeFilter = type;
    loadBalances();
  }

  Future<void> loadBalances() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final resp = await _client.rpc('app_admin_list_actor_balances', params: {
        if (_typeFilter.isNotEmpty) 'p_actor_type': _typeFilter,
      });
      final data = resp as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        final list = data['balances'] as List<dynamic>? ?? [];
        _balances = list.cast<Map<String, dynamic>>();
      } else {
        _error = data?['error']?.toString() ?? 'Erreur chargement soldes.';
      }
    } catch (e, st) {
      debugPrint('[AdminActorBalancesProvider] loadBalances error=$e\n$st');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
