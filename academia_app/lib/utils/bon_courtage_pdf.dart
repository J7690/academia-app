import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'enregistrer_dans_telechargements.dart';

/// LE BON DE COURTAGE, dans la forme de la maquette validée le 02/09/2026.
///
/// CE QU'IL EST, ET CE QU'IL N'EST PAS. Le reçu prouve à l'étudiant ce qu'il a
/// versé à Nexiom Group ; le bon prouve à l'ÉTABLISSEMENT que Nexiom a négocié
/// pour ce candidat. Deux documents, deux destinataires. L'analogue métier est
/// le « right to represent » du recrutement — l'enregistrement horodaté de la
/// présentation d'une personne à un client NOMMÉ, qui fonde le droit à
/// commission — et le bon de visite immobilier, dont la jurisprudence dit
/// qu'il ne vaut pas contrat mais preuve de l'intervention de l'intermédiaire.
///
/// TOUT VIENT DE `bon['snapshot']`, l'instantané figé par `app.emettre_bon()`
/// à l'émission. Un bon doit dire ce qui était vrai le jour où il a été émis,
/// même si la formation change de nom ou d'établissement ensuite.
///
/// LE QR NE PORTE PAS LES DONNÉES DU BON, ET C'EST DÉLIBÉRÉ. S'il les portait,
/// on fabriquerait un faux QR parfaitement cohérent avec un faux papier. Il ne
/// porte qu'une adresse : le numéro et un jeton. C'est l'ENREGISTREMENT qui
/// fait foi, jamais le papier.
///
/// DEUX SECRETS, PARCE QUE DEUX LECTEURS. Le QR encode le `scan_token` de
/// 128 bits, qu'aucun humain ne lit. Le papier imprime le `verification_code`
/// de 8 caractères, pour l'oeil et la saisie à la main. Ne jamais imprimer le
/// jeton long en clair : il perdrait tout son intérêt.
///
/// RÉGLAGES DU QR DÉJÀ PAYÉS (02/09). Un premier QR à 41 modules dans 78 px ne
/// se scannait pas : moins de deux pixels par module. Ramené à une correction
/// moyenne et agrandi à 118 px, il s'est lu, et Jocelyn l'a confirmé sur son
/// propre téléphone. Ne pas réduire cette taille.

/// Fabrique le bon et l'enregistre dans les téléchargements de l'appareil.
///
/// Renvoie le sort du document ; ne lance pas. L'appelant DOIT lire le
/// résultat — un retour ignoré redonnerait le faux succès corrigé le 03/09 sur
/// le reçu, où « Télécharger » ouvrait en réalité un aperçu d'impression.
Future<ResultatEnregistrement> genererEtEnregistrerBonPdf({
  required Map<String, dynamic> bon,
}) async {
  final doc = pw.Document();
  final octets = await construirePdfBonCourtage(bon: bon, doc: doc);
  final numero = _texte(bon['voucher_number']);
  return enregistrerDansTelechargements(
    octets: octets,
    nom: 'bon_de_courtage_${numero.isEmpty ? 'academia' : numero}.pdf',
  );
}

// ── Palette : la même que le reçu, pour que les deux pièces se reconnaissent ──
const _encre = PdfColor.fromInt(0xFF14251D);
const _vert = PdfColor.fromInt(0xFF1EA75C);
const _vertFonce = PdfColor.fromInt(0xFF14663A);
const _gris = PdfColor.fromInt(0xFF5A6560);
const _grisClair = PdfColor.fromInt(0xFF6B7873);
const _grisPale = PdfColor.fromInt(0xFF8A9490);
const _trait = PdfColor.fromInt(0xFFE2E8E4);
const _fondBloc = PdfColor.fromInt(0xFFF8FAF9);
const _fondReduction = PdfColor.fromInt(0xFFF3FAF6);
const _ardoise = PdfColor.fromInt(0xFF33414A);

const _siteVerification = 'https://www.app.academiea.com';

String _texte(dynamic v) => v?.toString() ?? '';

Map<String, dynamic> _objet(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

String _ouSinon(dynamic v, String repli) {
  final s = _texte(v).trim();
  return s.isEmpty ? repli : s;
}

String _dateOuTexte(dynamic v, DateFormat f) {
  if (v == null) return '';
  final d = DateTime.tryParse(v.toString());
  return d == null ? v.toString() : f.format(d.toLocal());
}

/// Le code imprimé, groupé par quatre : `7K4M-92XQ` se recopie mieux que
/// `7K4M92XQ`. La vérification côté serveur retire les séparateurs.
String _codeLisible(String code) {
  final c = code.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();
  if (c.length <= 4) return c;
  final morceaux = <String>[];
  for (var i = 0; i < c.length; i += 4) {
    morceaux.add(c.substring(i, i + 4 > c.length ? c.length : i + 4));
  }
  return morceaux.join('-');
}

/// Construit le document et rend ses octets. Séparé de l'enregistrement pour
/// que l'écran puisse partager le fichier sans le déposer sur l'appareil.
Future<Uint8List> construirePdfBonCourtage({
  required Map<String, dynamic> bon,
  pw.Document? doc,
}) async {
  final document = doc ?? pw.Document();
  // Le bon ne porte que des DATES, jamais d'heures : il vaut quatorze jours,
  // pas quatorze heures. Le reçu, lui, horodate à la minute, parce qu'un
  // versement se situe dans la journée.
  final jour = DateFormat('dd/MM/yyyy');

  final snap = _objet(bon['snapshot']);
  final emetteur = _objet(snap['emetteur']);
  final destinataire = _objet(snap['destinataire']);
  final formation = _objet(snap['formation']);
  final candidat = _objet(snap['candidat']);
  final reduction = _objet(snap['reduction']);
  final courtage = _objet(snap['courtage']);

  final raisonSociale = _ouSinon(emetteur['raison_sociale'], 'NEXIOM GROUP');
  final villeEmetteur = _ouSinon(emetteur['ville'], 'Ouagadougou');
  final paysEmetteur = _ouSinon(emetteur['pays'], 'Burkina Faso');
  final rccm = _ouSinon(emetteur['rccm'], 'BF-OUA-01-2025-B13-13341');
  final ifu = _ouSinon(emetteur['ifu'], '00281802P');
  final telEmetteur = _ouSinon(emetteur['telephone'], '73 93 43 92');
  final siteEmetteur = _ouSinon(emetteur['site'], 'www.app.academiea.com');

  final numero = _texte(bon['voucher_number']);
  final code = _codeLisible(_texte(bon['verification_code']));
  final jeton = _texte(bon['scan_token']);
  final emisLe = _dateOuTexte(bon['issued_at'] ?? snap['emis_le'], jour);
  final echeance = _dateOuTexte(bon['expires_at'] ?? snap['expire_le'], jour);
  final empreinte = _texte(bon['signature_hash']);

  final ecole = _ouSinon(destinataire['nom'], "l'établissement destinataire");
  final villeEcole = _texte(destinataire['ville']);

  final titreFormation = _texte(formation['titre']);
  final ligneFormation = <String>[
    _texte(formation['niveau']),
    _texte(formation['mode']),
    _texte(formation['horaires']),
  ].where((e) => e.trim().isNotEmpty).join(' · ');

  final nomCandidat = _texte(candidat['nom']);
  final naissance = _dateOuTexte(candidat['date_de_naissance'], jour);
  final telCandidat = _texte(candidat['telephone']);
  final villeCandidat = _texte(candidat['ville']);

  final taux = _formaterTaux(reduction['taux']);
  final valideeLe = _dateOuTexte(reduction['validee_le'], jour);
  final acquitteLe = _dateOuTexte(courtage['acquitte_le'], jour);

  // L'adresse encodée dans le QR. Elle porte le JETON LONG, pas le code
  // imprimé : une machine le lit, sa longueur ne coûte rien.
  final urlVerification = jeton.isEmpty
      ? '$_siteVerification/v/$numero'
      : '$_siteVerification/v/$numero/$jeton';

  // Les logos et les polices ne bloquent jamais l'émission : un bon sans
  // en-tête illustré vaut mieux qu'un bon qui n'existe pas.
  // LES DEUX MARQUES, COMME SUR LE REÇU. `assets/marque/` porte les versions
  // détourées : Nexiom Group en gris et bleu, Academia en vert et rouge. NE PAS
  // prendre `assets/ACADEMIA_logo1.png`, qui est la version BLANCHE, faite pour
  // un fond sombre et invisible sur du papier.
  //
  // Les sources font 600 px de côté ; rendues à 42 et 46 points, elles pèsent
  // encore ~175 px à 300 dpi. Un logo posé plus petit paraît flou — c'est ce
  // qui s'est passé au premier jet, où Nexiom était à 26 points et Academia
  // absent. Les deux tailles sont celles du reçu, pour que les deux pièces se
  // reconnaissent au premier coup d'oeil.
  pw.MemoryImage? logoNexiom;
  pw.MemoryImage? logoAcademia;
  try {
    logoNexiom = pw.MemoryImage(
        (await rootBundle.load('assets/marque/nexiom_logo.png')).buffer.asUint8List());
    logoAcademia = pw.MemoryImage(
        (await rootBundle.load('assets/marque/academia_logo.png')).buffer.asUint8List());
  } catch (e) {
    debugPrint('[Bon] logos indisponibles, bon émis sans en-tête illustré : $e');
  }

  // ROBOTO EMBARQUÉE. Les polices intégrées du paquet `pdf` sont des Type1
  // sans Unicode : elles avaient fait DISPARAÎTRE le tiret cadratin du reçu,
  // sans erreur ni trace. Le même silence effacerait un caractère dans le NOM
  // d'un candidat, et c'est ça le vrai risque.
  pw.ThemeData? theme;
  try {
    final regular = pw.Font.ttf(await rootBundle.load('assets/polices/roboto-regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/polices/roboto-bold.ttf'));
    final italic = pw.Font.ttf(await rootBundle.load('assets/polices/roboto-italic.ttf'));
    theme = pw.ThemeData.withFont(
        base: regular, bold: bold, italic: italic, boldItalic: bold);
  } catch (e) {
    debugPrint('[Bon] polices indisponibles, composition en Helvetica : $e');
  }

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.fromLTRB(40, 38, 40, 24),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── BANDE DE MARQUE : la même que le reçu, au point près ──────────
          // Nexiom émet, Academia instruit. Les deux marques se lisent d'un
          // coup d'oeil, aux mêmes tailles et aux mêmes places que sur le reçu
          // validé le 02/09 : un établissement qui reçoit les deux pièces doit
          // les reconnaître comme venant de la même maison.
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                if (logoNexiom != null) ...[
                  pw.Image(logoNexiom, height: 42),
                  pw.SizedBox(width: 10),
                ],
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(raisonSociale,
                      style: pw.TextStyle(
                          fontSize: 10.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _ardoise)),
                  pw.SizedBox(height: 2),
                  _petit('$villeEmetteur, $paysEmetteur'),
                  _petit('RCCM $rccm'),
                  _petit('IFU $ifu · Tél. $telEmetteur'),
                ]),
              ]),
              pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('Plateforme Academia',
                      style: pw.TextStyle(
                          fontSize: 10.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _vertFonce)),
                  pw.SizedBox(height: 2),
                  _petit('Dossier instruit sur la plateforme'),
                  _petit(siteEmetteur),
                ]),
                if (logoAcademia != null) ...[
                  pw.SizedBox(width: 10),
                  pw.Image(logoAcademia, height: 46),
                ],
              ]),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Container(height: 1.6, color: _encre),

          // ── Titre du document, et son numéro ─────────────────────────────
          pw.SizedBox(height: 16),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Bon de courtage',
                      style: pw.TextStyle(
                          fontSize: 26, fontWeight: pw.FontWeight.bold, color: _encre)),
                  pw.SizedBox(height: 3),
                  pw.Text('RÉDUCTION NÉGOCIÉE · DROITS ACQUITTÉS',
                      style: pw.TextStyle(
                          fontSize: 8,
                          letterSpacing: 0.8,
                          color: _vertFonce,
                          fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('N° DU BON',
                      style: pw.TextStyle(
                          fontSize: 7,
                          letterSpacing: 1.2,
                          color: _grisPale,
                          fontWeight: pw.FontWeight.bold)),
                  pw.Text(numero,
                      style: pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                          font: pw.Font.courierBold())),
                  pw.SizedBox(height: 2),
                  pw.Text('Émis le $emisLe',
                      style: const pw.TextStyle(fontSize: 8.5, color: _gris)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // ── Le destinataire, et la formation visée ───────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _bloc("À L'ATTENTION DE", [
                  pw.Text(ecole,
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold, color: _encre)),
                  if (villeEcole.isNotEmpty)
                    pw.Text(villeEcole,
                        style: const pw.TextStyle(fontSize: 9, color: _gris)),
                ]),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: _bloc('FORMATION VISÉE', [
                  pw.Text(titreFormation,
                      style: pw.TextStyle(
                          fontSize: 11, fontWeight: pw.FontWeight.bold, color: _encre)),
                  if (ligneFormation.isNotEmpty)
                    pw.Text(ligneFormation,
                        style: const pw.TextStyle(fontSize: 9, color: _gris)),
                ]),
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // ── Le candidat présenté ─────────────────────────────────────────
          _bloc('CANDIDAT PRÉSENTÉ', [
            pw.Row(children: [
              pw.Expanded(
                  flex: 3,
                  child: _paire('Nom et prénoms', nomCandidat, gras: true)),
              pw.Expanded(flex: 2, child: _paire('Né(e) le', naissance)),
            ]),
            pw.SizedBox(height: 6),
            pw.Row(children: [
              pw.Expanded(flex: 3, child: _paire('Téléphone', telCandidat)),
              pw.Expanded(flex: 2, child: _paire('Ville', villeCandidat)),
            ]),
          ]),
          pw.SizedBox(height: 12),

          // ── LA RÉDUCTION : le coeur de la page ───────────────────────────
          // Ordre rétabli par Jocelyn le 02/09, et il change tout : l'étudiant
          // ne paie qu'une fois la réduction obtenue. La négociation n'est pas
          // une étape administrative, c'est ce qu'il achète.
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: pw.BoxDecoration(
              color: _fondReduction,
              border: pw.Border.all(color: _vert, width: 1),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("RÉDUCTION OBTENUE ET VALIDÉE PAR L'ÉTABLISSEMENT",
                    style: pw.TextStyle(
                        fontSize: 7.5,
                        letterSpacing: 1.1,
                        color: _vertFonce,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('$taux %',
                        style: pw.TextStyle(
                            fontSize: 34,
                            fontWeight: pw.FontWeight.bold,
                            color: _vertFonce)),
                    pw.SizedBox(width: 14),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                              'de réduction sur les frais de scolarité de la '
                              'formation ci-dessus.',
                              style: const pw.TextStyle(fontSize: 9.5, color: _encre)),
                          pw.SizedBox(height: 3),
                          pw.Text(
                              valideeLe.isEmpty
                                  ? 'Négociée par $raisonSociale et validée par '
                                      "l'établissement."
                                  : 'Négociée par $raisonSociale et validée par '
                                      "l'établissement le $valideeLe.",
                              style: const pw.TextStyle(fontSize: 8.5, color: _gris)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // ── Ce que le bon atteste ────────────────────────────────────────
          pw.Text('CE BON ATTESTE QUE',
              style: pw.TextStyle(
                  fontSize: 7.5,
                  letterSpacing: 1.2,
                  color: _grisPale,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 7),
          _attestation('01',
              '$raisonSociale, via sa plateforme Academia, a instruit et '
              "négocié ce dossier auprès de l'établissement ;"),
          _attestation('02',
              "l'établissement a validé le taux de réduction ci-dessus ;"),
          _attestation(
              '03',
              acquitteLe.isEmpty
                  ? "le candidat s'est acquitté de ses droits de courtage ;"
                  : "le candidat s'est acquitté de ses droits de courtage le "
                      '$acquitteLe ;'),
          _attestation('04',
              "il peut en conséquence être reçu par l'établissement pour "
              'finaliser son inscription.'),
          pw.SizedBox(height: 14),

          // ── L'empreinte, puis la vérification ────────────────────────────
          if (empreinte.isNotEmpty) ...[
            pw.Text('EMPREINTE DU DOCUMENT',
                style: pw.TextStyle(
                    fontSize: 7,
                    letterSpacing: 1.2,
                    color: _grisPale,
                    fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 3),
            pw.Text(_empreinteLisible(empreinte),
                style: pw.TextStyle(
                    fontSize: 9, color: _ardoise, font: pw.Font.courier())),
            pw.SizedBox(height: 2),
            pw.Text(
                "Calculée à l'émission sur le contenu de ce bon. Toute "
                'modification la rend fausse. Elle remplace le cachet : elle ne '
                "peut pas servir à un autre document.",
                style: const pw.TextStyle(fontSize: 7.5, color: _grisClair)),
            pw.SizedBox(height: 12),
          ],

          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: _fondBloc,
              border: pw.Border.all(color: _trait),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // LA TAILLE EST MESURÉE, PAS CHOISIE. Le 02/09, un QR correct
                // à l'oeil ne se scannait pas : 41 modules dans 78 px, moins
                // de deux pixels par module. À 84 points, la relecture par
                // OpenCV du document rendu tenait jusqu'à 110 dpi et ÉCHOUAIT
                // à 96 dpi — or un A4 affiché plein écran sur un téléphone est
                // précisément dans cette zone. À 112 points, il passe à 72 dpi.
                // Ne pas réduire sans refaire la mesure.
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(
                      errorCorrectLevel: pw.BarcodeQRCorrectionLevel.medium),
                  data: urlVerification,
                  width: 112,
                  height: 112,
                  drawText: false,
                  color: _encre,
                ),
                pw.SizedBox(width: 14),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Ce document n'a de valeur que vérifié.",
                          style: pw.TextStyle(
                              fontSize: 10.5,
                              fontWeight: pw.FontWeight.bold,
                              color: _encre)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                          "L'établissement destinataire scanne ce code depuis "
                          'son espace Academia et compare ce qui est imprimé '
                          "avec ce qui est enregistré. Un autre établissement "
                          'ne peut pas vérifier ce bon.',
                          style: const pw.TextStyle(fontSize: 8.5, color: _gris)),
                      pw.SizedBox(height: 6),
                      pw.Text('Sans lecteur de code : saisir le numéro et la clé',
                          style: const pw.TextStyle(fontSize: 7.5, color: _grisClair)),
                      pw.SizedBox(height: 2),
                      pw.Text('$numero   ·   $code',
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              font: pw.Font.courierBold(),
                              color: _ardoise)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.Spacer(),

          // ── Le délai, puis le pied de page ───────────────────────────────
          if (echeance.isNotEmpty)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _trait),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                  'Le candidat doit se présenter à la scolarité de '
                  "l'établissement au plus tard le $echeance.",
                  style: pw.TextStyle(
                      fontSize: 9, color: _encre, fontWeight: pw.FontWeight.bold)),
            ),
          pw.SizedBox(height: 8),
          pw.Container(height: 1, color: _trait),
          pw.SizedBox(height: 5),
          pw.Text(
              '$raisonSociale · $villeEmetteur, $paysEmetteur · RCCM $rccm · '
              'IFU $ifu · Tél. $telEmetteur · $siteEmetteur',
              style: const pw.TextStyle(fontSize: 7, color: _grisPale)),
        ],
      ),
    ),
  );

  return document.save();
}

// ── Petites briques de mise en page ──────────────────────────────────────────

/// Les lignes fines de l'en-tête, à la taille du reçu.
pw.Widget _petit(String texte) =>
    pw.Text(texte, style: const pw.TextStyle(fontSize: 8, color: _gris));

pw.Widget _bloc(String titre, List<pw.Widget> enfants) => pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: pw.BoxDecoration(
        color: _fondBloc,
        border: pw.Border.all(color: _trait),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(titre,
              style: pw.TextStyle(
                  fontSize: 7,
                  letterSpacing: 1.2,
                  color: _grisPale,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          ...enfants,
        ],
      ),
    );

pw.Widget _paire(String etiquette, String valeur, {bool gras = false}) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(etiquette, style: const pw.TextStyle(fontSize: 7.5, color: _grisPale)),
        pw.Text(valeur.isEmpty ? '—' : valeur,
            style: pw.TextStyle(
                fontSize: gras ? 11 : 9.5,
                color: _encre,
                fontWeight: gras ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ],
    );

pw.Widget _attestation(String rang, String texte) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 18,
            child: pw.Text(rang,
                style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _vertFonce,
                    font: pw.Font.courierBold())),
          ),
          pw.Expanded(
            child: pw.Text(texte,
                style: const pw.TextStyle(fontSize: 9, color: _encre)),
          ),
        ],
      ),
    );

/// 15 plutôt que 15.00, mais 12,5 reste 12,5 : on n'invente pas de précision
/// et on n'en retire pas. Un taux imprimé faux vaut un litige.
String _formaterTaux(dynamic v) {
  if (v == null) return '—';
  final d = v is num ? v.toDouble() : double.tryParse(v.toString());
  if (d == null) return _texte(v);
  return d == d.roundToDouble()
      ? d.toStringAsFixed(0)
      : d.toString().replaceAll(RegExp(r'0+$'), '');
}

/// L'empreinte se lit par groupes de huit : soixante-quatre caractères d'affilée
/// ne se comparent pas à l'oeil. On en montre les trente-deux premiers, ce qui
/// suffit à distinguer deux documents.
String _empreinteLisible(String h) {
  final c = h.trim();
  if (c.length < 8) return c;
  final court = c.length > 32 ? c.substring(0, 32) : c;
  final morceaux = <String>[];
  for (var i = 0; i < court.length; i += 8) {
    morceaux.add(court.substring(i, i + 8 > court.length ? court.length : i + 8));
  }
  return morceaux.join(' · ');
}
