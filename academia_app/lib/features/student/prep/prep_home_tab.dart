import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../providers/prep_quiz_provider.dart';
import '../../../theme/prep_theme.dart';

/// Onglet Accueil — Dashboard interactif avec streak, XP, quiz du jour, progression.
class PrepHomeTab extends StatelessWidget {
  const PrepHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final quizProvider = context.watch<PrepQuizProvider>();

    return RefreshIndicator(
      color: PrepTheme.primary,
      onRefresh: () async => quizProvider.loadProgress(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        children: [
          // ─── Hero card ─────────────────────────────────────────
          FadeInDown(
            duration: const Duration(milliseconds: 500),
            child: _HeroCard(
              streak: quizProvider.currentStreak,
              xp: quizProvider.totalXp,
            ),
          ),
          const SizedBox(height: 20),

          // ─── Quick stats row ───────────────────────────────────
          FadeInUp(
            delay: const Duration(milliseconds: 100),
            duration: const Duration(milliseconds: 500),
            child: _QuickStatsRow(
              totalAnswered: quizProvider.totalAnswered,
              totalCorrect: quizProvider.totalCorrect,
              longestStreak: quizProvider.longestStreak,
            ),
          ),
          const SizedBox(height: 20),

          // ─── Quiz du jour ──────────────────────────────────────
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            duration: const Duration(milliseconds: 500),
            child: _DailyQuizCard(onStart: () => _startDailyQuiz(context)),
          ),
          const SizedBox(height: 16),

          // ─── Actions rapides ───────────────────────────────────
          FadeInUp(
            delay: const Duration(milliseconds: 300),
            duration: const Duration(milliseconds: 500),
            child: const _QuickActionsGrid(),
          ),
          const SizedBox(height: 16),

          // ─── Actuality notifications opt-in ─────────────────
          FadeInUp(
            delay: const Duration(milliseconds: 400),
            duration: const Duration(milliseconds: 500),
            child: const _ActualityNotifCard(),
          ),
          const SizedBox(height: 16),

          // ─── Motivation quote ──────────────────────────────────
          FadeInUp(
            delay: const Duration(milliseconds: 500),
            duration: const Duration(milliseconds: 500),
            child: const _MotivationCard(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _startDailyQuiz(BuildContext context) {
    final provider = context.read<PrepQuizProvider>();
    provider.startQuizFromServer(count: 5);
    DefaultTabController.of(context).animateTo(1); // Go to Quiz tab
  }
}

// ═══════════════════════════════════════════════════════════════════
// Hero Card — Streak + XP
// ═══════════════════════════════════════════════════════════════════
class _HeroCard extends StatelessWidget {
  final int streak;
  final int xp;

  const _HeroCard({required this.streak, required this.xp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: PrepTheme.gradientBox(PrepTheme.headerGradient, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar / Icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.rocket_launch, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Prêt à conquérir tes concours ?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Badges row
          Row(
            children: [
              PrepTheme.streakBadge(streak),
              const SizedBox(width: 10),
              PrepTheme.xpBadge(xp),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(PrepTheme.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Niv. ${(xp / 100).floor() + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // XP progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (xp % 100) / 100,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(PrepTheme.accentLight),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${xp % 100}/100 XP pour le prochain niveau',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '☀️ Bonjour !';
    if (hour < 18) return '🌤️ Bon après-midi !';
    return '🌙 Bonsoir !';
  }
}

// ═══════════════════════════════════════════════════════════════════
// Quick Stats Row
// ═══════════════════════════════════════════════════════════════════
class _QuickStatsRow extends StatelessWidget {
  final int totalAnswered;
  final int totalCorrect;
  final int longestStreak;

  const _QuickStatsRow({
    required this.totalAnswered,
    required this.totalCorrect,
    required this.longestStreak,
  });

  @override
  Widget build(BuildContext context) {
    final accuracy = totalAnswered > 0
        ? ((totalCorrect / totalAnswered) * 100).round()
        : 0;

    return Row(
      children: [
        _StatMini(
          icon: Icons.check_circle,
          value: '$totalAnswered',
          label: 'Réponses',
          color: PrepTheme.primary,
        ),
        const SizedBox(width: 10),
        _StatMini(
          icon: Icons.gps_fixed,
          value: '$accuracy%',
          label: 'Précision',
          color: PrepTheme.success,
        ),
        const SizedBox(width: 10),
        _StatMini(
          icon: Icons.local_fire_department,
          value: '$longestStreak',
          label: 'Record',
          color: PrepTheme.streakOrange,
        ),
      ],
    );
  }
}

class _StatMini extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatMini({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: PrepTheme.cardBox(),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: PrepTheme.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Daily Quiz Card
// ═══════════════════════════════════════════════════════════════════
class _DailyQuizCard extends StatelessWidget {
  final VoidCallback onStart;

  const _DailyQuizCard({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: PrepTheme.gradientBox(PrepTheme.quizGradient, radius: 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onStart,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quiz du jour',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '5 questions · Culture Générale · ~3 min',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.7),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Quick Actions Grid
// ═══════════════════════════════════════════════════════════════════
class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Entraîne-toi',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: PrepTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _ActionTile(
              icon: Icons.quiz,
              label: 'QCM\nrapide',
              gradient: PrepTheme.quizGradient,
              onTap: () => DefaultTabController.of(context).animateTo(1),
            ),
            const SizedBox(width: 10),
            _ActionTile(
              icon: Icons.style,
              label: 'Flash\ncards',
              gradient: PrepTheme.successGradient,
              onTap: () => DefaultTabController.of(context).animateTo(1),
            ),
            const SizedBox(width: 10),
            _ActionTile(
              icon: Icons.timer,
              label: 'Examen\nblanc',
              gradient: PrepTheme.streakGradient,
              onTap: () => DefaultTabController.of(context).animateTo(1),
            ),
            const SizedBox(width: 10),
            _ActionTile(
              icon: Icons.auto_awesome,
              label: 'IA\nTutor',
              gradient: PrepTheme.aiGradient,
              onTap: () => DefaultTabController.of(context).animateTo(3),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 90,
          decoration: PrepTheme.gradientBox(gradient, radius: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Actuality Notifications Opt-in Card
// ═══════════════════════════════════════════════════════════════════
class _ActualityNotifCard extends StatefulWidget {
  const _ActualityNotifCard();

  @override
  State<_ActualityNotifCard> createState() => _ActualityNotifCardState();
}

class _ActualityNotifCardState extends State<_ActualityNotifCard> {
  bool _isEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final result = await Supabase.instance.client.rpc(
        'app_student_get_actuality_preferences',
      );
      if (!mounted) return;
      final data = result as Map<String, dynamic>?;
      setState(() {
        _isEnabled = data?['is_enabled'] == true;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggle(bool value) async {
    setState(() => _isEnabled = value);
    try {
      await Supabase.instance.client.rpc(
        'app_student_toggle_actuality_notifications',
        params: {'p_enabled': value, 'p_min_score': 0.4},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Notifications actualites concours activees'
                : 'Notifications actualites desactivees',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isEnabled = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur, reessayez'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PrepTheme.cardBg,
        borderRadius: BorderRadius.circular(PrepTheme.radiusLg),
        border: Border.all(
          color: _isEnabled
              ? PrepTheme.primary.withOpacity(0.3)
              : PrepTheme.divider,
        ),
        boxShadow: PrepTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isEnabled
                    ? PrepTheme.headerGradient
                    : [PrepTheme.textTertiary, PrepTheme.textTertiary],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.newspaper_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alertes Actualites Concours',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: PrepTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Recevez les actualites susceptibles de tomber au concours',
                  style: TextStyle(
                    fontSize: 11,
                    color: PrepTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch.adaptive(
              value: _isEnabled,
              onChanged: _toggle,
              activeColor: PrepTheme.primary,
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Motivation Card
// ═══════════════════════════════════════════════════════════════════
class _MotivationCard extends StatelessWidget {
  const _MotivationCard();

  static const _quotes = [
    '"Le succès n\'est pas final, l\'échec n\'est pas fatal : c\'est le courage de continuer qui compte." — Winston Churchill',
    '"La seule façon de faire du bon travail est d\'aimer ce que vous faites." — Steve Jobs',
    '"L\'éducation est l\'arme la plus puissante pour changer le monde." — Nelson Mandela',
    '"Ce n\'est pas parce que les choses sont difficiles que nous n\'osons pas, c\'est parce que nous n\'osons pas qu\'elles sont difficiles." — Sénèque',
    '"Le génie est fait d\'un pour cent d\'inspiration et de quatre-vingt-dix-neuf pour cent de transpiration." — Thomas Edison',
    '"Chaque expert a d\'abord été un débutant." — Helen Hayes',
    '"La persévérance est la mère de la réussite." — Proverbe africain',
  ];

  @override
  Widget build(BuildContext context) {
    final quote = _quotes[DateTime.now().day % _quotes.length];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PrepTheme.accentSurface,
        borderRadius: BorderRadius.circular(PrepTheme.radiusLg),
        border: Border.all(color: PrepTheme.accent.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              quote,
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: PrepTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
