import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPaymentsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  bool _disposed = false;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _payments = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get payments => _payments;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _setLoading(bool value) {
    if (_disposed) return;
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    if (_disposed) return;
    _error = value;
    notifyListeners();
  }

  Future<void> loadAllPayments() async {
    if (_disposed) return;
    _setLoading(true);
    _setError(null);
    try {
      final raw = await _client.rpc('app_admin_list_payments_with_context');
      final list = raw as List<dynamic>? ?? [];
      if (!_disposed) {
        _payments = list.cast<Map<String, dynamic>>();
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('[AdminPaymentsProvider] loadAllPayments error=$e stack=$st');
      if (!_disposed) _setError(e.toString());
    } finally {
      if (!_disposed) _setLoading(false);
    }
  }

  Future<void> reload() => loadAllPayments();

  Future<bool> verifyPayment({
    required String paymentId,
    required bool isValid,
    String? comment,
  }) async {
    if (_disposed) return false;
    _setError(null);
    try {
      // NOTE: RPC app_admin_verify_payment n'existe plus dans Supabase.
      // Les paiements sont vérifiés automatiquement via Edge Function ligdicash-callback.
      // Cette fonction est conservée pour compatibilité mais ne fait rien.
      debugPrint('[AdminPaymentsProvider] verifyPayment: RPC app_admin_verify_payment n\'existe plus. Les paiements sont vérifiés via Edge Function ligdicash-callback.');
      
      await loadAllPayments();
      return true;
    } catch (e, st) {
      debugPrint('[AdminPaymentsProvider] verifyPayment error=$e stack=$st');
      if (_disposed) _setError(e.toString());
      return false;
    }
  }

  Future<bool> confirmPayment(String paymentId) async {
    if (_disposed) return false;
    _setError(null);
    try {
      // NOTE: RPC app_admin_confirm_payment n'existe plus dans Supabase.
      // Les paiements sont confirmés automatiquement via Edge Function ligdicash-callback.
      // Cette fonction est conservée pour compatibilité mais ne fait rien.
      debugPrint('[AdminPaymentsProvider] confirmPayment: RPC app_admin_confirm_payment n\'existe plus. Les paiements sont confirmés via Edge Function ligdicash-callback.');
      
      await loadAllPayments();
      return true;
    } catch (e, st) {
      debugPrint('[AdminPaymentsProvider] confirmPayment error=$e stack=$st');
      if (_disposed) _setError(e.toString());
      return false;
    }
  }
}
