import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Vérifie les permissions de notification et guide l'utilisateur
/// si les notifications sont bloquées (Android 13+, TECNO, Xiaomi, etc.).
class NotificationPermissionChecker {
  NotificationPermissionChecker._();
  static final instance = NotificationPermissionChecker._();

  bool _alreadyChecked = false;

  /// Vérifie et demande les permissions si nécessaire.
  /// Affiche un dialogue si les notifications sont bloquées.
  Future<void> checkAndRequest(BuildContext context) async {
    if (kIsWeb || _alreadyChecked) return;
    _alreadyChecked = true;

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.getNotificationSettings();
      debugPrint('[NOTIF-CHECK] Current status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied ||
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        // Demander la permission
        final result = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('[NOTIF-CHECK] After request: ${result.authorizationStatus}');

        if (result.authorizationStatus == AuthorizationStatus.denied) {
          // Permission refusée → guider vers les paramètres
          if (context.mounted) {
            _showEnableNotificationsDialog(context);
          }
        }
      }

      // Vérifier aussi si le canal local fonctionne
      if (!kIsWeb) {
        final plugin = FlutterLocalNotificationsPlugin();
        final androidPlugin = plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          final enabled = await androidPlugin.areNotificationsEnabled();
          debugPrint('[NOTIF-CHECK] Local notifications enabled: $enabled');
          if (enabled == false && context.mounted) {
            _showEnableNotificationsDialog(context);
          }
        }
      }
    } catch (e) {
      debugPrint('[NOTIF-CHECK] Error: $e');
    }
  }

  void _showEnableNotificationsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_off, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Notifications désactivées',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pour recevoir les notifications de messages, paiements et mises à jour importantes, vous devez activer les notifications.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            Text(
              'Comment faire :',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 8),
            Text('1. Appuyez sur "Ouvrir paramètres"', style: TextStyle(fontSize: 13)),
            Text('2. Activez "Autoriser les notifications"', style: TextStyle(fontSize: 13)),
            Text('3. Vérifiez que "Son" et "Vibration" sont activés', style: TextStyle(fontSize: 13)),
            SizedBox(height: 12),
            Text(
              '⚡ Sur TECNO/Infinix : allez aussi dans Paramètres → Batterie → Optimisation batterie → Academia → "Ne pas optimiser"',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Plus tard'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openNotificationSettings();
            },
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('Ouvrir paramètres'),
          ),
        ],
      ),
    );
  }

  Future<void> _openNotificationSettings() async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      final androidPlugin = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('[NOTIF-CHECK] Could not open settings: $e');
    }
  }

  /// Réinitialise pour permettre une nouvelle vérification.
  void reset() => _alreadyChecked = false;
}
