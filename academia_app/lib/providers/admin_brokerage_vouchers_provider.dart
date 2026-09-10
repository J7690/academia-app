import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Les bons de courtage, vus par l'administrateur.
///
/// POURQUOI CET ÉCRAN EXISTE (demande de Jocelyn, 10/09/2026). Le bon part
/// avec le candidat ; sans copie côté Academia, personne ne saurait dire ce
/// qui a été émis, à qui, ni à quel taux. C'est le jumeau de l'écran des reçus.
///
/// Il sert aussi de point de départ au TRANSFERT : l'administrateur envoie une
/// copie d'annonce à l'établissement destinataire, qui la retrouve dans son
/// propre onglet « Mes documents ».
class AdminBrokerageVouchersProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _enCours = false;
  String? _erreur;
  List<Map<String, dynamic>> _bons = [];

  bool get enCours => _enCours;
  String? get erreur => _erreur;
  List<Map<String, dynamic>> get bons => List.unmodifiable(_bons);

  /// Les bons qui n'ont pas encore été transmis à leur établissement.
  /// Compté ici plutôt que dans l'écran : c'est une information de gestion,
  /// pas une décoration.
  int get nonTransmis =>
      _bons.where((b) => b['transferred_at'] == null).length;

  Future<void> charger() async {
    _enCours = true;
    _erreur = null;
    notifyListeners();
    try {
      final reponse = await _client.rpc('app_admin_list_brokerage_vouchers');
      if (reponse is! Map<String, dynamic> || reponse['success'] != true) {
        _erreur = _message(reponse is Map<String, dynamic>
            ? reponse['error']?.toString()
            : null);
        return;
      }
      final liste = reponse['vouchers'];
      _bons = liste is List
          ? liste.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
    } catch (e, st) {
      debugPrint('[AdminBrokerageVouchersProvider] charger $e\n$st');
      _erreur = e.toString();
    } finally {
      _enCours = false;
      notifyListeners();
    }
  }

  /// Transmet la copie d'annonce à l'établissement destinataire.
  ///
  /// Rend le message du serveur, que l'écran DOIT afficher : il dit combien de
  /// comptes ont été prévenus, et zéro est un cas réel — un établissement peut
  /// n'avoir aucun compte rattaché. Un « transmis » affiché sans ce détail
  /// laisserait croire que quelqu'un a reçu le bon.
  Future<({bool reussi, String message})> transferer(String voucherId) async {
    try {
      final reponse = await _client.rpc(
        'app_admin_transferer_bon',
        params: {'p_voucher_id': voucherId},
      );
      if (reponse is! Map<String, dynamic> || reponse['success'] != true) {
        return (
          reussi: false,
          message: _message(reponse is Map<String, dynamic>
              ? reponse['error']?.toString()
              : null),
        );
      }
      await charger();
      return (
        reussi: true,
        message: (reponse['message'] ?? 'Bon transmis.').toString(),
      );
    } catch (e) {
      return (reussi: false, message: 'Le transfert a échoué : $e');
    }
  }

  /// Chaque refus du serveur porte un nom. Afficher le code brut à l'écran est
  /// le défaut corrigé le 09/09 sur six formulaires d'un coup.
  static String _message(String? code) {
    switch (code) {
      case 'not_admin':
        return 'Seul un administrateur peut consulter les bons de courtage.';
      case 'not_authenticated':
        return 'Session expirée. Reconnecte-toi et réessaie.';
      case 'bon_introuvable':
        return 'Ce bon est introuvable.';
      default:
        return code == null || code.isEmpty
            ? 'Les bons de courtage n\'ont pas pu être chargés.'
            : 'Les bons de courtage n\'ont pas pu être chargés ($code).';
    }
  }
}
