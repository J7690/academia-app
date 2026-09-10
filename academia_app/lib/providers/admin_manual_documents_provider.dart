import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_user_invitations_provider.dart';

/// La saisie au comptoir : l'administrateur ouvre un dossier pour quelqu'un
/// qui n'est pas devant un téléphone, encaisse hors plateforme, et repart avec
/// le reçu et le bon de courtage.
///
/// CE QUI N'EST PAS DUPLIQUÉ, ET C'EST LE POINT. Rien ici ne fabrique de
/// document. Le serveur appelle les MÊMES fonctions que le parcours étudiant
/// (`app.emettre_recu`, `app.emettre_bon`), et la création du compte passe par
/// l'Edge Function `admin-create-student-account` déjà utilisée par l'écran
/// Comptes. Ce fichier ne fait qu'enchaîner trois appels et traduire les refus.
///
/// POURQUOI LE CANDIDAT A QUAND MÊME UN COMPTE. `app.students.id` référence
/// `auth.users(id)` : une fiche EST un compte, et c'est l'invariant sur lequel
/// repose chaque écran « mon dossier ». « Une personne qui ne peut pas créer de
/// compte » veut dire qu'elle ne peut pas le faire elle-même. L'administrateur
/// le fait pour elle — et le jour où elle installe l'application, son dossier
/// l'y attend déjà.
class AdminManualDocumentsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  final AdminUserInvitationsProvider _comptes = AdminUserInvitationsProvider();

  bool _enCours = false;
  String? _erreur;
  List<Map<String, dynamic>> _formations = [];

  bool get enCours => _enCours;
  String? get erreur => _erreur;
  List<Map<String, dynamic>> get formations => List.unmodifiable(_formations);

  /// Les établissements présents dans la liste des formations, dédoublonnés.
  /// Sert au premier menu : on choisit l'école, puis la filière.
  List<({String id, String nom})> get etablissements {
    final vus = <String, String>{};
    for (final f in _formations) {
      final id = f['university_id']?.toString();
      if (id == null || id.isEmpty) continue;
      vus[id] = (f['university_name'] ?? 'Établissement').toString();
    }
    final liste = vus.entries
        .map((e) => (id: e.key, nom: e.value))
        .toList(growable: false);
    liste.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
    return liste;
  }

  List<Map<String, dynamic>> formationsDe(String? universiteId) {
    if (universiteId == null || universiteId.isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    return _formations
        .where((f) => f['university_id']?.toString() == universiteId)
        .toList(growable: false);
  }

  Future<void> chargerFormations() async {
    _enCours = true;
    _erreur = null;
    notifyListeners();
    try {
      final reponse = await _client.rpc('app_admin_list_programs_pricing');
      if (reponse is! Map<String, dynamic> || reponse['success'] != true) {
        _erreur = 'La liste des formations n\'a pas pu être chargée.';
        return;
      }
      final brut = reponse['programs'];
      _formations = brut is List
          ? brut.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
    } catch (e, st) {
      debugPrint('[AdminManualDocumentsProvider] chargerFormations $e\n$st');
      _erreur = e.toString();
    } finally {
      _enCours = false;
      notifyListeners();
    }
  }

  /// Crée le compte du candidat. Rend son identifiant, ou un message.
  ///
  /// Le mot de passe est saisi par l'administrateur et remis au candidat avec
  /// ses papiers : il n'est PAS inventé ici. Un secret qu'on ne peut pas rendre
  /// à son propriétaire est un compte perdu — c'est la leçon du 09/09.
  Future<({String? studentId, String message})> creerCompteCandidat({
    required String email,
    required String motDePasse,
    required String nom,
  }) async {
    final data = await _comptes.createStudentAccountDirect(
      email: email,
      password: motDePasse,
      fullName: nom,
    );
    if (data == null) {
      return (
        studentId: null,
        message: _comptes.error ?? 'La création du compte a échoué.',
      );
    }
    final id = data['user_id']?.toString();
    if (id == null || id.isEmpty) {
      return (
        studentId: null,
        message: 'Le serveur n\'a pas renvoyé l\'identifiant du compte créé.',
      );
    }
    return (studentId: id, message: 'Compte créé.');
  }

  /// Émet le reçu et le bon. Rend les deux documents prêts à imprimer.
  ///
  /// `forcer` ne sert qu'après un refus `bon_deja_vivant` : au comptoir, un
  /// double-clic produirait deux papiers présentables au même guichet.
  Future<({bool reussi, String message, Map<String, dynamic>? documents})>
      emettre({
    required String studentId,
    required String programId,
    required double taux,
    String? nom,
    String? telephone,
    String? email,
    String? ville,
    String? pays,
    DateTime? dateDeNaissance,
    double? montant,
    String canal = 'cash',
    String? reference,
    String? note,
    String? modeEtude,
    bool forcer = false,
  }) async {
    _enCours = true;
    notifyListeners();
    try {
      final reponse = await _client.rpc(
        'app_admin_emettre_documents_manuels',
        params: {
          'p_student_id': studentId,
          'p_program_id': programId,
          'p_taux': taux,
          if (nom != null && nom.trim().isNotEmpty) 'p_nom': nom.trim(),
          if (telephone != null && telephone.trim().isNotEmpty)
            'p_telephone': telephone.trim(),
          if (email != null && email.trim().isNotEmpty) 'p_email': email.trim(),
          if (ville != null && ville.trim().isNotEmpty) 'p_ville': ville.trim(),
          if (pays != null && pays.trim().isNotEmpty) 'p_pays': pays.trim(),
          if (dateDeNaissance != null)
            'p_date_naissance':
                dateDeNaissance.toIso8601String().substring(0, 10),
          if (montant != null && montant > 0) 'p_montant': montant,
          'p_canal': canal,
          if (reference != null && reference.trim().isNotEmpty)
            'p_reference': reference.trim(),
          if (note != null && note.trim().isNotEmpty) 'p_note': note.trim(),
          if (modeEtude != null && modeEtude.trim().isNotEmpty)
            'p_mode_etude': modeEtude.trim(),
          'p_forcer': forcer,
        },
      );

      if (reponse is! Map<String, dynamic>) {
        return (
          reussi: false,
          message: 'Réponse inattendue du serveur.',
          documents: null,
        );
      }
      if (reponse['success'] != true) {
        return (
          reussi: false,
          message: (reponse['message'] ??
                  _message(reponse['error']?.toString()))
              .toString(),
          documents: reponse,
        );
      }

      final paymentId = reponse['payment_id']?.toString();
      final documents =
          paymentId == null ? null : await _documents(paymentId);
      return (
        reussi: true,
        message: 'Reçu ${reponse['receipt_number']} et bon '
            '${reponse['voucher_number']} émis.',
        documents: documents ?? reponse,
      );
    } catch (e, st) {
      debugPrint('[AdminManualDocumentsProvider] emettre $e\n$st');
      // Le serveur lève plutôt qu'il ne rend un échec quand l'émission a
      // commencé : la transaction est alors annulée en entier, et il ne reste
      // AUCUN dossier à moitié fait. Le message brut porte le motif.
      return (reussi: false, message: _messageException(e), documents: null);
    } finally {
      _enCours = false;
      notifyListeners();
    }
  }

  /// Relit le paiement, le reçu et le bon dans les formes qu'attendent les deux
  /// fabriques de PDF. Un seul appel, réutilisable pour une réimpression.
  Future<Map<String, dynamic>?> _documents(String paymentId) async {
    try {
      final reponse = await _client.rpc(
        'app_admin_documents_du_paiement',
        params: {'p_payment_id': paymentId},
      );
      if (reponse is Map<String, dynamic> && reponse['success'] == true) {
        return reponse;
      }
    } catch (e) {
      debugPrint('[AdminManualDocumentsProvider] documents $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> documentsDuPaiement(String paymentId) =>
      _documents(paymentId);

  static String _message(String? code) {
    switch (code) {
      case 'not_admin':
        return 'Seul un administrateur peut faire une saisie au comptoir.';
      case 'not_authenticated':
        return 'Session expirée. Reconnecte-toi et réessaie.';
      case 'candidat_sans_compte':
        return 'Ce candidat n\'a pas encore de compte : crée-le d\'abord.';
      case 'taux_invalide':
        return 'Le pourcentage négocié est obligatoire, entre 0 et 100.';
      case 'formation_introuvable':
        return 'Cette formation est introuvable.';
      case 'programme_sans_etablissement':
        return 'Cette formation n\'est rattachée à aucun établissement.';
      case 'montant_indeterminable':
        return 'Aucun frais de courtage sur cette formation : saisis le montant.';
      case 'canal_invalide':
        return 'Ce moyen de paiement n\'est pas reconnu.';
      case 'bon_deja_vivant':
        return 'Un bon en cours de validité existe déjà pour ce candidat.';
      default:
        return code == null || code.isEmpty
            ? 'L\'émission a échoué.'
            : 'L\'émission a échoué ($code).';
    }
  }

  /// Les deux seuls motifs que le serveur lève au lieu de les rendre. Les
  /// afficher tels quels montrerait une trace PostgreSQL à un administrateur.
  static String _messageException(Object e) {
    final brut = e.toString();
    if (brut.contains('emission_bon_refusee')) {
      if (brut.contains('taux_de_reduction_non_fixe')) {
        return 'Le bon n\'a pas pu être émis : le pourcentage n\'était pas '
            'enregistré. Rien n\'a été créé.';
      }
      return 'Le bon n\'a pas pu être émis. Rien n\'a été créé.';
    }
    if (brut.contains('emission_recu_refusee')) {
      return 'Le reçu n\'a pas pu être émis. Rien n\'a été créé.';
    }
    return 'L\'émission a échoué : $brut';
  }
}
