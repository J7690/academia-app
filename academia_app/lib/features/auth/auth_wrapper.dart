import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/push_notification_service.dart';
import '../student/student_dashboard_screen.dart';
import '../university/university_dashboard_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../instructor/instructor_dashboard_screen.dart';
import '../commercial/commercial_dashboard_screen.dart';
import '../merchant/merchant_dashboard_screen_v2.dart';
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
    super.initState();
    _client = Supabase.instance.client;
    _authSub = _client.auth.onAuthStateChange.listen((_) {
      if (mounted) {
        setState(() {
          _referralHandledForSession = false;
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
      final prefs = await SharedPreferences.getInstance();
      final refCode = prefs.getString('pending_referral_code_v1');
      debugPrint('ReferralAttach: pending_referral_code_v1=' +
          (refCode ?? 'null'));
      if (refCode == null || refCode.trim().isEmpty) {
        _referralHandledForSession = true;
        return;
      }

      final source =
          prefs.getString('pending_referral_source_v1') ?? 'link';

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

  @override
  Widget build(BuildContext context) {
    final session = _client.auth.currentSession;

    if (session == null) {
      return const AuthLandingScreen();
    }

    // Rattacher un éventuel parrainage capturé avant la création du compte.
    // On le fait ici car on est certain que l'utilisateur est authentifié.
    _attachReferralIfNeeded();

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
      case 'merchant':
        return const MerchantDashboardScreenV2();
      default:
        return const AuthLandingScreen();
    }
  }
}
