import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/animations/motion.dart';
import '../../core/animations/animation_constants.dart';
import 'bobodo_state.dart';

class BobodoView extends StatelessWidget {
  final BobodoState state;
  final String? text;
  final double size;

  const BobodoView({
    super.key,
    required this.state,
    this.text,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    final reduced = reduceMotion(context);

    final scale = switch (state) {
      BobodoState.success => 1.05,
      BobodoState.warning => 0.95,
      _ => 1.0,
    };

    final opacity = state == BobodoState.thinking ? 0.8 : 1.0;

    Widget avatar = SvgPicture.asset(
      'assets/bobodo/images/bobodo_avatar.svg',
      height: size,
    );

    if (!reduced) {
      avatar = AnimatedScale(
        scale: scale,
        duration: AnimDur.normal,
        curve: AnimCurve.standard,
        child: AnimatedOpacity(
          opacity: opacity,
          duration: AnimDur.normal,
          child: avatar,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (reduced)
          avatar
        else
          avatar,
        if (text != null) ...[
          const SizedBox(height: 8),
          Text(
            text!,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
