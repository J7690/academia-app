import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminTreasuryProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _ledger = [];
  int _ledgerTotal = 0;

  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get summary => _summary;
  List<Map<String, dynamic>> get ledger => _ledger;
  int get ledgerTotal => _ledgerTotal;

  Future<void> loadSummary() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final resp = await _client.rpc('app_admin_get_treasury_summary');
      final data = resp as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        _error = data?['error']?.toString() ?? 'Erreur chargement trésorerie.';
      } else {
        _summary = data;
      }
    } catch (e, st) {
      debugPrint('[AdminTreasuryProvider] loadSummary error=$e\n$st');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLedger({int limit = 50, int offset = 0, String? transactionType}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final resp = await _client.rpc('app_admin_list_ledger', params: {
        'p_limit': limit,
        'p_offset': offset,
        if (transactionType != null) 'p_transaction_type': transactionType,
      });
      final data = resp as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        _error = data?['error']?.toString() ?? 'Erreur chargement grand livre.';
      } else {
        final entries = data['entries'] as List<dynamic>? ?? [];
        _ledger = entries.cast<Map<String, dynamic>>();
        _ledgerTotal = data['total'] as int? ?? 0;
      }
    } catch (e, st) {
      debugPrint('[AdminTreasuryProvider] loadLedger error=$e\n$st');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
