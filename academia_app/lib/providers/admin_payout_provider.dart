import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPayoutProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isProcessing = false;
  String? _error;
  List<Map<String, dynamic>> _payouts = [];
  int _total = 0;
  String _statusFilter = 'pending';

  bool get isLoading => _isLoading;
  bool get isProcessing => _isProcessing;
  String? get error => _error;
  List<Map<String, dynamic>> get payouts => _payouts;
  int get total => _total;
  String get statusFilter => _statusFilter;

  void setStatusFilter(String status) {
    _statusFilter = status;
    loadPayouts();
  }

  Future<void> loadPayouts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final resp = await _client.rpc('app_admin_list_payout_queue', params: {
        'p_status': _statusFilter.isEmpty ? null : _statusFilter,
        'p_limit': 100,
        'p_offset': 0,
      });
      final data = resp as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        _error = data?['error']?.toString() ?? 'Erreur chargement payouts.';
      } else {
        final list = data['payouts'] as List<dynamic>? ?? [];
        _payouts = list.cast<Map<String, dynamic>>();
        _total = data['total'] as int? ?? 0;
      }
    } catch (e, st) {
      debugPrint('[AdminPayoutProvider] loadPayouts error=$e\n$st');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> triggerPayouts({List<String>? payoutIds, bool allPending = false}) async {
    _isProcessing = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _client.functions.invoke(
        'ligdicash-payout',
        body: allPending
            ? {'all_pending': true}
            : {'payout_ids': payoutIds ?? []},
      );

      final rawData = response.data;
      Map<String, dynamic>? data;
      if (rawData is Map<String, dynamic>) {
        data = rawData;
      } else if (rawData is String) {
        try { data = jsonDecode(rawData) as Map<String, dynamic>?; } catch (_) {}
      }

      if (data?['success'] == true) {
        await loadPayouts();
        return true;
      } else {
        _error = data?['error']?.toString() ?? 'Erreur lors du traitement des payouts.';
        return false;
      }
    } catch (e, st) {
      debugPrint('[AdminPayoutProvider] triggerPayouts error=$e\n$st');
      _error = e.toString();
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }
}
