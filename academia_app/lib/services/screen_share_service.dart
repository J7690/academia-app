import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_background/flutter_background.dart';
// `Helper.requestCapturePermission()` : demande l'autorisation de capture et
// renvoie le jeton MediaProjection. Doit précéder le service de premier plan.
import 'package:flutter_webrtc/flutter_webrtc.dart' show Helper;
import 'package:livekit_client/livekit_client.dart';

/// Démarrage et arrêt du partage d'écran, avec la mécanique Android
/// qu'aucune plateforme ne peut contourner depuis Android 14.
///
/// **L'ORDRE EST LA SEULE CHOSE QUI COMPTE** (correctif du 31/07/2026)
///
/// Android 14 traite la capture d'écran comme une surveillance à haut risque
/// et impose un enchaînement strict :
///
/// > L'autorisation MediaProjection doit être accordée **AVANT** le démarrage
/// > d'un service de premier plan de type `mediaProjection`.
///
/// En cas de violation, le système lève une `SecurityException` et **ferme
/// l'application**. Pas de reprise, pas de repli — c'est exactement le
/// symptôme observé : « l'application s'est fermée automatiquement ».
///
/// La version précédente de ce fichier faisait l'inverse : elle démarrait le
/// service **puis** demandait la capture. Cet ordre fonctionnait jusqu'à
/// Android 13 ; depuis Android 14 il est fatal. Le projet cible `targetSdk 35`.
///
/// Ordre correct, désormais appliqué :
///
/// 1. demander l'autorisation de capture — boîte système, renvoie le jeton
/// 2. seulement ensuite, démarrer le service de premier plan
/// 3. laisser au service le temps de devenir actif
/// 4. activer la capture
/// 5. à l'arrêt, couper la capture **avant** le service
///
/// Sur iOS, le partage d'écran passe par une extension de diffusion système :
/// le service Android n'a pas lieu d'être. Sur le web, `getDisplayMedia` gère
/// tout seul. Le service n'est donc activé que sur Android.
class ScreenShareService {
  const ScreenShareService._();

  static bool _serviceRunning = false;

  /// Vrai si la plateforme impose le service de premier plan.
  static bool get _needsForegroundService {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  /// Démarre le partage d'écran. Retourne `null` si tout s'est bien passé,
  /// sinon un message destiné à l'utilisateur.
  ///
  /// Le message est volontairement explicite : un partage d'écran qui échoue
  /// en silence pendant un cours est bien pire qu'un message d'erreur.
  static Future<String?> start(LocalParticipant? participant) async {
    if (participant == null) return 'Vous n\'êtes pas connecté à la salle.';

    if (_needsForegroundService) {
      // ÉTAPE 1 — l'autorisation D'ABORD. C'est cet appel qui ouvre la boîte
      // système « Academia va commencer à capturer… » et produit le jeton de
      // projection. Sans ce jeton, l'étape 2 fait fermer l'application.
      try {
        final granted = await Helper.requestCapturePermission();
        if (!granted) {
          return 'Partage annulé : la capture d\'écran n\'a pas été autorisée.';
        }
      } catch (e) {
        debugPrint('[ScreenShare] demande d\'autorisation impossible : $e');
        return 'Le partage d\'écran n\'est pas disponible sur cet appareil.';
      }

      // ÉTAPE 2 — le service de premier plan, maintenant que le jeton existe.
      final ready = await _startForegroundService();
      if (ready != null) return ready;

      // ÉTAPE 3 — laisser le service passer réellement au premier plan.
      // Android exige `startForeground()` dans les 5 secondes ; enchaîner la
      // capture immédiatement peut la déclencher avant que le service ne soit
      // actif, ce qui rejoue l'erreur qu'on vient d'éliminer.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    try {
      // ÉTAPE 4 — la capture elle-même.
      await participant.setScreenShareEnabled(true);
      return null;
    } catch (e) {
      await _stopForegroundService();
      debugPrint('[ScreenShare] échec du démarrage : $e');

      final message = e.toString().toLowerCase();
      if (message.contains('permission') || message.contains('denied')) {
        return 'Partage refusé. Autorisez la capture d\'écran quand le '
            'téléphone vous le demande.';
      }
      if (message.contains('foreground') || message.contains('security')) {
        return 'Le partage d\'écran nécessite une autorisation système qui '
            'n\'a pas pu être obtenue. Redémarrez l\'application et réessayez.';
      }
      return 'Impossible de démarrer le partage d\'écran.';
    }
  }

  /// Arrête le partage d'écran puis le service de premier plan, dans cet ordre.
  ///
  /// Chaque étape est bornée dans le temps. Un arrêt qui reste en attente
  /// donnerait un bouton « Arrêter le partage » sans effet visible — le
  /// symptôme observé le 31/07/2026. Mieux vaut un nettoyage imparfait qu'une
  /// interface figée : l'utilisateur doit toujours reprendre la main.
  static Future<void> stop(LocalParticipant? participant) async {
    try {
      await participant
          ?.setScreenShareEnabled(false)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[ScreenShare] échec de l\'arrêt de la capture : $e');
    }
    await _stopForegroundService();
  }

  // ─── Service de premier plan Android ────────────────────────────────

  static Future<String?> _startForegroundService() async {
    if (_serviceRunning) return null;
    try {
      const config = FlutterBackgroundAndroidConfig(
        notificationTitle: 'Partage d\'écran en cours',
        notificationText: 'Academia diffuse votre écran dans la séance.',
        notificationImportance: AndroidNotificationImportance.normal,
        notificationIcon: AndroidResource(
          name: 'ic_launcher',
          defType: 'mipmap',
        ),
      );

      final initialised =
          await FlutterBackground.initialize(androidConfig: config);
      if (!initialised) {
        return 'Autorisation refusée pour le partage d\'écran.';
      }

      final started = await FlutterBackground.enableBackgroundExecution();
      if (!started) {
        return 'Le service de partage d\'écran n\'a pas pu démarrer.';
      }

      _serviceRunning = true;
      return null;
    } catch (e) {
      debugPrint('[ScreenShare] service de premier plan indisponible : $e');
      return 'Le partage d\'écran n\'est pas disponible sur cet appareil.';
    }
  }

  static Future<void> _stopForegroundService() async {
    if (!_serviceRunning) return;
    try {
      await FlutterBackground.disableBackgroundExecution()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[ScreenShare] échec de l\'arrêt du service : $e');
    } finally {
      // Remis à faux quoi qu'il arrive : sinon un échec unique empêcherait
      // définitivement de relancer un partage dans la même session.
      _serviceRunning = false;
    }
  }
}
