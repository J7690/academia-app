import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../services/session_summary_service.dart';

/// Fiche de séance — consultation, publication et export PDF.
///
/// Un même écran sert l'enseignant et l'étudiant, mais pas avec le même
/// contenu ni les mêmes pouvoirs :
///
/// * l'enseignant voit la version `host`, avec les statistiques de
///   participation et les points à reprendre, et peut publier ;
/// * l'étudiant voit la version `student`, une fois publiée seulement.
class SessionSummaryScreen extends StatefulWidget {
  final String sessionId;
  final String sessionTitle;
  final bool isHost;

  const SessionSummaryScreen({
    super.key,
    required this.sessionId,
    required this.sessionTitle,
    required this.isHost,
  });

  @override
  State<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends State<SessionSummaryScreen> {
  static const _accent = Color(0xFF6C5CE7);
  static const _red = Color(0xFFE14D4D);
  static const _teal = Color(0xFF12B886);

  final _service = SessionSummaryService.instance;
  SummaryResult? _result;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    final result = await _service.load(
      widget.sessionId,
      audience: widget.isHost ? 'host' : 'student',
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _busy = false;
    });
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? _red : null),
    );
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    final error = await _service.generate(widget.sessionId);
    if (!mounted) return;
    if (error != null) {
      setState(() => _busy = false);
      _toast(error, error: true);
      return;
    }
    await _load();
    _toast('Fiche générée. Relisez-la avant de la publier.');
  }

  Future<void> _publish(bool publish) async {
    setState(() => _busy = true);
    final error = await _service.publish(widget.sessionId, publish: publish);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      _toast(error, error: true);
      return;
    }
    _toast(publish
        ? 'Fiche publiée — vos étudiants y ont accès.'
        : 'Fiche retirée de la vue des étudiants.');
    await _load();
  }

  // ─── Export PDF ─────────────────────────────────────────────────────

  Future<void> _exportPdf() async {
    final content = _result?.content;
    if (content == null || content.isEmpty) return;
    try {
      final doc = _buildPdf(content);
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: '${_safeFilename(widget.sessionTitle)}.pdf',
      );
    } catch (e) {
      _toast('Impossible de produire le PDF.', error: true);
    }
  }

  static String _safeFilename(String title) {
    final cleaned = title.replaceAll(RegExp(r'[^a-zA-Z0-9 \-_]'), '').trim();
    return cleaned.isEmpty ? 'fiche-de-seance' : cleaned.replaceAll(' ', '-');
  }

  pw.Document _buildPdf(Map<String, dynamic> c) {
    final doc = pw.Document();
    final seance = (c['seance'] as Map?)?.cast<String, dynamic>() ?? const {};
    // Le type est posé par la fonction de synthèse. On ne le devine pas :
    // une fiche pédagogique et un compte rendu d'orientation n'ont ni les
    // mêmes rubriques ni le même titre.
    final estOrientation = c['type'] == 'orientation';

    List<String> strings(String key) {
      final v = c[key];
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    List<Map<String, dynamic>> maps(String key) {
      final v = c[key];
      if (v is List) {
        return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
      return const [];
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 44, 40, 44),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Academia · page ${ctx.pageNumber} sur ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) => [
          pw.Text(
              estOrientation
                  ? 'Compte rendu d\'orientation'
                  : 'Fiche de séance',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text(seance['titre']?.toString() ?? widget.sessionTitle,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(
            [
              if (seance['theme'] != null) seance['theme'].toString(),
              if (seance['matiere'] != null) seance['matiere'].toString(),
              if (seance['conseiller'] != null) seance['conseiller'].toString(),
              if (seance['enseignant'] != null) seance['enseignant'].toString(),
              if (seance['duree_minutes'] != null)
                '${seance['duree_minutes']} minutes',
            ].join(' · '),
            style: const pw.TextStyle(fontSize: 10.5, color: PdfColors.grey700),
          ),
          pw.Divider(height: 26, color: PdfColors.grey300),

          if (c['resume'] != null) ...[
            _pdfHeading('Résumé'),
            pw.Text(c['resume'].toString(),
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 3)),
            pw.SizedBox(height: 18),
          ],

          // ── Sections propres à l'orientation ───────────────────────
          if (c['synthese'] != null) ...[
            _pdfHeading('Synthèse de l\'entretien'),
            pw.Text(c['synthese'].toString(),
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 3)),
            pw.SizedBox(height: 18),
          ],

          if (c['profil'] != null &&
              c['profil'].toString().trim().isNotEmpty) ...[
            _pdfHeading('Profil'),
            pw.Text(c['profil'].toString(),
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 3)),
            pw.SizedBox(height: 18),
          ],

          if (maps('pistes').isNotEmpty) ...[
            _pdfHeading('Pistes envisagées'),
            ...maps('pistes').map((m) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        [
                          m['filiere']?.toString() ?? '',
                          if ((m['etablissement']?.toString() ?? '').isNotEmpty)
                            m['etablissement'].toString(),
                        ].where((s) => s.isNotEmpty).join(' — '),
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                      if ((m['pourquoi']?.toString() ?? '').isNotEmpty)
                        pw.Text(m['pourquoi'].toString(),
                            style: const pw.TextStyle(
                                fontSize: 10.5, color: PdfColors.grey700)),
                    ],
                  ),
                )),
            pw.SizedBox(height: 18),
          ],

          if (maps('echeances').isNotEmpty) ...[
            _pdfHeading('Échéances'),
            ...maps('echeances').map((m) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text(
                    [
                      m['quoi']?.toString() ?? '',
                      if ((m['quand']?.toString() ?? '').isNotEmpty)
                        m['quand'].toString(),
                    ].where((s) => s.isNotEmpty).join(' — '),
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                )),
            pw.SizedBox(height: 18),
          ] else if (strings('echeances').isNotEmpty) ...[
            _pdfHeading('Échéances'),
            ...strings('echeances').map((s) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text('• $s', style: const pw.TextStyle(fontSize: 11)),
                )),
            pw.SizedBox(height: 18),
          ],

          if (strings('documents_a_reunir').isNotEmpty) ...[
            _pdfHeading('Documents à réunir'),
            ...strings('documents_a_reunir').map((s) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text('• $s', style: const pw.TextStyle(fontSize: 11)),
                )),
            pw.SizedBox(height: 18),
          ],

          if (strings('prochaines_etapes').isNotEmpty) ...[
            _pdfHeading('Prochaines étapes'),
            ...strings('prochaines_etapes').asMap().entries.map((e) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text('${e.key + 1}. ${e.value}',
                      style: const pw.TextStyle(fontSize: 11)),
                )),
            pw.SizedBox(height: 18),
          ],

          if (strings('points_de_vigilance').isNotEmpty) ...[
            _pdfHeading('Points de vigilance'),
            ...strings('points_de_vigilance').map((s) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text('• $s', style: const pw.TextStyle(fontSize: 11)),
                )),
            pw.SizedBox(height: 18),
          ],

          if (strings('plan').isNotEmpty) ...[
            _pdfHeading('Plan de la séance'),
            ...strings('plan').asMap().entries.map((e) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text('${e.key + 1}. ${e.value}',
                      style: const pw.TextStyle(fontSize: 11)),
                )),
            pw.SizedBox(height: 18),
          ],

          if (maps('concepts').isNotEmpty) ...[
            _pdfHeading('Concepts clés'),
            ...maps('concepts').map((m) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 7),
                  child: pw.RichText(
                    text: pw.TextSpan(children: [
                      pw.TextSpan(
                          text: '${m['terme']} — ',
                          style: pw.TextStyle(
                              fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.TextSpan(
                          text: m['definition']?.toString() ?? '',
                          style: const pw.TextStyle(fontSize: 11)),
                    ]),
                  ),
                )),
            pw.SizedBox(height: 18),
          ],

          if (maps('questions').isNotEmpty) ...[
            _pdfHeading('Questions posées en séance'),
            ...maps('questions').map((m) {
              final reponse = m['reponse']?.toString().trim() ?? '';
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.only(left: 9),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      left: pw.BorderSide(color: PdfColors.grey400, width: 2)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('${m['auteur'] ?? 'Participant'} : ${m['question']}',
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      reponse.isEmpty
                          ? 'Restée sans réponse pendant la séance.'
                          : reponse,
                      style: pw.TextStyle(
                        fontSize: 10.5,
                        color: reponse.isEmpty
                            ? PdfColors.orange700
                            : PdfColors.grey800,
                        fontStyle:
                            reponse.isEmpty ? pw.FontStyle.italic : null,
                      ),
                    ),
                  ],
                ),
              );
            }),
            pw.SizedBox(height: 18),
          ],

          if (strings('a_retenir').isNotEmpty) ...[
            _pdfHeading('À retenir'),
            ...strings('a_retenir').map((s) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text('· $s',
                      style: const pw.TextStyle(fontSize: 11)),
                )),
            pw.SizedBox(height: 18),
          ],

          if (strings('pour_aller_plus_loin').isNotEmpty) ...[
            _pdfHeading('Pour aller plus loin'),
            ...strings('pour_aller_plus_loin').map((s) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text('· $s',
                      style: const pw.TextStyle(fontSize: 11)),
                )),
          ],

          pw.SizedBox(height: 26),
          pw.Text(
            'Document généré automatiquement à partir des échanges de la séance, '
            'puis relu par l\'enseignant.',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
          ),
        ],
      ),
    );
    return doc;
  }

  static pw.Widget _pdfHeading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 7),
        child: pw.Text(text.toUpperCase(),
            style: pw.TextStyle(
                fontSize: 9.5,
                letterSpacing: 0.6,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700)),
      );

  // ─── Rendu ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final r = _result;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('Fiche de séance'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        actions: [
          if (r != null && r.hasContent)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Télécharger en PDF',
              onPressed: _exportPdf,
            ),
        ],
      ),
      body: _busy && r == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  Text(widget.sessionTitle,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 14),
                  if (r == null)
                    const SizedBox.shrink()
                  else if (r.error != null)
                    _Card(child: Text(r.error!, style: const TextStyle(color: _red)))
                  else if (r.neverGenerated)
                    _EmptyState(
                      icon: Icons.auto_awesome_outlined,
                      title: widget.isHost
                          ? 'Aucune fiche pour cette séance'
                          : 'La fiche n\'est pas encore disponible',
                      body: widget.isHost
                          ? 'Générez la fiche à partir des échanges, des questions '
                              'posées et du déroulé de la séance.'
                          : 'Votre enseignant n\'a pas encore publié la fiche de '
                              'cette séance. Vous serez prévenu dès qu\'elle sera prête.',
                      action: widget.isHost
                          ? FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  backgroundColor: _accent),
                              onPressed: _busy ? null : _generate,
                              icon: const Icon(Icons.auto_awesome, size: 18),
                              label: const Text('Générer la fiche'),
                            )
                          : null,
                    )
                  else if (r.awaitingPublication)
                    const _EmptyState(
                      icon: Icons.hourglass_empty,
                      title: 'Fiche en cours de relecture',
                      body: 'Votre enseignant relit la fiche avant de la publier.',
                    )
                  else ...[
                    if (widget.isHost) _publicationBanner(r),
                    ..._sections(r.content),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: _exportPdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: const Text('Télécharger en PDF'),
                    ),
                    if (r.modelUsed != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Généré automatiquement à partir des échanges de la séance, '
                        'puis relu par l\'enseignant.',
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  Widget _publicationBanner(SummaryResult r) {
    final published = r.isPublished;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: published
            ? _teal.withValues(alpha: 0.08)
            : const Color(0xFFF0A020).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(published ? Icons.check_circle_outline : Icons.visibility_off_outlined,
              size: 20, color: published ? _teal : const Color(0xFFB07510)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              published
                  ? 'Publiée — vos étudiants y ont accès.'
                  : 'Non publiée — relisez-la, corrigez si besoin, puis publiez.',
              style: TextStyle(
                  fontSize: 13,
                  color: published ? const Color(0xFF0F7A57) : const Color(0xFF7A5510)),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _busy ? null : () => _publish(!published),
            child: Text(published ? 'Retirer' : 'Publier'),
          ),
        ],
      ),
    );
  }

  /// Une rubrique à puces. Beaucoup de sections d'orientation ont cette forme ;
  /// les écrire une à une aurait multiplié le même bloc cinq fois.
  List<Widget> _liste(String titre, List<String> entrees) => [
        _Heading(titre),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entrees
                .map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ',
                              style: TextStyle(fontSize: 13.5, height: 1.5)),
                          Expanded(
                            child: Text(s,
                                style: const TextStyle(
                                    fontSize: 13.5, height: 1.5)),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ];

  List<Widget> _sections(Map<String, dynamic> c) {
    List<String> strings(String key) {
      final v = c[key];
      return v is List ? v.map((e) => e.toString()).toList() : const [];
    }

    List<Map<String, dynamic>> maps(String key) {
      final v = c[key];
      return v is List
          ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
          : const [];
    }

    final stats = (c['statistiques'] as Map?)?.cast<String, dynamic>();
    final estOrientation = c['type'] == 'orientation';

    return [
      if (stats != null) ...[
        _Heading(estOrientation ? 'Suivi de l\'entretien' : 'Suivi de la séance'),
        _Card(
          // Wrap : les indicateurs passent à la ligne au lieu de déborder
          // sur les écrans étroits.
          child: Wrap(
            spacing: 20,
            runSpacing: 12,
            children: estOrientation
                ? [
                    _Stat(
                        label: 'Pistes',
                        value: '${stats['pistes_identifiees'] ?? 0}'),
                    _Stat(
                        label: 'Échéances', value: '${stats['echeances'] ?? 0}'),
                    _Stat(
                        label: 'Étapes',
                        value: '${stats['etapes_a_suivre'] ?? 0}'),
                    _Stat(
                        label: 'Messages',
                        value: '${stats['messages_echanges'] ?? 0}'),
                  ]
                : [
                    _Stat(
                        label: 'Participants',
                        value: '${stats['participants'] ?? 0}'),
                    _Stat(
                        label: 'Messages',
                        value: '${stats['messages_echanges'] ?? 0}'),
                    _Stat(
                        label: 'Questions',
                        value: '${stats['questions_posees'] ?? 0}'),
                    _Stat(
                      label: 'Sans réponse',
                      value: '${stats['questions_sans_reponse'] ?? 0}',
                      highlight: (stats['questions_sans_reponse'] ?? 0) != 0,
                    ),
                  ],
          ),
        ),
      ],
      if (c['resume'] != null) ...[
        const _Heading('Résumé'),
        _Card(
          child: Text(c['resume'].toString(),
              style: const TextStyle(fontSize: 14, height: 1.6)),
        ),
      ],

      // ── Sections propres à l'orientation ─────────────────────────────
      if (c['synthese'] != null) ...[
        const _Heading('Synthèse de l\'entretien'),
        _Card(
          child: Text(c['synthese'].toString(),
              style: const TextStyle(fontSize: 14, height: 1.6)),
        ),
      ],
      if ((c['profil']?.toString() ?? '').trim().isNotEmpty) ...[
        const _Heading('Profil'),
        _Card(
          child: Text(c['profil'].toString(),
              style: const TextStyle(fontSize: 13.5, height: 1.55)),
        ),
      ],
      if (maps('pistes').isNotEmpty) ...[
        const _Heading('Pistes envisagées'),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: maps('pistes')
                .map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [
                              m['filiere']?.toString() ?? '',
                              if ((m['etablissement']?.toString() ?? '')
                                  .isNotEmpty)
                                m['etablissement'].toString(),
                            ].where((s) => s.isNotEmpty).join(' — '),
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                          if ((m['pourquoi']?.toString() ?? '').isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(m['pourquoi'].toString(),
                                style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: Color(0xFF5C6270))),
                          ],
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
      if (maps('echeances').isNotEmpty) ...[
        const _Heading('Échéances'),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: maps('echeances')
                .map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Text(
                        [
                          m['quoi']?.toString() ?? '',
                          if ((m['quand']?.toString() ?? '').isNotEmpty)
                            m['quand'].toString(),
                        ].where((s) => s.isNotEmpty).join(' — '),
                        style: const TextStyle(fontSize: 13.5, height: 1.5),
                      ),
                    ))
                .toList(),
          ),
        ),
      ] else if (strings('echeances').isNotEmpty)
        ..._liste('Échéances', strings('echeances')),
      if (strings('documents_a_reunir').isNotEmpty)
        ..._liste('Documents à réunir', strings('documents_a_reunir')),
      if (strings('prochaines_etapes').isNotEmpty) ...[
        const _Heading('Prochaines étapes'),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: strings('prochaines_etapes')
                .asMap()
                .entries
                .map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Text('${e.key + 1}. ${e.value}',
                          style: const TextStyle(fontSize: 13.5, height: 1.5)),
                    ))
                .toList(),
          ),
        ),
      ],
      if (strings('points_de_vigilance').isNotEmpty)
        ..._liste('Points de vigilance', strings('points_de_vigilance')),
      if (strings('plan').isNotEmpty) ...[
        const _Heading('Plan de la séance'),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: strings('plan')
                .asMap()
                .entries
                .map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Text('${e.key + 1}. ${e.value}',
                          style: const TextStyle(fontSize: 13.5, height: 1.5)),
                    ))
                .toList(),
          ),
        ),
      ],
      if (maps('concepts').isNotEmpty) ...[
        const _Heading('Concepts clés'),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: maps('concepts')
                .map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.5,
                              color: Color(0xFF14161A)),
                          children: [
                            TextSpan(
                                text: '${m['terme']} — ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            TextSpan(text: m['definition']?.toString() ?? ''),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
      if (maps('questions').isNotEmpty) ...[
        const _Heading('Questions posées'),
        ...maps('questions').map((m) {
          final reponse = m['reponse']?.toString().trim() ?? '';
          return _Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${m['auteur'] ?? 'Participant'} : ${m['question']}',
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  reponse.isEmpty
                      ? 'Restée sans réponse pendant la séance.'
                      : reponse,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: reponse.isEmpty
                        ? const Color(0xFFB07510)
                        : const Color(0xFF5C6270),
                    fontStyle: reponse.isEmpty ? FontStyle.italic : null,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
      if (strings('a_reprendre').isNotEmpty) ...[
        const _Heading('À reprendre au prochain cours'),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: strings('a_reprendre')
                .map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('· $s',
                          style: const TextStyle(fontSize: 13.5, height: 1.5)),
                    ))
                .toList(),
          ),
        ),
      ],
      if (strings('a_retenir').isNotEmpty) ...[
        const _Heading('À retenir'),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: strings('a_retenir')
                .map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('· $s',
                          style: const TextStyle(fontSize: 13.5, height: 1.5)),
                    ))
                .toList(),
          ),
        ),
      ],
      if (strings('pour_aller_plus_loin').isNotEmpty) ...[
        const _Heading('Pour aller plus loin'),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: strings('pour_aller_plus_loin')
                .map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('· $s',
                          style: const TextStyle(fontSize: 13.5, height: 1.5)),
                    ))
                .toList(),
          ),
        ),
      ],
    ];
  }
}

// ─── Composants ───────────────────────────────────────────────────────

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF8A90A0),
          ),
        ),
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets? margin;
  const _Card({required this.child, this.margin});

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E5EA)),
        ),
        child: child,
      );
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _Stat(
      {required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 9.5,
                  letterSpacing: 0.4,
                  color: Color(0xFF8A90A0))),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  color: highlight
                      ? const Color(0xFFF0A020)
                      : const Color(0xFF14161A))),
        ],
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, size: 42, color: const Color(0xFF8A90A0)),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 7),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13.5, height: 1.5, color: Color(0xFF5C6270))),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      );
}
