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

  bool _documentsEnCours = false;
  String? _erreurDocuments;
  List<Map<String, dynamic>> _recus = [];

  bool get documentsEnCours => _documentsEnCours;
  String? get erreurDocuments => _erreurDocuments;

  /// Les reçus de l'étudiant courant, du plus récent au plus ancien, chacun
  /// accompagné du paiement qu'il atteste.
  ///
  /// La politique RLS `recu_lisible_par_son_proprietaire` fait le filtrage :
  /// inutile de passer un `student_id`, et surtout on ne s'y fie pas.
  List<Map<String, dynamic>> get recus => _recus;

  Future<void> chargerMesDocuments() async {
    _documentsEnCours = true;
    _erreurDocuments = null;
    notifyListeners();
    try {
      // Le paiement est ramené dans la même requête : le reçu seul ne dit pas
      // son motif, et l'écran en a besoin pour la pastille de couleur.
      final raw = await _client
          .schema('app')
          .from('payment_receipts')
          .select('*, paiement:application_payments!inner(*)')
          .order('issued_at', ascending: false);

      final list = raw as List<dynamic>? ?? [];
      _recus = list.cast<Map<String, dynamic>>();
    } catch (e, st) {
      // La jointure imbriquée dépend de la façon dont PostgREST expose la clé
      // étrangère ; elle n'a pas pu être exercée depuis le poste de
      // développement, faute de session étudiante. Si elle échoue, on refait
      // le travail en deux requêtes plutôt que de rendre un écran vide.
      debugPrint(
        '[StudentApplicationPaymentsProvider] jointure reçus indisponible, '
        'repli en deux requêtes : $e\n$st',
      );
      try {
        _recus = await _recusEnDeuxRequetes();
      } catch (e2, st2) {
        debugPrint(
          '[StudentApplicationPaymentsProvider] chargerMesDocuments error=$e2 stack=$st2',
        );
        _erreurDocuments = e2.toString();
      }
    } finally {
      _documentsEnCours = false;
      notifyListeners();
    }
  }

  /// Repli : les reçus, puis les paiements correspondants, rapprochés ici.
  /// Deux allers-retours au lieu d'un — acceptable pour une liste de documents
  /// qui tient sur un écran.
  Future<List<Map<String, dynamic>>> _recusEnDeuxRequetes() async {
    final bruts = await _client
        .schema('app')
        .from('payment_receipts')
        .select()
        .order('issued_at', ascending: false);

    final recus = (bruts as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    if (recus.isEmpty) return recus;

    final ids = recus
        .map((r) => r['payment_id']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return recus;

    final paiementsBruts = await _client
        .schema('app')
        .from('application_payments')
        .select()
        .inFilter('id', ids);

    final parId = <String, Map<String, dynamic>>{
      for (final p in (paiementsBruts as List<dynamic>? ?? []))
        (p as Map)['id'].toString(): Map<String, dynamic>.from(p),
    };

    return [
      for (final r in recus)
        {...r, 'paiement': parId[r['payment_id']?.toString()] ?? const {}},
    ];
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
      // CETTE MÉTHODE NE FAISAIT RIEN, ET RENVOYAIT `true`.
      //
      // Le commentaire qui l'expliquait — « RPC app_student_declare_payment
      // n'existe plus dans Supabase » — était FAUX. La fonction existe,
      // vérifie l'appartenance du paiement et son statut, puis le passe à
      // `declared_by_student`. Le même fichier l'appelle d'ailleurs déjà,
      // avec succès, dans `createAndDeclareProfilePayment` (l.335).
      //
      // Conséquence du no-op : l'étudiant qui payait par Orange/Moov/Telecel
      // saisissait sa référence SMS, lisait « Paiement déclaré, en attente de
      // vérification », et rien n'était écrit — référence perdue, statut resté
      // `pending`, admin jamais prévenu. Constat B7 de l'audit du 03/09/2026.
      final resp = await _client.rpc(
        'app_student_declare_payment',
        params: {
          'p_payment_id': paymentId,
          'p_channel': channel,
          'p_amount_paid': amount,
          'p_external_reference': externalReference,
          'p_student_note': studentNote,
        },
      );
      final data = resp as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        // On remonte l'erreur du serveur plutôt qu'un succès fabriqué.
        _setError(
          data?['error']?.toString() ??
              'La déclaration du paiement n\'a pas abouti.',
        );
        return false;
      }

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
