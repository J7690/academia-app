import 'package:flutter/material.dart';

/// Clé de navigation globale de l'application.
///
/// Utilisée par le routeur de notifications (NotificationRouter) pour
/// naviguer vers l'écran concerné lorsqu'un utilisateur clique sur une
/// notification push, quel que soit l'état de l'app (foreground,
/// background ou lancée depuis une notification).
class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
}
