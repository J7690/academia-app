import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/academia_session_provider.dart';
import '../../providers/orientation_provider.dart';
import '../live/academia_classroom_screen.dart';
import '../live/session_summary_screen.dart';
import 'orientation_theme.dart';

/// Les séances que le conseiller ouvre lui-même.
///
/// Deux formats, et la distinction n'est pas cosmétique :
///
/// * **Entretien individuel** — deux places, main levée sans objet, profil
///   LiveKit « consultation ». C'est le rendez-vous hors réservation : un
///   élève rappelé, une séance de rattrapage après une coupure.
/// * **Séance collective** — de 3 à 200 places, main levée activée.
///   « Choisir sa filière après le bac », « Les dossiers de bourse ».
///
/// Le cycle de vie est celui du studio commun : brouillon → programmée →
/// en cours → terminée. Rien n'est redéveloppé ici, `AcademiaSessionProvider`
/// s'appuie sur `host_id` et le conseiller est l'hôte.
class CounselorSessionsTab extends StatefulWidget {
  const CounselorSessionsTab({super.key});

  @override
  State<CounselorSessionsTab> createState() => _CounselorSessionsTabState();
}

class _CounselorSessionsTabState extends State<CounselorSessionsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<OrientationProvider>().loadMySessions(),
    );
  }

  void _message(String texte, {bool erreur = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texte),
      backgroundColor: erreur ? OrientationTheme.red : null,
    ));
  }

  Future<void> _ouvrirFormulaire({Map<String, dynamic>? existante}) async {
    final enregistree = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CounselorSessionForm(existante: existante),
    );
    if (enregistree == true) _message('Séance enregistrée.');
  }

  Future<void> _changerStatut(Map<String, dynamic> s, String statut) async {
    final sessions = context.read<AcademiaSessionProvider>();
    final ok = await sessions.setSessionStatus(s['id'].toString(), statut);
    if (!mounted) return;
    if (!ok) {
      _message(sessions.error ?? 'Changement de statut impossible.',
          erreur: true);
      return;
    }
    await context.read<OrientationProvider>().loadMySessions();
    if (!mounted) return;
    _message(statut == 'scheduled'
        ? 'Séance publiée : les élèves la voient dans leur onglet Lives.'
        : 'Séance annulée.');
  }

  Future<void> _demarrer(Map<String, dynamic> s) async {
    final sessions = context.read<AcademiaSessionProvider>();
    final id = s['id'].toString();
    final session = await sessions.getSession(id);
    if (!mounted) return;
    if (session == null) {
      _message(sessions.error ?? 'Salle introuvable.', erreur: true);
      return;
    }
    // Déjà en cours : on rejoint sans redémarrer, pour ne pas écraser
    // l'horodatage de début réel.
    if (s['status'] != 'running') {
      final res = await sessions.startSession(id);
      if (!mounted) return;
      if (res == null) {
        _message(sessions.error ?? 'Impossible de démarrer la séance.',
            erreur: true);
        return;
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AcademiaClassroomScreen(session: session, isHost: true),
    ));
    if (!mounted) return;
    await context.read<OrientationProvider>().loadMySessions();
  }

  Future<void> _compteRendu(Map<String, dynamic> s) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SessionSummaryScreen(
        sessionId: s['id'].toString(),
        sessionTitle: s['title']?.toString() ?? 'Entretien d\'orientation',
        isHost: true,
      ),
    ));
  }

  Future<void> _terminer(Map<String, dynamic> s) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminer la séance ?'),
        content: const Text(
          'La salle sera fermée pour tous les participants. Une fiche de '
          'séance pourra ensuite être générée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    final sessions = context.read<AcademiaSessionProvider>();
    final orientation = context.read<OrientationProvider>();
    final ok = await sessions.endSession(s['id'].toString());
    if (!mounted) return;
    if (!ok) {
      _message(sessions.error ?? 'Impossible de terminer la séance.',
          erreur: true);
      return;
    }
    // La clôture métier suit la fermeture technique : c'est elle qui crédite
    // le conseiller au nombre de participants réellement entrés.
    final erreur = await orientation.closeSession(s['id'].toString());
    if (!mounted) return;
    if (erreur != null) {
      _message('Séance terminée, mais la rémunération a échoué : $erreur',
          erreur: true);
      return;
    }
    _message('Séance terminée et créditée.');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrientationProvider>(
      builder: (context, p, _) {
        final seances = p.mySessions;
        return Scaffold(
          backgroundColor: OrientationTheme.background,
          body: RefreshIndicator(
            onRefresh: p.loadMySessions,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
              children: [
                const _Intro(),
                const SizedBox(height: 14),
                if (seances.isEmpty)
                  const _Vide()
                else
                  ...seances.map((s) => _CarteSeance(
                        seance: s,
                        onModifier: () => _ouvrirFormulaire(existante: s),
                        onPublier: () => _changerStatut(s, 'scheduled'),
                        onAnnuler: () => _changerStatut(s, 'cancelled'),
                        onDemarrer: () => _demarrer(s),
                        onTerminer: () => _terminer(s),
                        onCompteRendu: () => _compteRendu(s),
                      )),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _ouvrirFormulaire(),
            backgroundColor: OrientationTheme.accent,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle séance'),
          ),
        );
      },
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: OrientationTheme.cardDecoration,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vos séances',
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text(
            'Vous n\'êtes plus obligé d\'attendre qu\'un élève réserve. Ouvrez '
            'un entretien individuel hors rendez-vous, ou une séance '
            'collective sur un thème — les élèves la verront dans leur onglet '
            'Lives dès que vous l\'aurez publiée.',
            style: TextStyle(
                fontSize: 13, height: 1.5, color: OrientationTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      decoration: OrientationTheme.cardDecoration,
      child: const Column(
        children: [
          Icon(Icons.video_call_outlined,
              size: 38, color: OrientationTheme.textMuted),
          SizedBox(height: 12),
          Text(
            'Aucune séance pour l\'instant',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6),
          Text(
            'Créez votre première séance avec le bouton en bas de l\'écran.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, height: 1.5, color: OrientationTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _CarteSeance extends StatelessWidget {
  final Map<String, dynamic> seance;
  final VoidCallback onModifier;
  final VoidCallback onPublier;
  final VoidCallback onAnnuler;
  final VoidCallback onDemarrer;
  final VoidCallback onTerminer;

  /// Compte rendu de l'entretien. Une séance close n'était qu'une impasse :
  /// « Séance close », et rien d'autre. C'est pourtant le moment où le
  /// conseiller a le plus besoin de la fiche — pour la relire et la partager
  /// avec l'élève.
  final VoidCallback onCompteRendu;

  const _CarteSeance({
    required this.seance,
    required this.onModifier,
    required this.onPublier,
    required this.onAnnuler,
    required this.onDemarrer,
    required this.onTerminer,
    required this.onCompteRendu,
  });

  static const _statuts = <String, (String, Color)>{
    'draft': ('Brouillon', OrientationTheme.textMuted),
    'scheduled': ('Programmée', OrientationTheme.accent),
    'running': ('En cours', OrientationTheme.teal),
    'ended': ('Terminée', OrientationTheme.textSecondary),
    'cancelled': ('Annulée', OrientationTheme.red),
  };

  @override
  Widget build(BuildContext context) {
    final statut = seance['status']?.toString() ?? 'draft';
    final (libelle, couleur) =
        _statuts[statut] ?? ('Inconnu', OrientationTheme.textMuted);
    final collective = seance['format'] == 'collective';
    final estUnRdv = seance['est_un_rdv'] == true;
    final debut = seance['scheduled_start'] != null
        ? DateTime.tryParse(seance['scheduled_start'].toString())?.toLocal()
        : null;
    final tarif = (seance['tarif_place'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: OrientationTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                collective ? Icons.groups_outlined : Icons.person_outline,
                size: 20,
                color: OrientationTheme.accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  seance['title']?.toString() ?? 'Sans titre',
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.3),
                ),
              ),
              const SizedBox(width: 8),
              _Etiquette(libelle, couleur),
            ],
          ),
          if ((seance['description']?.toString() ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              seance['description'].toString(),
              style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: OrientationTheme.textSecondary),
            ),
          ],
          const SizedBox(height: 10),
          // Wrap plutôt que Row : sur un écran étroit les compteurs passent à
          // la ligne au lieu de déborder.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Puce(collective ? 'Collective' : 'Individuelle'),
              if (debut != null) _Puce(OrientationLabels.dateComplete(debut)),
              _Puce('${seance['duree_minutes'] ?? 45} min'),
              _Puce('${seance['inscrits'] ?? 0}/${seance['max_participants'] ?? 2} inscrits'),
              if (tarif > 0) _Puce('${OrientationLabels.montant(tarif)} FCFA / place'),
              if (seance['tableau'] == true) _Puce('Tableau'),
              if (seance['enregistrement'] == true) _Puce('Enregistrée'),
              if (estUnRdv) _Puce('Issue d\'un rendez-vous'),
            ],
          ),
          const SizedBox(height: 12),
          // Les actions aussi : un Wrap évite l'overflow quand elles sont
          // nombreuses sur un petit écran.
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.end,
            children: _actions(estUnRdv, statut),
          ),
        ],
      ),
    );
  }

  List<Widget> _actions(bool estUnRdv, String statut) {
    // Une séance née d'un rendez-vous se pilote depuis l'onglet
    // Consultations : on n'offre pas deux chemins pour la même chose.
    if (estUnRdv) {
      return [
        const Text(
          'Pilotée depuis l\'onglet Consultations',
          style: TextStyle(fontSize: 12, color: OrientationTheme.textMuted),
        ),
      ];
    }
    return switch (statut) {
      'draft' => [
          _Action('Modifier', Icons.edit_outlined, onModifier),
          _Action('Publier', Icons.publish_outlined, onPublier,
              principal: true),
        ],
      'scheduled' => [
          _Action('Modifier', Icons.edit_outlined, onModifier),
          _Action('Annuler', Icons.close, onAnnuler, danger: true),
          _Action('Démarrer', Icons.play_arrow, onDemarrer, principal: true),
        ],
      'running' => [
          _Action('Terminer', Icons.stop_circle_outlined, onTerminer,
              danger: true),
          _Action('Rejoindre', Icons.login, onDemarrer, principal: true),
        ],
      'ended' => [
          _Action('Compte rendu', Icons.description_outlined, onCompteRendu,
              principal: true),
        ],
      _ => const [
          Text(
            'Séance close',
            style: TextStyle(fontSize: 12, color: OrientationTheme.textMuted),
          ),
        ],
    };
  }
}

class _Action extends StatelessWidget {
  final String libelle;
  final IconData icone;
  final VoidCallback onTap;
  final bool principal;
  final bool danger;

  const _Action(this.libelle, this.icone, this.onTap,
      {this.principal = false, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final couleur = danger
        ? OrientationTheme.red
        : principal
            ? Colors.white
            : OrientationTheme.textSecondary;
    final enfant = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 16, color: couleur),
        const SizedBox(width: 5),
        Text(libelle,
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600, color: couleur)),
      ],
    );
    return Material(
      color: principal ? OrientationTheme.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: enfant,
        ),
      ),
    );
  }
}

class _Etiquette extends StatelessWidget {
  final String texte;
  final Color couleur;
  const _Etiquette(this.texte, this.couleur);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        texte,
        style: TextStyle(
            fontSize: 11.5, fontWeight: FontWeight.w700, color: couleur),
      ),
    );
  }
}

class _Puce extends StatelessWidget {
  final String texte;
  const _Puce(this.texte);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: OrientationTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: OrientationTheme.border),
      ),
      child: Text(texte,
          style: const TextStyle(
              fontSize: 11.5, color: OrientationTheme.textSecondary)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Formulaire
// ─────────────────────────────────────────────────────────────────────────

/// Feuille de création / modification d'une séance d'orientation.
///
/// Les champs ne sont volontairement pas ceux du formulaire enseignant :
/// pas de matière ni de type de concours, mais un thème d'orientation, un
/// niveau visé et un format.
class CounselorSessionForm extends StatefulWidget {
  final Map<String, dynamic>? existante;
  const CounselorSessionForm({super.key, this.existante});

  @override
  State<CounselorSessionForm> createState() => _CounselorSessionFormState();
}

class _CounselorSessionFormState extends State<CounselorSessionForm> {
  late final TextEditingController _titre;
  late final TextEditingController _description;
  late final TextEditingController _places;
  late final TextEditingController _tarif;

  String _format = 'individuelle';
  String? _theme;
  String? _niveau;
  DateTime? _quand;
  int _duree = 45;
  bool _tableau = true;
  bool _enregistrement = false;
  bool _enCours = false;
  String? _erreur;

  static const _themes = <String, String>{
    'filieres': 'Choix de filière',
    'bourses': 'Bourses et financements',
    'concours': 'Concours et sélections',
    'etudes_etranger': 'Études à l\'étranger',
    'reconversion': 'Reconversion',
    'methode': 'Méthode et organisation',
  };

  static const _durees = [15, 30, 45, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    final e = widget.existante;
    _titre = TextEditingController(text: e?['title']?.toString() ?? '');
    _description =
        TextEditingController(text: e?['description']?.toString() ?? '');
    _places = TextEditingController(
        text: (e?['max_participants'] as num?)?.toInt().toString() ?? '30');
    _tarif = TextEditingController(
        text: (e?['tarif_place'] as num?)?.toInt().toString() ?? '0');
    if (e != null) {
      _format = e['format']?.toString() ?? 'individuelle';
      _theme = _themes.containsKey(e['theme']) ? e['theme'].toString() : null;
      _niveau = OrientationLabels.niveaux.containsKey(e['niveau'])
          ? e['niveau'].toString()
          : null;
      _duree = (e['duree_minutes'] as num?)?.toInt() ?? 45;
      _tableau = e['tableau'] != false;
      _enregistrement = e['enregistrement'] == true;
      final d = e['scheduled_start'];
      if (d != null) _quand = DateTime.tryParse(d.toString())?.toLocal();
    }
  }

  @override
  void dispose() {
    _titre.dispose();
    _description.dispose();
    _places.dispose();
    _tarif.dispose();
    super.dispose();
  }

  Future<void> _choisirMoment() async {
    final maintenant = DateTime.now();
    final jour = await showDatePicker(
      context: context,
      initialDate: _quand ?? maintenant.add(const Duration(days: 1)),
      firstDate: maintenant,
      lastDate: maintenant.add(const Duration(days: 365)),
    );
    if (jour == null || !mounted) return;
    final heure = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          _quand ?? maintenant.add(const Duration(hours: 1))),
    );
    if (heure == null || !mounted) return;
    setState(() {
      _quand =
          DateTime(jour.year, jour.month, jour.day, heure.hour, heure.minute);
    });
  }

  Future<void> _enregistrer() async {
    if (_titre.text.trim().isEmpty) {
      setState(() => _erreur = 'Le titre est obligatoire.');
      return;
    }
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    final erreur = await context.read<OrientationProvider>().saveSession(
          sessionId: widget.existante?['id']?.toString(),
          titre: _titre.text.trim(),
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          format: _format,
          theme: _theme,
          niveau: _niveau,
          scheduledAt: _quand,
          dureeMinutes: _duree,
          maxPlaces: _format == 'collective'
              ? int.tryParse(_places.text.trim()) ?? 30
              : null,
          tarifPlace: int.tryParse(_tarif.text.trim()) ?? 0,
          tableau: _tableau,
          enregistrement: _enregistrement,
        );
    if (!mounted) return;
    if (erreur != null) {
      setState(() {
        _enCours = false;
        _erreur = erreur;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final collective = _format == 'collective';
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: OrientationTheme.sheetDecoration,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: OrientationTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.existante == null
                          ? 'Nouvelle séance'
                          : 'Modifier la séance',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                children: [
                  if (_erreur != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: OrientationTheme.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_erreur!,
                          style: const TextStyle(
                              fontSize: 12.5, color: OrientationTheme.red)),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const _Titre('Format'),
                  _ChoixFormat(
                    valeur: _format,
                    onChanged: (v) => setState(() => _format = v),
                  ),
                  const SizedBox(height: 18),
                  const _Titre('Intitulé'),
                  TextField(
                    controller: _titre,
                    decoration: const InputDecoration(
                      hintText: 'Choisir sa filière après le bac',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 13.5),
                  ),
                  const SizedBox(height: 14),
                  const _Titre('Présentation (facultatif)'),
                  TextField(
                    controller: _description,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Ce que les élèves y trouveront.',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 13.5),
                  ),
                  const SizedBox(height: 18),
                  const _Titre('Thème'),
                  _Choix(
                    options: _themes,
                    selection: _theme,
                    onChanged: (v) => setState(() => _theme = v),
                  ),
                  const SizedBox(height: 18),
                  const _Titre('Niveau visé (facultatif)'),
                  _Choix(
                    options: OrientationLabels.niveaux,
                    selection: _niveau,
                    onChanged: (v) => setState(() => _niveau = v),
                  ),
                  const SizedBox(height: 18),
                  const _Titre('Date et heure'),
                  InkWell(
                    onTap: _choisirMoment,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: OrientationTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: OrientationTheme.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_outlined,
                              size: 18, color: OrientationTheme.textMuted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _quand == null
                                  ? 'Choisir un moment'
                                  : OrientationLabels.dateComplete(_quand!),
                              style: TextStyle(
                                fontSize: 13.5,
                                color: _quand == null
                                    ? OrientationTheme.textMuted
                                    : OrientationTheme.text,
                              ),
                            ),
                          ),
                          if (_quand != null)
                            IconButton(
                              onPressed: () => setState(() => _quand = null),
                              icon: const Icon(Icons.clear, size: 18),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _Titre('Durée'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _durees
                        .map((d) => ChoiceChip(
                              label: Text('$d min',
                                  style: const TextStyle(fontSize: 12.5)),
                              selected: _duree == d,
                              onSelected: (_) => setState(() => _duree = d),
                            ))
                        .toList(),
                  ),
                  if (collective) ...[
                    const SizedBox(height: 18),
                    const _Titre('Nombre de places'),
                    TextField(
                      controller: _places,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        helperText: 'Entre 3 et 200.',
                        helperStyle: TextStyle(fontSize: 11.5),
                      ),
                      style: const TextStyle(fontSize: 13.5),
                    ),
                    const SizedBox(height: 14),
                    const _Titre('Tarif par place (FCFA)'),
                    TextField(
                      controller: _tarif,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        helperText: '0 pour une séance gratuite.',
                        helperStyle: TextStyle(fontSize: 11.5),
                      ),
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const _Titre('Outils en séance'),
                  SwitchListTile(
                    value: _tableau,
                    onChanged: (v) => setState(() => _tableau = v),
                    title: const Text('Tableau blanc',
                        style: TextStyle(fontSize: 13.5)),
                    subtitle: const Text(
                      'Arbre de filières, calendrier de concours, trajectoire d\'études.',
                      style: TextStyle(fontSize: 11.5),
                    ),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  SwitchListTile(
                    value: _enregistrement,
                    onChanged: (v) => setState(() => _enregistrement = v),
                    title: const Text('Enregistrement',
                        style: TextStyle(fontSize: 13.5)),
                    subtitle: Text(
                      collective
                          ? 'Les participants seront prévenus par un bandeau permanent.'
                          : 'En entretien individuel, l\'accord de l\'élève est requis '
                              'avant tout enregistrement.',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _enCours ? null : _enregistrer,
                      style: FilledButton.styleFrom(
                        backgroundColor: OrientationTheme.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _enCours
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Enregistrer'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'La séance est créée en brouillon. Elle ne devient visible '
                    'des élèves qu\'une fois publiée.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: OrientationTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoixFormat extends StatelessWidget {
  final String valeur;
  final ValueChanged<String> onChanged;
  const _ChoixFormat({required this.valeur, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder : côte à côte s'il y a la place, empilés sinon.
    return LayoutBuilder(
      builder: (context, contraintes) {
        final cote = contraintes.maxWidth >= 360;
        final cartes = [
          _CarteFormat(
            titre: 'Entretien individuel',
            detail: 'Deux places. Un élève, en tête-à-tête.',
            icone: Icons.person_outline,
            actif: valeur == 'individuelle',
            onTap: () => onChanged('individuelle'),
          ),
          _CarteFormat(
            titre: 'Séance collective',
            detail: 'Jusqu\'à 200 places, main levée activée.',
            icone: Icons.groups_outlined,
            actif: valeur == 'collective',
            onTap: () => onChanged('collective'),
          ),
        ];
        if (!cote) {
          return Column(
            children: [
              cartes[0],
              const SizedBox(height: 8),
              cartes[1],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: cartes[0]),
            const SizedBox(width: 8),
            Expanded(child: cartes[1]),
          ],
        );
      },
    );
  }
}

class _CarteFormat extends StatelessWidget {
  final String titre;
  final String detail;
  final IconData icone;
  final bool actif;
  final VoidCallback onTap;

  const _CarteFormat({
    required this.titre,
    required this.detail,
    required this.icone,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: actif
              ? OrientationTheme.accent.withValues(alpha: 0.07)
              : OrientationTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: actif ? OrientationTheme.accent : OrientationTheme.border,
            width: actif ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone,
                size: 20,
                color: actif
                    ? OrientationTheme.accent
                    : OrientationTheme.textMuted),
            const SizedBox(height: 8),
            Text(
              titre,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color:
                    actif ? OrientationTheme.accent : OrientationTheme.text,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              detail,
              style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: OrientationTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Choix extends StatelessWidget {
  final Map<String, String> options;
  final String? selection;
  final ValueChanged<String?> onChanged;

  const _Choix({
    required this.options,
    required this.selection,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.entries
          .map((e) => ChoiceChip(
                label: Text(e.value, style: const TextStyle(fontSize: 12.5)),
                selected: selection == e.key,
                onSelected: (sel) => onChanged(sel ? e.key : null),
              ))
          .toList(),
    );
  }
}

class _Titre extends StatelessWidget {
  final String texte;
  const _Titre(this.texte);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(texte.toUpperCase(), style: OrientationTheme.label),
    );
  }
}
