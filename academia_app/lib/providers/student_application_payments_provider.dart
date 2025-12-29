import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentApplicationPaymentsProvider extends ChangeNotifier {
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

  /// Charge tous les paiements du profil étudiant courant (via RLS).
  Future<void> loadMyPayments() async {
    _setLoading(true);
    _setError(null);
    try {
      final raw = await _client
          .schema('app')
          .from('application_payments')
          .select()
          .order('created_at', ascending: false);

      final list = raw as List<dynamic>? ?? [];
      _payments = list.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e, st) {
      debugPrint(
        '[StudentApplicationPaymentsProvider] loadMyPayments error=$e stack=$st',
      );
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadPayments(String applicationId) async {
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
        '[StudentApplicationPaymentsProvider] loadPayments error=$e stack=$st',
      );
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createAndDeclarePayment({
    required String applicationId,
    required String paymentReason,
    required String channel,
    required double amount,
    String? externalReference,
    String? studentNote,
  }) async {
    if (applicationId.isEmpty) {
      _setError('Candidature invalide.');
      return false;
    }
    _setLoading(true);
    _setError(null);
    try {
      final createResp = await _client.rpc(
        'app_create_application_payment',
        params: {
          'p_application_id': applicationId,
          'p_payment_reason': paymentReason,
          'p_amount_due': amount,
        },
      );
      final createData = createResp as Map<String, dynamic>?;
      if (createData == null || createData['success'] != true) {
        _setError(
          createData?['error']?.toString() ??
              'Erreur lors de la création de l\'intention de paiement.',
        );
        return false;
      }

      final paymentId = createData['payment_id']?.toString();
      if (paymentId == null || paymentId.isEmpty) {
        _setError('Réponse serveur invalide (payment_id manquant).');
        return false;
      }

      final declareResp = await _client.rpc(
        'app_student_declare_payment',
        params: {
          'p_payment_id': paymentId,
          'p_channel': channel,
          'p_amount_paid': amount,
          'p_external_reference': externalReference,
          'p_student_note': studentNote,
        },
      );
      final declareData = declareResp as Map<String, dynamic>?;
      if (declareData == null || declareData['success'] != true) {
        _setError(
          declareData?['error']?.toString() ??
              'Erreur lors de la déclaration du paiement.',
        );
        return false;
      }

      await loadPayments(applicationId);
      return true;
    } catch (e, st) {
      debugPrint(
        '[StudentApplicationPaymentsProvider] createAndDeclarePayment error=$e stack=$st',
      );
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createAndDeclareProfilePayment({
    required String paymentReason,
    required String channel,
    required double amount,
    String? externalReference,
    String? studentNote,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final createResp = await _client.rpc(
        'app_student_create_profile_payment',
        params: {
          'p_payment_reason': paymentReason,
          'p_amount_due': amount,
        },
      );
      final createData = createResp as Map<String, dynamic>?;
      if (createData == null || createData['success'] != true) {
        _setError(
          createData?['error']?.toString() ??
              'Erreur lors de la création de l\'intention de paiement (profil).',
        );
        return false;
      }

      final paymentId = createData['payment_id']?.toString();
      if (paymentId == null || paymentId.isEmpty) {
        _setError('Réponse serveur invalide (payment_id manquant).');
        return false;
      }

      final declareResp = await _client.rpc(
        'app_student_declare_payment',
        params: {
          'p_payment_id': paymentId,
          'p_channel': channel,
          'p_amount_paid': amount,
          'p_external_reference': externalReference,
          'p_student_note': studentNote,
        },
      );
      final declareData = declareResp as Map<String, dynamic>?;
      if (declareData == null || declareData['success'] != true) {
        _setError(
          declareData?['error']?.toString() ??
              'Erreur lors de la déclaration du paiement (profil).',
        );
        return false;
      }

      await loadMyPayments();
      return true;
    } catch (e, st) {
      debugPrint(
        '[StudentApplicationPaymentsProvider] createAndDeclareProfilePayment error=$e stack=$st',
      );
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<Map<String, dynamic>>> getReceiptsForPayment(
      String paymentId) async {
    if (paymentId.isEmpty) return [];
    try {
      final raw = await _client
          .schema('app')
          .from('payment_receipts')
          .select()
          .eq('payment_id', paymentId)
          .order('issued_at', ascending: false);

      final list = raw as List<dynamic>? ?? [];
      return list.cast<Map<String, dynamic>>();
    } catch (e, st) {
      debugPrint(
        '[StudentApplicationPaymentsProvider] getReceiptsForPayment error=$e stack=$st',
      );
      return [];
    }
  }
}
