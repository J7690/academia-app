import 'dart:async';

import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';

import '../../../providers/prep_quiz_provider.dart';
import '../../../widgets/academia_rich_content.dart';
import '../../../providers/prep_flashcard_provider.dart';
import '../../../theme/prep_theme.dart';
import 'prep_scan_subject_screen.dart';

/// Onglet Quiz — QCM adaptatifs, examens blancs, flashcards.
class PrepQuizTab extends StatelessWidget {
  const PrepQuizTab({super.key});

  @override
  Widget build(BuildContext context) {
    final quizProvider = context.watch<PrepQuizProvider>();

    switch (quizProvider.status) {
      case QuizStatus.idle:
        return _QuizMenuView();
      case QuizStatus.inProgress:
        return _QuizPlayView();
      case QuizStatus.reviewing:
        return _QuizReviewView();
      case QuizStatus.completed:
        return _QuizResultsView();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// Menu — Choix du mode
// ═══════════════════════════════════════════════════════════════════
class _QuizMenuView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        FadeInDown(
          duration: const Duration(milliseconds: 400),
          child: _ModeCard(
            icon: Icons.bolt,
            title: 'Quiz rapide',
            subtitle: '10 questions · Tous sujets · ~5 min',
            gradient: PrepTheme.quizGradient,
            onTap: () => _startQuiz(context, count: 10),
          ),
        ),
        const SizedBox(height: 12),
        FadeInDown(
          delay: const Duration(milliseconds: 100),
          duration: const Duration(milliseconds: 400),
          child: _ModeCard(
            icon: Icons.psychology,
            title: 'Quiz adaptatif',
            subtitle: 'Questions ciblées sur tes faiblesses · Progression optimisée',
            gradient: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
            onTap: () => _startAdaptiveQuiz(context),
          ),
        ),
        const SizedBox(height: 12),
        FadeInDown(
          delay: const Duration(milliseconds: 200),
          duration: const Duration(milliseconds: 400),
          child: _ModeCard(
            icon: Icons.timer,
            title: 'Examen blanc',
            subtitle: '20 questions · 30 min · Mode concentration',
            gradient: PrepTheme.streakGradient,
            onTap: () => _startExam(context),
          ),
        ),
        const SizedBox(height: 12),
        FadeInDown(
          delay: const Duration(milliseconds: 300),
          duration: const Duration(milliseconds: 400),
          child: _ModeCard(
            icon: Icons.style,
            title: 'Flashcards',
            subtitle: 'Révision espacée · Mémorisation active',
            gradient: PrepTheme.successGradient,
            onTap: () => _openFlashcards(context),
          ),
        ),
        const SizedBox(height: 12),
        FadeInDown(
          delay: const Duration(milliseconds: 400),
          duration: const Duration(milliseconds: 400),
          child: _ModeCard(
            icon: Icons.document_scanner,
            title: 'Scanner un sujet',
            subtitle: 'Photo d\'un sujet → Réponses IA détaillées',
            gradient: const [Color(0xFF0891B2), Color(0xFF0E7490)],
            onTap: () => _openScanSubject(context),
          ),
        ),
        const SizedBox(height: 24),

        // ─── Sujets disponibles ────────────────────────────────
        FadeInUp(
          delay: const Duration(milliseconds: 300),
          duration: const Duration(milliseconds: 400),
          child: const Text(
            'Par matière',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: PrepTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        FadeInUp(
          delay: const Duration(milliseconds: 350),
          duration: const Duration(milliseconds: 400),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SubjectChip('Culture Générale', Icons.public, const Color(0xFF6366F1)),
              _SubjectChip('Mathématiques', Icons.calculate, const Color(0xFF0891B2)),
              _SubjectChip('Droit', Icons.gavel, const Color(0xFF7C3AED)),
              _SubjectChip('Histoire-Géo', Icons.map, const Color(0xFFEA580C)),
              _SubjectChip('Physique-Chimie', Icons.science, const Color(0xFF059669)),
              _SubjectChip('Biologie', Icons.biotech, const Color(0xFFDB2777)),
              _SubjectChip('Économie', Icons.trending_up, const Color(0xFFF59E0B)),
              _SubjectChip('Philosophie', Icons.psychology, const Color(0xFF64748B)),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ─── Concours cibles ───────────────────────────────────
        FadeInUp(
          delay: const Duration(milliseconds: 400),
          duration: const Duration(milliseconds: 400),
          child: const Text(
            'Concours',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: PrepTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        FadeInUp(
          delay: const Duration(milliseconds: 450),
          duration: const Duration(milliseconds: 400),
          child: _ConcoursGrid(),
        ),
      ],
    );
  }

  void _startQuiz(BuildContext context, {int count = 10, String? subject, String? concoursType}) {
    final provider = context.read<PrepQuizProvider>();
    provider.startQuizFromServer(count: count, subject: subject, concoursType: concoursType);
  }

  void _startAdaptiveQuiz(BuildContext context) {
    final provider = context.read<PrepQuizProvider>();
    provider.startQuizFromServer(
      count: 10,
      adaptiveMode: true,
    );
  }

  void _startExam(BuildContext context) {
    final provider = context.read<PrepQuizProvider>();
    provider.startQuizFromServer(
      count: 20,
      timeLimitSeconds: 30 * 60,
      examMode: true,
    );
  }

  void _openFlashcards(BuildContext context) {
    final provider = context.read<PrepFlashcardProvider>();
    provider.loadDemoCards();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const _FlashcardScreen()),
    );
  }

  void _openScanSubject(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PrepScanSubjectScreen()),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: PrepTheme.gradientBox(gradient, radius: 18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.8), fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.6), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _SubjectChip(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final provider = context.read<PrepQuizProvider>();
        provider.startQuizFromServer(subject: label, count: 10);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(PrepTheme.radiusFull),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _ConcoursGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final concours = [
      ('ENAREF', 'Régies financières', Icons.account_balance, const Color(0xFF7C3AED)),
      ('ADMIN_CIVIL', 'Administration', Icons.gavel, const Color(0xFF0891B2)),
      ('DOUANE', 'Douane', Icons.local_shipping, const Color(0xFFEA580C)),
      ('GREFFIERS', 'Justice', Icons.balance, const Color(0xFF059669)),
      ('SANTE', 'Santé', Icons.local_hospital, const Color(0xFF6366F1)),
      ('EDUCATION', 'Éducation', Icons.school, const Color(0xFFDB2777)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: concours.length,
      itemBuilder: (context, index) {
        final (name, sub, icon, color) = concours[index];
        return GestureDetector(
          onTap: () {
            final provider = context.read<PrepQuizProvider>();
            provider.startQuizFromServer(concoursType: name, count: 10);
          },
          child: Container(
            decoration: PrepTheme.cardBox(borderColor: color.withOpacity(0.2)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 8),
                Text(name,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                Text(sub,
                    style: const TextStyle(fontSize: 9, color: PrepTheme.textTertiary),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Quiz Play View — Question en cours
// ═══════════════════════════════════════════════════════════════════
class _QuizPlayView extends StatefulWidget {
  @override
  State<_QuizPlayView> createState() => _QuizPlayViewState();
}

class _QuizPlayViewState extends State<_QuizPlayView> {
  Timer? _timer;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    final provider = context.read<PrepQuizProvider>();
    if (provider.isExamMode && provider.remainingSeconds > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        provider.tickTimer();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrepQuizProvider>();
    final question = provider.currentQuestion;
    if (question == null) return const SizedBox.shrink();

    final progress = (provider.currentIndex + 1) / provider.questions.length;

    return Column(
      children: [
        // ─── Progress bar ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => _showQuitDialog(context, provider),
                    child: const Icon(Icons.close, color: PrepTheme.textTertiary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        builder: (_, value, __) => LinearProgressIndicator(
                          value: value,
                          backgroundColor: PrepTheme.divider,
                          valueColor: const AlwaysStoppedAnimation<Color>(PrepTheme.primary),
                          minHeight: 8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${provider.currentIndex + 1}/${provider.questions.length}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: PrepTheme.textSecondary,
                    ),
                  ),
                  if (provider.isExamMode) ...[
                    const SizedBox(width: 12),
                    _TimerBadge(seconds: provider.remainingSeconds),
                  ],
                ],
              ),
              if (question.subject.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: PrepTheme.chip(question.subject, PrepTheme.primary),
                ),
              ],
            ],
          ),
        ),

        // ─── Question ──────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                FadeInUp(
                  duration: const Duration(milliseconds: 350),
                  child: AcademiaRichContent(
                    content: question.content,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: PrepTheme.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ─── Options ─────────────────────────────────────
                ...List.generate(question.options.length, (i) {
                  final isSelected = _selectedIndex == i;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FadeInUp(
                      delay: Duration(milliseconds: 50 * i),
                      duration: const Duration(milliseconds: 350),
                      child: _OptionButton(
                        label: String.fromCharCode(65 + i),
                        text: question.options[i],
                        isSelected: isSelected,
                        onTap: () {
                          setState(() => _selectedIndex = i);
                          if (!provider.isExamMode) {
                            provider.answerQuestion(i);
                            _selectedIndex = null;
                          }
                        },
                      ),
                    ),
                  );
                }),

                // Exam mode: submit button
                if (provider.isExamMode && _selectedIndex != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PrepTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(PrepTheme.radiusMd),
                        ),
                      ),
                      onPressed: () {
                        provider.answerQuestion(_selectedIndex!);
                        setState(() => _selectedIndex = null);
                        if (provider.hasNext) {
                          provider.nextQuestion();
                        } else {
                          provider.finishExam();
                        }
                      },
                      child: Text(
                        provider.hasNext ? 'Question suivante' : 'Terminer l\'examen',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showQuitDialog(BuildContext context, PrepQuizProvider provider) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter le quiz ?'),
        content: const Text('Ta progression sur ce quiz sera perdue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Continuer'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              provider.resetQuiz();
            },
            child: const Text('Quitter', style: TextStyle(color: PrepTheme.danger)),
          ),
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String label;
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionButton({
    required this.label,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? PrepTheme.primary.withOpacity(0.08) : PrepTheme.cardBg,
          borderRadius: BorderRadius.circular(PrepTheme.radiusMd),
          border: Border.all(
            color: isSelected ? PrepTheme.primary : PrepTheme.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? PrepTheme.glowShadow(PrepTheme.primary) : PrepTheme.softShadow,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? PrepTheme.primary : PrepTheme.shimmer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : PrepTheme.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: AcademiaRichContent(
                content: text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: PrepTheme.textPrimary,
                  height: 1.3,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: PrepTheme.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

class _TimerBadge extends StatelessWidget {
  final int seconds;

  const _TimerBadge({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    final isLow = seconds < 120;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isLow ? PrepTheme.dangerSurface : PrepTheme.primarySurface,
        borderRadius: BorderRadius.circular(PrepTheme.radiusFull),
        border: Border.all(
          color: isLow ? PrepTheme.danger.withOpacity(0.3) : PrepTheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, size: 14, color: isLow ? PrepTheme.danger : PrepTheme.primary),
          const SizedBox(width: 4),
          Text(
            '$m:$s',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isLow ? PrepTheme.danger : PrepTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Review View — Après chaque réponse (mode non-examen)
// ═══════════════════════════════════════════════════════════════════
class _QuizReviewView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrepQuizProvider>();
    if (provider.answers.isEmpty) return const SizedBox.shrink();

    final lastAnswer = provider.answers.last;
    final question = provider.questions.firstWhere(
      (q) => q.id == lastAnswer.questionId,
      orElse: () => provider.questions.first,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // ─── Result icon ─────────────────────────────────────
          FadeInDown(
            duration: const Duration(milliseconds: 400),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: lastAnswer.isCorrect
                    ? PrepTheme.successSurface
                    : PrepTheme.dangerSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                lastAnswer.isCorrect ? Icons.check_circle : Icons.cancel,
                size: 48,
                color: lastAnswer.isCorrect ? PrepTheme.success : PrepTheme.danger,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeInUp(
            duration: const Duration(milliseconds: 400),
            child: Text(
              lastAnswer.isCorrect ? 'Bonne réponse ! 🎉' : 'Pas tout à fait…',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: lastAnswer.isCorrect ? PrepTheme.success : PrepTheme.danger,
              ),
            ),
          ),
          if (lastAnswer.isCorrect)
            FadeInUp(
              delay: const Duration(milliseconds: 100),
              duration: const Duration(milliseconds: 400),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: PrepTheme.xpBadge(20),
              ),
            ),
          const SizedBox(height: 24),

          // ─── Correct answer ──────────────────────────────────
          FadeInUp(
            delay: const Duration(milliseconds: 150),
            duration: const Duration(milliseconds: 400),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PrepTheme.successSurface,
                borderRadius: BorderRadius.circular(PrepTheme.radiusMd),
                border: Border.all(color: PrepTheme.success.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Réponse correcte',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: PrepTheme.success)),
                  const SizedBox(height: 6),
                  AcademiaRichContent(
                    content: question.options[question.correctIndex],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: PrepTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Explanation ─────────────────────────────────────
          if (question.explanation != null && question.explanation!.isNotEmpty) ...[
            const SizedBox(height: 16),
            FadeInUp(
              delay: const Duration(milliseconds: 250),
              duration: const Duration(milliseconds: 400),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: PrepTheme.cardBox(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: PrepTheme.primarySurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.lightbulb, color: PrepTheme.primary, size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Text('Explication',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: PrepTheme.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AcademiaRichContent(
                      content: question.explanation!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: PrepTheme.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ─── Next button ─────────────────────────────────────
          FadeInUp(
            delay: const Duration(milliseconds: 350),
            duration: const Duration(milliseconds: 400),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: PrepTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PrepTheme.radiusMd),
                  ),
                  elevation: 0,
                ),
                onPressed: () => provider.nextQuestion(),
                child: Text(
                  provider.hasNext ? 'Question suivante →' : 'Voir les résultats',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Results View — Score final
// ═══════════════════════════════════════════════════════════════════
class _QuizResultsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrepQuizProvider>();
    final pct = provider.scorePercent;
    final correct = provider.correctCount;
    final total = provider.questions.length;

    Color scoreColor;
    String emoji;
    String message;
    if (pct >= 0.9) {
      scoreColor = PrepTheme.success;
      emoji = '🏆';
      message = 'Exceptionnel ! Tu maîtrises le sujet.';
    } else if (pct >= 0.7) {
      scoreColor = PrepTheme.primary;
      emoji = '💪';
      message = 'Très bien ! Continue comme ça.';
    } else if (pct >= 0.5) {
      scoreColor = PrepTheme.accent;
      emoji = '📚';
      message = 'Pas mal ! Révise les points faibles.';
    } else {
      scoreColor = PrepTheme.coral;
      emoji = '🔄';
      message = 'Courage ! La répétition est la clé.';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // ─── Score circle ────────────────────────────────────
          FadeInDown(
            duration: const Duration(milliseconds: 500),
            child: SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: pct),
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeOutCubic,
                      builder: (_, value, __) => CircularProgressIndicator(
                        value: value,
                        strokeWidth: 10,
                        backgroundColor: scoreColor.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 4),
                      Text(
                        '${(pct * 100).round()}%',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: scoreColor,
                        ),
                      ),
                      Text(
                        '$correct/$total',
                        style: const TextStyle(
                          fontSize: 13,
                          color: PrepTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FadeInUp(
            duration: const Duration(milliseconds: 400),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: PrepTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          FadeInUp(
            delay: const Duration(milliseconds: 100),
            duration: const Duration(milliseconds: 400),
            child: PrepTheme.xpBadge(provider.isExamMode ? 50 : 20),
          ),
          const SizedBox(height: 32),

          // ─── Actions ─────────────────────────────────────────
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            duration: const Duration(milliseconds: 400),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PrepTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(PrepTheme.radiusMd),
                      ),
                      side: const BorderSide(color: PrepTheme.primary),
                    ),
                    onPressed: () => provider.resetQuiz(),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Menu', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PrepTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(PrepTheme.radiusMd),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      provider.resetQuiz();
                      final questions = PrepQuizProvider.generateDemoQuestions(count: 10);
                      provider.startQuiz(questions: questions);
                    },
                    icon: const Icon(Icons.replay, size: 18),
                    label: const Text('Rejouer', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Flashcard Screen
// ═══════════════════════════════════════════════════════════════════
class _FlashcardScreen extends StatelessWidget {
  const _FlashcardScreen();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrepFlashcardProvider>();
    final card = provider.currentCard;

    return Scaffold(
      backgroundColor: PrepTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Flashcards · ${provider.reviewedToday} révisées',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: PrepTheme.textPrimary,
      ),
      body: provider.isSessionComplete || card == null
          ? _buildSessionComplete(context, provider)
          : _buildCard(context, provider, card),
    );
  }

  Widget _buildSessionComplete(BuildContext context, PrepFlashcardProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeInDown(
              duration: const Duration(milliseconds: 500),
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: PrepTheme.successSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: PrepTheme.success, size: 48),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Session terminée ! 🎉',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '${provider.reviewedToday} carte(s) révisée(s)',
              style: const TextStyle(color: PrepTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: PrepTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PrepTheme.radiusMd),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Retour'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, PrepFlashcardProvider provider, PrepFlashcard card) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Progress
          LinearProgressIndicator(
            value: provider.dueCards.isEmpty
                ? 0
                : provider.currentIndex / provider.dueCards.length,
            backgroundColor: PrepTheme.divider,
            valueColor: const AlwaysStoppedAnimation<Color>(PrepTheme.success),
            minHeight: 4,
          ),
          const SizedBox(height: 8),
          PrepTheme.chip(card.subject, PrepTheme.primary),
          const SizedBox(height: 16),

          // Card
          Expanded(
            child: GestureDetector(
              onTap: () => provider.flipCard(),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: Container(
                  key: ValueKey(provider.isFlipped),
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: provider.isFlipped
                          ? [const Color(0xFFECFDF5), const Color(0xFFF0FDF4)]
                          : [const Color(0xFFEFF6FF), const Color(0xFFF0F9FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: provider.isFlipped
                          ? PrepTheme.success.withOpacity(0.2)
                          : PrepTheme.primary.withOpacity(0.2),
                    ),
                    boxShadow: PrepTheme.softShadow,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        provider.isFlipped ? Icons.lightbulb : Icons.help_outline,
                        size: 32,
                        color: provider.isFlipped ? PrepTheme.success : PrepTheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        provider.isFlipped ? 'Réponse' : 'Question',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: provider.isFlipped
                              ? PrepTheme.success
                              : PrepTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AcademiaRichContent(
                        content: provider.isFlipped ? card.back : card.front,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: PrepTheme.textPrimary,
                          height: 1.5,
                        ),
                      ),
                      if (!provider.isFlipped) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Touche pour voir la réponse',
                          style: TextStyle(
                            fontSize: 12,
                            color: PrepTheme.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Rating buttons (only when flipped)
          if (provider.isFlipped) ...[
            const SizedBox(height: 16),
            FadeInUp(
              duration: const Duration(milliseconds: 300),
              child: Row(
                children: [
                  _RatingButton(
                    label: 'À revoir',
                    icon: Icons.replay,
                    color: PrepTheme.danger,
                    onTap: () => provider.reviewCurrent(1),
                  ),
                  const SizedBox(width: 8),
                  _RatingButton(
                    label: 'Difficile',
                    icon: Icons.sentiment_neutral,
                    color: PrepTheme.coral,
                    onTap: () => provider.reviewCurrent(3),
                  ),
                  const SizedBox(width: 8),
                  _RatingButton(
                    label: 'Bien',
                    icon: Icons.thumb_up,
                    color: PrepTheme.primary,
                    onTap: () => provider.reviewCurrent(4),
                  ),
                  const SizedBox(width: 8),
                  _RatingButton(
                    label: 'Facile',
                    icon: Icons.star,
                    color: PrepTheme.success,
                    onTap: () => provider.reviewCurrent(5),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RatingButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(PrepTheme.radiusMd),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
