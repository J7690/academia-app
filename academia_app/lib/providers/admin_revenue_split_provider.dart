import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRevenueSplitProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  List<Map<String, dynamic>> _rules = [];
  List<Map<String, dynamic>> _validations = [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  List<Map<String, dynamic>> get rules => _rules;
  List<Map<String, dynamic>> get validations => _validations;

  /// Grouper les règles par payment_reason pour l'affichage en tableau.
  Map<String, List<Map<String, dynamic>>> get rulesByReason {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final r in _rules) {
      final reason = r['payment_reason']?.toString() ?? '*';
      map.putIfAbsent(reason, () => []).add(r);
    }
    return map;
  }

  Future<void> loadRules() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final resp = await _client.rpc('app_admin_list_revenue_split_rules');
      final data = resp as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        final list = data['rules'] as List<dynamic>? ?? [];
        _rules = list.cast<Map<String, dynamic>>();
      } else {
        _error = data?['error']?.toString() ?? 'Erreur chargement règles.';
      }
    } catch (e, st) {
      debugPrint('[AdminRevenueSplitProvider] loadRules error=$e\n$st');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadValidations() async {
    try {
      final resp = await _client.rpc('app_admin_validate_split_totals');
      final data = resp as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        final list = data['validations'] as List<dynamic>? ?? [];
        _validations = list.cast<Map<String, dynamic>>();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AdminRevenueSplitProvider] loadValidations error=$e');
    }
  }

  Future<bool> upsertRule({
    required String paymentReason,
    required String beneficiaryType,
    required double percentage,
    double? maxAmount,
    String? description,
    bool isActive = true,
  }) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final resp = await _client.rpc('app_admin_upsert_revenue_split_rule', params: {
        'p_payment_reason': paymentReason,
        'p_beneficiary_type': beneficiaryType,
        'p_percentage': percentage,
        if (maxAmount != null) 'p_max_amount': maxAmount,
        if (description != null) 'p_description': description,
        'p_is_active': isActive,
      });
      final data = resp as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        await loadRules();
        await loadValidations();
        return true;
      }
      _error = data?['error']?.toString() ?? 'Erreur sauvegarde.';
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteRule(String ruleId) async {
    try {
      final resp = await _client.rpc('app_admin_delete_revenue_split_rule', params: {'p_rule_id': ruleId});
      final data = resp as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        await loadRules();
        await loadValidations();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  bool isReasonValid(String reason) {
    for (final v in _validations) {
      if (v['payment_reason'] == reason) {
        return v['is_valid'] == true;
      }
    }
    return false;
  }

  double reasonTotal(String reason) {
    for (final v in _validations) {
      if (v['payment_reason'] == reason) {
        final t = v['total_percentage'];
        if (t is num) return t.toDouble();
      }
    }
    return 0;
  }

  static const reasonLabels = {
    'application_fee': 'Frais de dossier',
    'registration_fee': "Frais d'inscription",
    'tuition_deposit': 'Acompte scolarité',
    'td_access': 'Accès TD',
    'marketplace_purchase': 'Marketplace',
    'online_course': 'Cours en ligne',
    'subscription': 'Abonnement',
    '*': 'Défaut (wildcard)',
  };

  static const beneficiaryLabels = {
    'platform': 'Plateforme',
    'university': 'Université',
    'instructor': 'Enseignant',
    'commercial': 'Commercial',
    'merchant': 'Marchand',
  };
}
