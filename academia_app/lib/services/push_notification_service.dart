import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service centralisé pour la gestion des notifications push (FCM) côté Flutter.
///
/// Rôles :
/// - Initialiser Firebase (web + mobile)
/// - Configurer Firebase Messaging
/// - Demander les permissions de notifications
/// - Récupérer le token FCM et l'enregistrer côté Supabase via la RPC
///   register_push_token(user_id, token, platform)
/// - Retry automatique si getToken() échoue (SERVICE_NOT_AVAILABLE, etc.)
///
/// Ce service ne gère PAS la navigation ni la logique métier.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  bool _initialized = false;
  String? _lastRegisteredToken;
  void Function(String applicationId)? _onApplicationNotification;
  String? _pendingApplicationId;
  Timer? _retryTimer;
  int _retryCount = 0;
  static const int _maxRetries = 5;

  /// Canal de notification Android pour les push FCM.
  static const String _androidChannelId = 'academia_default';
  static const String _androidChannelName = 'Notifications Academia';
  static const String _androidChannelDesc =
      'Notifications push pour les messages, candidatures et mises à jour.';

  /// Plugin local notifications pour afficher les push en foreground sur Android.
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (_initialized) return;
    debugPrint('[PUSH] init() starting...');

    // 1) Initialisation Firebase selon la plateforme
    try {
      if (Firebase.apps.isEmpty) {
        if (kIsWeb) {
          await Firebase.initializeApp(
            options: const FirebaseOptions(
              apiKey: 'AIzaSyB_9r-GJ9KdbgTTjZHhav9DZpoCSuh63qA',
              appId: '1:593442809911:web:3d63c267fcc760123af7b2',
              messagingSenderId: '593442809911',
              projectId: 'academia-e2c41',
              storageBucket: 'academia-e2c41.firebasestorage.app',
            ),
          );
        } else {
          await Firebase.initializeApp();
        }
      }
      debugPrint('[PUSH] Firebase initialized OK');
    } catch (e) {
      debugPrint('[PUSH] Firebase init ERROR: $e');
      return;
    }

    // 2) Handler pour les messages en arrière-plan (doit être enregistré tôt)
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // 3) Créer le canal de notification Android (obligatoire Android 8+)
    if (!kIsWeb) {
      try {
        const androidSettings =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        const initSettings =
            InitializationSettings(android: androidSettings);
        await _localNotifications.initialize(initSettings);

        final androidPlugin =
            _localNotifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              _androidChannelId,
              _androidChannelName,
              description: _androidChannelDesc,
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
              enableLights: true,
            ),
          );
          debugPrint('[PUSH] Android notification channel created');
        }
      } catch (e) {
        debugPrint('[PUSH] Error creating notification channel: $e');
      }
    }

    // 4) Permissions notifications
    // Sur Android 13+ (API 33+), il faut EXPLICITEMENT demander POST_NOTIFICATIONS
    // via flutter_local_notifications (pas juste firebase_messaging qui est iOS-only)
    if (!kIsWeb) {
      try {
        final androidPlugin =
            _localNotifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          // Vérifier si les notifications sont déjà autorisées
          final enabled = await androidPlugin.areNotificationsEnabled() ?? false;
          debugPrint('[PUSH] areNotificationsEnabled = $enabled');
          if (!enabled) {
            // Demander la permission Android native (affiche le dialogue système)
            final granted = await androidPlugin.requestNotificationsPermission() ?? false;
            debugPrint('[PUSH] requestNotificationsPermission result = $granted');
          }
        }
      } catch (e) {
        debugPrint('[PUSH] Android permission request error: $e');
      }
    }
    // iOS/Web: utiliser firebase_messaging
    if (kIsWeb) {
      try {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true, badge: true, sound: true,
        );
        debugPrint('[PUSH] FCM Permission: ${settings.authorizationStatus}');
      } catch (e) {
        debugPrint('[PUSH] FCM permission error: $e');
      }
    }

    // 5) Token FCM initial avec retry
    await _getAndRegisterToken();

    // 6) Mise à jour du token FCM
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      if (newToken.isEmpty) return;
      debugPrint('[PUSH] Token refreshed');
      _retryTimer?.cancel();
      _retryCount = 0;
      await _registerToken(newToken);
    });

    // 7) Messages reçus en foreground → afficher une notification locale sur Android
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 8) Gestion des clics sur notification (app ouverte depuis une notif)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Cas où l'application est lancée depuis un état "terminé" par une notif.
    try {
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }
    } catch (_) {}

    _initialized = true;
    debugPrint('[PUSH] init() DONE — token=${_lastRegisteredToken != null ? "registered" : "pending retry"}');
  }

  /// Obtient le token FCM avec retry automatique si SERVICE_NOT_AVAILABLE.
  Future<void> _getAndRegisterToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('[PUSH] FCM token obtained: ${token.substring(0, 20)}...');
        await _registerToken(token);
        _retryCount = 0;
        _retryTimer?.cancel();
        return;
      }
      debugPrint('[PUSH] FCM token is null/empty');
    } catch (e) {
      debugPrint('[PUSH] getToken() FAILED (attempt ${_retryCount + 1}/$_maxRetries): $e');
    }

    // Schedule retry with exponential backoff
    _retryCount++;
    if (_retryCount <= _maxRetries) {
      final delay = Duration(seconds: 10 * _retryCount); // 10s, 20s, 30s, 40s, 50s
      debugPrint('[PUSH] Will retry getToken() in ${delay.inSeconds}s...');
      _retryTimer?.cancel();
      _retryTimer = Timer(delay, () async {
        debugPrint('[PUSH] Retry #$_retryCount getToken()...');
        await _getAndRegisterToken();
      });
    } else {
      debugPrint('[PUSH] GAVE UP after $_maxRetries retries. Push notifications will NOT work on this device.');
      debugPrint('[PUSH] Cause: Google Play Services may be unavailable or outdated.');
    }
  }

  /// Re-enregistre le token FCM après un login (le token existe déjà mais
  /// n'a pas pu être enregistré car l'utilisateur n'était pas connecté).
  Future<void> reRegisterTokenAfterLogin() async {
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('[PUSH] reRegister after login: ${token.substring(0, 20)}...');
        _lastRegisteredToken = null; // Forcer le ré-enregistrement
        await _registerToken(token);
      } else {
        debugPrint('[PUSH] reRegister: token null, scheduling retry');
        _retryCount = 0;
        await _getAndRegisterToken();
      }
    } catch (e) {
      debugPrint('[PUSH] reRegisterTokenAfterLogin error: $e');
      _retryCount = 0;
      await _getAndRegisterToken();
    }
  }

  /// Affiche une notification locale quand un message FCM arrive en foreground.
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint(
      '[PUSH] Foreground message: ${message.notification?.title}',
    );
    final notification = message.notification;
    if (notification == null) return;
    if (kIsWeb) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'Academia',
      notification.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: _androidChannelDesc,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          icon: '@mipmap/ic_launcher',
          fullScreenIntent: true,
          number: 1,
        ),
      ),
    );
  }

  Future<void> _registerToken(String token) async {
    if (token == _lastRegisteredToken) {
      return;
    }

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      debugPrint('[PUSH] _registerToken: user not logged in, will retry after login');
      return;
    }

    final String platform;
    if (kIsWeb) {
      platform = 'web';
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          platform = 'android';
          break;
        case TargetPlatform.iOS:
          platform = 'ios';
          break;
        default:
          platform = 'android';
      }
    }

    try {
      await client.rpc(
        'app_register_device_token',
        params: {
          'p_platform': platform,
          'p_fcm_token': token,
          'p_device_info': null,
        },
      );
      _lastRegisteredToken = token;
      debugPrint('[PUSH] Token registered OK for $platform user=${user.id.substring(0, 8)}...');
    } catch (e) {
      debugPrint('[PUSH] _registerToken RPC error: $e');
    }
  }

  void setOnApplicationNotification(
    void Function(String applicationId) handler,
  ) {
    _onApplicationNotification = handler;
    final pending = _pendingApplicationId;
    if (pending != null) {
      _pendingApplicationId = null;
      handler(pending);
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    final data = message.data;
    if (data.isEmpty) return;

    final domain = data['domain']?.toString();
    if (domain != 'student_applications') {
      return;
    }

    final appId = (data['application_id'] ?? data['applicationId'])?.toString();
    if (appId == null || appId.isEmpty) return;

    final handler = _onApplicationNotification;
    if (handler != null) {
      handler(appId);
    } else {
      _pendingApplicationId = appId;
    }
  }
}

/// Handler pour les messages FCM reçus en arrière-plan.
/// Doit être une fonction top-level (pas une méthode de classe).
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  debugPrint(
    '[PUSH] Background message: ${message.notification?.title}',
  );
}
