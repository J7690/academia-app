import 'dart:math';

import 'package:flutter/material.dart';

import '../services/video_reaction_service.dart';

/// Animated emoji reaction bar for video feed items.
/// Shows available reactions with counts and animated feedback.
class VideoReactionsBar extends StatefulWidget {
  final String videoId;
  final String? participationId;
  final Map<String, int>? initialCounts;
  final List<String>? myReactions;

  const VideoReactionsBar({
    super.key,
    required this.videoId,
    this.participationId,
    this.initialCounts,
    this.myReactions,
  });

  @override
  State<VideoReactionsBar> createState() => _VideoReactionsBarState();
}

class _VideoReactionsBarState extends State<VideoReactionsBar>
    with TickerProviderStateMixin {
  Map<String, int> _counts = {};
  Set<String> _myReactions = {};

  // Floating emoji animations
  final List<_FloatingEmoji> _floatingEmojis = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    if (widget.initialCounts != null) {
      _counts = Map.from(widget.initialCounts!);
    }
    if (widget.myReactions != null) {
      _myReactions = Set.from(widget.myReactions!);
    }
    _loadReactions();
  }

  Future<void> _loadReactions() async {
    final data = await VideoReactionService.getReactions(widget.videoId);
    if (!mounted || data == null) return;

    final reactions = data['reactions'];
    final myReactions = data['my_reactions'];

    setState(() {
      if (reactions is Map) {
        _counts = Map<String, int>.from(
          reactions.map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
        );
      }
      if (myReactions is List) {
        _myReactions = Set<String>.from(myReactions.map((e) => e.toString()));
      }
    });
  }

  Future<void> _onReactionTap(VideoReactionType type) async {
    // Optimistic update
    final wasActive = _myReactions.contains(type.value);
    setState(() {
      if (wasActive) {
        _myReactions.remove(type.value);
        _counts[type.value] = (_counts[type.value] ?? 1) - 1;
      } else {
        _myReactions.add(type.value);
        _counts[type.value] = (_counts[type.value] ?? 0) + 1;
        _spawnFloatingEmoji(type.emoji);
      }
    });

    final result = await VideoReactionService.toggleReaction(
      videoId: widget.videoId,
      reactionType: type,
      participationId: widget.participationId,
    );

    if (!mounted) return;
    if (result != null) {
      setState(() {
        _counts[type.value] = (result['count'] as num?)?.toInt() ?? _counts[type.value] ?? 0;
      });
    }
  }

  void _spawnFloatingEmoji(String emoji) {
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800 + _rng.nextInt(400)),
    );
    final floating = _FloatingEmoji(
      emoji: emoji,
      controller: controller,
      xOffset: -20 + _rng.nextDouble() * 40,
    );
    setState(() => _floatingEmojis.add(floating));
    controller.forward().then((_) {
      controller.dispose();
      if (mounted) {
        setState(() => _floatingEmojis.remove(floating));
      }
    });
  }

  @override
  void dispose() {
    for (final f in _floatingEmojis) {
      f.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Floating emojis
        SizedBox(
          height: 80,
          child: Stack(
            clipBehavior: Clip.none,
            children: _floatingEmojis.map((f) {
              return AnimatedBuilder(
                animation: f.controller,
                builder: (_, __) {
                  final progress = f.controller.value;
                  return Positioned(
                    bottom: progress * 80,
                    left: 20 + f.xOffset,
                    child: Opacity(
                      opacity: 1.0 - progress,
                      child: Transform.scale(
                        scale: 1.0 + progress * 0.5,
                        child: Text(f.emoji, style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),
        // Reaction buttons
        ...VideoReactionType.values.map((type) {
          final count = _counts[type.value] ?? 0;
          final isActive = _myReactions.contains(type.value);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: GestureDetector(
              onTap: () => _onReactionTap(type),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: isActive ? 1.3 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      type.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                  if (count > 0)
                    Text(
                      _formatCount(count),
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.white70,
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

class _FloatingEmoji {
  final String emoji;
  final AnimationController controller;
  final double xOffset;
  _FloatingEmoji({required this.emoji, required this.controller, required this.xOffset});
}
