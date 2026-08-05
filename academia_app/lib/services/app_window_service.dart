import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Réduction de l'application sans la fermer.
///
/// **Pourquoi c'est nécessaire au partage d'écran**
///
/// Sur un téléphone, partager son écran sert à montrer *autre chose* : un
/// document, une copie, une application. Tant qu'Academia reste au premier
/// plan, elle se diffuse elle-même — l'exercice n'a aucun intérêt.
///
/// L'utilisateur doit donc pouvoir revenir à son écran d'accueil **pendant**
/// que le partage continue. C'est possible parce que la capture est portée par
/// un service de premier plan, qui survit au passage en arrière-plan.
///
/// Distinction importante : on **réduit**, on ne **ferme** pas.
/// `SystemNavigator.pop()` terminerait l'activité et quitterait la séance ;
/// `moveTaskToBack()` la laisse vivante. Revenir se fait par la notification
/// persistante ou par l'icône de l'application.
class AppWindowService {
  const AppWindowService._();

  static const MethodChannel _channel = MethodChannel('com.academia.app/app');

  /// Vrai si la plateforme sait réduire l'application.
  ///
  /// Android uniquement : iOS interdit à une application de se mettre
  /// elle-même en arrière-plan (règle de l'App Store), et sur le web la
  /// notion n'a pas de sens.
  static bool get isSupported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  /// Renvoie l'utilisateur à son écran d'accueil, l'application restant
  /// active en arrière-plan. Retourne `false` si l'opération n'est pas
  /// possible — l'appelant doit alors rester utilisable.
  static Future<bool> minimize() async {
    if (!isSupported) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('moveToBackground');
      return ok ?? false;
    } on PlatformException catch (e) {
      debugPrint('[AppWindow] réduction impossible : ${e.message}');
      return false;
    } on MissingPluginException {
      // Canal absent (ancienne version native) : on échoue proprement.
      debugPrint('[AppWindow] canal natif indisponible');
      return false;
    }
  }
}
