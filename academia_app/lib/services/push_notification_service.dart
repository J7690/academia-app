import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service centralisé pour la gestion des notifications push (FCM) côté Flutter.
///
/// Rôles :
/// - Initialiser Firebase (web + mobile)
/// - Configurer Firebase Messaging
/// - Demander les permissions de notifications
/// - Récupérer le token FCM et l'enregistrer côté Supabase via la RPC
///   register_push_token(user_id, token, platform)
///
/// Ce service ne gère PAS la navigation ni la logique métier.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  bool _initialized = false;
  String? _lastRegisteredToken;
  void Function(String applicationId)? _onApplicationNotification;
  String? _pendingApplicationId;

  Future<void> init() async {
    if (_initialized) return;

    // 1) Initialisation Firebase selon la plateforme
    if (Firebase.apps.isEmpty) {
      if (kIsWeb) {
        // Config Web issue du projet Firebase "acadmia-cb427".
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'AIzaSyDWmkr4yNdQkP5QSDRGzX-8UXCB1Jrg30w',
            appId: '1:352842183958:web:892dd9dece487871fde7af',
            messagingSenderId: '352842183958',
            projectId: 'acadmia-cb427',
            storageBucket: 'acadmia-cb427.firebasestorage.app',
          ),
        );
      } else {
        // Sur Android / iOS, on s'appuie sur google-services.json /
        // GoogleService-Info.plist déjà intégrés côté natif.
        await Firebase.initializeApp();
      }
    }

    final messaging = FirebaseMessaging.instance;

    // 2) Permissions notifications (iOS, Web, Android 13+)
    try {
      await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
    } catch (_) {
      // On ne bloque pas l'app si la demande de permission échoue.
    }

    // 3) Token FCM initial
    try {
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }
    } catch (_) {}

    // 4) Mise à jour du token FCM
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      if (newToken.isEmpty) return;
      await _registerToken(newToken);
    });

    // 5) Gestion des clics sur notification (app ouverte depuis une notif)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Cas où l'application est lancée depuis un état "terminé" par une notif.
    try {
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }
    } catch (_) {}

    _initialized = true;
  }

  Future<void> _registerToken(String token) async {
    if (token == _lastRegisteredToken) {
      return;
    }

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      // Pas encore connecté : on attendra un prochain appel après login.
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
    } catch (_) {
      // Si la RPC n'existe pas encore ou échoue, on ne casse pas l'app.
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

