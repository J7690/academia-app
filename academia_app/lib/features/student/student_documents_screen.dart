import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/student_application_payments_provider.dart';
import '../../utils/bon_courtage_pdf.dart';
import '../../utils/payment_receipt_pdf.dart';
import 'widgets/student_mobile_scaffold.dart';

/// « Mes documents » — les pièces que l'étudiant peut montrer à quelqu'un.
///
/// Distinct de « Mes paiements », qui est un atelier : on y crée un paiement,
/// on choisit un canal, on déclare un versement. Ici on ne fabrique rien, on
/// consulte et on télécharge. Les deux écrans coexistent volontairement.
///
/// Deux volets, parce que les deux documents ne servent pas à la même chose :
///   — le REÇU prouve ce que l'étudiant a versé à Nexiom Group ;
///   — le BON DE COURTAGE se présente à l'établissement.
///
/// Les deux volets sont vivants depuis le 09/09/2026. Le second lisait
/// jusque-là « cette fonctionnalité arrive prochainement » : la table des bons
/// n'existait pas. Elle existe, l'émission est automatique à la confirmation
/// d'un paiement de courtage, et le bon se télécharge ici.
///
/// LES DEUX VOLETS SONT INDÉPENDANTS. Ils se chargent ensemble mais leurs
/// erreurs sont distinctes : une panne sur les bons ne doit pas vider la liste
/// des reçus, ni l'inverse.
class StudentDocumentsScreen extends StatefulWidget {
  const StudentDocumentsScreen({super.key});

  @override
  State<StudentDocumentsScreen> createState() => _StudentDocumentsScreenState();
}

class _StudentDocumentsScreenState extends State<StudentDocumentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _onglets = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<StudentApplicationPaymentsProvider>().chargerMesDocuments();
    });
  }

  @override
  void dispose() {
    _onglets.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentApplicationPaymentsProvider>(
      builder: (context, provider, _) {
        final recus = provider.recus;
        return StudentMobileScaffold(
          appBar: AppBar(
            title: const Text('Mes documents'),
            bottom: TabBar(
              controller: _onglets,
              tabs: [
                Tab(text: 'Reçus${recus.isEmpty ? '' : '  ${recus.length}'}'),
                const Tab(text: 'Bons de courtage'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _onglets,
            children: [
              _VoletRecus(provider: provider),
              _VoletBons(provider: provider),
            ],
          ),
        );
      },
    );
  }
}

class _VoletRecus extends StatelessWidget {
  const _VoletRecus({required this.provider});

  final StudentApplicationPaymentsProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.documentsEnCours && provider.recus.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.erreurDocuments != null && provider.recus.isEmpty) {
      return _Message(
        icone: Icons.wifi_off_outlined,
        titre: 'Tes reçus n\'ont pas pu être chargés',
        // On montre l'erreur : un écran muet a déjà coûté une séance entière
        // de diagnostic sur ce dépôt.
        detail: provider.erreurDocuments!,
        action: TextButton.icon(
          onPressed: provider.chargerMesDocuments,
          icon: const Icon(Icons.refresh),
          label: const Text('Réessayer'),
        ),
      );
    }

    if (provider.recus.isEmpty) {
      return const _Message(
        icone: Icons.receipt_long_outlined,
        titre: 'Aucun reçu pour le moment',
        detail: 'Chaque paiement confirmé génère automatiquement un reçu. '
            'Il apparaîtra ici, et tu pourras le télécharger en PDF.',
      );
    }

    return RefreshIndicator(
      onRefresh: provider.chargerMesDocuments,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: provider.recus.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 11),
        itemBuilder: (context, i) {
          if (i == provider.recus.length) return const _NoteDeBasDePage();
          return _CarteRecu(recu: provider.recus[i]);
        },
      ),
    );
  }
}

class _CarteRecu extends StatelessWidget {
  const _CarteRecu({required this.recu});

  final Map<String, dynamic> recu;

  @override
  Widget build(BuildContext context) {
    final paiement = recu['paiement'] is Map
        ? Map<String, dynamic>.from(recu['paiement'] as Map)
        : <String, dynamic>{};
    final snapshot = recu['snapshot'] is Map
        ? Map<String, dynamic>.from(recu['snapshot'] as Map)
        : <String, dynamic>{};

    final motif = (snapshot['motif'] ?? paiement['payment_reason'] ?? '').toString();
    final aspect = _AspectMotif.pour(motif);

    final montant = _nombre(snapshot['montant']) ??
        _nombre(paiement['amount_paid']) ??
        _nombre(paiement['amount_due']) ??
        0;
    final devise = (snapshot['devise'] ?? paiement['currency'] ?? 'XOF').toString();

    final numero = (recu['receipt_number'] ?? '').toString();
    final emisLe = DateTime.tryParse((recu['issued_at'] ?? '').toString());

    final reglement = snapshot['reglement'] is Map
        ? Map<String, dynamic>.from(snapshot['reglement'] as Map)
        : <String, dynamic>{};
    final moyen = (reglement['moyen'] ?? '').toString();

    final sousTitre = [
      (snapshot['designation'] ?? recu['training_name'] ?? '').toString(),
      [
        if (emisLe != null) DateFormat('dd/MM/yyyy').format(emisLe.toLocal()),
        if (moyen.isNotEmpty) moyen,
      ].join(' · '),
    ].where((s) => s.trim().isNotEmpty).join('\n');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E9E5)),
        borderRadius: BorderRadius.circular(13),
      ),
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: aspect.fond,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        aspect.etiquette,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .5,
                          color: aspect.encre,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_millierEspace(montant)} $devise',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF14251D),
                      ),
                    ),
                    if (sousTitre.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        sousTitre,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: Color(0xFF6B7873),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('REÇU',
                      style: TextStyle(
                          fontSize: 9.5,
                          letterSpacing: 1,
                          color: Color(0xFF7C8783))),
                  const SizedBox(height: 2),
                  Text(
                    _numeroCourt(numero),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: () => _telecharger(context, paiement, recu),
              icon: const Icon(Icons.download_outlined, size: 17),
              label: const Text('Télécharger le reçu'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF14251D),
                side: const BorderSide(color: Color(0xFF14251D)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9)),
                textStyle: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _telecharger(BuildContext context, Map<String, dynamic> paiement,
      Map<String, dynamic> recu) async {
    final messager = ScaffoldMessenger.of(context);
    try {
      final resultat =
          await genererEtEnregistrerRecuPdf(payment: paiement, receipt: recu);

      if (!resultat.reussi) {
        messager.showSnackBar(
          SnackBar(
            content: Text(
              'Le reçu n\'a pas pu être enregistré : ${resultat.erreur}',
            ),
          ),
        );
        return;
      }

      // On ne dit « enregistré dans Téléchargements » que là où c'est vrai.
      // Sur le web et sur iOS, le document part par le navigateur ou la
      // feuille de partage : annoncer un dossier qui n'existe pas enverrait
      // l'étudiant chercher son reçu au mauvais endroit.
      messager.showSnackBar(
        SnackBar(
          content: Text(
            resultat.enregistreSurLAppareil
                ? 'Reçu enregistré dans Téléchargements '
                    '(${resultat.nomFichier})'
                : 'Reçu téléchargé',
          ),
        ),
      );
    } catch (e) {
      // On dit ce qui a échoué. Un bouton qui ne fait rien, sans message, est
      // indiscernable d'un bouton mort.
      messager.showSnackBar(
        SnackBar(content: Text('Le reçu n\'a pas pu être préparé : $e')),
      );
    }
  }
}

class _VoletBons extends StatelessWidget {
  const _VoletBons({required this.provider});

  final StudentApplicationPaymentsProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.documentsEnCours && provider.bons.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.erreurBons != null && provider.bons.isEmpty) {
      return _Message(
        icone: Icons.wifi_off_outlined,
        titre: 'Tes bons n\'ont pas pu être chargés',
        detail: provider.erreurBons!,
        action: TextButton.icon(
          onPressed: provider.chargerMesDocuments,
          icon: const Icon(Icons.refresh),
          label: const Text('Réessayer'),
        ),
      );
    }

    if (provider.bons.isEmpty) {
      return const _Message(
        icone: Icons.confirmation_number_outlined,
        titre: 'Aucun bon de courtage pour le moment',
        detail: 'Le bon t\'est remis dès que tes frais de courtage sont '
            'confirmés, une fois la réduction négociée auprès de '
            'l\'établissement. Tu le présentes à l\'école, qui vérifie son '
            'code depuis son propre espace Academia.',
      );
    }

    return RefreshIndicator(
      onRefresh: provider.chargerMesDocuments,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: provider.bons.length,
        separatorBuilder: (_, __) => const SizedBox(height: 11),
        itemBuilder: (context, i) => _CarteBon(bon: provider.bons[i]),
      ),
    );
  }
}

class _CarteBon extends StatelessWidget {
  const _CarteBon({required this.bon});

  final Map<String, dynamic> bon;

  @override
  Widget build(BuildContext context) {
    final snapshot = bon['snapshot'] is Map
        ? Map<String, dynamic>.from(bon['snapshot'] as Map)
        : <String, dynamic>{};
    final reduction = snapshot['reduction'] is Map
        ? Map<String, dynamic>.from(snapshot['reduction'] as Map)
        : <String, dynamic>{};
    final formation = snapshot['formation'] is Map
        ? Map<String, dynamic>.from(snapshot['formation'] as Map)
        : <String, dynamic>{};

    final numero = (bon['voucher_number'] ?? '').toString();
    final ecole = (bon['universite'] ?? '').toString();
    final titreFormation = (formation['titre'] ?? '').toString();
    final taux = _taux(reduction['taux']);
    final echeance = DateTime.tryParse((bon['expires_at'] ?? '').toString());
    final consomme = (bon['consumed_at'] ?? '').toString().isNotEmpty;
    final expire = bon['expire'] == true;

    // TROIS ÉTATS, TROIS COULEURS, ET LE MOTIF ÉCRIT. Un bon périmé qui
    // ressemblerait à un bon valable enverrait l'étudiant se présenter pour
    // rien à la scolarité d'une école.
    final (String etiquette, Color fond, Color encre, String note) = consomme
        ? (
            'ACCEPTÉ',
            const Color(0xFFEDF3FF),
            const Color(0xFF1B4F9C),
            'Ce bon a été accepté par l\'établissement. Il ne peut plus '
                'servir.'
          )
        : expire
            ? (
                'ÉCHU',
                const Color(0xFFFFF1F0),
                const Color(0xFFB3261E),
                'Le délai est passé. Rapproche-toi d\'Academia pour obtenir '
                    'un nouveau bon.'
              )
            : (
                'VALABLE',
                const Color(0xFFEAF6EE),
                const Color(0xFF14663A),
                echeance == null
                    ? 'Présente ce bon à l\'établissement.'
                    : 'À présenter à l\'établissement avant le '
                        '${DateFormat('dd/MM/yyyy').format(echeance.toLocal())}.'
              );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E9E5)),
        borderRadius: BorderRadius.circular(13),
      ),
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: fond, borderRadius: BorderRadius.circular(99)),
                      child: Text(etiquette,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: .5,
                              color: encre)),
                    ),
                    const SizedBox(height: 8),
                    if (ecole.isNotEmpty)
                      Text(ecole,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF14251D))),
                    if (titreFormation.isNotEmpty)
                      Text(titreFormation,
                          style: const TextStyle(
                              fontSize: 12.5, color: Color(0xFF5A6560))),
                  ],
                ),
              ),
              if (taux != null) ...[
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$taux %',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF14663A))),
                    const Text('de réduction',
                        style:
                            TextStyle(fontSize: 10.5, color: Color(0xFF5A6560))),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text('$numero · ${_codeLisible(bon['verification_code'])}',
              style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Color(0xFF3E4A44))),
          const SizedBox(height: 6),
          Text(note,
              style: const TextStyle(
                  fontSize: 12, height: 1.4, color: Color(0xFF5A6560))),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: () => _telechargerBon(context, bon),
              icon: const Icon(Icons.download_outlined, size: 17),
              label: const Text('Télécharger le bon'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF14251D),
                side: const BorderSide(color: Color(0xFF14251D)),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                textStyle:
                    const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 15 plutôt que 15.0, mais 12,5 reste 12,5.
  static String? _taux(dynamic v) {
    if (v == null) return null;
    final d = v is num ? v.toDouble() : double.tryParse(v.toString());
    if (d == null) return null;
    return d == d.roundToDouble()
        ? d.toStringAsFixed(0)
        : d.toString().replaceAll(RegExp(r'0+$'), '');
  }

  /// Le code se lit par groupes de quatre : il se recopie à la main.
  static String _codeLisible(dynamic v) {
    final c =
        (v ?? '').toString().replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();
    if (c.length <= 4) return c;
    final m = <String>[];
    for (var i = 0; i < c.length; i += 4) {
      m.add(c.substring(i, i + 4 > c.length ? c.length : i + 4));
    }
    return m.join('-');
  }

  Future<void> _telechargerBon(
      BuildContext context, Map<String, dynamic> bon) async {
    final messager = ScaffoldMessenger.of(context);
    try {
      final resultat = await genererEtEnregistrerBonPdf(bon: bon);
      if (!resultat.reussi) {
        messager.showSnackBar(SnackBar(
            content: Text(
                'Le bon n\'a pas pu être enregistré : ${resultat.erreur}')));
        return;
      }
      messager.showSnackBar(SnackBar(
        content: Text(resultat.enregistreSurLAppareil
            ? 'Bon enregistré dans Téléchargements (${resultat.nomFichier})'
            : 'Bon téléchargé'),
      ));
    } catch (e) {
      messager.showSnackBar(
          SnackBar(content: Text('Le bon n\'a pas pu être préparé : $e')));
    }
  }
}

class _NoteDeBasDePage extends StatelessWidget {
  const _NoteDeBasDePage();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E9E5)),
        borderRadius: BorderRadius.circular(13),
      ),
      child: RichText(
        text: const TextSpan(
          style: TextStyle(
              fontSize: 12.5, height: 1.5, color: Color(0xFF3E4A44)),
          children: [
            TextSpan(
              text: 'Tout paiement donne un reçu.',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: Color(0xFF14251D)),
            ),
            TextSpan(
              text: ' Il prouve ce que tu as versé à Nexiom Group. '
                  'Le bon de courtage, lui, se présente à l\'établissement.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icone,
    required this.titre,
    required this.detail,
    this.action,
  });

  final IconData icone;
  final String titre;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
      children: [
        Icon(icone, size: 44, color: const Color(0xFF8A9490)),
        const SizedBox(height: 16),
        Text(
          titre,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF14251D)),
        ),
        const SizedBox(height: 8),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 13, height: 1.5, color: Color(0xFF6B7873)),
        ),
        if (action != null) ...[
          const SizedBox(height: 14),
          Center(child: action!),
        ],
      ],
    );
  }
}

/// Pastille de couleur par motif, reprise de la maquette validée.
class _AspectMotif {
  const _AspectMotif(this.etiquette, this.fond, this.encre);

  final String etiquette;
  final Color fond;
  final Color encre;

  static _AspectMotif pour(String motif) {
    switch (motif) {
      case 'application_fee':
        return const _AspectMotif(
            'FRAIS DE COURTAGE', Color(0xFFE8F5ED), Color(0xFF14663A));
      case 'credit_purchase':
        return const _AspectMotif(
            'CRÉDITS IA', Color(0xFFEEF2FB), Color(0xFF2B4F84));
      case 'td_access':
        return const _AspectMotif(
            'ACCÈS TD', Color(0xFFFBF3EF), Color(0xFFA3441B));
      case 'subscription':
        return const _AspectMotif(
            'ABONNEMENT', Color(0xFFF3EFFB), Color(0xFF4B2B84));
      case 'registration_fee':
        return const _AspectMotif(
            'INSCRIPTION', Color(0xFFE8F5ED), Color(0xFF14663A));
      case 'tuition_deposit':
        return const _AspectMotif(
            'ACOMPTE SCOLARITÉ', Color(0xFFE8F5ED), Color(0xFF14663A));
      // LES QUATRE MOTIFS AJOUTÉS LE 10/09/2026. L'énumération
      // `payment_reason` en compte onze ; sept étaient traités, et les quatre
      // autres retombaient sur « PAIEMENT ». Sur un reçu de version 1 — c'est
      // le cas des dix-huit reçus existants — la désignation est vide : la
      // carte ne disait alors NI ce qui avait été payé, ni pour quoi.
      case 'online_course':
        return const _AspectMotif(
            'COURS EN LIGNE', Color(0xFFEEF2FB), Color(0xFF2B4F84));
      case 'orientation_consultation':
        return const _AspectMotif(
            'ORIENTATION', Color(0xFFF3EFFB), Color(0xFF4B2B84));
      case 'prep_concours':
        return const _AspectMotif(
            'PRÉPA CONCOURS', Color(0xFFFBF3EF), Color(0xFFA3441B));
      case 'marketplace_purchase':
        return const _AspectMotif(
            'PLACE DE MARCHÉ', Color(0xFFFDF6E3), Color(0xFF7A5A00));
      default:
        return const _AspectMotif(
            'PAIEMENT', Color(0xFFEFF1F0), Color(0xFF4A5551));
    }
  }
}

num? _nombre(dynamic v) {
  if (v is num) return v;
  return num.tryParse(v?.toString() ?? '');
}

String _millierEspace(num n) {
  final entier = n.round();
  final chiffres = entier.abs().toString();
  final morceaux = <String>[];
  for (var i = chiffres.length; i > 0; i -= 3) {
    morceaux.insert(0, chiffres.substring(i - 3 < 0 ? 0 : i - 3, i));
  }
  return '${entier < 0 ? '-' : ''}${morceaux.join(' ')}';
}

/// « REC-2026-000318 » → « REC-…0318 ». Les anciens numéros horodatés sont
/// bien plus longs : on garde la fin, qui est ce qui les distingue.
String _numeroCourt(String numero) {
  if (numero.length <= 12) return numero;
  return 'REC-…${numero.substring(numero.length - 4)}';
}
