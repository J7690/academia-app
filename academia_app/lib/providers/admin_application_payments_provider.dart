import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminApplicationPaymentsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _payments = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get payments => _payments;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadPaymentsForApplication(String applicationId) async {
    if (applicationId.isEmpty) return;
    _setLoading(true);
    _setError(null);
    try {
      final raw = await _client
          .schema('app')
          .from('application_payments')
          .select()
          .eq('application_id', applicationId)
          .order('created_at', ascending: false);
      final list = raw as List<dynamic>? ?? [];
      _payments = list.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e, st) {
      debugPrint(
        '[AdminApplicationPaymentsProvider] loadPaymentsForApplication error=$e stack=$st',
      );
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> verifyPayment({
    required String paymentId,
    required String decision, // 'valid' ou 'invalid'
    String? comment,
    required String applicationId,
  }) async {
    if (paymentId.isEmpty) {
      _setError('Paiement invalide.');
      return false;
    }
    _setLoading(true);
    _setError(null);
    try {
      final resp = await _client.rpc(
        'app_admin_verify_payment',
        params: {
          'p_payment_id': paymentId,
          'p_decision': decision,
          'p_comment': comment,
        },
      );
      final data = resp as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        _setError(
          data?['error']?.toString() ??
              'Erreur lors de la vérification du paiement.',
        );
        return false;
      }
      await loadPaymentsForApplication(applicationId);
      return true;
    } catch (e, st) {
      debugPrint(
        '[AdminApplicationPaymentsProvider] verifyPayment error=$e stack=$st',
      );
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> confirmPayment({
    required String paymentId,
    required String applicationId,
  }) async {
    if (paymentId.isEmpty) {
      _setError('Paiement invalide.');
      return false;
    }
    _setLoading(true);
    _setError(null);
    try {
      final resp = await _client.rpc(
        'app_admin_confirm_payment',
        params: {
          'p_payment_id': paymentId,
        },
      );
      final data = resp as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        _setError(
          data?['error']?.toString() ??
              'Erreur lors de la confirmation du paiement.',
        );
        return false;
      }
      await loadPaymentsForApplication(applicationId);
      return true;
    } catch (e, st) {
      debugPrint(
        '[AdminApplicationPaymentsProvider] confirmPayment error=$e stack=$st',
      );
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
