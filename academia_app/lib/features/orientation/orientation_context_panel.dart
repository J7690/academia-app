import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'orientation_theme.dart';

/// Panneau de contexte affiché **pendant** la consultation d'orientation.
///
/// Avant, le conseiller devait quitter la salle pour lire le dossier de
/// l'élève, puis y revenir, puis en ressortir pour rédiger la fiche. La
/// consultation commençait par « alors, c'était quoi ta question ? ».
///
/// Ici, tout est sous la main sans quitter le flux vidéo :
///
/// * le dossier de l'élève, chargé avant même qu'il ne parle ;
/// * la fiche d'orientation, rédigée au fil de l'entretien ;
/// * les fiches précédentes que l'élève a accepté de partager.
///
/// **Sauvegarde automatique.** Un réseau mobile ouest-africain coupe. Perdre
/// vingt minutes de notes parce que la salle s'est fermée serait inacceptable :
/// la fiche est écrite en base trente secondes après la dernière frappe, et
/// une dernière fois à la fermeture du panneau.
class OrientationContextPanel extends StatefulWidget {
  final String sessionId;
  final VoidCallback onClose;

  const OrientationContextPanel({
    super.key,
    required this.sessionId,
    required this.onClose,
  });

  @override
  State<OrientationContextPanel> createState() =>
      _OrientationContextPanelState();
}

class _OrientationContextPanelState extends State<OrientationContextPanel> {
  final _client = Supabase.instance.client;

  final _profil = TextEditingController();
  final _pistes = TextEditingController();
  final _echeances = TextEditingController();
  final _etapes = TextEditingController();
  final _notes = TextEditingController();

  Timer? _minuteur;
  bool _chargement = true;
  bool _enregistrement = false;
  bool _modifie = false;
  bool _partager = false;
  DateTime? _dernierEnregistrement;
  String? _erreur;
  String? _bookingId;
  Map<String, dynamic>? _dossier;
  List<Map<String, dynamic>> _precedentes = const [];
  int _onglet = 0;

  @override
  void initState() {
    super.initState();
    for (final c in [_profil, _pistes, _echeances, _etapes, _notes]) {
      c.addListener(_marquerModifie);
    }
    _charger();
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    // Dernière écriture avant fermeture : on ne perd pas la frappe en cours.
    if (_modifie && _bookingId != null) {
      unawaited(_enregistrer(silencieux: true));
    }
    for (final c in [_profil, _pistes, _echeances, _etapes, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _marquerModifie() {
    if (!_modifie) setState(() => _modifie = true);
    _minuteur?.cancel();
    _minuteur = Timer(const Duration(seconds: 30), () {
      if (mounted && _modifie) _enregistrer(silencieux: true);
    });
  }

  Future<void> _charger() async {
    try {
      final res = await _client.rpc('app_orientation_session_context',
          params: {'p_session_id': widget.sessionId});
      if (!mounted) return;
      if (res is! Map || res['success'] != true) {
        setState(() {
          _erreur = res is Map
              ? res['error']?.toString() ?? 'Contexte indisponible.'
              : 'Contexte indisponible.';
          _chargement = false;
        });
        return;
      }
      final fiche = (res['fiche'] as Map?)?.cast<String, dynamic>();
      final contenu = (fiche?['content'] as Map?)?.cast<String, dynamic>();
      setState(() {
        _bookingId = res['booking_id']?.toString();
        _dossier = (res['dossier'] as Map?)?.cast<String, dynamic>();
        _precedentes = ((res['fiches_precedentes'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (contenu != null) {
          _profil.text = contenu['profil']?.toString() ?? '';
          _pistes.text = _lignes(contenu['pistes'], cle: 'filiere');
          _echeances.text = _lignes(contenu['echeances']);
          _etapes.text = _lignes(contenu['prochaines_etapes']);
          _notes.text = contenu['notes']?.toString() ?? '';
        }
        _partager = fiche?['is_shared'] == true;
        _modifie = false;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.toString();
        _chargement = false;
      });
    }
  }

  /// Aplatit une liste (de chaînes ou d'objets) en une ligne par entrée.
  String _lignes(dynamic valeur, {String? cle}) {
    if (valeur is! List) return '';
    return valeur
        .map((e) {
          if (e is Map) {
            if (cle != null && e[cle] != null) {
              final etab = e['etablissement']?.toString();
              return etab == null || etab.isEmpty
                  ? e[cle].toString()
                  : '${e[cle]} — $etab';
            }
            return (e['quoi'] ?? e['libelle'] ?? e.values.first).toString();
          }
          return e.toString();
        })
        .where((s) => s.trim().isNotEmpty)
        .join('\n');
  }

  List<String> _decouper(String texte) => texte
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  Future<void> _enregistrer({bool silencieux = false}) async {
    final id = _bookingId;
    if (id == null) return;
    if (!silencieux) setState(() => _enregistrement = true);
    try {
      final contenu = <String, dynamic>{
        'profil': _profil.text.trim(),
        // Chaque ligne « Filière — Établissement » redevient un objet, pour
        // rester dans le même format que la fiche du tableau de bord.
        'pistes': _decouper(_pistes.text).map((l) {
          final bout = l.split('—');
          return {
            'filiere': bout.first.trim(),
            'etablissement': bout.length > 1 ? bout.sublist(1).join('—').trim() : '',
            'pourquoi': '',
          };
        }).toList(),
        'echeances': _decouper(_echeances.text),
        'prochaines_etapes': _decouper(_etapes.text),
        'notes': _notes.text.trim(),
      };
      final res = await _client.rpc('app_orientation_upsert_record', params: {
        'p_booking_id': id,
        'p_content': contenu,
        'p_share': _partager,
      });
      if (!mounted) return;
      if (res is Map && res['success'] == true) {
        setState(() {
          _modifie = false;
          _enregistrement = false;
          _dernierEnregistrement = DateTime.now();
          _erreur = null;
        });
      } else {
        setState(() {
          _enregistrement = false;
          _erreur = res is Map ? res['error']?.toString() : 'Échec de la sauvegarde.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enregistrement = false;
        _erreur = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF161B26),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _entete(),
          if (_erreur != null)
            Container(
              width: double.infinity,
              color: OrientationTheme.red.withValues(alpha: 0.18),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(_erreur!,
                  style: const TextStyle(fontSize: 11.5, color: Colors.white)),
            ),
          Expanded(
            child: _chargement
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white54),
                    ),
                  )
                : _bookingId == null
                    ? _seanceSansRendezVous()
                    : IndexedStack(
                        index: _onglet,
                        children: [
                          _vueDossier(),
                          _vueFiche(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _entete() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF2A3040))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.folder_shared_outlined,
                  size: 17, color: OrientationTheme.accent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Contexte',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700),
                ),
              ),
              if (_enregistrement)
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.6, color: Colors.white54),
                )
              else if (_modifie)
                const Icon(Icons.edit_note, size: 16, color: Color(0xFFF0A020))
              else if (_dernierEnregistrement != null)
                const Icon(Icons.cloud_done_outlined,
                    size: 16, color: OrientationTheme.teal),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          if (_bookingId != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _bouton('Dossier', 0)),
                const SizedBox(width: 6),
                Expanded(child: _bouton('Fiche', 1)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _bouton(String libelle, int index) {
    final actif = _onglet == index;
    return InkWell(
      onTap: () => setState(() => _onglet = index),
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: actif ? OrientationTheme.accent : const Color(0xFF222836),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          libelle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: actif ? Colors.white : Colors.white60,
          ),
        ),
      ),
    );
  }

  Widget _seanceSansRendezVous() {
    return const Padding(
      padding: EdgeInsets.all(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups_outlined, size: 32, color: Colors.white24),
          SizedBox(height: 12),
          Text(
            'Séance sans rendez-vous',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6),
          Text(
            'Le dossier et la fiche sont propres à une consultation '
            'individuelle réservée par un élève.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 11.5, height: 1.45),
          ),
        ],
      ),
    );
  }

  // ── Dossier de l'élève ────────────────────────────────────────────────

  Widget _vueDossier() {
    final d = _dossier;
    if (d == null) {
      return const Center(
        child: Text('Dossier indisponible.',
            style: TextStyle(color: Colors.white38, fontSize: 12)),
      );
    }
    final psycho = (d['profil_psychotechnique'] as Map?)?.cast<String, dynamic>();
    final resultats = (d['derniers_resultats_psychotech'] as List?) ?? const [];
    final precedentes = (d['consultations_precedentes'] as List?) ?? const [];
    final motif = d['motif']?.toString();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        _bloc('Élève', [d['nom']?.toString() ?? 'Non renseigné']),
        if (motif != null && motif.trim().isNotEmpty)
          _bloc('Sa question', [motif]),
        if (psycho != null)
          _bloc('Profil psychotechnique', [
            for (final e in psycho.entries)
              if (e.value != null &&
                  !const {'id', 'student_id', 'created_at', 'updated_at'}
                      .contains(e.key))
                '${_humaniser(e.key)} : ${e.value}',
          ]),
        if (resultats.isNotEmpty)
          _bloc('Derniers résultats', [
            for (final r in resultats.whereType<Map>())
              '${r['score'] ?? '—'} — ${r['created_at']?.toString().split('T').first ?? ''}',
          ]),
        if (precedentes.isNotEmpty)
          _bloc('Consultations passées', [
            for (final c in precedentes.whereType<Map>())
              '${c['date']?.toString().split('T').first ?? ''} — ${c['motif'] ?? 'sans motif'}',
          ]),
        if (_precedentes.isNotEmpty)
          _bloc('Fiches partagées par l\'élève', [
            for (final f in _precedentes)
              '${f['date']?.toString().split('T').first ?? ''} — '
                  '${((f['contenu'] as Map?)?['profil'] ?? 'fiche').toString()}',
          ]),
      ],
    );
  }

  String _humaniser(String cle) {
    final t = cle.replaceAll('_', ' ');
    return t.isEmpty ? t : '${t[0].toUpperCase()}${t.substring(1)}';
  }

  Widget _bloc(String titre, List<String> lignes) {
    final utiles = lignes.where((l) => l.trim().isNotEmpty).toList();
    if (utiles.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2432),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre.toUpperCase(),
              style: const TextStyle(
                  fontSize: 9.5,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white38)),
          const SizedBox(height: 7),
          ...utiles.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(l,
                    style: const TextStyle(
                        fontSize: 12, height: 1.45, color: Colors.white70)),
              )),
        ],
      ),
    );
  }

  // ── Fiche d'orientation ───────────────────────────────────────────────

  Widget _vueFiche() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            children: [
              _champ('Profil de l\'élève', _profil,
                  aide: 'Ce qui ressort de l\'entretien.', lignes: 3),
              _champ('Pistes envisagées', _pistes,
                  aide: 'Une par ligne. « Filière — Établissement ».',
                  lignes: 4),
              _champ('Échéances', _echeances,
                  aide: 'Une par ligne. Dates de concours, dépôts de dossier.',
                  lignes: 3),
              _champ('Prochaines étapes', _etapes,
                  aide: 'Une par ligne. Ce que l\'élève doit faire.', lignes: 3),
              _champ('Notes internes', _notes,
                  aide: 'Jamais partagées avec l\'élève.', lignes: 3),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFF2A3040))),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _partager,
                      onChanged: (v) => setState(() {
                        _partager = v;
                        _modifie = true;
                      }),
                      activeThumbColor: OrientationTheme.accent,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Partager la fiche avec l\'élève',
                      style: TextStyle(fontSize: 11.5, color: Colors.white70),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _enregistrement ? null : () => _enregistrer(),
                  style: FilledButton.styleFrom(
                    backgroundColor: OrientationTheme.accent,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: Text(
                    _modifie ? 'Enregistrer' : 'Enregistré',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _modifie
                    ? 'Sauvegarde automatique dans 30 secondes.'
                    : 'Vos notes sont à jour.',
                style: const TextStyle(fontSize: 10.5, color: Colors.white38),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _champ(String libelle, TextEditingController controleur,
      {required String aide, int lignes = 3}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(libelle.toUpperCase(),
              style: const TextStyle(
                  fontSize: 9.5,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white38)),
          const SizedBox(height: 6),
          TextField(
            controller: controleur,
            maxLines: lignes,
            style: const TextStyle(fontSize: 12.5, color: Colors.white),
            decoration: InputDecoration(
              hintText: aide,
              hintStyle: const TextStyle(fontSize: 11, color: Colors.white24),
              filled: true,
              fillColor: const Color(0xFF1E2432),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
