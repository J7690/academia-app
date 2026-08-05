import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/orientation_provider.dart';
import '../../theme/academia_palette.dart';

/// La fiche d'orientation, vue par l'élève. Lecture seule.
///
/// POURQUOI CE FICHIER EXISTE. En retirant `orientation_screen.dart`, on a
/// retiré `_RecordSheet`, qui servait aux DEUX rôles : le conseiller (avec
/// `canEdit: true`) et l'élève (`canEdit: false`). Le conseiller a récupéré son
/// remplaçant dans `counselor_sheets.dart` ; l'élève, lui, n'a rien eu. Sa
/// carte « Fiche du 12/03 » a alors été câblée sur `SessionSummaryScreen` —
/// qui affiche le **compte rendu de séance** produit par l'IA, un tout autre
/// document, généré uniquement si l'hôte appuie sur un bouton. La carte
/// apparaissait donc parce que le conseiller avait rédigé la fiche
/// d'orientation, et ouvrait un écran vide alimenté par autre chose.
///
/// Cette feuille rétablit le lien : la carte annonce la fiche d'orientation,
/// et c'est la fiche d'orientation qui s'ouvre.
class StudentRecordSheet extends StatefulWidget {
  const StudentRecordSheet({
    super.key,
    required this.bookingId,
    this.conseiller,
    this.quand,
  });

  final String bookingId;
  final String? conseiller;
  final DateTime? quand;

  @override
  State<StudentRecordSheet> createState() => _StudentRecordSheetState();
}

class _StudentRecordSheetState extends State<StudentRecordSheet> {
  @override
  void initState() {
    super.initState();
    // `loadRecord` remet l'état à zéro avant l'appel : ouvrir une fiche puis
    // une autre ne peut plus afficher le contenu de la précédente.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<OrientationProvider>().loadRecord(widget.bookingId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrientationProvider>();
    final statut = p.recordStatus;
    final contenu = (p.record?['content'] as Map?)?.cast<String, dynamic>();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: AcademiaPalette.surfaceAlt,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          children: [
            _poignee(),
            _entete(),
            const SizedBox(height: 14),
            if (statut == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: AcademiaPalette.teal),
                ),
              )
            else if (statut == 'disponible' && contenu != null)
              ..._contenu(contenu)
            else
              _absence(statut),
          ],
        ),
      ),
    );
  }

  Widget _poignee() => Center(
        child: Container(
          width: 38,
          height: 4,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: AcademiaPalette.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _entete() {
    final quand = widget.quand?.toLocal();
    final sousTitre = [
      if (widget.conseiller != null && widget.conseiller!.isNotEmpty)
        widget.conseiller!,
      if (quand != null) 'entretien du ${quand.day}/${quand.month}',
    ].join(' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Fiche d'orientation",
                style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: AcademiaPalette.ink),
              ),
              if (sousTitre.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(sousTitre,
                    style: const TextStyle(
                        fontSize: 11.5, color: AcademiaPalette.muted)),
              ],
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: AcademiaPalette.muted),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  /// Trois absences, trois messages. Les confondre, c'est laisser l'élève
  /// devant un écran vide sans savoir s'il doit attendre ou s'inquiéter.
  Widget _absence(String statut) {
    final (IconData icone, String titre, String corps) = switch (statut) {
      'en_redaction' => (
          Icons.edit_note_outlined,
          'Fiche en cours de rédaction',
          'Ton conseiller la partagera dès qu’elle sera prête. Tu la '
              'retrouveras ici, et elle restera consultable.',
        ),
      'erreur' => (
          Icons.wifi_off_outlined,
          'Fiche momentanément indisponible',
          'La fiche n’a pas pu être chargée. Vérifie ta connexion, puis '
              'referme et rouvre cette page.',
        ),
      _ => (
          Icons.description_outlined,
          'Pas encore de fiche',
          'Ton conseiller n’a pas encore rédigé de fiche pour cet entretien.',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      decoration: BoxDecoration(
        color: AcademiaPalette.surface,
        borderRadius: BorderRadius.circular(AcademiaPalette.rLg),
        border: Border.all(color: AcademiaPalette.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AcademiaPalette.teal.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icone, size: 26, color: AcademiaPalette.teal),
          ),
          const SizedBox(height: 14),
          Text(titre,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AcademiaPalette.ink)),
          const SizedBox(height: 7),
          Text(corps,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12.5, height: 1.5, color: AcademiaPalette.muted)),
        ],
      ),
    );
  }

  List<Widget> _contenu(Map<String, dynamic> c) {
    final profil = c['profil']?.toString().trim() ?? '';
    final pistes = (c['pistes'] as List?)?.whereType<Map>().toList() ?? const [];
    final echeances = _liste(c['echeances']);
    final etapes = _liste(c['prochaines_etapes']);
    final notes = c['notes']?.toString().trim() ?? '';

    final blocs = <Widget>[
      if (profil.isNotEmpty) ...[
        const _Titre('Synthèse du profil'),
        _Carte(child: _Paragraphe(profil)),
      ],
      if (pistes.isNotEmpty) ...[
        const _Titre('Pistes proposées'),
        for (final piste in pistes) _pisteCarte(piste.cast<String, dynamic>()),
      ],
      if (etapes.isNotEmpty) ...[
        const _Titre('Prochaines étapes'),
        _Carte(child: _Puces(etapes, numerotee: true)),
      ],
      if (echeances.isNotEmpty) ...[
        const _Titre('Échéances à retenir'),
        _Carte(child: _Puces(echeances)),
      ],
      if (notes.isNotEmpty) ...[
        const _Titre('Notes du conseiller'),
        _Carte(child: _Paragraphe(notes)),
      ],
    ];

    // Une fiche partagée mais vide de tout contenu est possible : le conseiller
    // a pu partager avant d'écrire. Mieux vaut le dire que rendre une page
    // blanche.
    if (blocs.isEmpty) return [_absence('en_redaction')];
    return blocs;
  }

  Widget _pisteCarte(Map<String, dynamic> p) {
    final titre = p['titre']?.toString().trim() ?? '';
    final argumentaire = p['argumentaire']?.toString().trim() ?? '';
    final etablissements = p['etablissements']?.toString().trim() ?? '';
    final cout = p['cout']?.toString().trim() ?? '';
    if (titre.isEmpty && argumentaire.isEmpty) return const SizedBox.shrink();

    return _Carte(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titre.isNotEmpty)
            Text(titre,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AcademiaPalette.ink)),
          if (argumentaire.isNotEmpty) ...[
            const SizedBox(height: 6),
            _Paragraphe(argumentaire),
          ],
          if (etablissements.isNotEmpty) ...[
            const SizedBox(height: 9),
            _Ligne(icone: Icons.school_outlined, texte: etablissements),
          ],
          if (cout.isNotEmpty) ...[
            const SizedBox(height: 6),
            _Ligne(icone: Icons.payments_outlined, texte: cout),
          ],
        ],
      ),
    );
  }

  static List<String> _liste(dynamic v) {
    if (v is List) {
      return v.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
    }
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? const [] : [s];
  }
}

// ─── Briques d'affichage ──────────────────────────────────────────────────

class _Titre extends StatelessWidget {
  const _Titre(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 7),
        child: Text(texte.toUpperCase(),
            style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
                color: AcademiaPalette.faint)),
      );
}

class _Carte extends StatelessWidget {
  const _Carte({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AcademiaPalette.surface,
          borderRadius: BorderRadius.circular(AcademiaPalette.rLg),
          border: Border.all(color: AcademiaPalette.border),
        ),
        child: child,
      );
}

class _Paragraphe extends StatelessWidget {
  const _Paragraphe(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => Text(texte,
      style: const TextStyle(
          fontSize: 13, height: 1.55, color: AcademiaPalette.text));
}

class _Puces extends StatelessWidget {
  const _Puces(this.elements, {this.numerotee = false});
  final List<String> elements;
  final bool numerotee;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < elements.length; i++)
            Padding(
              padding: EdgeInsets.only(
                  bottom: i == elements.length - 1 ? 0 : 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 19,
                    height: 19,
                    alignment: Alignment.center,
                    margin: const EdgeInsets.only(top: 1, right: 9),
                    decoration: BoxDecoration(
                      color: AcademiaPalette.teal.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: numerotee
                        ? Text('${i + 1}',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AcademiaPalette.teal))
                        : const Icon(Icons.circle,
                            size: 6, color: AcademiaPalette.teal),
                  ),
                  Expanded(child: _Paragraphe(elements[i])),
                ],
              ),
            ),
        ],
      );
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.icone, required this.texte});
  final IconData icone;
  final String texte;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 15, color: AcademiaPalette.faint),
          const SizedBox(width: 7),
          Expanded(
            child: Text(texte,
                style: const TextStyle(
                    fontSize: 12, height: 1.45, color: AcademiaPalette.muted)),
          ),
        ],
      );
}
