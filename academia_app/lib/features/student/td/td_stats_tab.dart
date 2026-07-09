import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';

import '../../../providers/td_gamification_provider.dart';
import '../../../theme/td_theme.dart';

/// Onglet Stats — Analytics personnels, badges, certificats
class TdStatsTab extends StatefulWidget {
  const TdStatsTab({super.key});

  @override
  State<TdStatsTab> createState() => _TdStatsTabState();
}

class _TdStatsTabState extends State<TdStatsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TdGamificationProvider>().loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TdGamificationProvider>();

    if (p.statsLoading && p.statsData.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final progress = p.progressSummary;
    final totalXp = progress['total_xp'] as int? ?? 0;
    final level = progress['level'] as int? ?? 1;
    final streak = progress['current_streak'] as int? ?? 0;
    final longestStreak = progress['longest_streak'] as int? ?? 0;
    final totalQuizzes = progress['total_quizzes'] as int? ?? 0;
    final totalQuestions = progress['total_questions'] as int? ?? 0;
    final correctCount = progress['correct_count'] as int? ?? 0;
    final totalFlashcards = progress['total_flashcards'] as int? ?? 0;
    final accuracy = totalQuestions > 0 ? (correctCount / totalQuestions * 100).toInt() : 0;
    final studyHours = p.totalStudyTimeSeconds ~/ 3600;
    final studyMinutes = (p.totalStudyTimeSeconds % 3600) ~/ 60;

    return RefreshIndicator(
      onRefresh: p.loadStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          // ─── XP & Level hero ───────────────────────────────────
          FadeInDown(
            duration: const Duration(milliseconds: 400),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: TdTheme.gradientCard(TdTheme.studentTdGradient),
              child: Row(
                children: [
                  // Level circle
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                      border: Border.all(color: Colors.white.withOpacity(0.4), width: 3),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$level',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                          Text('Niv.',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.8), fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$totalXp XP au total',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          '${(level * 100) - totalXp} XP avant le niveau ${level + 1}',
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: 6,
                            child: LinearProgressIndicator(
                              value: ((totalXp % 100) / 100).clamp(0.0, 1.0),
                              backgroundColor: Colors.white.withOpacity(0.2),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── KPI grid ──────────────────────────────────────────
          FadeInUp(
            delay: const Duration(milliseconds: 100),
            duration: const Duration(milliseconds: 350),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _StatTile(icon: Icons.local_fire_department, label: 'Série actuelle', value: '$streak j', color: const Color(0xFFEF4444)),
                _StatTile(icon: Icons.whatshot, label: 'Record', value: '$longestStreak j', color: const Color(0xFFF97316)),
                _StatTile(icon: Icons.quiz, label: 'Quiz', value: '$totalQuizzes', color: TdTheme.studentTdPrimary),
                _StatTile(icon: Icons.check_circle, label: 'Précision', value: '$accuracy%', color: TdTheme.success),
                _StatTile(icon: Icons.style, label: 'Flashcards', value: '$totalFlashcards', color: const Color(0xFF7C3AED)),
                _StatTile(
                  icon: Icons.schedule,
                  label: 'Temps étude',
                  value: studyHours > 0 ? '${studyHours}h${studyMinutes.toString().padLeft(2, '0')}' : '${studyMinutes}min',
                  color: const Color(0xFF0891B2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ─── XP History (simple bar chart) ─────────────────────
          if (p.xpHistory.isNotEmpty) ...[
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              duration: const Duration(milliseconds: 350),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: TdTheme.cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('XP des 30 derniers jours',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: TdTheme.textPrimary)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 80,
                      child: _SimpleBarChart(data: p.xpHistory),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ─── Badges ────────────────────────────────────────────
          FadeInUp(
            delay: const Duration(milliseconds: 300),
            duration: const Duration(milliseconds: 350),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Badges',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: TdTheme.textPrimary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: TdTheme.studentTdPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${p.badges.length}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: TdTheme.studentTdPrimary)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (p.badges.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: TdTheme.cardDecoration(),
                    child: const Center(
                      child: Column(
                        children: [
                          Text('🏆', style: TextStyle(fontSize: 32)),
                          SizedBox(height: 8),
                          Text('Aucun badge encore',
                              style: TextStyle(fontSize: 13, color: TdTheme.textSecondary)),
                          Text('Continue tes TD pour débloquer des badges !',
                              style: TextStyle(fontSize: 11, color: TdTheme.textTertiary)),
                        ],
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: p.badges.map((b) => _BadgeCard(badge: b)).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 42) / 2;
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: TdTheme.cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
                  Text(label,
                      style: const TextStyle(fontSize: 10, color: TdTheme.textSecondary),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final Map<String, dynamic> badge;

  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    final emoji = badge['emoji']?.toString() ?? '🏆';
    final title = badge['title']?.toString() ?? '';
    final xpReward = badge['xp_reward'] as int? ?? 0;

    return Flexible(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: TdTheme.cardDecoration(),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
            if (xpReward > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('+$xpReward XP',
                    style: const TextStyle(fontSize: 9, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}

class _SimpleBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const _SimpleBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxXp = data.fold<int>(0, (prev, e) {
      final xp = e['xp'] as int? ?? 0;
      return xp > prev ? xp : prev;
    });
    final effectiveMax = maxXp > 0 ? maxXp : 1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.map((e) {
        final xp = e['xp'] as int? ?? 0;
        final ratio = xp / effectiveMax;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Tooltip(
              message: '$xp XP',
              child: Container(
                height: (ratio * 70).clamp(2.0, 70.0),
                decoration: BoxDecoration(
                  color: TdTheme.studentTdPrimary.withOpacity(0.7),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
