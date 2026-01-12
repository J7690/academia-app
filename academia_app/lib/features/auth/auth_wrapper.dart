import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/push_notification_service.dart';
import '../student/student_dashboard_screen.dart';
import '../university/university_dashboard_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../instructor/instructor_dashboard_screen.dart';
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
    super.initState();
    _client = Supabase.instance.client;
    _authSub = _client.auth.onAuthStateChange.listen((_) {
      if (mounted) {
        setState(() {});
      }
      _startActivityTracking();
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
      default:
        return const AuthLandingScreen();
    }
  }
}
