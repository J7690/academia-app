import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPaymentReceiptsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _receipts = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get receipts => _receipts;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadAllReceipts() async {
    _setLoading(true);
    _setError(null);
    try {
      final raw = await _client.rpc(
        'app_admin_list_payment_receipts_with_context',
      );
      final list = raw as List<dynamic>? ?? [];
      _receipts = list.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e, st) {
      debugPrint('[AdminPaymentReceiptsProvider] loadAllReceipts error=$e stack=$st');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> reload() => loadAllReceipts();
}
