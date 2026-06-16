import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour gérer les crédits Academia de l'étudiant.
class CreditProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  int _balance = 0;
  int _totalPurchased = 0;
  int _totalConsumed = 0;
  int _totalGifted = 0;
  String? _lastWeeklyBonus;
  List<Map<String, dynamic>> _packs = [];
  List<Map<String, dynamic>> _actionPrices = [];
  List<Map<String, dynamic>> _transactions = [];
  int _transactionsTotal = 0;
  bool _initialized = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  int get balance => _balance;
  int get totalPurchased => _totalPurchased;
  int get totalConsumed => _totalConsumed;
  int get totalGifted => _totalGifted;
  String? get lastWeeklyBonus => _lastWeeklyBonus;
  List<Map<String, dynamic>> get packs => _packs;
  List<Map<String, dynamic>> get actionPrices => _actionPrices;
  List<Map<String, dynamic>> get transactions => _transactions;
  int get transactionsTotal => _transactionsTotal;
  bool get initialized => _initialized;

  /// Peut réclamer le bonus hebdomadaire ?
  bool get canClaimWeeklyBonus {
    if (_lastWeeklyBonus == null) return true;
    final last = DateTime.tryParse(_lastWeeklyBonus!);
    if (last == null) return true;
    return DateTime.now().difference(last).inDays >= 6;
  }

  /// Charge le solde de crédits.
  Future<void> loadBalance() async {
    try {
      final resp = await _client.rpc('app_student_get_credit_balance');
      final data = resp as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        _balance = (data['balance'] as num?)?.toInt() ?? 0;
        _totalPurchased = (data['total_purchased'] as num?)?.toInt() ?? 0;
        _totalConsumed = (data['total_consumed'] as num?)?.toInt() ?? 0;
        _totalGifted = (data['total_gifted'] as num?)?.toInt() ?? 0;
        _lastWeeklyBonus = data['last_weekly_bonus']?.toString();
      }
      _initialized = true;
      _error = null;
    } catch (e) {
      debugPrint('[CreditProvider] loadBalance error=$e');
      _error = e.toString();
      _initialized = true;
    }
    notifyListeners();
  }

  /// Charge les packs disponibles.
  Future<void> loadPacks() async {
    try {
      final resp = await _client.rpc('app_student_list_credit_packs');
      final data = resp as Map<String, dynamic>?;
      if (data != null && data['success'] == true && data['packs'] is List) {
        _packs = (data['packs'] as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('[CreditProvider] loadPacks error=$e');
    }
    notifyListeners();
  }

  /// Charge les prix des actions IA.
  Future<void> loadActionPrices() async {
    try {
      final resp = await _client.rpc('app_student_list_ai_action_prices');
      final data = resp as Map<String, dynamic>?;
      if (data != null && data['success'] == true && data['actions'] is List) {
        _actionPrices = (data['actions'] as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('[CreditProvider] loadActionPrices error=$e');
    }
    notifyListeners();
  }

  /// Charge l'historique des transactions.
  Future<void> loadTransactions({int limit = 20, int offset = 0}) async {
    try {
      final resp = await _client.rpc('app_student_list_credit_transactions', params: {
        'p_limit': limit,
        'p_offset': offset,
      });
      final data = resp as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        _transactions = (data['transactions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _transactionsTotal = (data['total'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      debugPrint('[CreditProvider] loadTransactions error=$e');
    }
    notifyListeners();
  }

  /// Vérifie si l'étudiant a assez de crédits pour une action.
  Future<Map<String, dynamic>> checkAccess(String actionCode) async {
    try {
      final resp = await _client.rpc('app_student_check_ai_access', params: {
        'p_action_code': actionCode,
      });
      final data = resp as Map<String, dynamic>?;
      return data ?? {'success': false, 'error': 'null_response'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Réclame le bonus hebdomadaire.
  Future<Map<String, dynamic>> claimWeeklyBonus() async {
    _isLoading = true;
    notifyListeners();
    try {
      final resp = await _client.rpc('app_student_claim_weekly_bonus');
      final data = resp as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        _balance = (data['new_balance'] as num?)?.toInt() ?? _balance;
        _totalGifted += (data['credits_added'] as num?)?.toInt() ?? 0;
        _lastWeeklyBonus = DateTime.now().toIso8601String();
        _error = null;
      }
      return data ?? {'success': false};
    } catch (e) {
      _error = e.toString();
      return {'success': false, 'error': e.toString()};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Achète un pack de crédits (appelé après paiement LigdiCash confirmé).
  Future<Map<String, dynamic>> purchaseCredits(String packCode, {String? paymentId}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final resp = await _client.rpc('app_student_purchase_credits', params: {
        'p_pack_code': packCode,
        'p_payment_id': paymentId,
      });
      final data = resp as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        _balance = (data['new_balance'] as num?)?.toInt() ?? _balance;
        _totalPurchased += (data['credits_added'] as num?)?.toInt() ?? 0;
        _error = null;
      }
      return data ?? {'success': false};
    } catch (e) {
      _error = e.toString();
      return {'success': false, 'error': e.toString()};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Prix en crédits d'une action IA.
  int costForAction(String actionCode) {
    for (final a in _actionPrices) {
      if (a['action_code'] == actionCode) {
        return (a['cost_credits'] as num?)?.toInt() ?? 0;
      }
    }
    return 0;
  }

  /// Label d'une action IA.
  String labelForAction(String actionCode) {
    for (final a in _actionPrices) {
      if (a['action_code'] == actionCode) {
        return a['label']?.toString() ?? actionCode;
      }
    }
    return actionCode;
  }

  /// Charge tout d'un coup (solde + packs + prix).
  Future<void> loadAll() async {
    await Future.wait([loadBalance(), loadPacks(), loadActionPrices()]);
  }

  /// Met à jour le solde localement (après consommation côté Edge Function).
  void deductLocally(int amount) {
    _balance = (_balance - amount).clamp(0, 999999);
    _totalConsumed += amount;
    notifyListeners();
  }
}
