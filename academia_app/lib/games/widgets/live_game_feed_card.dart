import 'dart:async';

import 'package:flutter/material.dart';
import '../services/game_live_service.dart';

/// Widget qui affiche les sessions de jeux en direct dans le hub.
/// Se met à jour automatiquement via Supabase Realtime Presence.
class LiveGameFeedSection extends StatefulWidget {
  const LiveGameFeedSection({super.key});

  @override
  State<LiveGameFeedSection> createState() => _LiveGameFeedSectionState();
}

class _LiveGameFeedSectionState extends State<LiveGameFeedSection> {
  List<Map<String, dynamic>> _livePlayers = [];
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = GameLiveService.watchLivePlayers().listen((players) {
      if (mounted) setState(() => _livePlayers = players);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_livePlayers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            const Text(
              'En direct maintenant',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(width: 6),
            Text(
              '${_livePlayers.length}',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _livePlayers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final player = _livePlayers[index];
              return _LivePlayerChip(player: player);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _LivePlayerChip extends StatelessWidget {
  final Map<String, dynamic> player;

  const _LivePlayerChip({required this.player});

  @override
  Widget build(BuildContext context) {
    final gameType = player['game_type']?.toString() ?? 'Jeu';
    final displayName = player['display_name']?.toString();
    final userId = player['user_id']?.toString() ?? '';
    final name = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : 'Joueur ${userId.length > 6 ? userId.substring(0, 6) : userId}';

    return Container(
      width: 140,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade400, Colors.red.shade700],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              const Text(
                'LIVE',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            gameType,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
