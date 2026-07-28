import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/orientation_quiz_provider.dart';
import '../../theme/academia_palette.dart';
import '../../widgets/academia_motion.dart';
import '../../widgets/academia_ui.dart';

/// Déroulé du test d'orientation.
///
/// Une question par écran : c'est ce qui donne le sentiment d'avancer vite.
/// Chaque réponse est enregistrée immédiatement côté serveur — si l'étudiant
/// quitte l'app au milieu, il reprend exactement où il s'était arrêté.
class OrientationQuizScreen extends StatefulWidget {
  const OrientationQuizScreen({super.key});

  @override
  State<OrientationQuizScreen> createState() => _OrientationQuizScreenState();
}

class _OrientationQuizScreenState extends State<OrientationQuizScreen> {
  static const _accent = AcademiaPalette.teal;

  final PageController _pages = PageController();
  int _index = 0;
  String? _pending;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<OrientationQuizProvider>();
      final start = provider.resumeIndex;
      if (start > 0 && mounted) {
        setState(() => _index = start);
        _pages.jumpToPage(start);
      }
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _choose(
    OrientationQuizProvider provider,
    Map<String, dynamic> question,
    Map<String, dynamic> option,
  ) async {
    final optionId = '${option['id']}';
    setState(() => _pending = optionId);

    final done = await provider.answer(
      questionId: '${question['id']}',
      optionId: optionId,
    );

    if (!mounted) return;

    // Court temps d'arrêt : l'étudiant voit sa réponse sélectionnée avant que
    // l'écran ne change. Sans lui, le passage paraît accidentel.
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    setState(() => _pending = null);

    final isLast = _index >= provider.questions.length - 1;

    if (done && isLast) {
      await _finish(provider);
      return;
    }

    if (!isLast) {
      setState(() => _index += 1);
      _pages.animateToPage(
        _index,
        duration: AcademiaMotion.fast,
        curve: Curves.easeOutCubic,
      );
    } else {
      // Dernière question atteinte mais des trous plus haut : on y renvoie.
      final next = provider.resumeIndex;
      setState(() => _index = next);
      _pages.animateToPage(
        next,
        duration: AcademiaMotion.fast,
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _finish(OrientationQuizProvider provider) async {
    final ok = await provider.submit();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Calcul du résultat impossible.'),
          backgroundColor: AcademiaPalette.live,
        ),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  void _back() {
    if (_index == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _index -= 1);
    _pages.animateToPage(
      _index,
      duration: AcademiaMotion.fast,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrientationQuizProvider>(
      builder: (context, provider, _) {
        final questions = provider.questions;

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: AcademiaPalette.skyBackground,
            ),
            child: SafeArea(
              child: questions.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: _accent),
                    )
                  : Column(
                      children: [
                        _topBar(questions.length),
                        Expanded(
                          child: PageView.builder(
                            controller: _pages,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: questions.length,
                            onPageChanged: (i) => setState(() => _index = i),
                            itemBuilder: (context, i) =>
                                _questionPage(provider, questions[i], i),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _topBar(int count) {
    final value = count == 0 ? 0.0 : (_index + 1) / count;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: _back,
            icon: const Icon(Icons.arrow_back_rounded,
                color: AcademiaPalette.ink),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value),
                duration: AcademiaMotion.base,
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.6),
                  valueColor: const AlwaysStoppedAnimation(_accent),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${_index + 1}/$count',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AcademiaPalette.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionPage(
    OrientationQuizProvider provider,
    Map<String, dynamic> question,
    int position,
  ) {
    final options = OrientationQuizProvider.optionsOf(question);
    final saved = provider.answers['${question['id']}'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        AcademiaEntrance(
          key: ValueKey('enonce-$position'),
          child: Text(
            '${question['enonce']}',
            style: const TextStyle(
              fontSize: 22,
              height: 1.3,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AcademiaPalette.ink,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Il n’y a pas de bonne réponse — réponds spontanément.',
          style: TextStyle(fontSize: 12.5, color: AcademiaPalette.muted),
        ),
        const SizedBox(height: 20),
        ...options.asMap().entries.map((entry) {
          final option = entry.value;
          final id = '${option['id']}';
          final selected = _pending == id || (_pending == null && saved == id);
          return AcademiaEntrance(
            key: ValueKey('opt-$position-${entry.key}'),
            index: entry.key + 1,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AcademiaTapScale(
                onTap: provider.isSaving
                    ? null
                    : () => _choose(provider, question, option),
                child: AnimatedContainer(
                  duration: AcademiaMotion.fast,
                  curve: Curves.easeOutCubic,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  decoration: BoxDecoration(
                    color: selected
                        ? _accent.withValues(alpha: 0.10)
                        : AcademiaPalette.surface,
                    borderRadius:
                        BorderRadius.circular(AcademiaPalette.rLg),
                    border: Border.all(
                      color: selected ? _accent : AcademiaPalette.border,
                      width: selected ? 1.6 : 1,
                    ),
                    boxShadow: selected
                        ? AcademiaPalette.shadowAccent(_accent)
                        : AcademiaPalette.shadowSoft,
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: AcademiaMotion.fast,
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? _accent : Colors.transparent,
                          border: Border.all(
                            color: selected
                                ? _accent
                                : AcademiaPalette.borderStrong,
                            width: 2,
                          ),
                        ),
                        child: selected
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Text(
                          '${option['libelle']}',
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.35,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected
                                ? AcademiaPalette.teal
                                : AcademiaPalette.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        if (provider.answered >= provider.total && provider.total > 0) ...[
          const SizedBox(height: 8),
          AcademiaTapScale(
            onTap: provider.isSaving ? null : () => _finish(provider),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AcademiaPalette.shadowAccent(_accent),
              ),
              child: const Text(
                'Voir mon résultat',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Carte de résultat — profil et trois pistes, réutilisée dans l'onglet.
class OrientationQuizResultCard extends StatelessWidget {
  const OrientationQuizResultCard({
    super.key,
    required this.result,
    required this.onTalkToCounselor,
    required this.onRetake,
  });

  final Map<String, dynamic> result;
  final VoidCallback onTalkToCounselor;
  final VoidCallback onRetake;

  static const _accent = AcademiaPalette.teal;

  @override
  Widget build(BuildContext context) {
    final profil = result['profil'] as Map? ?? const {};
    final pistes = (result['pistes'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AcademiaPalette.surface,
        borderRadius: BorderRadius.circular(AcademiaPalette.rXl),
        border: Border.all(color: AcademiaPalette.border),
        boxShadow: AcademiaPalette.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(gradient: AcademiaPalette.cool),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TON PROFIL',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${profil['libelle'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${profil['description'] ?? ''}',
                  style: TextStyle(
                    fontSize: 11.8,
                    height: 1.45,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                ...pistes.asMap().entries.map(
                      (e) => AcademiaEntrance(
                        index: e.key,
                        child: _piste(e.key, e.value,
                            isLast: e.key == pistes.length - 1),
                      ),
                    ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: AcademiaTapScale(
                        onTap: onTalkToCounselor,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(11),
                            boxShadow: AcademiaPalette.shadowAccent(_accent),
                          ),
                          child: const Text(
                            'En parler à un conseiller',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AcademiaTapScale(
                        onTap: onRetake,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AcademiaPalette.surface,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: _accent, width: 1.5),
                          ),
                          child: const Text(
                            'Refaire',
                            style: TextStyle(
                              color: _accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _piste(int rank, Map<String, dynamic> piste, {required bool isLast}) {
    const colors = [
      AcademiaPalette.teal,
      AcademiaPalette.blue,
      AcademiaPalette.amber,
    ];
    final color = colors[rank % colors.length];
    final pct = (piste['pct'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AcademiaPalette.border),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '${rank + 1}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${piste['domaine'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AcademiaPalette.ink,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${piste['sous_titre'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AcademiaPalette.faint,
                  ),
                ),
              ],
            ),
          ),
          AcademiaCountUp(
            value: pct,
            suffix: ' %',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
