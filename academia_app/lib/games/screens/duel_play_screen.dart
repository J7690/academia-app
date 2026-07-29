import 'dart:async';

import 'package:flutter/material.dart';

import '../services/duel_service.dart';

/// La manche de duel : une question à la fois, chronométrée.
///
/// Le chrono court par question. À l'expiration, la question est comptée comme
/// non répondue (choix -1) et on enchaîne : le duel ne peut pas rester bloqué
/// parce que quelqu'un a posé son téléphone.
class DuelPlayScreen extends StatefulWidget {
  const DuelPlayScreen({super.key, required this.round});

  final DuelRound round;

  @override
  State<DuelPlayScreen> createState() => _DuelPlayScreenState();
}

class _DuelPlayScreenState extends State<DuelPlayScreen> {
  static const _vert = Color(0xFF1EA75C);

  int _index = 0;
  int _restant = 0;
  int? _choix;
  Timer? _chrono;
  final _reponses = <DuelAnswer>[];
  final _depart = DateTime.now();
  bool _envoiEnCours = false;

  DuelQuestion get _q => widget.round.questions[_index];

  @override
  void initState() {
    super.initState();
    _demarrerQuestion();
  }

  @override
  void dispose() {
    _chrono?.cancel();
    super.dispose();
  }

  void _demarrerQuestion() {
    _chrono?.cancel();
    setState(() {
      _choix = null;
      _restant = _q.seconds;
    });
    _chrono = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _restant--);
      if (_restant <= 0) {
        _chrono?.cancel();
        _valider(expire: true);
      }
    });
  }

  Future<void> _valider({bool expire = false}) async {
    _chrono?.cancel();
    _reponses.add(DuelAnswer(
      questionId: _q.id,
      choice: expire ? -1 : (_choix ?? -1),
    ));

    if (_index + 1 < widget.round.questions.length) {
      setState(() => _index++);
      _demarrerQuestion();
      return;
    }

    setState(() => _envoiEnCours = true);
    final resultat = await DuelService.submit(
      duelId: widget.round.duelId,
      answers: _reponses,
      elapsedMs: DateTime.now().difference(_depart).inMilliseconds,
    );

    if (!mounted) return;

    if (resultat == null) {
      setState(() => _envoiEnCours = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tes réponses n\'ont pas pu être envoyées. Vérifie ta connexion.'),
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DuelResultScreen(
          result: resultat,
          subject: widget.round.subject,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.round.questions.length;
    final urgent = _restant <= 5;

    return PopScope(
      // Quitter en pleine manche ferait perdre les réponses déjà données sans
      // que rien ne soit enregistré : on demande confirmation.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final quitter = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Abandonner le duel ?'),
            content: const Text('Tes réponses ne seront pas enregistrées.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Continuer'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Abandonner'),
              ),
            ],
          ),
        );
        if (quitter == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF101A14),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(widget.round.subject),
        ),
        body: _envoiEnCours
            ? const Center(child: CircularProgressIndicator(color: _vert))
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Question ${_index + 1} / $total',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          Text(
                            '$_restant s',
                            style: TextStyle(
                              color: urgent ? Colors.orangeAccent : Colors.white70,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _q.seconds == 0 ? 0 : _restant / _q.seconds,
                          minHeight: 4,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation(
                            urgent ? Colors.orangeAccent : _vert,
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      Text(
                        _q.question,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _q.options.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _choixTuile(i),
                        ),
                      ),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _choix == null ? null : () => _valider(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _vert,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.white12,
                            disabledForegroundColor: Colors.white38,
                          ),
                          child: Text(
                            _index + 1 == total ? 'Terminer' : 'Valider',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _choixTuile(int i) {
    final actif = _choix == i;
    return GestureDetector(
      onTap: () => setState(() => _choix = i),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: actif ? _vert.withValues(alpha: 0.18) : Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: actif ? _vert : Colors.white24,
            width: actif ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: actif ? _vert : Colors.white12,
              ),
              child: Text(
                String.fromCharCode(65 + i), // A, B, C, D
                style: TextStyle(
                  color: actif ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _q.options[i],
                style: const TextStyle(color: Colors.white, fontSize: 15.5, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le résultat d'une manche, avec la correction question par question.
///
/// La correction n'est pas un bonus : c'est ce qui fait la différence entre un
/// jeu et une révision. Chaque question ratée affiche la bonne réponse et son
/// explication.
class DuelResultScreen extends StatelessWidget {
  const DuelResultScreen({super.key, required this.result, required this.subject});

  final DuelResult result;
  final String subject;

  static const _vert = Color(0xFF1EA75C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Résultat'),
        backgroundColor: _vert,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _entete(),
          const SizedBox(height: 18),
          const Text('Correction', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...result.corrections.map(_correction),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              style: ElevatedButton.styleFrom(
                backgroundColor: _vert,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retour', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _entete() {
    final String titre;
    final Color couleur;
    if (!result.isFinished) {
      titre = 'En attente de ton adversaire';
      couleur = const Color(0xFF2D9CDB);
    } else if (result.isWinner == true) {
      titre = 'Duel remporté';
      couleur = _vert;
    } else if (result.isWinner == false) {
      titre = 'Duel perdu';
      couleur = const Color(0xFFB23A2B);
    } else {
      titre = 'Match nul';
      couleur = const Color(0xFFB8892B);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: couleur, width: 5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: couleur)),
          const SizedBox(height: 6),
          Text(subject, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          Text(
            'Ton score : ${result.score} / ${result.total}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          if (result.isFinished &&
              result.creatorScore != null &&
              result.opponentScore != null) ...[
            const SizedBox(height: 4),
            Text(
              'Duel : ${result.creatorScore} — ${result.opponentScore}',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
          if (!result.isFinished) ...[
            const SizedBox(height: 8),
            const Text(
              'Ton défi reste ouvert : le premier qui le relève sera ton adversaire.',
              style: TextStyle(color: Colors.black54, fontSize: 13.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _correction(DuelCorrection c) {
    final bonneReponse = (c.correctIndex >= 0 && c.correctIndex < c.options.length)
        ? c.options[c.correctIndex]
        : '—';

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                c.isCorrect ? Icons.check_circle : Icons.cancel,
                color: c.isCorrect ? _vert : const Color(0xFFB23A2B),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  c.question,
                  style: const TextStyle(fontWeight: FontWeight.w600, height: 1.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!c.isCorrect) ...[
            Text(
              c.chosen < 0
                  ? 'Pas de réponse (temps écoulé)'
                  : 'Ta réponse : ${c.chosen < c.options.length ? c.options[c.chosen] : '—'}',
              style: const TextStyle(color: Color(0xFFB23A2B), fontSize: 13.5),
            ),
            const SizedBox(height: 2),
          ],
          Text(
            'Bonne réponse : $bonneReponse',
            style: const TextStyle(color: _vert, fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
          if (c.explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              c.explanation,
              style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}
