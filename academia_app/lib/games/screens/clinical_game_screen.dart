import 'package:flutter/material.dart';

import '../services/clinical_service.dart';

/// « La consultation » — interroger, examiner, décider.
///
/// Le temps clinique se vide à chaque action : la jauge en haut de l'écran est le
/// vrai adversaire. Une action déjà faite ne peut pas être refaite, et son
/// résultat reste affiché — le joueur construit son raisonnement sous les yeux.
class ClinicalGameScreen extends StatefulWidget {
  const ClinicalGameScreen({super.key});

  @override
  State<ClinicalGameScreen> createState() => _ClinicalGameScreenState();
}

class _ClinicalGameScreenState extends State<ClinicalGameScreen> {
  static const _bleu = Color(0xFF2563A8);
  static const _teal = Color(0xFF0D8B8B);
  static const _corail = Color(0xFFD1543F);

  ClinicalCase? _cas;
  ClinicalVerdict? _verdict;
  final Set<String> _faites = {};
  int _depense = 0;
  String? _choix;
  bool _chargement = true;
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    _ouvrir();
  }

  Future<void> _ouvrir() async {
    setState(() => _chargement = true);
    final c = await ClinicalService.start();
    if (!mounted) return;

    if (c == null) {
      setState(() => _chargement = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun cas disponible pour le moment.')),
      );
      return;
    }
    setState(() {
      _cas = c;
      _verdict = null;
      _faites.clear();
      _depense = 0;
      _choix = null;
      _chargement = false;
    });
  }

  int get _reste => (_cas?.budget ?? 0) - _depense;

  void _faire(ClinicalAction a) {
    if (_faites.contains(a.code)) return;
    if (a.cost > _reste) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Il ne te reste que $_reste de temps clinique : '
            'cette action en demande ${a.cost}.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _faites.add(a.code);
      _depense += a.cost;
    });
  }

  Future<void> _conclure() async {
    if (_choix == null) return;
    setState(() => _envoi = true);
    final v = await ClinicalService.submit(
      roundId: _cas!.roundId,
      choice: _choix!,
      spent: _depense,
    );
    if (!mounted) return;

    if (v == null) {
      setState(() => _envoi = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ton diagnostic n\'a pas pu être envoyé. Réessaie.')),
      );
      return;
    }
    setState(() {
      _verdict = v;
      _envoi = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FA),
      appBar: AppBar(
        title: const Text('La consultation'),
        backgroundColor: _bleu,
        foregroundColor: Colors.white,
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: _bleu))
          : _cas == null
              ? _indisponible()
              : _verdict != null
                  ? _vueVerdict()
                  : _vueConsultation(),
    );
  }

  Widget _indisponible() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.medical_services_outlined, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 14),
              const Text('Cabinet fermé',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Aucun cas n\'est disponible pour le moment.',
                  style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      );

  // ── La consultation ───────────────────────────────────────────────────────
  Widget _vueConsultation() {
    final c = _cas!;
    final questions = c.actions.where((a) => a.kind == 'question').toList();
    final examens = c.actions.where((a) => a.kind == 'exam').toList();
    final tests = c.actions.where((a) => a.kind == 'test').toList();

    return Column(
      children: [
        _jauge(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: [
              _patient(),
              const SizedBox(height: 18),
              if (questions.isNotEmpty) ...[
                _titre('Interroger', Icons.chat_bubble_outline),
                ...questions.map(_carteAction),
                const SizedBox(height: 14),
              ],
              if (examens.isNotEmpty) ...[
                _titre('Examiner', Icons.touch_app_outlined),
                ...examens.map(_carteAction),
                const SizedBox(height: 14),
              ],
              if (tests.isNotEmpty) ...[
                _titre('Demander un examen', Icons.biotech_outlined),
                ...tests.map(_carteAction),
                const SizedBox(height: 18),
              ],
              _diagnostic(),
            ],
          ),
        ),
        _barreAction(),
      ],
    );
  }

  /// La jauge de temps clinique. Elle passe au corail quand il ne reste presque
  /// plus rien : c'est le signal qu'il va falloir décider avec ce qu'on a.
  Widget _jauge() {
    final c = _cas!;
    final part = c.budget == 0 ? 0.0 : _reste / c.budget;
    final serre = part <= 0.3;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Temps clinique',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              Text('$_reste / ${c.budget}',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: serre ? _corail : _bleu)),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: _JaugeTemps(part: part, serre: serre),
          ),
        ],
      ),
    );
  }

  Widget _patient() {
    final c = _cas!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _bleu.withValues(alpha: 0.12),
                ),
                child: const Icon(Icons.person_outline, color: _bleu),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(c.patient,
                    style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('« ${c.complaint} »',
              style: const TextStyle(fontSize: 16, height: 1.4, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _titre(String texte, IconData icone) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icone, size: 18, color: Colors.blueGrey.shade400),
            const SizedBox(width: 7),
            Text(texte,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        ),
      );

  Widget _carteAction(ClinicalAction a) {
    final faite = _faites.contains(a.code);
    final tropCher = !faite && a.cost > _reste;

    return GestureDetector(
      onTap: () => _faire(a),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: faite ? _teal.withValues(alpha: 0.07) : Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: faite ? _teal.withValues(alpha: 0.4) : const Color(0xFFDDE6E9),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(a.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        color: tropCher ? Colors.grey.shade400 : null,
                      )),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: faite
                        ? _teal.withValues(alpha: 0.15)
                        : Colors.blueGrey.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    faite ? 'fait' : '−${a.cost}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: faite ? _teal : Colors.blueGrey.shade500,
                    ),
                  ),
                ),
              ],
            ),
            // Le résultat reste affiché : le joueur voit son raisonnement
            // s'accumuler au lieu de devoir tout retenir.
            if (faite) ...[
              const SizedBox(height: 9),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _teal.withValues(alpha: 0.25)),
                ),
                child: Text(a.reveals,
                    style: const TextStyle(fontSize: 14, height: 1.4)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _diagnostic() {
    final c = _cas!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _bleu.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ton diagnostic',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
          const SizedBox(height: 4),
          Text('Tu peux décider à tout moment — chercher davantage coûte du temps.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 12),
          ...c.options.map((o) {
            final actif = _choix == o.code;
            return GestureDetector(
              onTap: () => setState(() => _choix = o.code),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                decoration: BoxDecoration(
                  color: actif ? _bleu.withValues(alpha: 0.09) : const Color(0xFFF6F9FA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: actif ? _bleu : const Color(0xFFE1E9EC),
                    width: actif ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      actif ? Icons.radio_button_checked : Icons.radio_button_off,
                      size: 20,
                      color: actif ? _bleu : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(o.label,
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: actif ? FontWeight.w600 : FontWeight.w400)),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _barreAction() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 50,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_choix == null || _envoi) ? null : _conclure,
            style: ElevatedButton.styleFrom(
              backgroundColor: _bleu,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            child: _envoi
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(
                    _choix == null ? 'Choisis un diagnostic' : 'Conclure',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ),
    );
  }

  // ── Le débrief ────────────────────────────────────────────────────────────
  Widget _vueVerdict() {
    final v = _verdict!;
    final utiles = v.review.where((r) => r.isUseful).toList();
    final impasses = v.review.where((r) => !r.isUseful).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: BorderSide(color: v.isCorrect ? _teal : _corail, width: 5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(v.isCorrect ? 'Diagnostic juste' : 'Diagnostic manqué',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: v.isCorrect ? _teal : _corail)),
              const SizedBox(height: 8),
              if (!v.isCorrect)
                Text('Il fallait retenir : ${v.correctLabel}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Temps clinique utilisé : ${v.spent} sur ${v.budget}',
                  style: const TextStyle(color: Colors.black54)),
              Text('Score : ${v.score}',
                  style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
        if (!v.isValidated) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFB07D16).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: Color(0xFFB07D16)),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Cas d\'entraînement en cours de validation par un médecin. '
                    'Il exerce une démarche, il ne remplace jamais une consultation.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF8A6212), height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Le raisonnement',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
              const SizedBox(height: 8),
              Text(v.explanation,
                  style: const TextStyle(fontSize: 14.5, height: 1.5, color: Colors.black87)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text('Les pistes',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
        const SizedBox(height: 8),
        if (utiles.isNotEmpty) _blocPistes('Utiles', utiles, _teal),
        if (impasses.isNotEmpty) _blocPistes('Impasses', impasses, _corail),
        const SizedBox(height: 20),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _ouvrir,
            style: ElevatedButton.styleFrom(
                backgroundColor: _bleu, foregroundColor: Colors.white),
            child: const Text('Nouveau patient',
                style: TextStyle(fontWeight: FontWeight.w700)),
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

  Widget _blocPistes(String titre, List<ClinicalReviewItem> items, Color couleur) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre,
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: couleur, fontSize: 14)),
          const SizedBox(height: 8),
          ...items.map((r) {
            final faite = _faites.contains(r.code);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    faite ? Icons.check : Icons.remove,
                    size: 16,
                    color: faite ? couleur : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(r.label,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: faite ? Colors.black87 : Colors.grey.shade500,
                        )),
                  ),
                  Text('−${r.cost}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Jauge de temps clinique. La barre GLISSE vers sa nouvelle valeur au lieu de
/// sauter : c'est ce qui rend la dépense perceptible quand on vient de demander
/// un examen coûteux.
class _JaugeTemps extends StatelessWidget {
  const _JaugeTemps({required this.part, required this.serre});

  final double part;
  final bool serre;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: part.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      builder: (_, valeur, __) => LinearProgressIndicator(
        value: valeur,
        minHeight: 6,
        backgroundColor: const Color(0xFFE1E9EC),
        valueColor: AlwaysStoppedAnimation(
          serre ? const Color(0xFFD1543F) : const Color(0xFF2563A8),
        ),
      ),
    );
  }
}
