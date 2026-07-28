import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:livekit_client/livekit_client.dart';

/// Démarrage et arrêt du partage d'écran, avec la mécanique Android
/// qu'aucune plateforme ne peut contourner depuis Android 14.
///
/// **Pourquoi ce service existe**
///
/// Appeler directement `setScreenShareEnabled(true)` sur Android 14 et
/// au-delà lève une `SecurityException` :
///
/// > Media projections require a foreground service of type
/// > ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
///
/// Le système exige qu'un service de premier plan de type `mediaProjection`
/// soit **déjà en cours** avant que la capture ne démarre. La cible du projet
/// est `targetSdk 35`, la contrainte s'applique donc pleinement.
///
/// L'ordre est impératif :
///
/// 1. initialiser le service de premier plan
/// 2. le démarrer, et vérifier qu'il tourne
/// 3. seulement ensuite, activer la capture
/// 4. à l'arrêt, couper la capture **avant** le service
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
      final ready = await _startForegroundService();
      if (ready != null) return ready;
    }

    try {
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
  static Future<void> stop(LocalParticipant? participant) async {
    try {
      await participant?.setScreenShareEnabled(false);
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
      await FlutterBackground.disableBackgroundExecution();
    } catch (e) {
      debugPrint('[ScreenShare] échec de l\'arrêt du service : $e');
    } finally {
      _serviceRunning = false;
    }
  }
}
