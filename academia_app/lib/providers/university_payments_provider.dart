import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UniversityPaymentsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _payments = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get payments => _payments;

  int get totalCount => _payments.length;
  int get confirmedCount =>
      _payments.where((p) => p['status'] == 'confirmed').length;
  int get pendingCount =>
      _payments.where((p) => p['status'] != 'confirmed' && p['status'] != 'rejected' && p['status'] != 'cancelled').length;

  Future<void> loadPayments() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final resp = await _client.rpc('app_university_list_payments');
      final data = resp as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        _error = data?['error']?.toString() ?? 'Erreur lors du chargement.';
        notifyListeners();
        return;
      }
      final list = data['payments'] as List<dynamic>? ?? [];
      _payments = list.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e, st) {
      debugPrint('[UniversityPaymentsProvider] loadPayments error=$e stack=$st');
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
