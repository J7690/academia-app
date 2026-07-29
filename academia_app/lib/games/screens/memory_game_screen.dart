import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/memory_service.dart';

/// Mémoire éclair — les trois temps d'une manche : mémoriser, restituer, corriger.
///
/// Les chiffres défilent PAR GROUPES plutôt que de s'afficher d'un bloc. Deux
/// raisons : c'est la technique que les compétiteurs emploient (on retient des
/// paquets, pas des chiffres isolés), et une capture d'écran ne suffit plus à
/// tout copier — il faudrait filmer l'écran entier.
class MemoryGameScreen extends StatefulWidget {
  const MemoryGameScreen({super.key});

  @override
  State<MemoryGameScreen> createState() => _MemoryGameScreenState();
}

enum _Phase { reglages, memorisation, restitution, resultat }

class _MemoryGameScreenState extends State<MemoryGameScreen> {
  static const _vert = Color(0xFF1EA75C);
  static const _fond = Color(0xFF0F1A22);

  /// Taille du paquet affiché à l'écran. Trois chiffres : la limite au-delà de
  /// laquelle la mémoire immédiate décroche pour la plupart des gens.
  static const _tailleGroupe = 3;

  _Phase _phase = _Phase.reglages;
  int _chiffres = 20;
  int _secondes = 60;

  MemoryRound? _manche;
  MemoryResult? _resultat;
  MemoryBest? _record;

  int _groupeCourant = 0;
  int _restant = 0;
  Timer? _chrono;
  Timer? _defilement;
  DateTime? _departRestitution;

  final _saisie = TextEditingController();
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    MemoryService.myBest().then((b) {
      if (mounted) setState(() => _record = b);
    });
  }

  @override
  void dispose() {
    _chrono?.cancel();
    _defilement?.cancel();
    _saisie.dispose();
    super.dispose();
  }

  List<String> get _groupes {
    final s = _manche?.sequence ?? '';
    return [
      for (var i = 0; i < s.length; i += _tailleGroupe)
        s.substring(i, (i + _tailleGroupe).clamp(0, s.length)),
    ];
  }

  Future<void> _demarrer() async {
    setState(() => _enCours = true);
    final manche = await MemoryService.start(
      digits: _chiffres,
      memoSeconds: _secondes,
    );
    if (!mounted) return;

    if (manche == null) {
      setState(() => _enCours = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de démarrer. Vérifie ta connexion.')),
      );
      return;
    }

    setState(() {
      _manche = manche;
      _enCours = false;
      _phase = _Phase.memorisation;
      _groupeCourant = 0;
      _restant = manche.memoSeconds;
      _saisie.clear();
    });

    // Le défilement est calé sur le temps disponible : la dernière tranche doit
    // apparaître avant la fin du chrono, quelle que soit la longueur choisie.
    final nb = _groupes.length;
    final msParGroupe = ((manche.memoSeconds * 1000) / (nb + 1)).floor();

    _defilement = Timer.periodic(Duration(milliseconds: msParGroupe), (t) {
      if (!mounted) return;
      if (_groupeCourant + 1 >= nb) {
        t.cancel();
        return;
      }
      setState(() => _groupeCourant++);
    });

    _chrono = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _restant--);
      if (_restant <= 0) _passerARestitution();
    });
  }

  void _passerARestitution() {
    _chrono?.cancel();
    _defilement?.cancel();
    setState(() {
      _phase = _Phase.restitution;
      _departRestitution = DateTime.now();
      _restant = _manche?.recallSeconds ?? 300;
    });
    _chrono = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _restant--);
      if (_restant <= 0) _rendre();
    });
  }

  Future<void> _rendre() async {
    if (_enCours) return;
    _chrono?.cancel();
    setState(() => _enCours = true);

    final resultat = await MemoryService.submit(
      roundId: _manche!.roundId,
      answer: _saisie.text,
      elapsedMs: _departRestitution == null
          ? null
          : DateTime.now().difference(_departRestitution!).inMilliseconds,
    );
    if (!mounted) return;

    if (resultat == null) {
      setState(() => _enCours = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ta réponse n\'a pas pu être envoyée. Réessaie.')),
      );
      return;
    }

    final record = await MemoryService.myBest();
    if (!mounted) return;
    setState(() {
      _resultat = resultat;
      _record = record;
      _enCours = false;
      _phase = _Phase.resultat;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _phase == _Phase.memorisation ? _fond : const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Mémoire éclair'),
        backgroundColor: _phase == _Phase.memorisation ? _fond : _vert,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: switch (_phase) {
        _Phase.reglages => _vueReglages(),
        _Phase.memorisation => _vueMemorisation(),
        _Phase.restitution => _vueRestitution(),
        _Phase.resultat => _vueResultat(),
      },
    );
  }

  // ── Réglages ──────────────────────────────────────────────────────────────
  Widget _vueReglages() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Comment ça marche',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Une suite de chiffres défile par petits paquets. Quand le temps '
                'est écoulé, tu la réécris dans l\'ordre. Un point par chiffre '
                'correctement placé.',
                style: TextStyle(color: Colors.grey.shade700, height: 1.45),
              ),
              if ((_record?.roundsPlayed ?? 0) > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _vert.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Ton record : ${_record!.bestScore} chiffres '
                    '· ${_record!.roundsPlayed} manche${_record!.roundsPlayed > 1 ? 's' : ''}',
                    style: const TextStyle(color: _vert, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        _curseur(
          titre: 'Longueur de la suite',
          valeur: _chiffres.toDouble(),
          min: 5,
          max: 80,
          divisions: 15,
          libelle: '$_chiffres chiffres',
          onChange: (v) => setState(() => _chiffres = v.round()),
        ),
        const SizedBox(height: 16),
        _curseur(
          titre: 'Temps de mémorisation',
          valeur: _secondes.toDouble(),
          min: 10,
          max: 120,
          divisions: 11,
          libelle: '$_secondes secondes',
          onChange: (v) => setState(() => _secondes = v.round()),
        ),
        const SizedBox(height: 26),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _enCours ? null : _demarrer,
            style: ElevatedButton.styleFrom(
              backgroundColor: _vert,
              foregroundColor: Colors.white,
            ),
            child: _enCours
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Commencer',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _curseur({
    required String titre,
    required double valeur,
    required double min,
    required double max,
    required int divisions,
    required String libelle,
    required ValueChanged<double> onChange,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(titre, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(libelle,
                  style: const TextStyle(color: _vert, fontWeight: FontWeight.w700)),
            ],
          ),
          Slider(
            value: valeur,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: _vert,
            onChanged: onChange,
          ),
        ],
      ),
    );
  }

  // ── Mémorisation ──────────────────────────────────────────────────────────
  Widget _vueMemorisation() {
    final groupes = _groupes;
    final courant = groupes.isEmpty ? '' : groupes[_groupeCourant];
    final urgent = _restant <= 5;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Paquet ${_groupeCourant + 1} / ${groupes.length}',
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
                Text('$_restant s',
                    style: TextStyle(
                      color: urgent ? Colors.orangeAccent : Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    )),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_manche?.memoSeconds ?? 1) == 0
                    ? 0
                    : _restant / _manche!.memoSeconds,
                minHeight: 4,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(urgent ? Colors.orangeAccent : _vert),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  courant,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 10,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            Text(
              'Retiens ce paquet, le suivant arrive',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 46,
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _passerARestitution,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                ),
                child: const Text('J\'ai mémorisé, passer à la saisie'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Restitution ───────────────────────────────────────────────────────────
  Widget _vueRestitution() {
    final saisis = _saisie.text.replaceAll(RegExp(r'[^0-9]'), '').length;
    final attendus = _manche?.digits ?? 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$saisis / $attendus chiffres',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${_restant ~/ 60}:${(_restant % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _saisie,
              onChanged: (_) => setState(() {}),
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLines: 4,
              minLines: 3,
              style: const TextStyle(
                fontSize: 22,
                letterSpacing: 4,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                hintText: 'Réécris la suite dans l\'ordre',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Si tu oublies un chiffre au milieu, laisse un autre chiffre à sa '
              'place : la position compte.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const Spacer(),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _enCours ? null : _rendre,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _vert,
                  foregroundColor: Colors.white,
                ),
                child: _enCours
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Valider',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Résultat ──────────────────────────────────────────────────────────────
  Widget _vueResultat() {
    final r = _resultat!;
    final parfait = r.score == r.digits;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: BorderSide(
                color: r.outOfTime
                    ? const Color(0xFFB23A2B)
                    : parfait
                        ? _vert
                        : const Color(0xFF2563a8),
                width: 5,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.outOfTime
                    ? 'Temps dépassé'
                    : parfait
                        ? 'Suite complète !'
                        : '${r.score} chiffres sur ${r.digits}',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: r.outOfTime ? const Color(0xFFB23A2B) : _vert,
                ),
              ),
              const SizedBox(height: 6),
              if (r.outOfTime)
                const Text(
                  'Cette manche ne compte pas au classement : la réponse est '
                  'arrivée trop tard.',
                  style: TextStyle(color: Colors.black54),
                )
              else
                Text(
                  'Plus longue série depuis le début : ${r.streak}',
                  style: const TextStyle(color: Colors.black54),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text('Comparaison',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('La suite', style: TextStyle(color: Colors.black54, fontSize: 13)),
              const SizedBox(height: 4),
              _suiteComparee(r),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: () => setState(() {
              _phase = _Phase.reglages;
              _resultat = null;
              _manche = null;
            }),
            style: ElevatedButton.styleFrom(
              backgroundColor: _vert,
              foregroundColor: Colors.white,
            ),
            child: const Text('Rejouer', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 46,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Retour'),
          ),
        ),
      ],
    );
  }

  /// Chaque chiffre attendu, coloré selon qu'il a été retrouvé ou non. C'est la
  /// partie qui fait progresser : on voit précisément où la mémoire a lâché.
  Widget _suiteComparee(MemoryResult r) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < r.sequence.length; i++)
          () {
            final attendu = r.sequence[i];
            final donne = i < r.answer.length ? r.answer[i] : null;
            final juste = donne == attendu;
            return Container(
              width: 34,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: juste
                    ? _vert.withValues(alpha: 0.13)
                    : const Color(0xFFB23A2B).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    attendu,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: juste ? _vert : const Color(0xFFB23A2B),
                    ),
                  ),
                  if (!juste)
                    Text(
                      donne ?? '–',
                      style: const TextStyle(fontSize: 10, color: Colors.black38),
                    ),
                ],
              ),
            );
          }(),
      ],
    );
  }
}
