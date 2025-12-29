import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPaymentDetailProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _payment;
  List<Map<String, dynamic>> _receipts = [];
  List<Map<String, dynamic>> _proofs = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get payment => _payment;
  List<Map<String, dynamic>> get receipts => _receipts;
  List<Map<String, dynamic>> get proofs => _proofs;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadDetail(String paymentId) async {
    if (paymentId.isEmpty) {
      _setError('Identifiant de paiement invalide.');
      return;
    }
    _setLoading(true);
    _setError(null);
    try {
      final resp = await _client.rpc(
        'app_admin_get_payment_detail',
        params: {
          'p_payment_id': paymentId,
        },
      );
      final data = resp as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        _setError(
          data?['error']?.toString() ??
              'Erreur lors du chargement du détail du paiement.',
        );
        return;
      }

      final paymentMap =
          (data['payment'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final receiptsList = (data['receipts'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final proofsList = (data['proofs'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      _payment = paymentMap;
      _receipts = receiptsList;
      _proofs = proofsList;
      notifyListeners();
    } catch (e, st) {
      debugPrint(
        '[AdminPaymentDetailProvider] loadDetail error=$e stack=$st',
      );
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
}
