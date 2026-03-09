import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';

import '../../../providers/td_gamification_provider.dart';
import '../../../theme/td_theme.dart';

/// Onglet Communauté — Leaderboard hebdomadaire + classement
class TdLeaderboardTab extends StatefulWidget {
  const TdLeaderboardTab({super.key});

  @override
  State<TdLeaderboardTab> createState() => _TdLeaderboardTabState();
}

class _TdLeaderboardTabState extends State<TdLeaderboardTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TdGamificationProvider>().loadLeaderboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TdGamificationProvider>();

    if (p.leaderboardLoading && p.leaderboardEntries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final entries = p.leaderboardEntries;
    final myRank = p.myRank;

    return RefreshIndicator(
      onRefresh: () => p.loadLeaderboard(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          // ─── Header ────────────────────────────────────────────
          FadeInDown(
            duration: const Duration(milliseconds: 400),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: TdTheme.gradientCard(const [Color(0xFFF59E0B), Color(0xFFEF4444)]),
              child: Column(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.white, size: 36),
                  const SizedBox(height: 8),
                  const Text('Classement de la semaine',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    myRank != null ? 'Tu es #$myRank cette semaine' : 'Gagne des XP pour apparaître !',
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Podium (top 3) ────────────────────────────────────
          if (entries.length >= 3)
            FadeInUp(
              delay: const Duration(milliseconds: 100),
              duration: const Duration(milliseconds: 350),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: _PodiumItem(entry: entries[1], rank: 2, height: 80)),
                  const SizedBox(width: 8),
                  Expanded(child: _PodiumItem(entry: entries[0], rank: 1, height: 100)),
                  const SizedBox(width: 8),
                  Expanded(child: _PodiumItem(entry: entries[2], rank: 3, height: 65)),
                ],
              ),
            ),
          if (entries.length >= 3) const SizedBox(height: 20),

          // ─── Full list ─────────────────────────────────────────
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.leaderboard_outlined, size: 56, color: TdTheme.textTertiary.withOpacity(0.4)),
                  const SizedBox(height: 12),
                  const Text('Pas encore de classement',
                      style: TextStyle(fontSize: 14, color: TdTheme.textSecondary)),
                  const SizedBox(height: 4),
                  const Text('Complète des activités pour gagner des XP !',
                      style: TextStyle(fontSize: 12, color: TdTheme.textTertiary)),
                ],
              ),
            )
          else
            ...entries.asMap().entries.skip(entries.length >= 3 ? 3 : 0).map((e) {
              final index = e.key;
              final entry = e.value;
              return FadeInUp(
                delay: Duration(milliseconds: 30 * index),
                duration: const Duration(milliseconds: 300),
                child: _LeaderboardRow(entry: entry, rank: index + 1),
              );
            }),
        ],
      ),
    );
  }
}

class _PodiumItem extends StatelessWidget {
  final Map<String, dynamic> entry;
  final int rank;
  final double height;

  const _PodiumItem({required this.entry, required this.rank, required this.height});

  @override
  Widget build(BuildContext context) {
    final xp = entry['xp_earned'] as int? ?? 0;
    final isMe = entry['is_me'] == true;
    final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉';
    final colors = rank == 1
        ? const [Color(0xFFF59E0B), Color(0xFFEF4444)]
        : rank == 2
            ? const [Color(0xFF9CA3AF), Color(0xFF6B7280)]
            : const [Color(0xFFD97706), Color(0xFFA16207)];

    return Column(
      children: [
        Text(medal, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors, begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  child: Text('#$rank',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 4),
                Text('$xp XP',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                if (isMe)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Toi', style: TextStyle(color: Colors.white, fontSize: 9)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  final int rank;

  const _LeaderboardRow({required this.entry, required this.rank});

  @override
  Widget build(BuildContext context) {
    final xp = entry['xp_earned'] as int? ?? 0;
    final isMe = entry['is_me'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? TdTheme.studentTdPrimary.withOpacity(0.06) : TdTheme.cardBg,
        borderRadius: BorderRadius.circular(TdTheme.radiusMd),
        border: Border.all(
          color: isMe ? TdTheme.studentTdPrimary.withOpacity(0.2) : TdTheme.divider,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('#$rank',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isMe ? TdTheme.studentTdPrimary : TdTheme.textSecondary,
                )),
          ),
          CircleAvatar(
            radius: 16,
            backgroundColor: isMe ? TdTheme.studentTdPrimary.withOpacity(0.12) : TdTheme.divider,
            child: Icon(Icons.person, size: 16,
                color: isMe ? TdTheme.studentTdPrimary : TdTheme.textTertiary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isMe ? 'Toi' : 'Étudiant #$rank',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                color: isMe ? TdTheme.studentTdPrimary : TdTheme.textPrimary,
              ),
            ),
          ),
          TdTheme.xpBadge(xp),
        ],
      ),
    );
  }
}
