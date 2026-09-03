import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Le reçu de paiement, dans la forme arrêtée avec Jocelyn le 02/09/2026.
///
/// Il tire d'abord ses données de `receipt['snapshot']` — l'instantané figé par
/// `app.emettre_recu()` au moment de l'émission (version 2). C'est volontaire :
/// un reçu doit dire ce qui était vrai le jour du versement, même si la fiche
/// de l'étudiant, le nom du programme ou le tarif ont changé depuis.
///
/// Les 18 reçus émis avant cette date n'ont pas cet instantané. Pour eux, on
/// retombe sur les colonnes du paiement : le document est moins complet, mais
/// il sort. On dégrade, on ne rejette pas.
///
/// Ce qui n'y figure PAS, et pourquoi :
///   — ni TVA ni régime fiscal : retirés sur décision de Jocelyn ;
///   — pas de cachet ni de signature : décision de Jocelyn également, pour ne
///     pas exposer sa signature sur un document qui circule ;
///   — la mention finale dit ce que ce document est ET ce qu'il n'est pas :
///     un reçu, pas une facture normalisée au sens de la loi N°037/2013/AN.
Future<void> generateAndSharePaymentReceiptPdf({
  required Map<String, dynamic> payment,
  required Map<String, dynamic> receipt,
}) async {
  final doc = pw.Document();
  final bytes = await construirePdfRecu(payment: payment, receipt: receipt, doc: doc);

  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => bytes,
    name: 'recu_${_texte(receipt['receipt_number'])}.pdf',
  );
}

// ── Palette de la maquette ───────────────────────────────────────────────────
const _encre = PdfColor.fromInt(0xFF14251D);
const _vert = PdfColor.fromInt(0xFF1EA75C);
const _vertFonce = PdfColor.fromInt(0xFF14663A);
const _gris = PdfColor.fromInt(0xFF5A6560);
const _grisClair = PdfColor.fromInt(0xFF6B7873);
const _grisPale = PdfColor.fromInt(0xFF8A9490);
const _trait = PdfColor.fromInt(0xFFE2E8E4);
const _fondTitre = PdfColor.fromInt(0xFFF5F8F6);
const _fondBloc = PdfColor.fromInt(0xFFF8FAF9);
const _fondTotal = PdfColor.fromInt(0xFFF3FAF6);
const _traitFin = PdfColor.fromInt(0xFFEEF2F0);
const _ardoise = PdfColor.fromInt(0xFF33414A);

String _texte(dynamic v) => v?.toString() ?? '';

Map<String, dynamic> _objet(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

/// Construit le document et rend ses octets. Séparé de l'aperçu pour que
/// l'écran « Mes documents » puisse partager le fichier sans ouvrir
/// l'aperçu système.
Future<Uint8List> construirePdfRecu({
  required Map<String, dynamic> payment,
  required Map<String, dynamic> receipt,
  pw.Document? doc,
}) async {
  final document = doc ?? pw.Document();
  final jourHeure = DateFormat('dd/MM/yyyy HH:mm');
  final jour = DateFormat('dd/MM/yyyy');

  final snap = _objet(receipt['snapshot']);
  final emetteur = _objet(snap['emetteur']);
  final payeur = _objet(snap['payeur']);
  final reglement = _objet(snap['reglement']);
  final dossier = _objet(snap['dossier']);

  // Identité de l'émetteur : figée dans l'instantané, avec les valeurs
  // actuelles en secours pour les reçus antérieurs au 02/09/2026.
  final raisonSociale = _ouSinon(emetteur['raison_sociale'], 'NEXIOM GROUP');
  final villeEmetteur = _ouSinon(emetteur['ville'], 'Ouagadougou');
  final paysEmetteur = _ouSinon(emetteur['pays'], 'Burkina Faso');
  final rccm = _ouSinon(emetteur['rccm'], 'BF-OUA-01-2025-B13-13341');
  final ifu = _ouSinon(emetteur['ifu'], '00281802P');
  final telEmetteur = _ouSinon(emetteur['telephone'], '73 93 43 92');
  final emailEmetteur = _ouSinon(emetteur['email'], 'contact@academiea.com');
  final siteEmetteur = _ouSinon(emetteur['site'], 'www.app.academiea.com');

  final numero = _texte(receipt['receipt_number']);
  final emisLe = _dateOuTexte(receipt['issued_at'], jourHeure);

  // Le payeur : instantané d'abord, colonnes du reçu ensuite.
  final nom = _ouSinon(payeur['nom'], _texte(receipt['student_name']));
  final tel = _ouSinon(payeur['telephone'], _texte(receipt['student_phone']));
  final courriel = _ouSinon(payeur['email'], _texte(receipt['student_email']));
  final lieuPayeur = [
    _texte(payeur['ville']),
    _texte(payeur['pays']),
  ].where((s) => s.isNotEmpty).join(', ');
  final idPayeur = _ouSinon(payeur['id'], _texte(payment['student_id']));

  // L'objet du versement.
  final libelle = _ouSinon(snap['libelle'], _libelleDeSecours(payment, receipt));
  final designation = _ouSinon(
    snap['designation'],
    [
      _texte(payment['university_name']),
      _texte(payment['program_title']),
      _texte(receipt['credit_pack_name']).isEmpty
          ? ''
          : 'Pack ${_texte(receipt['credit_pack_name'])}',
    ].where((s) => s.isNotEmpty).join(' · '),
  );
  final refDossier = _texte(dossier['candidature_id']);

  final devise = _ouSinon(snap['devise'],
      _texte(payment['currency']).isEmpty ? 'XOF' : _texte(payment['currency']));
  final montant = _nombre(snap['montant']) ??
      _nombre(payment['amount_paid']) ??
      _nombre(payment['amount_due']) ??
      0;
  // Le serveur dit s'il a inscrit un montant encaissé ou seulement l'attendu.
  final montantVerifie = _texte(snap['montant_source']) != 'attendu';

  // Le règlement.
  final moyen = _ouSinon(reglement['moyen'], _moyenDeSecours(payment));
  final encaisseLe = _dateOuTexte(
      reglement['encaisse_le'] ?? payment['confirmed_at'], jourHeure);
  final refAcademia =
      _ouSinon(reglement['reference_academia'], _texte(payment['reference_code']));
  final refOperateur = _ouSinon(reglement['reference_operateur'],
      _texte(payment['external_reference']));

  final empreinte = _texte(receipt['signature_hash']);

  // LES DEUX MARQUES, SUR LEUR VERSION DÉTOURÉE.
  //
  // `assets/marque/` porte les logos à fond transparent : Academia en vert et
  // rouge, Nexiom Group en gris et bleu. NE PAS prendre `assets/ACADEMIA_logo1.png`,
  // qui est la version BLANCHE — faite pour un fond sombre, elle est invisible
  // sur du papier et ne se voit pas à la relecture d'un PDF affiché sur blanc.
  //
  // Le chargement ne bloque jamais l'émission du reçu : un logo manquant vaut
  // mieux qu'un reçu qui n'existe pas.
  pw.MemoryImage? logoNexiom;
  pw.MemoryImage? logoAcademia;
  try {
    logoNexiom = pw.MemoryImage(
        (await rootBundle.load('assets/marque/nexiom_logo.png')).buffer.asUint8List());
    logoAcademia = pw.MemoryImage(
        (await rootBundle.load('assets/marque/academia_logo.png')).buffer.asUint8List());
  } catch (e) {
    debugPrint('[Recu] logos indisponibles, reçu émis sans en-tête illustré : $e');
  }

  // ROBOTO, ET POURQUOI ON NE GARDE PAS LES POLICES INTÉGRÉES.
  //
  // Les polices par défaut du paquet `pdf` sont des Type1 sans support
  // Unicode. Mesuré le 02/09/2026 en composant le document hors écran :
  // « Unable to find a font to draw "—" (U+2014) ». Le tiret cadratin de
  // « Frais de courtage — candidature universitaire » DISPARAISSAIT du
  // document, sans exception, sans trace, sans rien dans le PDF pour le
  // signaler. Le même silence effacerait un caractère dans le NOM d'un
  // étudiant — et c'est ça le vrai risque, pas la typographie.
  pw.ThemeData? theme;
  try {
    final regular = pw.Font.ttf(await rootBundle.load('assets/polices/roboto-regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/polices/roboto-bold.ttf'));
    final italic = pw.Font.ttf(await rootBundle.load('assets/polices/roboto-italic.ttf'));
    theme = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: italic,
      boldItalic: bold,
    );
  } catch (e) {
    // Le reçu sort quand même, en Helvetica, avec les caractères hors
    // Latin-1 manquants. Un reçu incomplet vaut mieux qu'un reçu absent.
    debugPrint('[Recu] polices indisponibles, composition en Helvetica : $e');
  }

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.fromLTRB(40, 38, 40, 24),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── EN-TÊTE ────────────────────────────────────────────────────────
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
                          fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _ardoise)),
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
                  _petit(siteEmetteur),
                  _petit(emailEmetteur),
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

          // ── TITRE ──────────────────────────────────────────────────────────
          pw.SizedBox(height: 16),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Reçu de paiement',
                    style: pw.TextStyle(
                        fontSize: 26, fontWeight: pw.FontWeight.bold, color: _encre)),
                pw.SizedBox(height: 3),
                pw.Text('Preuve de versement — ne vaut pas facture',
                    style: const pw.TextStyle(fontSize: 10, color: _grisClair)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('REÇU N°',
                    style: const pw.TextStyle(fontSize: 7.5, color: _grisPale)),
                pw.SizedBox(height: 1),
                pw.Text(numero,
                    style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        font: pw.Font.courierBold())),
                pw.SizedBox(height: 3),
                pw.Text('Émis le $emisLe',
                    style: const pw.TextStyle(fontSize: 9.5, color: _grisClair)),
              ]),
            ],
          ),

          // ── PARTIES ────────────────────────────────────────────────────────
          pw.SizedBox(height: 18),
          // `start`, et surtout PAS `stretch`. Essayé le 02/09 : dans une Row
          // placée sous une Column qui contient un Spacer, `stretch` rend la
          // hauteur non bornée et AVALE tout le reste de la page — en-tête
          // seul, plus rien en dessous. Le PDF sortait quand même, valide et
          // du bon poids. C'est `start` qui aligne les deux encadrés par le
          // haut sans rien casser ; ils n'ont pas la même hauteur, et c'est
          // le prix à payer.
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(
              child: _encadre('VERSÉ PAR', [
                pw.Text(nom.isEmpty ? 'Étudiant Academia' : nom,
                    style: pw.TextStyle(fontSize: 12.5, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 3),
                if (lieuPayeur.isNotEmpty) _petit(lieuPayeur),
                if (tel.isNotEmpty) _petit(tel),
                if (courriel.isNotEmpty) _petit(courriel),
                if (idPayeur.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  // « Étudiant n° » : É et ° hors ASCII, donc pas de Courier.
                  pw.Text('Étudiant n° ${_court(idPayeur)}',
                      style: const pw.TextStyle(fontSize: 8, color: _grisPale)),
                ],
              ]),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: _encadre('REÇU PAR', [
                pw.Text(raisonSociale,
                    style: pw.TextStyle(fontSize: 12.5, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 3),
                _petit('$villeEmetteur, $paysEmetteur'),
                _petit('RCCM $rccm'),
                _petit('IFU $ifu'),
                pw.SizedBox(height: 4),
                pw.Text('Tél. $telEmetteur',
                    style: const pw.TextStyle(fontSize: 8, color: _grisPale)),
              ]),
            ),
          ]),

          // ── OBJET ──────────────────────────────────────────────────────────
          pw.SizedBox(height: 18),
          _intertitre('OBJET DU PAIEMENT'),
          pw.SizedBox(height: 6),
          pw.Table(
            columnWidths: const {0: pw.FlexColumnWidth(), 1: pw.FixedColumnWidth(110)},
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: _fondTitre,
                  border: pw.Border(bottom: pw.BorderSide(color: _trait)),
                ),
                children: [
                  _cellule('DÉSIGNATION', gras: true, taille: 8, couleur: _grisClair),
                  _cellule('MONTANT',
                      gras: true, taille: 8, couleur: _grisClair, aDroite: true),
                ],
              ),
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: _traitFin)),
                ),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(libelle,
                            style: pw.TextStyle(
                                fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
                        if (designation.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(designation,
                              style: const pw.TextStyle(fontSize: 9, color: _grisClair)),
                        ],
                        if (refDossier.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text('Dossier n° ${_court(refDossier)}',
                              style: const pw.TextStyle(fontSize: 9, color: _grisClair)),
                        ],
                      ],
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    child: pw.Text(_millierEspace(montant),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontSize: 10.5, font: pw.Font.courier())),
                  ),
                ],
              ),
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: _fondTotal,
                  border: pw.Border(top: pw.BorderSide(color: _vert, width: 1.6)),
                ),
                children: [
                  _cellule('Total réglé', gras: true, taille: 12.5),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: pw.Text('${_millierEspace(montant)} $devise',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: 15,
                            fontWeight: pw.FontWeight.bold,
                            color: _vertFonce,
                            font: pw.Font.courierBold())),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Text('${_enLettres(montant, devise)}.',
              style: pw.TextStyle(
                  fontSize: 9, color: _grisClair, fontStyle: pw.FontStyle.italic)),
          // Le serveur n'a pas pu vérifier le montant encaissé auprès de
          // l'opérateur : on le dit sur le document plutôt que de laisser
          // croire qu'il est confirmé.
          if (!montantVerifie) ...[
            pw.SizedBox(height: 3),
            pw.Text(
                'Montant attendu au titre de cette prestation ; le montant encaissé '
                'n\'a pas pu être confirmé auprès de l\'opérateur.',
                style: const pw.TextStyle(fontSize: 8.5, color: _grisClair)),
          ],

          // ── RÈGLEMENT ──────────────────────────────────────────────────────
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(14, 11, 14, 12),
            decoration: pw.BoxDecoration(
              color: _fondBloc,
              border: pw.Border.all(color: _trait),
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _intertitre('RÈGLEMENT'),
              pw.SizedBox(height: 7),
              pw.Row(children: [
                pw.Expanded(child: _ligne('Moyen de paiement', moyen)),
                pw.SizedBox(width: 22),
                pw.Expanded(child: _ligne('Date d\'encaissement', encaisseLe, mono: true)),
              ]),
              pw.SizedBox(height: 5),
              pw.Row(children: [
                pw.Expanded(
                    child: _ligne('Référence Academia', refAcademia, mono: true)),
                pw.SizedBox(width: 22),
                pw.Expanded(
                    // On passe la chaîne vide, pas le tiret : c'est `_ligne`
                    // qui pose le caractère de remplacement, et qui sait
                    // alors ne pas lui appliquer Courier.
                    child: _ligne('Réf. opérateur',
                        refOperateur.isEmpty ? '' : _court(refOperateur, 18),
                        mono: true)),
              ]),
              if (refOperateur.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.RichText(
                  text: pw.TextSpan(
                    style: const pw.TextStyle(fontSize: 8.5, color: _grisClair),
                    children: [
                      const pw.TextSpan(text: 'La '),
                      pw.TextSpan(
                          text: 'référence opérateur',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, color: _encre)),
                      const pw.TextSpan(
                          text: ' est celle qui figure dans le SMS de confirmation reçu '
                              'sur votre téléphone : les deux doivent correspondre.'),
                    ],
                  ),
                ),
              ],
            ]),
          ),

          pw.Spacer(),

          // ── VÉRIFICATION ───────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.only(top: 11),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: _trait)),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.RichText(
                text: pw.TextSpan(
                  style: const pw.TextStyle(fontSize: 10, color: _encre),
                  children: [
                    pw.TextSpan(
                        text: 'Ce reçu est consultable en ligne',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    const pw.TextSpan(
                        text: ' depuis votre espace Academia, rubrique '
                            '« Mes documents ».'),
                    // On ne promet une empreinte que si elle existe : les reçus
                    // émis avant le 02/09/2026 n'en ont pas.
                  ],
                ),
              ),
              if (empreinte.isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.Text(
                    'L\'empreinte ci-dessous permet de vérifier que ce document n\'a '
                    'pas été modifié.',
                    style: const pw.TextStyle(fontSize: 10, color: _encre)),
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: _fondBloc,
                    border: pw.Border.all(color: _trait),
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Text(_empreinteLisible(empreinte),
                      style: pw.TextStyle(
                          fontSize: 8.5, color: _gris, font: pw.Font.courier())),
                ),
              ],
            ]),
          ),

          // ── PIED ───────────────────────────────────────────────────────────
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: _trait)),
            ),
            child: pw.Column(children: [
              pw.Text(
                  '$raisonSociale · $villeEmetteur, $paysEmetteur · RCCM $rccm · IFU $ifu',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7.5, color: _grisPale)),
              pw.Text('Assistance : $telEmetteur · $emailEmetteur · $siteEmetteur',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7.5, color: _grisPale)),
              pw.SizedBox(height: 2),
              pw.RichText(
                textAlign: pw.TextAlign.center,
                text: pw.TextSpan(
                  style: const pw.TextStyle(fontSize: 7.5, color: _grisPale),
                  children: [
                    pw.TextSpan(
                        text: 'Ce document est un reçu de paiement.',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, color: _grisClair)),
                    const pw.TextSpan(
                        text: ' Il atteste d\'un versement encaissé et ne constitue pas '
                            'une facture normalisée au sens de la loi N°037/2013/AN.'),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    ),
  );

  // `jour` sert au titre du fichier partagé, pas au corps du document.
  debugPrint('[Recu] $numero composé le ${jour.format(DateTime.now())}');
  return document.save();
}

// ── Fragments de mise en page ────────────────────────────────────────────────

pw.Widget _petit(String t) =>
    pw.Text(t, style: const pw.TextStyle(fontSize: 8.5, color: _gris));

// Pas de Courier ici : « RÈGLEMENT » porte un È, et les Type1 intégrées ne
// garantissent rien hors ASCII. Le thème (Roboto) le dessine sans risque.
pw.Widget _intertitre(String t) => pw.Text(t,
    style: pw.TextStyle(
        fontSize: 7.5,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 1.1,
        color: _vert));

pw.Widget _encadre(String titre, List<pw.Widget> enfants) => pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _trait),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _intertitre(titre),
        pw.SizedBox(height: 7),
        ...enfants,
      ]),
    );

pw.Widget _cellule(String t,
        {bool gras = false,
        double taille = 10,
        PdfColor couleur = _encre,
        bool aDroite = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Text(t,
          textAlign: aDroite ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
              fontSize: taille,
              color: couleur,
              fontWeight: gras ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );

pw.Widget _ligne(String etiquette, String valeur, {bool mono = false}) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(etiquette, style: const pw.TextStyle(fontSize: 9, color: _grisClair)),
        pw.SizedBox(width: 8),
        // Courier n'est demandé que pour une VALEUR : elle est en ASCII
        // (dates, références, montants) et l'alignement chiffre à chiffre
        // aide à la recopier. Le tiret cadratin du champ vide, lui, n'existe
        // pas dans cette Type1 — il repasse donc par la police du document.
        pw.Flexible(
          child: pw.Text(valeur.isEmpty ? '—' : valeur,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  font: (mono && valeur.isNotEmpty) ? pw.Font.courier() : null)),
        ),
      ],
    );

// ── Petits utilitaires ───────────────────────────────────────────────────────

String _ouSinon(dynamic valeur, String secours) {
  final t = _texte(valeur).trim();
  return t.isEmpty ? secours : t;
}

String _court(String s, [int n = 8]) =>
    s.length <= n ? s.toUpperCase() : s.replaceAll('-', '').substring(0, n).toUpperCase();

String _dateOuTexte(dynamic v, DateFormat f) {
  if (v is DateTime) return f.format(v.toLocal());
  final p = DateTime.tryParse(_texte(v));
  return p != null ? f.format(p.toLocal()) : _texte(v);
}

num? _nombre(dynamic v) {
  if (v is num) return v;
  return num.tryParse(_texte(v));
}

/// 25000 → « 25 000 ». L'espace insécable étroit n'existe pas dans les polices
/// intégrées du PDF : on utilise une espace ordinaire.
String _millierEspace(num n) {
  final entier = n.round();
  final chiffres = entier.abs().toString();
  final morceaux = <String>[];
  for (var i = chiffres.length; i > 0; i -= 3) {
    morceaux.insert(0, chiffres.substring(i - 3 < 0 ? 0 : i - 3, i));
  }
  return '${entier < 0 ? '-' : ''}${morceaux.join(' ')}';
}

String _empreinteLisible(String h) {
  final s = h.length > 32 ? h.substring(0, 32) : h;
  final blocs = <String>[];
  for (var i = 0; i < s.length; i += 8) {
    blocs.add(s.substring(i, i + 8 > s.length ? s.length : i + 8));
  }
  return blocs.join('·');
}

String _libelleDeSecours(Map<String, dynamic> payment, Map<String, dynamic> receipt) {
  if (_texte(receipt['credit_pack_name']).isNotEmpty) return 'Achat de crédits';
  switch (_texte(payment['payment_reason'])) {
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
    default:
      return 'Prestation Academia';
  }
}

String _moyenDeSecours(Map<String, dynamic> payment) {
  final op = _texte(payment['ligdicash_operator']);
  if (op.isNotEmpty && op.toUpperCase() != 'RECONCILIATION_MANUELLE') {
    return 'Mobile money — ${_capitale(op)}';
  }
  switch (_texte(payment['channel'])) {
    case 'orange_money':
      return 'Orange Money';
    case 'moov_money':
      return 'Moov Money';
    case 'telecel_money':
      return 'Telecel Money';
    case 'cash':
      return 'Espèces';
    case 'bank_transfer':
      return 'Virement bancaire';
    case 'ligdicash':
      return 'Mobile money';
    default:
      return 'Non précisé';
  }
}

String _capitale(String s) => s
    .toLowerCase()
    .split(' ')
    .where((m) => m.isNotEmpty)
    .map((m) => '${m[0].toUpperCase()}${m.substring(1)}')
    .join(' ');

/// « Vingt-cinq mille francs CFA ». Les reçus de la zone OHADA portent le
/// montant en toutes lettres ; c'est ce qui fait foi en cas de rature.
String _enLettres(num montant, String devise) {
  final entier = montant.round().abs();
  final mots = _entierEnLettres(entier);
  final unite = devise.toUpperCase() == 'XOF'
      ? (entier > 1 ? 'francs CFA' : 'franc CFA')
      : devise.toUpperCase();
  return '${mots[0].toUpperCase()}${mots.substring(1)} $unite';
}

const _unites = [
  'zéro', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf',
  'dix', 'onze', 'douze', 'treize', 'quatorze', 'quinze', 'seize',
  'dix-sept', 'dix-huit', 'dix-neuf',
];
const _dizaines = {
  2: 'vingt', 3: 'trente', 4: 'quarante', 5: 'cinquante', 6: 'soixante',
};

String _sousCent(int n) {
  if (n < 20) return _unites[n];
  final d = n ~/ 10;
  final u = n % 10;
  if (d == 7) return n == 71 ? 'soixante et onze' : 'soixante-${_unites[10 + u]}';
  if (d == 8) return u == 0 ? 'quatre-vingts' : 'quatre-vingt-${_unites[u]}';
  if (d == 9) return 'quatre-vingt-${_unites[10 + u]}';
  final mot = _dizaines[d]!;
  if (u == 0) return mot;
  if (u == 1) return '$mot et un';
  return '$mot-${_unites[u]}';
}

String _sousMille(int n) {
  if (n < 100) return _sousCent(n);
  final c = n ~/ 100;
  final r = n % 100;
  if (r == 0) return c == 1 ? 'cent' : '${_unites[c]} cents';
  return c == 1 ? 'cent ${_sousCent(r)}' : '${_unites[c]} cent ${_sousCent(r)}';
}

String _entierEnLettres(int n) {
  if (n == 0) return 'zéro';
  final morceaux = <String>[];
  final milliards = n ~/ 1000000000;
  final millions = (n % 1000000000) ~/ 1000000;
  final milliers = (n % 1000000) ~/ 1000;
  final reste = n % 1000;
  if (milliards > 0) {
    morceaux.add(milliards == 1 ? 'un milliard' : '${_sousMille(milliards)} milliards');
  }
  if (millions > 0) {
    morceaux.add(millions == 1 ? 'un million' : '${_sousMille(millions)} millions');
  }
  if (milliers > 0) {
    // « mille » est invariable : jamais « deux milles ».
    morceaux.add(milliers == 1 ? 'mille' : '${_sousMille(milliers)} mille');
  }
  if (reste > 0) morceaux.add(_sousMille(reste));
  return morceaux.join(' ');
}
