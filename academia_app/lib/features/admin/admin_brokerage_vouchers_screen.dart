import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_brokerage_vouchers_provider.dart';
import '../../utils/bon_courtage_pdf.dart';
import 'admin_manual_documents_screen.dart';

/// « Bons de courtage » — la copie d'Academia, et le point de transfert.
///
/// Deux actes, et un seul est réversible :
///   — TÉLÉCHARGER produit le PDF, avec son QR et son code. C'est le document
///     que le candidat présente ;
///   — TRANSMETTRE envoie une copie d'annonce à l'établissement. Cette copie
///     ne porte NI le code NI le jeton : l'école est informée, elle n'est pas
///     autorisée. Le candidat doit toujours se présenter au guichet.
///     Le transfert ne se fait qu'une fois.
class AdminBrokerageVouchersScreen extends StatelessWidget {
  const AdminBrokerageVouchersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AdminBrokerageVouchersProvider>(
      create: (_) => AdminBrokerageVouchersProvider()..charger(),
      child: const _Corps(),
    );
  }
}

class _Corps extends StatefulWidget {
  const _Corps();

  @override
  State<_Corps> createState() => _CorpsState();
}

class _CorpsState extends State<_Corps> {
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminBrokerageVouchersProvider>(
      builder: (context, p, _) {
        var liste = p.bons;
        final q = _recherche.trim().toLowerCase();
        if (q.isNotEmpty) {
          liste = liste.where((b) {
            bool contient(dynamic v) =>
                (v?.toString().toLowerCase() ?? '').contains(q);
            final s = _objet(b['snapshot']);
            return contient(b['voucher_number']) ||
                contient(b['universite']) ||
                contient(b['etudiant']) ||
                contient(_objet(s['formation'])['titre']) ||
                contient(_objet(s['candidat'])['nom']);
          }).toList(growable: false);
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Numéro, candidat, établissement, formation',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _recherche = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // LA SAISIE AU COMPTOIR VIT ICI, ET PAS DANS UN 31e ONGLET.
                  // Elle produit un bon ; sa place est là où les bons se
                  // regardent, se téléchargent et se transmettent.
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      final refaire = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => const AdminManualDocumentsScreen(),
                        ),
                      );
                      if (refaire != null) await p.charger();
                    },
                    icon: const Icon(Icons.point_of_sale),
                    label: const Text('Saisie au comptoir'),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Recharger',
                    onPressed: p.enCours ? null : p.charger,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            if (p.nonTransmis > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${p.nonTransmis} bon(s) pas encore transmis à leur '
                    'établissement.',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF92400E)),
                  ),
                ),
              ),
            Expanded(
              child: Builder(builder: (context) {
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
                if (liste.isEmpty) {
                  return _Vide(
                    icone: Icons.confirmation_number_outlined,
                    titre: p.bons.isEmpty
                        ? 'Aucun bon de courtage émis'
                        : 'Aucun bon ne correspond à cette recherche',
                    detail: p.bons.isEmpty
                        ? 'Un bon est émis automatiquement dès qu\'un paiement '
                            'de courtage est confirmé, à condition que le taux '
                            'de réduction ait été enregistré sur la '
                            'candidature.'
                        : 'Essaie un autre numéro, nom ou établissement.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: p.charger,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: liste.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _Carte(bon: liste[i]),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

Map<String, dynamic> _objet(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

class _Carte extends StatelessWidget {
  const _Carte({required this.bon});

  final Map<String, dynamic> bon;

  @override
  Widget build(BuildContext context) {
    final snap = _objet(bon['snapshot']);
    final candidat =
        (_objet(snap['candidat'])['nom'] ?? bon['etudiant'] ?? '').toString();
    final formation = (_objet(snap['formation'])['titre'] ?? '').toString();
    final taux = _taux(_objet(snap['reduction'])['taux']);
    final numero = (bon['voucher_number'] ?? '').toString();
    final ecole = (bon['universite'] ?? '').toString();
    final manuel = (bon['origin'] ?? '').toString() == 'saisie_manuelle';

    final transmisLe = DateTime.tryParse((bon['transferred_at'] ?? '').toString());
    final consomme = (bon['consumed_at'] ?? '').toString().isNotEmpty;
    final expire = bon['expire'] == true;

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
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      _Puce(
                        texte: consomme
                            ? 'ACCEPTÉ'
                            : expire
                                ? 'ÉCHU'
                                : 'VALABLE',
                        fond: consomme
                            ? const Color(0xFFEDF3FF)
                            : expire
                                ? const Color(0xFFFFF1F0)
                                : const Color(0xFFEAF6EE),
                        encre: consomme
                            ? const Color(0xFF1B4F9C)
                            : expire
                                ? const Color(0xFFB3261E)
                                : const Color(0xFF14663A),
                      ),
                      if (manuel)
                        const _Puce(
                          texte: 'SAISIE MANUELLE',
                          fond: Color(0xFFF3F0FF),
                          encre: Color(0xFF5B3FA8),
                        ),
                      _Puce(
                        texte: transmisLe == null
                            ? 'NON TRANSMIS'
                            : 'TRANSMIS LE '
                                '${DateFormat('dd/MM').format(transmisLe.toLocal())}',
                        fond: transmisLe == null
                            ? const Color(0xFFFFF7ED)
                            : const Color(0xFFF1F5F4),
                        encre: transmisLe == null
                            ? const Color(0xFF92400E)
                            : const Color(0xFF5A6560),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(candidat.isEmpty ? '—' : candidat,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF14251D))),
                    Text(
                      [ecole, formation].where((s) => s.isNotEmpty).join(' · '),
                      style: const TextStyle(
                          fontSize: 12.5, color: Color(0xFF5A6560)),
                    ),
                    const SizedBox(height: 4),
                    Text(numero,
                        style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: Color(0xFF3E4A44))),
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
          const SizedBox(height: 11),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _telecharger(context),
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Télécharger'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed:
                    transmisLe != null ? null : () => _transferer(context),
                icon: const Icon(Icons.send_outlined, size: 16),
                label: Text(transmisLe == null ? 'Transmettre' : 'Transmis'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  static String? _taux(dynamic v) {
    if (v == null) return null;
    final d = v is num ? v.toDouble() : double.tryParse(v.toString());
    if (d == null) return null;
    return d == d.roundToDouble()
        ? d.toStringAsFixed(0)
        : d.toString().replaceAll(RegExp(r'0+$'), '');
  }

  Future<void> _telecharger(BuildContext context) async {
    final messager = ScaffoldMessenger.of(context);
    try {
      final r = await genererEtEnregistrerBonPdf(bon: bon);
      messager.showSnackBar(SnackBar(
        content: Text(r.reussi
            ? (r.enregistreSurLAppareil
                ? 'Bon enregistré dans Téléchargements (${r.nomFichier})'
                : 'Bon téléchargé')
            : 'Le bon n\'a pas pu être enregistré : ${r.erreur}'),
      ));
    } catch (e) {
      messager.showSnackBar(
          SnackBar(content: Text('Le bon n\'a pas pu être préparé : $e')));
    }
  }

  Future<void> _transferer(BuildContext context) async {
    final p = context.read<AdminBrokerageVouchersProvider>();
    final messager = ScaffoldMessenger.of(context);

    // ON DEMANDE CONFIRMATION : le transfert ne se défait pas, et il prévient
    // l'établissement. Un appui malheureux annoncerait un candidat à une école
    // avant que le dossier ne soit prêt.
    final ecole = (bon['universite'] ?? 'l\'établissement').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Transmettre ce bon ?'),
        content: Text(
          'Une copie sera envoyée à $ecole, qui la retrouvera dans son espace '
          'et recevra une notification.\n\n'
          'Cette copie ne porte ni le code ni le QR : le candidat devra '
          'toujours présenter son bon au guichet pour que l\'école le vérifie '
          'et le clôture. Le transfert ne se fait qu\'une fois.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Transmettre')),
        ],
      ),
    );
    if (ok != true) return;

    final r = await p.transferer((bon['id'] ?? '').toString());
    messager.showSnackBar(SnackBar(content: Text(r.message)));
  }
}

class _Puce extends StatelessWidget {
  const _Puce({required this.texte, required this.fond, required this.encre});

  final String texte;
  final Color fond;
  final Color encre;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: fond, borderRadius: BorderRadius.circular(99)),
        child: Text(texte,
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: .5,
                color: encre)),
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
