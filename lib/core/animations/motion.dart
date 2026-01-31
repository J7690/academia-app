import 'package:flutter/material.dart';

bool reduceMotion(BuildContext context) {
  final mq = MediaQuery.of(context);
  return mq.disableAnimations || mq.accessibleNavigation;
}
