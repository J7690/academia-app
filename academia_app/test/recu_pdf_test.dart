import 'dart:convert';
import 'dart:io';

import 'package:academia_app/utils/payment_receipt_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fabrique le reçu PDF **par le code de production**, hors écran, et l'écrit
/// sur le disque pour relecture et pour contrôle.
///
///   flutter test test/recu_pdf_test.dart
///   python ..\outils\verifier_recu_pdf.py        (contrôle du CONTENU)
///
/// Pourquoi deux étapes. Le 02/09, une erreur de mise en page
/// (`CrossAxisAlignment.stretch` dans une Row placée sous un Spacer) a fait
/// disparaître **tout le corps du document** : il ne restait que l'en-tête.
/// La version d'alors de ce test est passée — elle ne regardait que le poids
/// et l'en-tête `%PDF-`. Un test qui ne peut pas échouer ne mesure rien.
///
/// Le texte d'un PDF produit par le paquet `pdf` est dans des flux compressés,
/// illisibles depuis Dart sans bibliothèque d'extraction. Ce test-ci produit
/// donc les documents et déclare ce qu'ils DOIVENT contenir ; le script Python
/// extrait le texte réellement rendu et compare. La sortie de `flutter test`
/// seule ne prouve pas le contenu, et le dit.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final controles = <Map<String, dynamic>>[];

  Future<void> composer(
    String nom,
    Map<String, dynamic> paiement,
    Map<String, dynamic> recu, {
    required List<String> attendus,
    List<String> absents = const [],
  }) async {
    final octets = await construirePdfRecu(payment: paiement, receipt: recu);

    expect(String.fromCharCodes(octets.take(5)), '%PDF-',
        reason: 'ce n\'est pas un PDF');
    // Les deux logos pèsent à eux seuls ~370 Ko. En dessous, l'en-tête
    // illustré manque — ce qui veut dire que les assets n'ont pas été chargés.
    expect(octets.length, greaterThan(300 * 1024),
        reason: 'document trop léger : les logos n\'y sont pas');

    final dossier = Directory('build/apercus_recu')..createSync(recursive: true);
    File('${dossier.path}/$nom.pdf').writeAsBytesSync(octets);

    controles.add({
      'fichier': '$nom.pdf',
      'attendus': attendus,
      'absents': absents,
    });

    // ignore: avoid_print
    print('→ build/apercus_recu/$nom.pdf  (${(octets.length / 1024).round()} Ko)');
  }

  tearDownAll(() {
    File('build/apercus_recu/controles.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(controles));
    // ignore: avoid_print
    print('\nContenu NON vérifié par ce test. Lancer depuis academia_app/ :\n'
        '    python ../outils/verifier_recu_pdf.py\n');
  });

  test('reçu de courtage — instantané version 2, cas nominal', () async {
    await composer(
      'recu_courtage',
      {
        'currency': 'XOF',
        'reference_code': 'AP-20260902154102-eb2daf',
        'student_id': '6745c7ad-732b-47d0-b5b8-06d6dcf286ff',
      },
      {
        'receipt_number': 'REC-2026-000001',
        'issued_at': '2026-09-02T15:42:00+00:00',
        'student_name': 'OUEDRAOGO Aminata',
        'student_phone': '+226 70 12 34 56',
        'student_email': 'aminata.ouedraogo@exemple.bf',
        'training_name':
            'Institut International de Management — Assurance, Banque, Finance',
        'signature_hash':
            'a3f7c21e9d04b8fa6e5137cc02b9ae41c8d5074fbb2913ae60d4f8127c3a95e0',
        'snapshot': {
          'version': 2,
          'numero': 'REC-2026-000001',
          'motif': 'application_fee',
          'libelle': 'Frais de courtage — candidature universitaire',
          'designation':
              'Institut International de Management · Assurance, Banque, Finance (Licence 1)',
          'montant': 25000,
          'montant_source': 'encaisse',
          'devise': 'XOF',
          'emetteur': {
            'raison_sociale': 'NEXIOM GROUP',
            'ville': 'Ouagadougou',
            'pays': 'Burkina Faso',
            'rccm': 'BF-OUA-01-2025-B13-13341',
            'ifu': '00281802P',
            'telephone': '73 93 43 92',
            'email': 'contact@academiea.com',
            'site': 'www.app.academiea.com',
          },
          'payeur': {
            'id': '6745c7ad-732b-47d0-b5b8-06d6dcf286ff',
            'nom': 'OUEDRAOGO Aminata',
            'telephone': '+226 70 12 34 56',
            'email': 'aminata.ouedraogo@exemple.bf',
            'ville': 'Bobo-Dioulasso',
            'pays': 'Burkina Faso',
          },
          'reglement': {
            'canal': 'ligdicash',
            'moyen': 'Mobile money — Orange Burkina',
            'operateur': 'ORANGE BURKINA',
            'encaisse_le': '2026-09-02T15:41:00+00:00',
            'reference_academia': 'AP-20260902154102-eb2daf',
            'reference_operateur': 'c67ad167-2bfb-4e94-bf1a-d84140f49b40',
          },
          'dossier': {
            'candidature_id': '8a5f2e24-1c3b-4d5e-9f70-2a1b3c4d5e6f',
            'formation': 'Assurance, Banque, Finance',
            'niveau': 'Licence 1',
            'universite': 'Institut International de Management',
          },
        },
      },
      attendus: [
        // Les cinq blocs du document. Si l'un manque, la page est mutilée.
        'NEXIOM GROUP',
        'Reçu de paiement',
        'REC-2026-000001',
        'VERSÉ PAR',
        'OUEDRAOGO Aminata',
        'REÇU PAR',
        'RCCM BF-OUA-01-2025-B13-13341',
        'OBJET DU PAIEMENT',
        'Frais de courtage — candidature universitaire',
        'Total réglé',
        '25 000 XOF',
        'Vingt-cinq mille francs CFA.',
        'RÈGLEMENT',
        'Mobile money — Orange Burkina',
        'AP-20260902154102-eb2daf',
        'empreinte',
        'a3f7c21e',
        'loi N°037/2013/AN',
      ],
      absents: const [
        // Retirés sur décision de Jocelyn le 02/09/2026.
        'TVA', 'Régime fiscal', 'régime fiscal', 'HT', 'TTC',
      ],
    );
  });

  test('reçu de crédits — le complément de l\'appelant est repris', () async {
    await composer(
      'recu_credits',
      {'currency': 'XOF', 'reference_code': 'PR-20260828101500-9e14aa'},
      {
        'receipt_number': 'REC-2026-000002',
        'issued_at': '2026-08-28T10:15:00+00:00',
        'student_name': 'OUEDRAOGO Aminata',
        'credit_pack_name': 'Mini',
        'signature_hash':
            '5b1f90c4772ae8130d6f2c48ba5e9736104dc8fe2b7a935016cd48ef2a70b3c9',
        'snapshot': {
          'version': 2,
          'motif': 'credit_purchase',
          'libelle': 'Achat de crédits',
          // Le complément écrase la désignation générique : 100 crédits
          // achetés, 150 réellement portés au compte (bonus premier achat).
          'designation': 'Pack Mini · 150 crédits',
          'montant': 1000,
          'montant_source': 'encaisse',
          'devise': 'XOF',
          'payeur': {'nom': 'OUEDRAOGO Aminata', 'telephone': '+226 70 12 34 56'},
          'reglement': {
            'moyen': 'Mobile money — Moov Africa',
            'encaisse_le': '2026-08-28T10:14:00+00:00',
            'reference_academia': 'PR-20260828101500-9e14aa',
            'reference_operateur': '9e14aa77-3b21-4c0d',
          },
          'credits': {
            'pack': 'Mini',
            'code': 'mini',
            'quantite': 100,
            'quantite_creditee': 150,
            'bonus_premier_achat': true,
          },
        },
      },
      attendus: [
        'Achat de crédits',
        'Pack Mini · 150 crédits',
        '1 000 XOF',
        'Mille francs CFA.',
        'Mobile money — Moov Africa',
      ],
    );
  });

  test('reçu ancien — sans instantané ni empreinte, il sort quand même',
      () async {
    // Les 18 reçus émis avant le 02/09/2026. On dégrade, on ne rejette pas :
    // le document se compose depuis les colonnes du paiement, et il
    // NE PROMET PAS d'empreinte qu'il n'a pas.
    await composer(
      'recu_ancien_sans_instantane',
      {
        'currency': 'XOF',
        'amount_paid': 2000,
        'amount_due': 2000,
        'payment_reason': 'td_access',
        'channel': 'orange_money',
        'reference_code': 'AP-20260815090000-c80612',
        'external_reference': 'OM240815C806',
        'confirmed_at': '2026-08-15T09:00:00+00:00',
        'program_title': 'Mathématiques — Licence 1',
      },
      {
        'receipt_number': 'REC-20260815090012-c80612',
        'issued_at': '2026-08-15T09:00:12+00:00',
      },
      attendus: [
        'Accès aux travaux dirigés',
        'Mathématiques — Licence 1',
        '2 000 XOF',
        'Deux mille francs CFA.',
        'Orange Money',
        'Étudiant Academia', // le payeur est inconnu : on le dit
      ],
      absents: const [
        // Sans empreinte, la phrase qui en promet une ne doit PAS s'imprimer.
        'L\'empreinte ci-dessous',
      ],
    );
  });

  test('montant en toutes lettres — les pièges du français', () async {
    // 80 → « quatre-vingts » avec un s ; 81 → sans. 71 → « soixante et onze ».
    // 2000 → « deux mille », jamais « deux milles ».
    const cas = {
      1: 'Un franc CFA.',
      71: 'Soixante et onze francs CFA.',
      80: 'Quatre-vingts francs CFA.',
      81: 'Quatre-vingt-un francs CFA.',
      100: 'Cent francs CFA.',
      200: 'Deux cents francs CFA.',
      2000: 'Deux mille francs CFA.',
      25000: 'Vingt-cinq mille francs CFA.',
      1000000: 'Un million francs CFA.',
    };
    for (final entree in cas.entries) {
      await composer(
        'lettres_${entree.key}',
        const {'currency': 'XOF'},
        {
          'receipt_number': 'REC-TEST-${entree.key}',
          'issued_at': '2026-09-02T12:00:00+00:00',
          'snapshot': {
            'montant': entree.key,
            'devise': 'XOF',
            'motif': 'other',
          },
        },
        attendus: [entree.value],
      );
    }
  });
}
