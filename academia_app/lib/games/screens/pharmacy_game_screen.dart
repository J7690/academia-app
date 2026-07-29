import 'dart:async';

import 'package:flutter/material.dart';

import '../services/pharmacy_service.dart';

/// « Le comptoir » — servir les clients d'une officine.
///
/// Ce n'est pas un questionnaire : on fait GLISSER les boîtes du rayon vers le
/// comptoir, la file d'attente s'allonge pendant qu'on réfléchit, et une même
/// boîte peut être la bonne réponse chez un client et une faute chez le suivant.
class PharmacyGameScreen extends StatefulWidget {
  const PharmacyGameScreen({super.key});

  @override
  State<PharmacyGameScreen> createState() => _PharmacyGameScreenState();
}

class _PharmacyGameScreenState extends State<PharmacyGameScreen> {
  static const _teal = Color(0xFF0D8B8B);
  static const _corail = Color(0xFFD1543F);

  PharmacyShift? _service;
  PharmacyReport? _rapport;
  int _index = 0;
  final Map<String, List<String>> _delivre = {};
  DateTime? _debut;
  bool _chargement = true;
  bool _envoi = false;

  /// Nombre de clients qui patientent derrière. Purement visuel, mais c'est ce
  /// qui met la pression : on voit la file grossir pendant qu'on hésite.
  int _attente = 0;
  Timer? _fileTimer;

  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  @override
  void dispose() {
    _fileTimer?.cancel();
    super.dispose();
  }

  Future<void> _demarrer() async {
    setState(() => _chargement = true);
    final s = await PharmacyService.start();
    if (!mounted) return;

    if (s == null || s.cases.isEmpty) {
      setState(() => _chargement = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun client disponible pour le moment.')),
      );
      return;
    }

    setState(() {
      _service = s;
      _index = 0;
      _delivre.clear();
      _rapport = null;
      _debut = DateTime.now();
      _chargement = false;
      _attente = 0;
    });

    // Un client de plus toutes les 20 secondes : assez lent pour laisser
    // réfléchir, assez visible pour qu'on sente le temps passer.
    _fileTimer?.cancel();
    _fileTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _attente++);
    });
  }

  PharmacyCase get _cas => _service!.cases[_index];
  List<String> get _panier => _delivre[_cas.id] ?? const [];

  void _basculer(String code) {
    setState(() {
      final courant = List<String>.from(_delivre[_cas.id] ?? const []);
      if (courant.contains(code)) {
        courant.remove(code);
      } else {
        courant.add(code);
      }
      _delivre[_cas.id] = courant;
    });
  }

  Future<void> _clientSuivant() async {
    // Servir fait avancer la file : c'est la récompense visible du rythme.
    if (_attente > 0) setState(() => _attente--);

    if (_index + 1 < _service!.cases.length) {
      setState(() => _index++);
      return;
    }

    _fileTimer?.cancel();
    setState(() => _envoi = true);
    final rapport = await PharmacyService.submit(
      roundId: _service!.roundId,
      delivered: _delivre,
      elapsedMs: _debut == null
          ? null
          : DateTime.now().difference(_debut!).inMilliseconds,
    );
    if (!mounted) return;

    if (rapport == null) {
      setState(() => _envoi = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ton service n\'a pas pu être envoyé. Réessaie.')),
      );
      return;
    }
    setState(() {
      _rapport = rapport;
      _envoi = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FA),
      appBar: AppBar(
        title: const Text('Le comptoir'),
        backgroundColor: _teal,
        foregroundColor: Colors.white,
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : _rapport != null
              ? _vueRapport()
              : _service == null
                  ? _vueIndisponible()
                  : _vueService(),
    );
  }

  Widget _vueIndisponible() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 14),
              const Text('Officine fermée',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Aucun cas n\'est disponible pour le moment.',
                  style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  // ── Le service ────────────────────────────────────────────────────────────
  Widget _vueService() {
    final total = _service!.cases.length;

    return Column(
      children: [
        _bandeauFile(total),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: [
              _client(),
              if (_cas.hasPrescription) ...[
                const SizedBox(height: 12),
                _ordonnance(),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Le rayon',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                  const SizedBox(width: 8),
                  Text('touche pour poser sur le comptoir',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                ],
              ),
              const SizedBox(height: 8),
              ..._cas.shelf.map(_boite),
              const SizedBox(height: 16),
              _comptoir(),
            ],
          ),
        ),
        _barreAction(total),
      ],
    );
  }

  /// La file d'attente : des silhouettes qui s'accumulent. C'est le seul élément
  /// qui bouge tout seul, et c'est lui qui crée la tension.
  Widget _bandeauFile(int total) {
    final tendu = _attente >= 3;
    return Container(
      color: tendu ? _corail.withValues(alpha: 0.10) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text('Client ${_index + 1} / $total',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: Row(
              key: ValueKey(_attente),
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _attente.clamp(0, 5); i++)
                  Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: Icon(Icons.person,
                        size: 19,
                        color: tendu ? _corail : Colors.grey.shade500),
                  ),
                if (_attente > 5)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text('+${_attente - 5}',
                        style: const TextStyle(
                            color: _corail, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                if (_attente == 0)
                  Text('personne n\'attend',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _client() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _teal.withValues(alpha: 0.13),
            ),
            child: const Icon(Icons.person, color: _teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('« ${_cas.customerLine} »',
                    style: const TextStyle(fontSize: 16, height: 1.4)),
                if (!_cas.hasPrescription) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB07D16).withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Pas d\'ordonnance',
                        style: TextStyle(
                            color: Color(0xFFB07D16),
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// L'ordonnance, présentée comme un papier plutôt que comme une liste : le
  /// support fait partie de ce qu'on apprend à lire.
  Widget _ordonnance() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6DFC8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, size: 17, color: Color(0xFF8A7B4A)),
              const SizedBox(width: 6),
              Text('ORDONNANCE',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                      color: Colors.brown.shade400)),
            ],
          ),
          const SizedBox(height: 10),
          ..._cas.prescription.map(
            (l) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('•  $l',
                  style: const TextStyle(fontSize: 15, height: 1.35, color: Color(0xFF3A3428))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _boite(ShelfItem item) {
    final pose = _panier.contains(item.code);
    return GestureDetector(
      onTap: () => _basculer(item.code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: pose ? _teal.withValues(alpha: 0.10) : Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: pose ? _teal : const Color(0xFFDDE6E9),
            width: pose ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.medication_outlined,
                color: pose ? _teal : Colors.grey.shade500, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  if (item.detail.isNotEmpty)
                    Text(item.detail,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                ],
              ),
            ),
            Icon(pose ? Icons.check_circle : Icons.add_circle_outline,
                color: pose ? _teal : Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  /// Le comptoir : ce qu'on s'apprête à délivrer. Vide, il rappelle qu'on peut
  /// aussi ne rien délivrer — c'est parfois la bonne réponse.
  Widget _comptoir() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7E4E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SUR LE COMPTOIR',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: Colors.blueGrey.shade400)),
          const SizedBox(height: 8),
          if (_panier.isEmpty)
            Text('Rien pour l\'instant — ne rien délivrer est parfois la bonne décision.',
                style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13.5))
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final code in _panier)
                  Chip(
                    label: Text(
                      _cas.shelf.firstWhere((s) => s.code == code,
                          orElse: () => ShelfItem(code: code, label: code, detail: '')).label,
                    ),
                    backgroundColor: Colors.white,
                    onDeleted: () => _basculer(code),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _barreAction(int total) {
    final dernier = _index + 1 == total;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 50,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _envoi ? null : _clientSuivant,
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
            ),
            child: _envoi
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(
                    _panier.isEmpty
                        ? (dernier ? 'Ne rien délivrer et terminer' : 'Ne rien délivrer')
                        : (dernier ? 'Délivrer et terminer' : 'Délivrer'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ),
    );
  }

  // ── Le débrief ────────────────────────────────────────────────────────────
  Widget _vueRapport() {
    final r = _rapport!;
    final aDuNonValide = r.cases.any((c) => !c.isValidated);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: BorderSide(
                color: r.score == r.total ? _teal : _corail,
                width: 5,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${r.score} client${r.score > 1 ? 's' : ''} sur ${r.total} bien servi${r.score > 1 ? 's' : ''}',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: r.score == r.total ? _teal : _corail)),
              const SizedBox(height: 6),
              const Text(
                'Un client n\'est bien servi que si tout le nécessaire est délivré '
                'et que rien de dangereux ne l\'est.',
                style: TextStyle(color: Colors.black54, fontSize: 13.5),
              ),
            ],
          ),
        ),
        if (aDuNonValide) ...[
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
                    'Contenu en cours de validation par un pharmacien. À utiliser '
                    'pour s\'entraîner, pas comme référence pour la pratique.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF8A6212), height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        const Text('Ce qu\'il fallait faire',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...r.cases.map(_ficheCas),
        const SizedBox(height: 20),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _demarrer,
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal, foregroundColor: Colors.white),
            child: const Text('Nouveau service',
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

  Widget _ficheCas(PharmacyCaseResult c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(c.isCorrect ? Icons.check_circle : Icons.cancel,
                  color: c.isCorrect ? _teal : _corail, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(c.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (c.shouldDeliver.isEmpty)
            const Text('À délivrer : rien',
                style: TextStyle(color: _teal, fontSize: 13.5, fontWeight: FontWeight.w600))
          else
            Text('À délivrer : ${c.shouldDeliver.join(', ')}',
                style: const TextStyle(
                    color: _teal, fontSize: 13.5, fontWeight: FontWeight.w600)),
          if (c.shouldRefuse.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text('À refuser : ${c.shouldRefuse.join(', ')}',
                style: const TextStyle(
                    color: _corail, fontSize: 13.5, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 9),
          Text(c.explanation,
              style: const TextStyle(color: Colors.black54, fontSize: 13.5, height: 1.45)),
        ],
      ),
    );
  }
}
