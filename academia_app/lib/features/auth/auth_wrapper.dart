import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/push_notification_service.dart';
import '../../services/share_tracking_service.dart';
import '../student/student_dashboard_screen.dart';
import '../university/university_dashboard_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../instructor/instructor_dashboard_screen.dart';
import '../commercial/commercial_dashboard_screen.dart';
import '../merchant/merchant_dashboard_screen_v2.dart';
import '../manager/manager_dashboard_screen.dart';
import '../orientation/counselor_dashboard_screen.dart';
import 'auth_landing_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late final SupabaseClient _client;
  StreamSubscription<AuthState>? _authSub;
  String? _pendingApplicationIdFromNotification;

  @override
  void initState() {
    print('P11_FIRST_SCREEN');
    super.initState();
    _client = Supabase.instance.client;
    _authSub = _client.auth.onAuthStateChange.listen((_) {
      if (mounted) {
        setState(() {
          _marketingAttrHandledForSession = false;
        });
      }
      _startActivityTracking();
      // Re-enregistrer le token FCM après login pour que Supabase
      // connaisse le device de l'utilisateur connecté.
      PushNotificationService.instance.reRegisterTokenAfterLogin();
    });
    _startActivityTracking();

    // Brancher le handler de notifications push pour les candidatures étudiant.
    PushNotificationService.instance
        .setOnApplicationNotification(_handleApplicationNotification);
  }

  @override
  void dispose() {
    _activityTimer?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  Timer? _activityTimer;
  bool _shareHandledForSession = false;
  bool _marketingAttrHandledForSession = false;

  Future<void> _captureShareIfNeeded() async {
    if (_shareHandledForSession) {
      debugPrint('ShareCapture: already handled for this session, skipping.');
      return;
    }

    final session = _client.auth.currentSession;
    if (session == null) {
      debugPrint('ShareCapture: no current session, skipping.');
      return;
    }

    try {
      final shareService = ShareTrackingService();
      final studentId = session.user.id;
      
      // Capturer depuis les paramètres URL actuels
      // Note: Pour une vraie app mobile, il faudrait utiliser uni_links ou deep linking
      // Ici on simule avec Uri.base pour le web
      final uri = Uri.base;
      await shareService.captureFromUrl(uri, studentId);
      
      _shareHandledForSession = true;
      debugPrint('ShareCapture: share captured successfully');
    } catch (e) {
      debugPrint('ShareCapture: error while capturing share: ' + e.toString());
      _shareHandledForSession = true;
    }
  }

  /// Attribution MARKETING (campagnes Facebook pilotées par Claude, multi-canal).
  /// Totalement ISOLÉE du référencement commercial : n'écrit QUE dans
  /// app.marketing_attributions via la RPC dédiée, ne touche jamais aux
  /// commissions ni à user_referrals. First-touch garanti côté base.
  Future<void> _captureMarketingAttributionIfNeeded() async {
    if (_marketingAttrHandledForSession) return;

    final session = _client.auth.currentSession;
    if (session == null) return;

    try {
      // Priorité : paramètre URL ?src= > SharedPreferences > user_metadata['mkt_ref'].
      String? mktRef;
      try {
        final urlSrc = Uri.base.queryParameters['src'];
        if (urlSrc != null && urlSrc.trim().isNotEmpty) mktRef = urlSrc.trim();
      } catch (_) {}

      final prefs = await SharedPreferences.getInstance();
      if (mktRef == null || mktRef.isEmpty) {
        final pref = prefs.getString('pending_marketing_ref_v1');
        if (pref != null && pref.trim().isNotEmpty) mktRef = pref.trim();
      }
      if (mktRef == null || mktRef.isEmpty) {
        final metaRef = session.user.userMetadata?['mkt_ref']?.toString();
        if (metaRef != null && metaRef.trim().isNotEmpty) mktRef = metaRef.trim();
      }

      if (mktRef == null || mktRef.isEmpty) {
        _marketingAttrHandledForSession = true;
        return;
      }

      final result = await _client.rpc(
        'app_register_marketing_attribution',
        params: {'p_ref': mktRef},
      );
      debugPrint('MarketingAttr: RPC result=' + result.toString());

      if (result is Map && result['success'] == true) {
        await prefs.remove('pending_marketing_ref_v1');
      }
    } catch (e) {
      // Ne jamais bloquer la connexion si l'attribution marketing échoue.
      debugPrint('MarketingAttr: error while capturing attribution: ' + e.toString());
    } finally {
      _marketingAttrHandledForSession = true;
    }
  }

  void _startActivityTracking() {
    _activityTimer?.cancel();
    final session = _client.auth.currentSession;
    if (session == null) {
      return;
    }

    // Enregistrer une activité immédiate puis périodiquement.
    _trackActivity();
    _activityTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _trackActivity();
    });
  }

  Future<void> _trackActivity() async {
    try {
      await _client.rpc('app_track_user_activity');
    } catch (_) {
      // On ignore les erreurs réseau ici : la présence sera mise à jour
      // au prochain appel réussi.
    }
  }

  void _handleApplicationNotification(String applicationId) {
    setState(() {
      _pendingApplicationIdFromNotification = applicationId;
    });
  }

  bool _accountStatusChecked = false;
  bool _accountBlocked = false;

  Future<void> _checkAccountStatus() async {
    if (_accountStatusChecked) return;
    try {
      final result = await _client.rpc('app_check_account_status');
      if (result is Map && result['active'] == false) {
        _accountBlocked = true;
        // Un compte bloqué ne doit plus rien recevoir sur cet appareil.
        await PushNotificationService.instance.unregisterTokenBeforeLogout();
        await _client.auth.signOut();
        debugPrint('AuthWrapper: account blocked (${result['reason']}), signed out.');
      }
    } catch (e) {
      debugPrint('AuthWrapper: account status check error: $e');
    } finally {
      _accountStatusChecked = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _client.auth.currentSession;

    if (session == null) {
      return const AuthLandingScreen();
    }

    // Check if account is deleted/suspended server-side
    if (!_accountStatusChecked) {
      _checkAccountStatus();
    }
    if (_accountBlocked) {
      return const AuthLandingScreen();
    }

    // Capturer les partages depuis les paramètres URL
    _captureShareIfNeeded();

    // Capturer l'attribution marketing (campagnes Facebook/Claude), isolée du commercial.
    _captureMarketingAttributionIfNeeded();

    final user = session.user;
    final metadata = user.userMetadata ?? <String, dynamic>{};
    final role = (metadata['role'] as String?) ?? 'student';

    switch (role) {
      case 'student':
        return StudentDashboardScreen(
          initialApplicationId: _pendingApplicationIdFromNotification,
        );
      case 'instructor':
        return const InstructorDashboardScreen();
      case 'university':
        return const UniversityDashboardScreen();
      case 'admin':
        return const AdminDashboardScreen();
      case 'commercial':
        return const CommercialDashboardScreen();
      case 'manager':
        return const ManagerDashboardScreen();
      case 'merchant':
        return const MerchantDashboardScreenV2();
      case 'orientation_counselor':
        // Le conseiller d'orientation n'anime ni cours ni TD : son espace est
        // son agenda de consultations, le dossier de chaque élève, les fiches
        // d'orientation qu'il rédige et ses revenus.
        return const CounselorDashboardScreen();
      default:
        return const AuthLandingScreen();
    }
  }
}
