import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../../../providers/prep_quiz_provider.dart';
import '../../../providers/prep_weakness_provider.dart';
import '../../../theme/prep_theme.dart';
import '../../../widgets/adaptive_dialog.dart';
import 'psychotech/psychotech_profile_widget.dart';
import 'prep_progress_dashboard.dart';

/// Onglet Stats — Analytics de progression, forces/faiblesses, historique.
class PrepStatsTab extends StatefulWidget {
  const PrepStatsTab({super.key});

  @override
  State<PrepStatsTab> createState() => _PrepStatsTabState();
}

class _PrepStatsTabState extends State<PrepStatsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrepWeaknessProvider>().loadWeaknessAnalysis();
    });
  }

  @override
  Widget build(BuildContext context) {
    final quizProvider = context.watch<PrepQuizProvider>();
    final weaknessProvider = context.watch<PrepWeaknessProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        // ─── Score global ────────────────────────────────────────
        FadeInDown(
          duration: const Duration(milliseconds: 400),
          child: _GlobalScoreCard(
            totalAnswered: quizProvider.totalAnswered,
            totalCorrect: quizProvider.totalCorrect,
            xp: quizProvider.totalXp,
            streak: quizProvider.currentStreak,
          ),
        ),
        const SizedBox(height: 16),

        // ─── Bouton Dashboard adaptatif ───────────────────────────
        FadeInDown(
          delay: const Duration(milliseconds: 50),
          duration: const Duration(milliseconds: 400),
          child: _AdaptiveDashboardButton(
            weaknessProvider: weaknessProvider,
          ),
        ),
        const SizedBox(height: 16),

        // ─── Graphique de progression ────────────────────────────
        FadeInUp(
          delay: const Duration(milliseconds: 100),
          duration: const Duration(milliseconds: 400),
          child: const _ProgressChart(),
        ),
        const SizedBox(height: 16),

        // ─── Forces / Faiblesses ─────────────────────────────────
        FadeInUp(
          delay: const Duration(milliseconds: 200),
          duration: const Duration(milliseconds: 400),
          child: const _SubjectBreakdown(),
        ),
        const SizedBox(height: 16),

        // ─── Profil Psychotechnique ────────────────────────────────
        FadeInUp(
          delay: const Duration(milliseconds: 300),
          duration: const Duration(milliseconds: 400),
          child: const PsychotechProfileWidget(compact: true),
        ),
        const SizedBox(height: 16),

        // ─── Badges ──────────────────────────────────────────────
        FadeInUp(
          delay: const Duration(milliseconds: 400),
          duration: const Duration(milliseconds: 400),
          child: _BadgesSection(
            totalCorrect: quizProvider.totalCorrect,
            totalAnswered: quizProvider.totalAnswered,
            streak: quizProvider.longestStreak,
            xp: quizProvider.totalXp,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Adaptive Dashboard Button
// ═══════════════════════════════════════════════════════════════════
class _AdaptiveDashboardButton extends StatelessWidget {
  final PrepWeaknessProvider weaknessProvider;

  const _AdaptiveDashboardButton({required this.weaknessProvider});

  @override
  Widget build(BuildContext context) {
    final hasWeaknesses = weaknessProvider.weakestSubjects.isNotEmpty;
    final primaryWeakness = weaknessProvider.primaryWeakness;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PrepProgressDashboard()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.psychology, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tableau de bord adaptatif',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasWeaknesses && primaryWeakness != null
                        ? 'Focus: ${primaryWeakness.subjectName} (${primaryWeakness.successRate.toStringAsFixed(0)}%)'
                        : 'Passe des quiz pour activer l\'analyse',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.6), size: 16),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Global Score Card
// ═══════════════════════════════════════════════════════════════════
class _GlobalScoreCard extends StatelessWidget {
  final int totalAnswered;
  final int totalCorrect;
  final int xp;
  final int streak;

  const _GlobalScoreCard({
    required this.totalAnswered,
    required this.totalCorrect,
    required this.xp,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final accuracy = totalAnswered > 0
        ? ((totalCorrect / totalAnswered) * 100).round()
        : 0;
    final level = (xp / 100).floor() + 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: PrepTheme.gradientBox(PrepTheme.headerGradient, radius: 20),
      child: Column(
        children: [
          Row(
            children: [
              // Score circle
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: accuracy / 100,
                        strokeWidth: 6,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(PrepTheme.accentLight),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$accuracy%',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const Text(
                          'Précision',
                          style: TextStyle(fontSize: 10, color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Niveau $level',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _MiniStat(Icons.bolt, '$xp XP'),
                        const SizedBox(width: 12),
                        _MiniStat(Icons.check_circle, '$totalCorrect/$totalAnswered'),
                        const SizedBox(width: 12),
                        _MiniStat(Icons.local_fire_department, '$streak 🔥'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // XP bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (xp % 100) / 100,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(PrepTheme.accentLight),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${xp % 100}/100 XP → Niveau ${level + 1}',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;

  const _MiniStat(this.icon, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(width: 4),
        Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Progress Chart (7 derniers jours simulé)
// ═══════════════════════════════════════════════════════════════════
class _ProgressChart extends StatelessWidget {
  const _ProgressChart();

  @override
  Widget build(BuildContext context) {
    // Demo data — will be replaced by real data from Supabase
    final days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final scores = [65.0, 72.0, 68.0, 80.0, 75.0, 85.0, 78.0];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: PrepTheme.cardBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: PrepTheme.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.show_chart, color: PrepTheme.primary, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Progression (7 jours)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: PrepTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.round()}%',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= days.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            days[idx],
                            style: const TextStyle(
                              fontSize: 11,
                              color: PrepTheme.textTertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barGroups: List.generate(scores.length, (i) {
                  final isToday = i == scores.length - 1;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: scores[i],
                        width: 24,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        gradient: LinearGradient(
                          colors: isToday
                              ? [PrepTheme.accent, PrepTheme.accentLight]
                              : [PrepTheme.primary, PrepTheme.primaryLight],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Subject Breakdown — Forces / Faiblesses
// ═══════════════════════════════════════════════════════════════════
class _SubjectBreakdown extends StatelessWidget {
  const _SubjectBreakdown();

  static const _subjectColors = <String, Color>{
    'Mathématiques': PrepTheme.primary,
    'Droit': PrepTheme.xpPurple,
    'Culture Générale': PrepTheme.success,
    'Économie': PrepTheme.accent,
    'Physique-Chimie': PrepTheme.coral,
    'Histoire-Géo': PrepTheme.streakOrange,
    'Biologie': Color(0xFFDB2777),
    'Philosophie': Color(0xFF64748B),
    'Français': Color(0xFF0891B2),
    'Anglais': Color(0xFF6366F1),
  };

  @override
  Widget build(BuildContext context) {
    final quizProvider = context.watch<PrepQuizProvider>();
    final serverStats = quizProvider.subjectStats;

    // Use server data if available, otherwise show demo
    final List<(String, double, Color)> subjects;
    if (serverStats.isNotEmpty) {
      subjects = serverStats.map((s) {
        final name = (s['subject'] ?? 'Autre').toString();
        final accuracy = ((s['accuracy'] as num?)?.toDouble() ?? 0) / 100;
        final color = _subjectColors[name] ?? PrepTheme.primary;
        return (name, accuracy, color);
      }).toList();
    } else {
      subjects = [
        ('Mathématiques', 0.85, PrepTheme.primary),
        ('Droit', 0.72, PrepTheme.xpPurple),
        ('Culture Générale', 0.68, PrepTheme.success),
        ('Économie', 0.55, PrepTheme.accent),
        ('Physique-Chimie', 0.45, PrepTheme.coral),
        ('Histoire-Géo', 0.62, PrepTheme.streakOrange),
      ];
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: PrepTheme.cardBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: PrepTheme.successSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.analytics, color: PrepTheme.success, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Par matière',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: PrepTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...subjects.map((s) {
            final (name, score, color) = s;
            final pct = (score * 100).round();
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: PrepTheme.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '$pct%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: score),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (_, value, __) => LinearProgressIndicator(
                        value: value,
                        backgroundColor: color.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 8,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Badges Section
// ═══════════════════════════════════════════════════════════════════
class _BadgesSection extends StatelessWidget {
  final int totalCorrect;
  final int totalAnswered;
  final int streak;
  final int xp;

  const _BadgesSection({
    required this.totalCorrect,
    required this.totalAnswered,
    required this.streak,
    required this.xp,
  });

  @override
  Widget build(BuildContext context) {
    final badges = [
      _Badge('🌟', 'Première étoile', 'Complète ton premier quiz', totalAnswered >= 1),
      _Badge('🔥', 'Flamme', '7 jours de streak', streak >= 7),
      _Badge('📚', 'Rat de bibliothèque', '100 réponses correctes', totalCorrect >= 100),
      _Badge('🎯', 'Tireur d\'élite', '10 quiz parfaits', false),
      _Badge('🧠', 'Génie', '500 réponses correctes', totalCorrect >= 500),
      _Badge('🏆', 'Champion', 'Top 3 du classement', false),
      _Badge('💎', 'Diamant', 'Atteins le niveau 10', xp >= 1000),
      _Badge('⚡', 'Éclair', '50 réponses en 1 jour', false),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: PrepTheme.cardBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: PrepTheme.accentSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emoji_events, color: PrepTheme.accent, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Badges',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: PrepTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                '${badges.where((b) => b.isUnlocked).length}/${badges.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: PrepTheme.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: badges.length,
            itemBuilder: (context, index) {
              final badge = badges[index];
              return GestureDetector(
                onTap: () => _showBadgeDetail(context, badge),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: badge.isUnlocked ? 1.0 : 0.4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: badge.isUnlocked
                              ? PrepTheme.accentSurface
                              : PrepTheme.divider.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: badge.isUnlocked
                              ? PrepTheme.glowShadow(PrepTheme.accent)
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            badge.emoji,
                            style: TextStyle(
                              fontSize: 24,
                              color: badge.isUnlocked ? null : PrepTheme.textTertiary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        badge.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: PrepTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showBadgeDetail(BuildContext context, _Badge badge) {
    showDialog<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => AdaptiveDialog(
        maxWidth: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(badge.emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              badge.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: PrepTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            PrepTheme.chip(
              badge.isUnlocked ? 'Débloqué ✓' : 'Verrouillé',
              badge.isUnlocked ? PrepTheme.success : PrepTheme.textTertiary,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _Badge {
  final String emoji;
  final String title;
  final String description;
  final bool isUnlocked;

  const _Badge(this.emoji, this.title, this.description, this.isUnlocked);
}
