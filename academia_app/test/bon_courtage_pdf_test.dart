import 'dart:convert';
import 'dart:io';

import 'package:academia_app/utils/bon_courtage_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fabrique le BON DE COURTAGE **par le code de production**, hors écran, et
/// l'écrit sur le disque pour relecture et pour contrôle.
///
///   flutter test test/bon_courtage_pdf_test.dart
///   python ../outils/verifier_recu_pdf.py apercus_bon      (CONTENU réel)
///
/// Pourquoi deux étapes, et pas une. Le 02/09, une erreur de mise en page a
/// fait disparaître **tout le corps** du reçu : il ne restait que l'en-tête.
/// Le test d'alors est passé, parce qu'il ne regardait que le poids du fichier
/// et les cinq octets « %PDF- ». Le document était valide, du bon poids, et
/// mutilé. Un test qui ne peut pas échouer ne mesure rien.
///
/// Le texte d'un PDF produit par le paquet `pdf` vit dans des flux compressés,
/// illisibles depuis Dart. Ce test produit donc les documents et DÉCLARE ce
/// qu'ils doivent contenir ; le script Python lit le texte réellement rendu et
/// compare. La sortie de `flutter test` seule ne prouve pas le contenu, et le
/// dit à la fin.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final controles = <Map<String, dynamic>>[];

  Future<void> composer(
    String nom,
    Map<String, dynamic> bon, {
    required List<String> attendus,
    List<String> absents = const [],
  }) async {
    final octets = await construirePdfBonCourtage(bon: bon);

    expect(String.fromCharCodes(octets.take(5)), '%PDF-',
        reason: 'ce n\'est pas un PDF');
    // LE POIDS EST UN DÉTECTEUR D'ASSETS MANQUANTS. Les deux logos pèsent à
    // eux seuls ~350 Ko. Le seuil valait 100 Ko tant que le bon ne portait que
    // Nexiom : il laissait donc passer un document SANS logo Academia, ce que
    // Jocelyn a vu à l'oeil et pas le test. Relevé à 300 Ko, comme le reçu.
    expect(octets.length, greaterThan(300 * 1024),
        reason: 'document trop léger : un des deux logos ou les polices manquent');

    final dossier = Directory('build/apercus_bon')..createSync(recursive: true);
    File('${dossier.path}/$nom.pdf').writeAsBytesSync(octets);

    controles.add({'fichier': '$nom.pdf', 'attendus': attendus, 'absents': absents});

    // ignore: avoid_print
    print('→ build/apercus_bon/$nom.pdf  (${(octets.length / 1024).round()} Ko)');
  }

  tearDownAll(() {
    File('build/apercus_bon/controles.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(controles));
    // ignore: avoid_print
    print('\nContenu NON vérifié par ce test. Lancer depuis academia_app/ :\n'
        '    python ../outils/verifier_recu_pdf.py apercus_bon\n');
  });

  /// Le bon tel que `app.emettre_bon()` le produit : tout vient de l'instantané.
  Map<String, dynamic> bonType({
    String numero = 'BC-2026-000147',
    String code = '7K4M92XQ',
    String? jeton = 'a3f7c21e9d04b8fa6e5137cc02b9ae41',
    dynamic taux = 15,
  }) =>
      {
        'voucher_number': numero,
        'verification_code': code,
        'scan_token': jeton,
        'issued_at': '2026-09-02T17:53:00.000Z',
        'expires_at': '2026-09-16T17:53:00.000Z',
        'signature_hash':
            'a3f7c21e9d04b8fa6e5137cc02b9ae41b7d2109f4c6e83a5d0f7b1c9e2a48d63',
        'snapshot': {
          'version': 1,
          'numero': numero,
          'emis_le': '2026-09-02T17:53:00.000Z',
          'expire_le': '2026-09-16T17:53:00.000Z',
          'origine': 'automatique',
          'emetteur': {
            'raison_sociale': 'NEXIOM GROUP',
            'ville': 'Ouagadougou',
            'pays': 'Burkina Faso',
            'rccm': 'BF-OUA-01-2025-B13-13341',
            'ifu': '00281802P',
            'telephone': '73 93 43 92',
            'site': 'www.app.academiea.com',
          },
          'destinataire': {
            'nom': 'Institut International de Management',
            'ville': 'Ouagadougou',
          },
          'formation': {
            'titre': 'Assurance, Banque, Finance',
            'niveau': 'Licence 1',
            'mode': 'présentiel',
            'horaires': 'jour',
          },
          'candidat': {
            'nom': 'OUEDRAOGO Aminata',
            'date_de_naissance': '2004-03-14',
            'telephone': '+226 70 12 34 56',
            'ville': 'Bobo-Dioulasso',
          },
          'reduction': {'taux': taux, 'validee_le': '2026-08-30T09:00:00.000Z'},
          'courtage': {
            'montant': 25000,
            'devise': 'XOF',
            'acquitte_le': '2026-09-02T15:41:00.000Z',
            'reference': 'AP-20260902154102-eb2daf',
          },
        },
      };

  test('bon nominal — tout ce que la maquette annonce est là', () async {
    await composer(
      'bon_nominal',
      bonType(),
      attendus: [
        'Bon de courtage',
        'BC-2026-000147',
        'NEXIOM GROUP',
        "À L'ATTENTION DE",
        'Institut International de Management',
        'Assurance, Banque, Finance',
        'Licence 1',
        'OUEDRAOGO Aminata',
        '14/03/2004',
        '+226 70 12 34 56',
        'Bobo-Dioulasso',
        '15 %',
        "RÉDUCTION OBTENUE ET VALIDÉE PAR L'ÉTABLISSEMENT",
        'CE BON ATTESTE QUE',
        'finaliser son inscription',
        'EMPREINTE DU DOCUMENT',
        "Ce document n'a de valeur que vérifié.",
        // Le code imprimé, groupé par quatre pour se recopier sans faute.
        '7K4M-92XQ',
        'RCCM BF-OUA-01-2025-B13-13341',
        '16/09/2026',
      ],
      absents: [
        // LE JETON DU QR NE S'IMPRIME JAMAIS. Il vit dans le code-barres, que
        // seule une machine lit. L'imprimer en clair le réduirait à la même
        // fragilité que le code court, et anéantirait tout l'intérêt d'avoir
        // deux secrets.
        'a3f7c21e9d04b8fa6e5137cc02b9ae41',
      ],
    );
  });

  test('taux décimal — 12,5 % ne devient pas 13 % ni 12 %', () async {
    await composer(
      'bon_taux_decimal',
      bonType(numero: 'BC-2026-000148', code: 'RTY45KLM', taux: 12.5),
      attendus: ['12.5 %', 'BC-2026-000148', 'RTY4-5KLM'],
      absents: ['13 %'],
    );
  });

  test('sans jeton de scan — le bon sort quand même, avec le code seul',
      () async {
    // Dégradation gracieuse : un bon sans jeton (cas d'un enregistrement
    // ancien) doit rester imprimable et vérifiable à la main. On ne rejette
    // pas, on retire ce qui manque.
    await composer(
      'bon_sans_jeton',
      bonType(numero: 'BC-2026-000149', code: 'ZXCV8899', jeton: null),
      attendus: ['BC-2026-000149', 'ZXCV-8899', "Ce document n'a de valeur que vérifié."],
    );
  });
}
