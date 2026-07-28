import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/orientation_provider.dart';
import 'orientation_theme.dart';

/// Enveloppe commune aux feuilles du module.
///
/// Toutes adoptent la même structure : un en-tête fixe, un corps défilant, et
/// une hauteur qui s'adapte à l'écran. C'est ce qui garantit qu'aucune ne
/// déborde, y compris quand le clavier occupe la moitié de la hauteur.
class _Sheet extends StatelessWidget {
  final String titre;
  final String? sousTitre;
  final Widget Function(ScrollController) corps;

  const _Sheet({required this.titre, this.sousTitre, required this.corps});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Container(
        decoration: OrientationTheme.sheetDecoration,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 6, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(titre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16.5, fontWeight: FontWeight.w600)),
                        if (sousTitre != null)
                          Text(sousTitre!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: OrientationTheme.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: corps(controller)),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
        child: Text(text.toUpperCase(), style: OrientationTheme.label),
      );
}

class _Field extends StatelessWidget {
  final Widget child;
  const _Field({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
        decoration: OrientationTheme.cardDecoration,
        child: child,
      );
}

// ═══ Profil du conseiller ══════════════════════════════════════════════

/// L'administrateur pose le minimum à la création ; le conseiller affine
/// ensuite depuis son compte, comme le fait un commercial ou un marchand.
class CounselorProfileSheet extends StatefulWidget {
  const CounselorProfileSheet({super.key});

  @override
  State<CounselorProfileSheet> createState() => _CounselorProfileSheetState();
}

class _CounselorProfileSheetState extends State<CounselorProfileSheet> {
  late final TextEditingController _nameC;
  late final TextEditingController _bioC;
  late final TextEditingController _tarifC;
  late String _kind;
  late int _duree;
  late Set<String> _specialites;
  late Set<String> _langues;
  late Set<String> _niveaux;

  @override
  void initState() {
    super.initState();
    final p = context.read<OrientationProvider>().myProfile ?? const {};
    _nameC = TextEditingController(text: p['full_name']?.toString() ?? '');
    _bioC = TextEditingController(text: p['bio']?.toString() ?? '');
    _tarifC = TextEditingController(text: '${p['tarif_fcfa'] ?? 0}');
    _kind = p['kind']?.toString() ?? 'orientation';
    _duree = (p['duree_minutes'] as num?)?.toInt() ?? 45;
    _specialites =
        ((p['specialites'] as List?) ?? const []).map((e) => '$e').toSet();
    _langues = ((p['langues'] as List?) ?? const ['fr']).map((e) => '$e').toSet();
    _niveaux = ((p['niveaux'] as List?) ?? const []).map((e) => '$e').toSet();
    if (_langues.isEmpty) _langues.add('fr');
  }

  @override
  void dispose() {
    _nameC.dispose();
    _bioC.dispose();
    _tarifC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_nameC.text.trim().isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Le nom affiché est obligatoire.')));
      return;
    }
    final error = await context.read<OrientationProvider>().updateMyProfile(
          fullName: _nameC.text.trim(),
          kind: _kind,
          specialites: _specialites.toList(),
          niveaux: _niveaux.toList(),
          langues: _langues.toList(),
          bio: _bioC.text.trim(),
          tarifFcfa: int.tryParse(_tarifC.text.trim()) ?? 0,
          dureeMinutes: _duree,
        );
    if (!mounted) return;
    if (error != null) {
      messenger.showSnackBar(SnackBar(
          content: Text(error), backgroundColor: OrientationTheme.red));
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<OrientationProvider>().isBooking;

    return _Sheet(
      titre: 'Mon profil de conseiller',
      sousTitre: 'Ce que les élèves voient avant de vous choisir',
      corps: (controller) => ListView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(
          18,
          4,
          18,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        children: [
          const _Label('Nom affiché'),
          _Field(
            child: TextField(
              controller: _nameC,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  border: InputBorder.none, hintText: 'Votre nom'),
            ),
          ),
          const _Label('Type de conseil'),
          _ChoixUnique(
            options: OrientationLabels.kinds,
            valeur: _kind,
            onChange: (v) => setState(() => _kind = v),
          ),
          const _Label('Spécialités'),
          _ChoixMultiple(
            options: OrientationLabels.specialites,
            valeurs: _specialites,
            onChange: (s) => setState(() => _specialites = s),
          ),
          const _Label('Niveaux accompagnés'),
          _ChoixMultiple(
            options: OrientationLabels.niveaux,
            valeurs: _niveaux,
            onChange: (s) => setState(() => _niveaux = s),
          ),
          const _Label('Langues parlées'),
          _ChoixMultiple(
            options: OrientationLabels.langues,
            valeurs: _langues,
            minimumUn: 'fr',
            onChange: (s) => setState(() => _langues = s),
          ),
          const _Label('Présentation'),
          _Field(
            child: TextField(
              controller: _bioC,
              maxLines: 4,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Votre parcours, votre façon d\'accompagner. '
                    'C\'est ce qui décide un élève à vous choisir.',
                hintStyle: TextStyle(fontSize: 13),
              ),
            ),
          ),
          const _Label('Tarif et durée'),
          LayoutBuilder(
            builder: (context, c) {
              final tarif = _Field(
                child: TextField(
                  controller: _tarifC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      border: InputBorder.none,
                      labelText: 'FCFA (0 = gratuit)'),
                ),
              );
              final duree = _Field(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _duree,
                    items: const [30, 45, 60, 90]
                        .map((m) => DropdownMenuItem(
                            value: m, child: Text('$m minutes')))
                        .toList(),
                    onChanged: (v) => setState(() => _duree = v ?? 45),
                  ),
                ),
              );
              // En dessous de 360 points, deux champs côte à côte deviennent
              // illisibles : on les empile.
              if (c.maxWidth < 360) {
                return Column(
                  children: [tarif, const SizedBox(height: 10), duree],
                );
              }
              return Row(
                children: [
                  Expanded(child: tarif),
                  const SizedBox(width: 10),
                  Expanded(child: duree),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: OrientationTheme.accent,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: busy ? null : _save,
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

class _ChoixUnique extends StatelessWidget {
  final Map<String, String> options;
  final String valeur;
  final ValueChanged<String> onChange;

  const _ChoixUnique(
      {required this.options, required this.valeur, required this.onChange});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 7,
        runSpacing: 7,
        children: options.entries
            .map((e) => ChoiceChip(
                  label: Text(e.value, style: const TextStyle(fontSize: 12)),
                  selected: valeur == e.key,
                  onSelected: (_) => onChange(e.key),
                ))
            .toList(),
      );
}

class _ChoixMultiple extends StatelessWidget {
  final Map<String, String> options;
  final Set<String> valeurs;
  final ValueChanged<Set<String>> onChange;

  /// Valeur réintroduite si l'utilisateur vide entièrement la sélection.
  final String? minimumUn;

  const _ChoixMultiple({
    required this.options,
    required this.valeurs,
    required this.onChange,
    this.minimumUn,
  });

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 7,
        runSpacing: 7,
        children: options.entries.map((e) {
          final selected = valeurs.contains(e.key);
          return FilterChip(
            label: Text(e.value, style: const TextStyle(fontSize: 12)),
            selected: selected,
            onSelected: (v) {
              final copie = Set<String>.from(valeurs);
              v ? copie.add(e.key) : copie.remove(e.key);
              if (copie.isEmpty && minimumUn != null) copie.add(minimumUn!);
              onChange(copie);
            },
          );
        }).toList(),
      );
}

// ═══ Agenda hebdomadaire ═══════════════════════════════════════════════

/// Le conseiller déclare ses plages une fois ; elles se répètent chaque
/// semaine. La base les découpe ensuite en créneaux de sa durée et retire ce
/// qui est déjà réservé — aucun calcul de disponibilité côté application.
class CounselorAvailabilityEditor extends StatefulWidget {
  const CounselorAvailabilityEditor({super.key});

  @override
  State<CounselorAvailabilityEditor> createState() =>
      _CounselorAvailabilityEditorState();
}

class _CounselorAvailabilityEditorState
    extends State<CounselorAvailabilityEditor> {
  final Map<int, List<_Plage>> _plages = {};
  bool _initialise = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialise) return;
    _charger();
  }

  void _charger() {
    final source = context.read<OrientationProvider>().myAvailability;
    _plages.clear();
    for (final s in source) {
      final j = (s['weekday'] as num?)?.toInt() ?? 0;
      _plages.putIfAbsent(j, () => []).add(_Plage(
            debut: '${s['start_time']}'.substring(0, 5),
            fin: '${s['end_time']}'.substring(0, 5),
          ));
    }
    _initialise = true;
  }

  int get _total => _plages.values.fold(0, (a, b) => a + b.length);

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _ajouter(int jour) async {
    final messenger = ScaffoldMessenger.of(context);
    final debut = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Début de la plage',
    );
    if (debut == null || !mounted) return;
    final fin = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (debut.hour + 3).clamp(0, 23), minute: 0),
      helpText: 'Fin de la plage',
    );
    if (fin == null) return;

    if (_fmt(fin).compareTo(_fmt(debut)) <= 0) {
      messenger.showSnackBar(const SnackBar(
          content: Text('L\'heure de fin doit suivre l\'heure de début.')));
      return;
    }
    setState(() => _plages
        .putIfAbsent(jour, () => [])
        .add(_Plage(debut: _fmt(debut), fin: _fmt(fin))));
  }

  /// Reprend les plages du premier jour renseigné sur toute la semaine.
  /// Saisir sept fois le même horaire serait pénible.
  void _appliquerSemaine() {
    List<_Plage>? modele;
    for (final e in _plages.entries) {
      if (e.value.isNotEmpty) {
        modele = e.value;
        break;
      }
    }
    if (modele == null) return;
    final copie = modele;
    setState(() {
      for (var j = 1; j <= 5; j++) {
        _plages[j] =
            copie.map((p) => _Plage(debut: p.debut, fin: p.fin)).toList();
      }
    });
  }

  Future<void> _enregistrer() async {
    final messenger = ScaffoldMessenger.of(context);
    final slots = <Map<String, dynamic>>[];
    _plages.forEach((jour, liste) {
      for (final p in liste) {
        slots.add(
            {'weekday': jour, 'start_time': p.debut, 'end_time': p.fin});
      }
    });

    final error =
        await context.read<OrientationProvider>().setMyAvailability(slots);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(error ??
          (slots.isEmpty
              ? 'Agenda vidé. Vous n\'êtes plus réservable.'
              : 'Créneaux enregistrés. Vous êtes réservable.')),
      backgroundColor: error != null ? OrientationTheme.red : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrientationProvider>();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: OrientationTheme.accent.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  'Déclarez vos plages une fois : elles se répètent chaque '
                  'semaine. Elles seront découpées automatiquement en créneaux '
                  'de ${p.myProfile?['duree_minutes'] ?? 45} minutes.',
                  style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: OrientationTheme.textSecondary),
                ),
              ),
              if (_total > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _appliquerSemaine,
                    icon: const Icon(Icons.copy_all_outlined, size: 17),
                    label: const Text('Appliquer du lundi au vendredi'),
                  ),
                ),
              const SizedBox(height: 4),
              // On commence au lundi : c'est le début de semaine ici.
              ...List.generate(7, (i) => (i + 1) % 7).map(_carteJour),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: OrientationTheme.accent,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: p.isBooking ? null : _enregistrer,
                child: p.isBooking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(_total == 0
                        ? 'Enregistrer (aucune disponibilité)'
                        : 'Enregistrer — $_total plage(s)'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _carteJour(int jour) {
    final liste = _plages[jour] ?? const <_Plage>[];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: OrientationTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(OrientationLabels.jours[jour],
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Ajouter une plage',
                icon: const Icon(Icons.add_circle_outline,
                    size: 22, color: OrientationTheme.accent),
                onPressed: () => _ajouter(jour),
              ),
            ],
          ),
          if (liste.isEmpty)
            const Text('Indisponible',
                style: TextStyle(
                    fontSize: 12.5, color: OrientationTheme.textMuted))
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: liste
                  .map((p) => Chip(
                        label: Text('${p.debut} – ${p.fin}',
                            style: const TextStyle(fontSize: 12)),
                        onDeleted: () =>
                            setState(() => _plages[jour]!.remove(p)),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _Plage {
  final String debut;
  final String fin;
  const _Plage({required this.debut, required this.fin});
}

// ═══ Dossier de l'élève ════════════════════════════════════════════════

/// Ce que la plateforme sait déjà de l'élève : son profil psychotechnique,
/// ses consultations précédentes, sa question. Le conseiller arrive informé
/// plutôt que de commencer par « alors, c'était quoi ta question ? ».
class StudentFileSheet extends StatelessWidget {
  final String? eleve;
  const StudentFileSheet({super.key, this.eleve});

  @override
  Widget build(BuildContext context) {
    final file = context.watch<OrientationProvider>().studentFile;

    return _Sheet(
      titre: 'Dossier de l\'élève',
      sousTitre: eleve,
      corps: (controller) {
        if (file == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Dossier indisponible.',
                  style: TextStyle(color: OrientationTheme.textSecondary)),
            ),
          );
        }

        final psycho = file['profil_psychotechnique'];
        final precedentes = (file['consultations_precedentes'] as List?) ?? const [];

        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
          children: [
            const _Label('Identité'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: OrientationTheme.cardDecoration,
              child: Text(file['nom']?.toString() ?? 'Élève',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            if (file['motif'] != null &&
                file['motif'].toString().trim().isNotEmpty) ...[
              const _Label('Sa question'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: OrientationTheme.cardDecoration,
                child: Text(file['motif'].toString(),
                    style: const TextStyle(fontSize: 13.5, height: 1.55)),
              ),
            ],
            const _Label('Profil psychotechnique'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: OrientationTheme.cardDecoration,
              child: psycho == null
                  ? const Text(
                      'Cet élève n\'a pas encore passé le test psychotechnique. '
                      'Vous pouvez le lui proposer pendant l\'entretien.',
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: OrientationTheme.textSecondary),
                    )
                  : Text(_lisible(psycho),
                      style: const TextStyle(fontSize: 13, height: 1.55)),
            ),
            const _Label('Consultations précédentes'),
            if (precedentes.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: OrientationTheme.cardDecoration,
                child: const Text('Premier entretien.',
                    style: TextStyle(
                        fontSize: 13, color: OrientationTheme.textSecondary)),
              )
            else
              ...precedentes.whereType<Map>().map((c) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(13),
                    decoration: OrientationTheme.cardDecoration,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateTime.tryParse('${c['date']}') != null
                              ? OrientationLabels.dateComplete(
                                  DateTime.parse('${c['date']}').toLocal())
                              : '${c['date']}',
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: OrientationTheme.textMuted),
                        ),
                        if (c['motif'] != null) ...[
                          const SizedBox(height: 4),
                          Text('${c['motif']}',
                              style: const TextStyle(
                                  fontSize: 13, height: 1.5)),
                        ],
                      ],
                    ),
                  )),
          ],
        );
      },
    );
  }

  static String _lisible(dynamic v) {
    if (v is! Map) return '$v';
    final b = StringBuffer();
    v.forEach((k, value) {
      if (value == null) return;
      final cle = '$k'.replaceAll('_', ' ');
      b.writeln('$cle : $value');
    });
    final s = b.toString().trim();
    return s.isEmpty ? 'Aucune donnée exploitable.' : s;
  }
}

// ═══ Fiche d'orientation ═══════════════════════════════════════════════

/// Le livrable de la consultation. Un entretien laisse un souvenir ; une fiche
/// circule dans la famille, se relit et se compare.
///
/// La saisie est volontairement structurée mais souple : profil, pistes,
/// échéances, prochaines étapes. Chaque conseiller n'ayant pas les mêmes
/// habitudes, on ne fige pas davantage tant que le format n'a pas été éprouvé.
class OrientationRecordSheet extends StatefulWidget {
  final String bookingId;
  final String eleve;

  const OrientationRecordSheet({
    super.key,
    required this.bookingId,
    required this.eleve,
  });

  @override
  State<OrientationRecordSheet> createState() => _OrientationRecordSheetState();
}

class _OrientationRecordSheetState extends State<OrientationRecordSheet> {
  final _profilC = TextEditingController();
  final _echeancesC = TextEditingController();
  final _etapesC = TextEditingController();
  final _notesC = TextEditingController();
  final List<_Piste> _pistes = [];
  bool _partager = false;

  @override
  void initState() {
    super.initState();
    final record = context.read<OrientationProvider>().record;
    final content = (record?['content'] as Map?)?.cast<String, dynamic>();
    if (content != null) {
      _profilC.text = content['profil']?.toString() ?? '';
      _echeancesC.text = _joindre(content['echeances']);
      _etapesC.text = _joindre(content['prochaines_etapes']);
      _notesC.text = content['notes']?.toString() ?? '';
      final pistes = content['pistes'];
      if (pistes is List) {
        for (final p in pistes.whereType<Map>()) {
          _pistes.add(_Piste(
            titre: p['titre']?.toString() ?? '',
            argumentaire: p['argumentaire']?.toString() ?? '',
            etablissements: p['etablissements']?.toString() ?? '',
            cout: p['cout']?.toString() ?? '',
          ));
        }
      }
    }
    _partager = record?['is_shared'] == true;
  }

  static String _joindre(dynamic v) =>
      v is List ? v.map((e) => '$e').join('\n') : (v?.toString() ?? '');

  static List<String> _decouper(String s) => s
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  @override
  void dispose() {
    _profilC.dispose();
    _echeancesC.dispose();
    _etapesC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    final messenger = ScaffoldMessenger.of(context);
    final content = <String, dynamic>{
      'profil': _profilC.text.trim(),
      'pistes': _pistes
          .where((p) => p.titre.trim().isNotEmpty)
          .map((p) => {
                'titre': p.titre.trim(),
                'argumentaire': p.argumentaire.trim(),
                'etablissements': p.etablissements.trim(),
                'cout': p.cout.trim(),
              })
          .toList(),
      'echeances': _decouper(_echeancesC.text),
      'prochaines_etapes': _decouper(_etapesC.text),
      'notes': _notesC.text.trim(),
    };

    final error = await context
        .read<OrientationProvider>()
        .saveRecord(widget.bookingId, content, share: _partager);
    if (!mounted) return;
    if (error != null) {
      messenger.showSnackBar(SnackBar(
          content: Text(error), backgroundColor: OrientationTheme.red));
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      titre: 'Fiche d\'orientation',
      sousTitre: widget.eleve,
      corps: (controller) => ListView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(
          18,
          4,
          18,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        children: [
          const _Label('Synthèse du profil'),
          _Field(
            child: TextField(
              controller: _profilC,
              maxLines: 3,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Ce que vous retenez de l\'élève : ses points forts, '
                    'ses contraintes, ses envies.',
                hintStyle: TextStyle(fontSize: 13),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
            child: Row(
              children: [
                Text('PISTES RECOMMANDÉES', style: OrientationTheme.label),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _pistes.add(_Piste())),
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
          ),
          if (_pistes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: OrientationTheme.cardDecoration,
              child: const Text(
                'Aucune piste. Ajoutez-en deux ou trois, classées par ordre de '
                'pertinence — c\'est le cœur de la fiche.',
                style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: OrientationTheme.textSecondary),
              ),
            )
          else
            ..._pistes.asMap().entries.map((e) => _carteEditionPiste(e.key)),
          const _Label('Échéances à ne pas manquer'),
          _Field(
            child: TextField(
              controller: _echeancesC,
              maxLines: 3,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Une par ligne. Ex. : dépôt du dossier avant le 15 août',
                hintStyle: TextStyle(fontSize: 13),
              ),
            ),
          ),
          const _Label('Prochaines étapes'),
          _Field(
            child: TextField(
              controller: _etapesC,
              maxLines: 3,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Une par ligne. Ce que l\'élève doit faire en sortant.',
                hintStyle: TextStyle(fontSize: 13),
              ),
            ),
          ),
          const _Label('Notes internes'),
          _Field(
            child: TextField(
              controller: _notesC,
              maxLines: 3,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Vos notes. Non partagées avec l\'élève.',
                hintStyle: TextStyle(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: OrientationTheme.cardDecoration,
            child: SwitchListTile(
              value: _partager,
              activeColor: OrientationTheme.accent,
              onChanged: (v) => setState(() => _partager = v),
              title: const Text('Partager avec l\'élève',
                  style: TextStyle(fontSize: 14)),
              subtitle: Text(
                _partager
                    ? 'L\'élève et sa famille pourront la consulter.'
                    : 'La fiche reste en brouillon, visible de vous seul.',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Consumer<OrientationProvider>(
            builder: (context, p, _) => FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: OrientationTheme.accent,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: p.isBooking ? null : _enregistrer,
              child: p.isBooking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(_partager
                      ? 'Enregistrer et partager'
                      : 'Enregistrer le brouillon'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _carteEditionPiste(int index) {
    final piste = _pistes[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: OrientationTheme.cardDecoration,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: OrientationTheme.accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text('${index + 1}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: OrientationTheme.accent)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Piste',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline,
                    size: 19, color: OrientationTheme.red),
                onPressed: () => setState(() => _pistes.removeAt(index)),
              ),
            ],
          ),
          TextFormField(
            initialValue: piste.titre,
            onChanged: (v) => piste.titre = v,
            decoration: const InputDecoration(
                labelText: 'Intitulé', isDense: true),
            style: const TextStyle(fontSize: 13.5),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: piste.argumentaire,
            onChanged: (v) => piste.argumentaire = v,
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'Pourquoi cette piste', isDense: true),
            style: const TextStyle(fontSize: 13.5),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: piste.etablissements,
            onChanged: (v) => piste.etablissements = v,
            decoration: const InputDecoration(
                labelText: 'Établissements', isDense: true),
            style: const TextStyle(fontSize: 13.5),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: piste.cout,
            onChanged: (v) => piste.cout = v,
            decoration: const InputDecoration(
                labelText: 'Durée et coût estimé', isDense: true),
            style: const TextStyle(fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}

class _Piste {
  String titre;
  String argumentaire;
  String etablissements;
  String cout;

  _Piste({
    this.titre = '',
    this.argumentaire = '',
    this.etablissements = '',
    this.cout = '',
  });
}
