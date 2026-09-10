import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'university_scan_bon_screen.dart';

/// « Mes documents » — les bons de courtage qu'Academia a transmis à l'école.
///
/// CE QUE CET ONGLET EST, ET CE QU'IL N'EST PAS. C'est une **copie
/// d'annonce** : l'établissement sait qu'un candidat lui a été présenté, avec
/// quel taux et jusqu'à quelle date, avant même que la personne ne se déplace.
///
/// **Il n'autorise rien.** La procédure ne change pas (décision de Jocelyn,
/// 10/09/2026) : le candidat vient au guichet avec son bon, l'école scanne le
/// code, et c'est ce scan qui permet d'accepter et de clore. C'est pourquoi le
/// serveur ne transmet ici NI le code de vérification NI le jeton du QR — sans
/// eux, `app_consommer_bon_de_courtage` ne peut pas être appelé depuis cet
/// écran, même par erreur.
///
/// Il n'y a donc volontairement ni bouton « accepter », ni téléchargement du
/// PDF : le PDF porte le code, et le donner ici viderait la règle de son sens.
class UniversityDocumentsTab extends StatelessWidget {
  const UniversityDocumentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UniversityBrokerageVouchersProvider>(
      create: (_) => UniversityBrokerageVouchersProvider()..charger(),
      child: const _Corps(),
    );
  }
}

class UniversityBrokerageVouchersProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _enCours = false;
  String? _erreur;
  List<Map<String, dynamic>> _bons = [];

  bool get enCours => _enCours;
  String? get erreur => _erreur;
  List<Map<String, dynamic>> get bons => List.unmodifiable(_bons);

  Future<void> charger() async {
    _enCours = true;
    _erreur = null;
    notifyListeners();
    try {
      final r = await _client.rpc('app_university_list_brokerage_vouchers');
      if (r is! Map<String, dynamic> || r['success'] != true) {
        _erreur = _message(
            r is Map<String, dynamic> ? r['error']?.toString() : null);
        return;
      }
      final liste = r['vouchers'];
      _bons = liste is List
          ? liste.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
    } catch (e, st) {
      debugPrint('[UniversityBrokerageVouchers] charger $e\n$st');
      _erreur = e.toString();
    } finally {
      _enCours = false;
      notifyListeners();
    }
  }

  /// `university_not_configured` n'est pas une panne : c'est un compte qui
  /// n'est rattaché à aucun établissement. Mesuré le 09/09 — un compte
  /// université sur trente est dans ce cas. Le dire permet d'appeler Academia
  /// plutôt que de croire l'application cassée.
  static String _message(String? code) {
    switch (code) {
      case 'reserve_aux_universites':
        return 'Cet espace est réservé aux comptes d\'établissement.';
      case 'university_not_configured':
        return 'Ce compte n\'est rattaché à aucun établissement. '
            'Contacte Academia pour qu\'il soit relié à ton école.';
      case 'not_authenticated':
        return 'Session expirée. Reconnecte-toi et réessaie.';
      default:
        return code == null || code.isEmpty
            ? 'Les documents n\'ont pas pu être chargés.'
            : 'Les documents n\'ont pas pu être chargés ($code).';
    }
  }
}

class _Corps extends StatelessWidget {
  const _Corps();

  @override
  Widget build(BuildContext context) {
    // LE BOUTON DE SCAN EST AU-DESSUS DE LA LISTE, ET FIXE. C'est le seul geste
    // qui permet d'accepter un candidat ; l'enterrer sous une liste vide
    // reviendrait à cacher la fonction principale de cet écran.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const UniversityScanBonScreen(),
                ),
              ),
              icon: const Icon(Icons.qr_code_scanner, size: 19),
              label: const Text('Vérifier le bon d\'un candidat'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF14663A),
                textStyle: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const Expanded(child: _Liste()),
      ],
    );
  }
}

class _Liste extends StatelessWidget {
  const _Liste();

  @override
  Widget build(BuildContext context) {
    return Consumer<UniversityBrokerageVouchersProvider>(
      builder: (context, p, _) {
        if (p.enCours && p.bons.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (p.erreur != null && p.bons.isEmpty) {
          return _Vide(
            icone: Icons.error_outline,
            titre: 'Chargement impossible',
            detail: p.erreur!,
            action: TextButton.icon(
              onPressed: p.charger,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          );
        }
        if (p.bons.isEmpty) {
          return const _Vide(
            icone: Icons.inbox_outlined,
            titre: 'Aucun bon de courtage reçu',
            detail: 'Academia t\'envoie ici une copie des bons de courtage '
                'émis pour des candidats présentés à ton établissement. '
                'Le candidat viendra ensuite avec son bon : c\'est en scannant '
                'son code que tu pourras le vérifier et l\'accepter.',
          );
        }

        return RefreshIndicator(
          onRefresh: p.charger,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            itemCount: p.bons.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) =>
                i == 0 ? const _Rappel() : _Carte(bon: p.bons[i - 1]),
          ),
        );
      },
    );
  }
}

/// Le rappel de la procédure, en tête de liste. Sans lui, un agent pourrait
/// croire qu'un bon vu ici vaut inscription.
class _Rappel extends StatelessWidget {
  const _Rappel();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC7D2FE)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 18, color: Color(0xFF4F46E5)),
            const SizedBox(width: 9),
            Expanded(
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(
                      fontSize: 12.5, height: 1.45, color: Color(0xFF3730A3)),
                  children: [
                    TextSpan(
                        text: 'Ces bons sont des copies d\'annonce. ',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(
                        text: 'Le candidat doit se présenter avec son bon : '
                            'c\'est en scannant son code que tu le vérifies et '
                            'que tu l\'acceptes.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _Carte extends StatelessWidget {
  const _Carte({required this.bon});

  final Map<String, dynamic> bon;

  static Map<String, dynamic> _objet(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  @override
  Widget build(BuildContext context) {
    final snap = _objet(bon['snapshot']);
    final candidat = _objet(snap['candidat']);
    final formation = _objet(snap['formation']);
    final reduction = _objet(snap['reduction']);

    final nom = (candidat['nom'] ?? '').toString();
    final naissance = _date(candidat['date_de_naissance']);
    final tel = (candidat['telephone'] ?? '').toString();
    final titre = (formation['titre'] ?? '').toString();
    final niveau = [
      (formation['niveau'] ?? '').toString(),
      (formation['mode'] ?? '').toString(),
    ].where((s) => s.isNotEmpty).join(' · ');
    final taux = _taux(reduction['taux']);
    final numero = (bon['voucher_number'] ?? '').toString();
    final echeance = _date(bon['expires_at']);
    final consomme = (bon['consumed_at'] ?? '').toString().isNotEmpty;
    final expire = bon['expire'] == true;

    final (String etiquette, Color fond, Color encre) = consomme
        ? ('DÉJÀ ACCEPTÉ', const Color(0xFFEDF3FF), const Color(0xFF1B4F9C))
        : expire
            ? ('ÉCHU', const Color(0xFFFFF1F0), const Color(0xFFB3261E))
            : ('EN ATTENTE DU CANDIDAT',
                const Color(0xFFEAF6EE), const Color(0xFF14663A));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E9E5)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: fond,
                          borderRadius: BorderRadius.circular(99)),
                      child: Text(etiquette,
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .4,
                              color: encre)),
                    ),
                    const SizedBox(height: 8),
                    Text(nom.isEmpty ? '—' : nom,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF14251D))),
                    if (titre.isNotEmpty)
                      Text(titre,
                          style: const TextStyle(
                              fontSize: 12.5, color: Color(0xFF5A6560))),
                    if (niveau.isNotEmpty)
                      Text(niveau,
                          style: const TextStyle(
                              fontSize: 11.5, color: Color(0xFF8A9490))),
                  ],
                ),
              ),
              if (taux != null)
                Text('$taux %',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF14663A))),
            ],
          ),
          const SizedBox(height: 9),
          const Divider(height: 1, color: Color(0xFFEEF2F0)),
          const SizedBox(height: 8),
          _Ligne('N° du bon', numero, monospace: true),
          if (naissance.isNotEmpty) _Ligne('Né(e) le', naissance),
          if (tel.isNotEmpty) _Ligne('Téléphone', tel),
          if (echeance.isNotEmpty)
            _Ligne(consomme ? 'Échéance' : 'À présenter avant le', echeance),
        ],
      ),
    );
  }

  static String _date(dynamic v) {
    final d = DateTime.tryParse((v ?? '').toString());
    return d == null ? '' : DateFormat('dd/MM/yyyy').format(d.toLocal());
  }

  static String? _taux(dynamic v) {
    if (v == null) return null;
    final d = v is num ? v.toDouble() : double.tryParse(v.toString());
    if (d == null) return null;
    return d == d.roundToDouble()
        ? d.toStringAsFixed(0)
        : d.toString().replaceAll(RegExp(r'0+$'), '');
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne(this.etiquette, this.valeur, {this.monospace = false});

  final String etiquette;
  final String valeur;
  final bool monospace;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 132,
              child: Text(etiquette,
                  style: const TextStyle(
                      fontSize: 11.5, color: Color(0xFF8A9490))),
            ),
            Expanded(
              child: Text(valeur,
                  style: TextStyle(
                      fontSize: 12.5,
                      color: const Color(0xFF14251D),
                      fontFamily: monospace ? 'monospace' : null)),
            ),
          ],
        ),
      );
}

class _Vide extends StatelessWidget {
  const _Vide(
      {required this.icone,
      required this.titre,
      required this.detail,
      this.action});

  final IconData icone;
  final String titre;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 42, color: const Color(0xFF9AA5A0)),
              const SizedBox(height: 12),
              Text(titre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF14251D))),
              const SizedBox(height: 6),
              Text(detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, height: 1.45, color: Color(0xFF5A6560))),
              if (action != null) ...[const SizedBox(height: 12), action!],
            ],
          ),
        ),
      );
}
