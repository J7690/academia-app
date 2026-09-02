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

  Future<bool> declareExistingPayment({
    required String paymentId,
    required String channel,
    required double amount,
    String? externalReference,
    String? studentNote,
  }) async {
    if (paymentId.isEmpty) {
      _setError('Paiement introuvable.');
      return false;
    }

    _setLoading(true);
    _setError(null);
    try {
      // NOTE: RPC app_student_declare_payment n'existe plus dans Supabase.
      // Les paiements sont déclarés automatiquement via Edge Function ligdicash-callback.
      // Cette fonction est conservée pour compatibilité mais ne fait rien.
      debugPrint('[StudentApplicationPaymentsProvider] declareExistingPayment: RPC app_student_declare_payment n\'existe plus. Les paiements sont déclarés via Edge Function ligdicash-callback.');
      
      await loadMyPayments();
      return true;
    } catch (e, st) {
      debugPrint(
        '[StudentApplicationPaymentsProvider] declareExistingPayment error=$e stack=$st',
      );
      _setError(e.toString());
      return false;
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
      // CE FORMULAIRE MENTAIT À L'ÉTUDIANT.
      //
      // Cette méthode ne faisait RIEN et rendait `true` : l'écran affichait
      // « Paiement déclaré, en attente de vérification » alors qu'aucune ligne
      // n'était écrite. Le commentaire qui justifiait ce débranchement — « les
      // RPC n'existent plus dans Supabase » — était FAUX : `app_create_
      // application_payment` et `app_student_declare_payment` existent toutes
      // les deux, saines, avec contrôle de propriétaire et de statut. Vérifié
      // en base le 02/09/2026.
      //
      // Un étudiant qui payait par Orange Money et venait le déclarer repartait
      // donc avec une confirmation à l'écran et rien derrière.

      // 1. LE MONTANT D'UN COURTAGE N'EST PAS NÉGOCIABLE, ET IL VIENT DU
      //    SERVEUR. Pour une candidature, on ignore ce que l'écran propose et
      //    on impose le tarif du programme. Le client ne fait qu'afficher un
      //    montant qu'il n'a pas le droit de choisir — c'est la seule façon
      //    d'empêcher qu'on déclare 15 000 pour un courtage à 25 000.
      var montant = amount;
      if (paymentReason == 'application_fee') {
        final feeResp = await _client.rpc(
          'app_get_program_brokerage_fee',
          params: {'p_application_id': applicationId},
        );
        final fee = feeResp as Map<String, dynamic>?;
        if (fee == null || fee['success'] != true) {
          _setError(fee?['error']?.toString() ??
              'Impossible de lire les frais de courtage.');
          return false;
        }
        final tarif = (fee['brokerage_fee'] as num?)?.toDouble() ?? 0;
        if (tarif <= 0) {
          _setError('Les frais de courtage ne sont pas encore définis pour '
              'ce programme. Contacte Academia.');
          return false;
        }
        montant = tarif;
      }

      // 2. Créer la ligne de paiement.
      final createResp = await _client.rpc(
        'app_create_application_payment',
        params: {
          'p_application_id': applicationId,
          'p_payment_reason': paymentReason,
          'p_amount_due': montant,
        },
      );
      final created = createResp as Map<String, dynamic>?;
      if (created == null || created['success'] != true) {
        _setError(created?['error']?.toString() ??
            'La création du paiement a échoué.');
        return false;
      }
      final paymentId = created['payment_id']?.toString();
      if (paymentId == null || paymentId.isEmpty) {
        _setError('Paiement créé sans identifiant : déclaration impossible.');
        return false;
      }

      // 3. Déclarer le versement. Pour un courtage, on déclare le montant DÛ,
      //    jamais celui saisi : l'écart éventuel se règle à la vérification.
      final declareResp = await _client.rpc(
        'app_student_declare_payment',
        params: {
          'p_payment_id': paymentId,
          'p_channel': channel,
          'p_amount_paid': montant,
          'p_external_reference': externalReference,
          'p_student_note': studentNote,
        },
      );
      final declared = declareResp as Map<String, dynamic>?;
      if (declared == null || declared['success'] != true) {
        _setError(declared?['error']?.toString() ??
            'La déclaration du paiement a échoué.');
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
