import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'bobodo_state.dart';

class BobodoView extends StatelessWidget {
  final BobodoState state;
  final String? text;
  final double size;

  const BobodoView({
    super.key,
    required this.state,
    this.text,
    this.size = 96,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final reduceMotion = mq.disableAnimations || mq.accessibleNavigation;

    final double scale;
    switch (state) {
      case BobodoState.success:
        scale = 1.05;
        break;
      case BobodoState.warning:
        scale = 0.95;
        break;
      default:
        scale = 1.0;
        break;
    }

    final double opacity = state == BobodoState.thinking ? 0.85 : 1.0;

    Widget avatar = SvgPicture.asset(
      'assets/bobodo_avatar.svg',
      height: size,
    );

    if (!reduceMotion) {
      avatar = AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 250),
          child: avatar,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        avatar,
        if (text != null) ...[
          const SizedBox(height: 8),
          Text(
            text!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ],
    );
  }
}
