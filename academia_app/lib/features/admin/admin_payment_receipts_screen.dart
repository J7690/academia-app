import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_payment_receipts_provider.dart';
import '../../utils/payment_receipt_pdf.dart';
import 'admin_payment_detail_screen.dart';

/// La liste des reçus, vue par l'administrateur.
///
/// TROIS CHANGEMENTS DU 10/09/2026, tous demandés par Jocelyn — « l'administrateur
/// doit être capable de pouvoir les télécharger et les recevoir dans ces
/// documents lui aussi » :
///
///   1. LE TÉLÉCHARGEMENT EST ICI, en un clic. Il fallait auparavant ouvrir le
///      détail d'un paiement — deux clics et un second aller-retour serveur —
///      alors que l'écran jumeau des bons télécharge depuis sa liste. Un même
///      geste pour deux documents de même nature.
///   2. LE MÊME DOCUMENT POUR TOUS. La RPC rend désormais `signature_hash` et
///      le nom du payeur : la copie de l'administrateur porte l'empreinte de
///      vérification et nomme la personne, comme celle de l'étudiant. Elles
///      différaient.
///   3. LE FILTRE `courtageSeulement` sépare les deux familles de reçus sans
///      dupliquer cet écran : le courtage d'un côté, les autres achats de
///      l'autre. C'est ce qui permet à « Mes documents » d'avoir trois volets
///      et un seul code de liste.
///
/// UN SEUL OBJET SERT DE PAIEMENT ET DE REÇU. `app_admin_list_payment_receipts_with_context`
/// rend une ligne à plat qui porte les deux jeux de clés ; les deux paramètres
/// de `construirePdfRecu` reçoivent donc la même carte. Aller rechercher le
/// paiement séparément ajouterait un appel pour des données déjà en main.
class AdminPaymentReceiptsScreen extends StatelessWidget {
  const AdminPaymentReceiptsScreen({super.key, this.courtageSeulement});

  /// `null` : tous les reçus. `true` : seulement le courtage
  /// (`application_fee`). `false` : tous les autres achats.
  final bool? courtageSeulement;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AdminPaymentReceiptsProvider>(
      create: (_) => AdminPaymentReceiptsProvider()..loadAllReceipts(),
      child: _AdminPaymentReceiptsBody(courtageSeulement: courtageSeulement),
    );
  }
}

class _AdminPaymentReceiptsBody extends StatefulWidget {
  const _AdminPaymentReceiptsBody({this.courtageSeulement});

  final bool? courtageSeulement;

  @override
  State<_AdminPaymentReceiptsBody> createState() =>
      _AdminPaymentReceiptsBodyState();
}

class _AdminPaymentReceiptsBodyState extends State<_AdminPaymentReceiptsBody> {
  String _query = '';
  String? _enCours;

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminPaymentReceiptsProvider>(
      builder: (context, receiptsProvider, child) {
        final isLoading = receiptsProvider.isLoading;
        final error = receiptsProvider.error;

        var all = receiptsProvider.receipts;
        if (widget.courtageSeulement != null) {
          all = all.where((r) {
            final courtage = r['payment_reason']?.toString() == 'application_fee';
            return courtage == widget.courtageSeulement;
          }).toList(growable: false);
        }

        List<Map<String, dynamic>> filtered = all;
        final q = _query.trim().toLowerCase();
        if (q.isNotEmpty) {
          filtered = all.where((r) {
            bool contains(dynamic value) {
              final s = value?.toString().toLowerCase() ?? '';
              return s.contains(q);
            }

            return contains(r['receipt_number']) ||
                contains(r['reference_code']) ||
                contains(r['student_name']) ||
                contains(libelleDuMotif(r['payment_reason']?.toString())) ||
                contains(r['payment_reason']) ||
                contains(r['payment_status']) ||
                contains(r['program_title']) ||
                contains(r['university_name']);
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
                        labelText:
                            'Rechercher par reçu, payeur, référence, programme ou université',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _query = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Recharger',
                    onPressed: () {
                      receiptsProvider.reload();
                    },
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            if (isLoading && all.isEmpty)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null && all.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          error,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            receiptsProvider.reload();
                          },
                          child: const Text('Recharger'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (filtered.isEmpty)
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Aucun reçu trouvé pour les critères actuels.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final r = filtered[index];
                    final paymentId = r['payment_id']?.toString() ?? '';
                    final receiptNumber = r['receipt_number']?.toString() ?? '';
                    final issuedAt = r['issued_at']?.toString() ?? '';
                    final paymentStatus = r['payment_status']?.toString() ?? '';
                    final amountDue = r['amount_due']?.toString() ?? '';
                    final amountPaid = r['amount_paid']?.toString() ?? '';
                    final currency = r['currency']?.toString() ?? '';
                    final payeur = r['student_name']?.toString() ?? '';
                    final motif = libelleDuMotif(
                        r['payment_reason']?.toString());
                    final programTitle = r['program_title']?.toString() ?? '';
                    final universityName =
                        r['university_name']?.toString() ?? '';
                    final referenceCode =
                        r['reference_code']?.toString() ?? '';
                    final externalReference =
                        r['external_reference']?.toString() ?? '';

                    return InkWell(
                      onTap: paymentId.isEmpty
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AdminPaymentDetailScreen(
                                    paymentId: paymentId,
                                  ),
                                ),
                              );
                            },
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Reçu $receiptNumber',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _statusChip(paymentStatus),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (payeur.isNotEmpty)
                                Text(
                                  payeur,
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              if (issuedAt.isNotEmpty)
                                Text(
                                  'Émis le $issuedAt',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              const SizedBox(height: 4),
                              if (programTitle.isNotEmpty)
                                Text(
                                  'Programme : $programTitle',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              if (universityName.isNotEmpty)
                                Text(
                                  'Université : $universityName',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              if (motif.isNotEmpty)
                                Text(
                                  motif,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              if (amountDue.isNotEmpty)
                                Text('Montant dû : $amountDue $currency'),
                              if (amountPaid.isNotEmpty)
                                Text('Montant payé : $amountPaid $currency'),
                              if (referenceCode.isNotEmpty)
                                Text('Référence paiement : $referenceCode'),
                              if (externalReference.isNotEmpty)
                                Text(
                                  'Référence opérateur : $externalReference',
                                ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.tonalIcon(
                                  onPressed: _enCours == receiptNumber
                                      ? null
                                      : () => _telecharger(r),
                                  icon: _enCours == receiptNumber
                                      ? const SizedBox(
                                          width: 15,
                                          height: 15,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.download, size: 18),
                                  label: const Text('Télécharger'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  /// Le retour est LU, jamais supposé. Un « téléchargé » affiché sans vérifier
  /// ce que la fabrique a rendu est le faux succès corrigé le 03/09, où
  /// « Télécharger » ouvrait en réalité un aperçu d'impression.
  Future<void> _telecharger(Map<String, dynamic> ligne) async {
    final numero = ligne['receipt_number']?.toString() ?? '';
    setState(() => _enCours = numero);
    final messager = ScaffoldMessenger.of(context);
    try {
      final resultat = await genererEtEnregistrerRecuPdf(
        payment: ligne,
        receipt: ligne,
      );
      messager.showSnackBar(SnackBar(
        content: Text(
          !resultat.reussi
              ? 'Reçu non enregistré : ${resultat.erreur}'
              : resultat.enregistreSurLAppareil
                  ? 'Reçu enregistré dans Téléchargements '
                      '(${resultat.nomFichier})'
                  : 'Reçu téléchargé',
        ),
      ));
    } finally {
      if (mounted) setState(() => _enCours = null);
    }
  }

  Widget _statusChip(String status) {
    String label;
    Color color;
    switch (status) {
      case 'pending':
        label = 'En attente';
        color = Colors.orange;
        break;
      case 'declared_by_student':
        label = 'Déclaré';
        color = Colors.blueGrey;
        break;
      case 'under_verification':
        label = 'En vérification';
        color = Colors.blue;
        break;
      case 'confirmed':
        label = 'Confirmé';
        color = Colors.green;
        break;
      case 'rejected':
        label = 'Rejeté';
        color = Colors.red;
        break;
      case 'cancelled':
        label = 'Annulé';
        color = Colors.grey;
        break;
      default:
        label = status.isEmpty ? 'Inconnu' : status;
        color = Colors.grey;
        break;
    }

    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
      backgroundColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Les onze motifs de `payment_reason`, en français.
///
/// Cette table existait déjà à deux endroits — dans `app.emettre_recu` et dans
/// le générateur de PDF — et à un troisième, incomplète : l'écran de détail
/// n'en traduisait que trois, et la liste affichait la valeur brute
/// (« Type : credit_purchase »). Elle est ici pour que les écrans
/// d'administration en partagent une seule.
String libelleDuMotif(String? motif) {
  switch (motif) {
    case 'application_fee':
      return 'Frais de courtage — candidature universitaire';
    case 'registration_fee':
      return 'Frais d\'inscription';
    case 'tuition_deposit':
      return 'Acompte sur frais de scolarité';
    case 'td_access':
      return 'Accès aux travaux dirigés';
    case 'subscription':
      return 'Abonnement Academia';
    case 'credit_purchase':
      return 'Achat de crédits';
    case 'online_course':
      return 'Cours en ligne';
    case 'orientation_consultation':
      return 'Consultation d\'orientation';
    case 'prep_concours':
      return 'Préparation aux concours';
    case 'marketplace_purchase':
      return 'Achat sur la place de marché';
    case 'other':
      return 'Prestation Academia';
    default:
      return motif == null || motif.isEmpty ? '' : motif;
  }
}
