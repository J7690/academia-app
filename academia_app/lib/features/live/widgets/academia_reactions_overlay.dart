import 'dart:math';

import 'package:flutter/material.dart';

/// Overlay de réactions flottantes pour AcademiaClassroom.
class AcademiaReactionsOverlay extends StatefulWidget {
  const AcademiaReactionsOverlay({super.key});

  @override
  State<AcademiaReactionsOverlay> createState() =>
      _AcademiaReactionsOverlayState();
}

class _AcademiaReactionsOverlayState extends State<AcademiaReactionsOverlay>
    with TickerProviderStateMixin {
  final List<_ReactionParticle> _particles = [];
  final _emojis = ['👏', '❤️', '🔥', '😮', '😂', '👍'];
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _spawnParticles();
  }

  void _spawnParticles() {
    for (int i = 0; i < 6; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (!mounted) return;
        final emoji = _emojis[_random.nextInt(_emojis.length)];
        final particle = _ReactionParticle(
          emoji: emoji,
          xFraction: 0.1 + _random.nextDouble() * 0.8,
          controller: AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 1800),
          ),
        );
        setState(() => _particles.add(particle));
        particle.controller.forward().then((_) {
          if (mounted) setState(() => _particles.remove(particle));
          particle.controller.dispose();
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return IgnorePointer(
      child: Stack(
        children: _particles.map((p) {
          return AnimatedBuilder(
            animation: p.controller,
            builder: (_, __) {
              final progress = p.controller.value;
              final opacity = progress < 0.8 ? 1.0 : (1.0 - progress) / 0.2;
              final x = size.width * p.xFraction;
              final y = size.height * 0.7 - (progress * size.height * 0.4);
              return Positioned(
                left: x,
                top: y,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Text(
                    p.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}

class _ReactionParticle {
  final String emoji;
  final double xFraction;
  final AnimationController controller;

  _ReactionParticle({
    required this.emoji,
    required this.xFraction,
    required this.controller,
  });
}
