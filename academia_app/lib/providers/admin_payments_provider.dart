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
      // CES DEUX MÉTHODES NE FAISAIENT RIEN, ET RENVOYAIENT `true`.
      //
      // Leurs commentaires — « la RPC n'existe plus dans Supabase » — étaient
      // FAUX : `app_admin_verify_payment` et `app_admin_confirm_payment`
      // existent, contrôlent le rôle admin, gardent les statuts, et la seconde
      // émet le reçu via app.emettre_recu(). L'écran affichait pourtant
      // « Paiement confirmé et reçu généré » sans qu'aucune ligne ne bouge.
      // Constat B8 de l'audit du 03/09/2026.
      final resp = await _client.rpc(
        'app_admin_verify_payment',
        params: {
          'p_payment_id': paymentId,
          'p_decision': isValid ? 'valid' : 'invalid',
          'p_comment': comment,
        },
      );
      final data = resp as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        if (!_disposed) {
          _setError(
            data?['error']?.toString() ?? 'La vérification n\'a pas abouti.',
          );
        }
        return false;
      }

      await loadAllPayments();
      return true;
    } catch (e, st) {
      debugPrint('[AdminPaymentsProvider] verifyPayment error=$e stack=$st');
      if (!_disposed) _setError(e.toString());
      return false;
    }
  }

  Future<bool> confirmPayment(String paymentId) async {
    if (_disposed) return false;
    _setError(null);
    try {
      // Confirme réellement le paiement ET déclenche l'émission du reçu
      // (app_admin_confirm_payment → app.emettre_recu). Voir le commentaire
      // de verifyPayment ci-dessus.
      final resp = await _client.rpc(
        'app_admin_confirm_payment',
        params: {'p_payment_id': paymentId},
      );
      final data = resp as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        if (!_disposed) {
          _setError(
            data?['error']?.toString() ?? 'La confirmation n\'a pas abouti.',
          );
        }
        return false;
      }

      await loadAllPayments();
      return true;
    } catch (e, st) {
      debugPrint('[AdminPaymentsProvider] confirmPayment error=$e stack=$st');
      if (!_disposed) _setError(e.toString());
      return false;
    }
  }
}
