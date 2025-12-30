import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/admin_applications_provider.dart';
import '../../services/notification_sound_service.dart';
import '../../widgets/notification_sound_settings_dialog.dart';
import 'admin_applications_screen.dart';
import 'admin_payments_screen.dart';
import 'admin_payment_receipts_screen.dart';
import 'admin_programs_screen.dart';
import 'admin_opportunities_screen.dart';
import 'admin_communities_screen.dart';
import 'admin_challenges_screen.dart';
import 'admin_course_library_screen.dart';
import 'admin_online_courses_screen.dart';
import 'admin_short_trainings_screen.dart';
import 'admin_university_sites_screen.dart';
import 'admin_bobodo_screen.dart';
import 'prep_concours/admin_prep_concours_screen.dart';
import 'admin_landing_screen.dart';
import 'admin_student_home_screen.dart';
import 'admin_hero_accueil_screen.dart';
import 'admin_user_invitations_screen.dart';
import 'admin_live_sessions_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _hasNewUniversityContent = false;
  bool _hasNewShortTrainings = false;
  bool _hasNewPayments = false;
  Timer? _pollingTimer;
  int _lastAdminUnreadCount = 0;
  bool _adminUnreadInitialized = false;
  bool _adminContentNotificationInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotificationSummary();
    });

    _pollingTimer = Timer.periodic(const Duration(seconds: 45), (_) async {
      if (!mounted) return;
      try {
        await context.read<AdminApplicationsProvider>().loadApplications();
        await _checkAdminUnreadChange();
      } catch (_) {}
      await _loadNotificationSummary();
    });
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  Future<void> _loadNotificationSummary() async {
    final client = Supabase.instance.client;
    try {
      final response = await client.rpc('app_get_notification_summary');
      if (response is! Map<String, dynamic>) return;
      if (response['success'] != true) return;
      final summary = response['summary'];
      if (summary is! Map) return;
      debugPrint('[AdminDashboard] notification summary keys: ' +
          summary.keys.map((e) => e.toString()).toList().toString());
      debugPrint('[AdminDashboard] admin_payments summary: ' +
          (summary['admin_payments']?.toString() ?? 'null'));
      final adminContent = summary['admin_university_content'];
      final adminShortTrainings = summary['admin_short_trainings'];
      final adminPayments = summary['admin_payments'];

      final hasNewUniversity =
          adminContent is Map && adminContent['has_new'] == true;
      final hasNewShort =
          adminShortTrainings is Map && adminShortTrainings['has_new'] == true;
      final hasNewPayments =
          adminPayments is Map && adminPayments['has_new'] == true;
      if (!mounted) return;
      if (!_adminContentNotificationInitialized) {
        _adminContentNotificationInitialized = true;
        setState(() {
          _hasNewUniversityContent = hasNewUniversity;
          _hasNewShortTrainings = hasNewShort;
          _hasNewPayments = hasNewPayments;
        });
        return;
      }
      final previousUniversity = _hasNewUniversityContent;
      final previousShort = _hasNewShortTrainings;
      final previousPayments = _hasNewPayments;
      final willPlaySound =
          (!previousUniversity && hasNewUniversity) ||
          (!previousShort && hasNewShort) ||
          (!previousPayments && hasNewPayments);
      if (willPlaySound) {
        try {
          await NotificationSoundService.instance.playIfEnabled();
        } catch (_) {}
      }
      setState(() {
        _hasNewUniversityContent = hasNewUniversity;
        _hasNewShortTrainings = hasNewShort;
        _hasNewPayments = hasNewPayments;
      });
    } catch (_) {}
  }

  Future<void> _markAdminUniversityContentSeen() async {
    final client = Supabase.instance.client;
    try {
      await client.rpc('app_mark_domain_seen', params: {
        'p_domain': 'admin_university_content',
      });
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _hasNewUniversityContent = false;
    });
  }

  Future<void> _markAdminShortTrainingsSeen() async {
    final client = Supabase.instance.client;
    try {
      await client.rpc('app_mark_domain_seen', params: {
        'p_domain': 'admin_short_trainings',
      });
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _hasNewShortTrainings = false;
    });
  }

  Future<void> _markAdminPaymentsSeen() async {
    final client = Supabase.instance.client;
    try {
      await client.rpc('app_mark_domain_seen', params: {
        'p_domain': 'admin_payments',
      });
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _hasNewPayments = false;
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAdminUnreadChange() async {
    if (!mounted) return;
    final provider = context.read<AdminApplicationsProvider>();
    final current = provider.unreadCount;
    if (!_adminUnreadInitialized) {
      _adminUnreadInitialized = true;
      _lastAdminUnreadCount = current;
      return;
    }
    if (current > _lastAdminUnreadCount && current > 0) {
      _lastAdminUnreadCount = current;
      try {
        await NotificationSoundService.instance.playIfEnabled();
      } catch (_) {}
    } else {
      _lastAdminUnreadCount = current;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 18,
      child: Consumer<AdminApplicationsProvider>(
        builder: (context, applicationsProvider, child) {
          final unread = applicationsProvider.unreadCount;
          return Scaffold(
            backgroundColor: const Color(0xFFF3F4F6),
            appBar: AppBar(
              elevation: 0,
              centerTitle: false,
              title: const Text('Dashboard Admin'),
              foregroundColor: Colors.white,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFA3D65C), Color(0xFF1EA75C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              actions: [
                IconButton(
                  onPressed: () {
                    NotificationSoundSettingsDialog.show(context);
                  },
                  icon: const Icon(Icons.settings),
                  tooltip: 'Paramètres',
                ),
                IconButton(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout),
                  tooltip: 'Se déconnecter',
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
                indicator: BoxDecoration(
                  color: const Color(0xFF1EA75C),
                  borderRadius: BorderRadius.circular(999),
                ),
                indicatorPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.85),
                onTap: (index) {
                  if (index == 1) {
                    _markAdminPaymentsSeen();
                  } else if (index == 10) {
                    _markAdminShortTrainingsSeen();
                  } else if (index == 11) {
                    _markAdminUniversityContentSeen();
                  }
                },
                tabs: [
                  Tab(child: _AdminTabLabel(text: 'Candidatures', count: unread)),
                  Tab(
                    child: _AdminDotLabel(
                      text: 'Paiements',
                      hasNew: _hasNewPayments,
                    ),
                  ),
                  const Tab(text: 'Reçus'),
                  const Tab(text: 'Programmes'),
                  const Tab(text: 'Opportunités'),
                  const Tab(text: 'Communautés'),
                  const Tab(text: 'Challenges'),
                  const Tab(text: 'Bibliothèque de cours'),
                  const Tab(text: 'Cours en ligne'),
                  const Tab(text: 'Lives'),
                  Tab(
                    child: _AdminDotLabel(
                      text: 'Formations courtes',
                      hasNew: _hasNewShortTrainings,
                    ),
                  ),
                  Tab(
                    child: _AdminDotLabel(
                      text: 'Mini-sites',
                      hasNew: _hasNewUniversityContent,
                    ),
                  ),
                  const Tab(text: 'Bobodo'),
                  const Tab(text: 'Prépa concours'),
                  const Tab(text: 'Accueil étudiant'),
                  const Tab(text: 'Landing'),
                  const Tab(text: 'Hero / Accueil TV'),
                  const Tab(text: 'Invitations'),
                ],
              ),
            ),
            body: const TabBarView(
              children: [
                AdminApplicationsScreen(),
                AdminPaymentsScreen(),
                AdminPaymentReceiptsScreen(),
                AdminProgramsScreen(),
                AdminOpportunitiesScreen(),
                AdminCommunitiesScreen(),
                AdminChallengesScreen(),
                AdminCourseLibraryScreen(),
                AdminOnlineCoursesScreen(),
                AdminLiveSessionsScreen(),
                AdminShortTrainingsScreen(),
                AdminUniversitySitesScreen(),
                AdminBobodoScreen(),
                AdminPrepConcoursScreen(),
                AdminStudentHomeScreen(),
                AdminLandingScreen(),
                AdminHeroAccueilScreen(),
                AdminUserInvitationsScreen(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdminTabLabel extends StatelessWidget {
  final String text;
  final int count;

  const _AdminTabLabel({required this.text, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return Text(text);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFF3B30),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count > 9 ? '9+' : '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminDotLabel extends StatelessWidget {
  final String text;
  final bool hasNew;

  const _AdminDotLabel({required this.text, required this.hasNew});

  @override
  Widget build(BuildContext context) {
    if (!hasNew) {
      return Text(text);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        const SizedBox(width: 4),
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFFFF3B30),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}
