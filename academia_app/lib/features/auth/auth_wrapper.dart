import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../student/student_dashboard_screen.dart';
import '../university/university_dashboard_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import 'auth_landing_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late final SupabaseClient _client;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;
    _authSub = _client.auth.onAuthStateChange.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
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
        return const StudentDashboardScreen();
      case 'university':
        return const UniversityDashboardScreen();
      case 'admin':
        return const AdminDashboardScreen();
      default:
        return const AuthLandingScreen();
    }
  }
}
