import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/push_notification_service.dart';
import '../../services/share_tracking_service.dart';
import '../../services/install_referrer_service.dart';
import '../../services/deep_link_service.dart';
import '../student/student_dashboard_screen.dart';
import '../university/university_dashboard_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../instructor/instructor_dashboard_screen.dart';
import '../commercial/commercial_dashboard_screen.dart';
import '../merchant/merchant_dashboard_screen_v2.dart';
import '../manager/manager_dashboard_screen.dart';
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
  bool _referralHandledForSession = false;

  @override
  void initState() {
    print('P11_FIRST_SCREEN');
    super.initState();
    _client = Supabase.instance.client;
    _authSub = _client.auth.onAuthStateChange.listen((_) {
      if (mounted) {
        setState(() {
          _referralHandledForSession = false;
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

    // Initialiser Install Referrer Service pour Play Store attribution
    InstallReferrerService.instance.initialize();
    DeepLinkService.instance.getInitialLink().then((link) {
      if (link != null) _captureReferralFromDeepLink(link);
    });
    DeepLinkService.instance.listenForLinks(_captureReferralFromDeepLink);
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

  Future<void> _captureReferralFromDeepLink(String link) async {
    if (_client.auth.currentSession != null) return;

    try {
      final uri = Uri.parse(link);
      // B2 : accepter le domaine canonique et sa variante www (les utilisateurs
      // tapent souvent www.app.academiea.com).
      const allowedHosts = {'app.academiea.com', 'www.app.academiea.com'};
      if (uri.scheme != 'https' || !allowedHosts.contains(uri.host)) return;

      final segments = uri.pathSegments;
      if (segments.length < 2 || segments.first != 'ref') return;

      final refCode = segments[1].trim();
      if (refCode.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_referral_code_v1', refCode);
      await prefs.setString('pending_referral_source_v1', 'link');
    } catch (e) {
      debugPrint('ReferralAppLink: error while capturing link: $e');
    }
  }

  Future<void> _attachReferralIfNeeded() async {
    if (_referralHandledForSession) {
      debugPrint('ReferralAttach: already handled for this session, skipping.');
      return;
    }

    final session = _client.auth.currentSession;
    if (session == null) {
      debugPrint('ReferralAttach: no current session, skipping.');
      return;
    }

    try {
      debugPrint('ReferralAttach: session userId=' + session.user.id);

      String? refCode;
      String source = 'link';

      // Priority 1: Install Referrer Service (Play Store attribution).
      // Aucune saisie requise : le token capté au clic est résolu en ref_code.
      final referrerService = InstallReferrerService.instance;
      await referrerService.initialize();
      final installRefCode = referrerService.resolvedRefCode;
      debugPrint('ReferralAttach: InstallReferrer ref_code=' + (installRefCode ?? 'null'));
      if (installRefCode != null && installRefCode.trim().isNotEmpty) {
        refCode = installRefCode.trim();
        source = 'play_store_install';
      }

      // Priority 2: Use URL parameters (web deep linking, ?ref= capté avant inscription)
      final prefs = await SharedPreferences.getInstance();
      if (refCode == null || refCode.trim().isEmpty) {
        final prefRefCode = prefs.getString('pending_referral_code_v1');
        debugPrint('ReferralAttach: SharedPrefs refCode=' + (prefRefCode ?? 'null'));
        if (prefRefCode != null && prefRefCode.trim().isNotEmpty) {
          refCode = prefRefCode.trim();
          source = prefs.getString('pending_referral_source_v1') ?? 'link';
        }
      }

      // Priority 3 (filet de secours): user_metadata — ?ref= capté côté serveur au
      // signUp, ou saisie manuelle du code de parrainage par l'utilisateur.
      if (refCode == null || refCode.trim().isEmpty) {
        final metadata = session.user.userMetadata;
        final metaRef = metadata?['ref_code']?.toString();
        debugPrint('ReferralAttach: user_metadata ref_code=' + (metaRef ?? 'null'));
        if (metaRef != null && metaRef.trim().isNotEmpty) {
          refCode = metaRef.trim();
          source = 'metadata';
        }
      }

      if (refCode == null || refCode.trim().isEmpty) {
        _referralHandledForSession = true;
        return;
      }

      debugPrint('ReferralAttach: calling app_register_referral_for_current_user '
          'with refCode=' +
          refCode +
          ' source=' +
          source);

      final result = await _client
          .rpc('app_register_referral_for_current_user', params: {
        'p_ref_code': refCode,
        'p_source': source,
      });

      debugPrint('ReferralAttach: RPC result=' + result.toString());

      if (result is Map && result['success'] == true) {
        await prefs.remove('pending_referral_code_v1');
        await prefs.remove('pending_referral_source_v1');
        debugPrint('ReferralAttach: cleared pending referral from preferences.');
      } else {
        debugPrint('ReferralAttach: RPC did not succeed, keeping pending referral in preferences.');
      }
    } catch (e) {
      // On n'échoue pas la connexion si le rattachement échoue.
      debugPrint('ReferralAttach: error while attaching referral: ' +
          e.toString());
    } finally {
      _referralHandledForSession = true;
      debugPrint('ReferralAttach: mark handledForSession=true');
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

    // Rattacher un éventuel parrainage capturé avant la création du compte.
    // On le fait ici car on est certain que l'utilisateur est authentifié.
    _attachReferralIfNeeded();
    
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
      default:
        return const AuthLandingScreen();
    }
  }
}
