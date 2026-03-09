import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminCommissionRulesProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isUpdating = false;
  String? _error;
  List<Map<String, dynamic>> _rules = [];

  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  String? get error => _error;
  List<Map<String, dynamic>> get rules => List.unmodifiable(_rules);

  Future<void> loadRules() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final resp = await _client.rpc('app_admin_list_commission_rules');
      if (resp is! Map<String, dynamic> || resp['success'] != true) {
        _error = resp?['error']?.toString() ?? 'Erreur lors du chargement.';
        return;
      }
      final data = resp['rules'];
      if (data is List) {
        _rules = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _rules = [];
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> upsertRule({
    required String paymentReason,
    required String degreeLevel,
    required double commissionRate,
    double maxAmount = 0,
    String? description,
    int priority = 0,
    bool isActive = true,
  }) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();
    try {
      final resp = await _client.rpc('app_admin_upsert_commission_rule', params: {
        'p_payment_reason': paymentReason,
        'p_degree_level': degreeLevel,
        'p_commission_rate': commissionRate,
        'p_max_amount': maxAmount,
        'p_description': description,
        'p_priority': priority,
        'p_is_active': isActive,
      });
      if (resp is! Map<String, dynamic> || resp['success'] != true) {
        _error = resp?['error']?.toString() ?? 'Erreur lors de la sauvegarde.';
        return false;
      }
      await loadRules();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<bool> deleteRule(String ruleId) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();
    try {
      final resp = await _client.rpc('app_admin_delete_commission_rule', params: {
        'p_rule_id': ruleId,
      });
      if (resp is! Map<String, dynamic> || resp['success'] != true) {
        _error = resp?['error']?.toString() ?? 'Erreur lors de la suppression.';
        return false;
      }
      await loadRules();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }
}
