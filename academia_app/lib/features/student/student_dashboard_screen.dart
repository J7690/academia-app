import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/student_applications_provider.dart';
import '../../providers/student_opportunities_provider.dart';
import '../../services/notification_sound_service.dart';
import 'tabs/student_home_tab.dart';
import 'tabs/student_applications_tab.dart';
import 'tabs/student_opportunities_tab.dart';
import 'tabs/student_communities_tab.dart';
import 'tabs/student_challenges_tab.dart';
import 'tabs/student_partners_tab.dart';
import 'tabs/student_courses_tab.dart';
import 'tabs/student_online_trainings_tab.dart';
import 'tabs/student_live_sessions_tab.dart';
import 'tabs/student_bobodo_tab.dart';

/// Dashboard étudiant avec onglets principaux
class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  int _currentIndex = 0;
  bool _hasNewHomeContent = false;
  Timer? _pollingTimer;
  int _lastStudentUnreadCount = 0;
  bool _studentUnreadInitialized = false;
  bool _studentHomeNotificationInitialized = false;

  @override
  void initState() {
    super.initState();
    _ensureStudentProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // Précharger les candidatures pour que le badge soit à jour
        await context.read<StudentApplicationsProvider>().loadApplications();
        await _checkStudentUnreadChange();
      } catch (_) {}
      try {
        await context.read<StudentOpportunitiesProvider>().loadTypes();
      } catch (_) {}
      await _loadNotificationSummary();
    });

    _pollingTimer = Timer.periodic(const Duration(seconds: 45), (_) async {
      if (!mounted) return;
      try {
        await context.read<StudentApplicationsProvider>().loadApplications();
        await _checkStudentUnreadChange();
      } catch (_) {}
      await _loadNotificationSummary();
    });
  }

  void _ensureStudentProfile() async {
    final client = Supabase.instance.client;
    try {
      await client.rpc('app_ensure_student_profile');
    } catch (_) {}
  }

  Future<void> _loadNotificationSummary() async {
    final client = Supabase.instance.client;
    try {
      final response = await client.rpc('app_get_notification_summary');
      if (response is! Map<String, dynamic>) return;
      if (response['success'] != true) return;
      final summary = response['summary'];
      if (summary is! Map) return;
      final home = summary['student_home'];
      final shortTrainings = summary['short_trainings'];
      final hasNewHome = home is Map && home['has_new'] == true;
      final hasNewShortTrainings = shortTrainings is Map && shortTrainings['has_new'] == true;
      final hasNew = hasNewHome || hasNewShortTrainings;
      if (!mounted) return;
      if (!_studentHomeNotificationInitialized) {
        _studentHomeNotificationInitialized = true;
        setState(() {
          _hasNewHomeContent = hasNew;
        });
        return;
      }
      final previous = _hasNewHomeContent;
      if (!previous && hasNew) {
        try {
          await NotificationSoundService.instance.playIfEnabled();
        } catch (_) {}
      }
      setState(() {
        _hasNewHomeContent = hasNew;
      });
    } catch (_) {}
  }

  Future<void> _markStudentHomeSeen() async {
    final client = Supabase.instance.client;
    try {
      await client.rpc('app_mark_domain_seen', params: {
        'p_domain': 'student_home',
      });
      await client.rpc('app_mark_domain_seen', params: {
        'p_domain': 'short_trainings',
      });
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _hasNewHomeContent = false;
    });
  }

  Future<void> _checkStudentUnreadChange() async {
    if (!mounted) return;
    final provider = context.read<StudentApplicationsProvider>();
    final current = provider.unreadCount;
    if (!_studentUnreadInitialized) {
      _studentUnreadInitialized = true;
      _lastStudentUnreadCount = current;
      return;
    }
    if (current > _lastStudentUnreadCount && current > 0) {
      _lastStudentUnreadCount = current;
      try {
        await NotificationSoundService.instance.playIfEnabled();
      } catch (_) {}
    } else {
      _lastStudentUnreadCount = current;
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      const StudentHomeTab(),
      const StudentApplicationsTab(),
      const StudentOpportunitiesTab(),
      const StudentCommunitiesTab(),
      const StudentChallengesTab(),
      const StudentPartnersTab(),
      const StudentCoursesTab(),
      const StudentOnlineTrainingsTab(),
      const StudentLiveSessionsTab(),
      const StudentBobodoTab(),
    ];

    return Consumer<StudentApplicationsProvider>(
      builder: (context, applicationsProvider, child) {
        final unread = applicationsProvider.unreadCount;
        return Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),
          body: tabs[_currentIndex],
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFA3D65C), Color(0xFF1EA75C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              indicatorColor: Colors.white.withOpacity(0.2),
              height: 52,
              labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
                if (index == 0) {
                  _markStudentHomeSeen();
                }
              },
              destinations: [
                NavigationDestination(
                  icon: _HomeNavIcon(
                    icon: Icons.home_outlined,
                    hasNew: _hasNewHomeContent,
                  ),
                  selectedIcon: _HomeNavIcon(
                    icon: Icons.home,
                    hasNew: _hasNewHomeContent,
                  ),
                  label: 'Accueil',
                ),
                NavigationDestination(
                  icon: _NavBadgeIcon(
                    icon: Icons.assignment_outlined,
                    count: unread,
                  ),
                  selectedIcon: _NavBadgeIcon(
                    icon: Icons.assignment,
                    count: unread,
                  ),
                  label: 'Candidatures',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.work_outline),
                  selectedIcon: Icon(Icons.work),
                  label: 'Opportunités',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.groups_outlined),
                  selectedIcon: Icon(Icons.groups),
                  label: 'Communautés',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.emoji_events_outlined),
                  selectedIcon: Icon(Icons.emoji_events),
                  label: 'Challenges',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.apartment_outlined),
                  selectedIcon: Icon(Icons.apartment),
                  label: 'Universités',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: 'Cours',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.play_circle_outline),
                  selectedIcon: Icon(Icons.play_circle),
                  label: 'Formations',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.videocam_outlined),
                  selectedIcon: Icon(Icons.videocam),
                  label: 'Lives',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.smart_toy_outlined),
                  selectedIcon: Icon(Icons.smart_toy),
                  label: 'Bobodo',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavBadgeIcon extends StatelessWidget {
  final IconData icon;
  final int count;

  const _NavBadgeIcon({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return Icon(icon);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Color(0xFFFF3B30),
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
            child: Center(
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeNavIcon extends StatelessWidget {
  final IconData icon;
  final bool hasNew;

  const _HomeNavIcon({required this.icon, required this.hasNew});

  @override
  Widget build(BuildContext context) {
    if (!hasNew) {
      return Icon(icon);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFFFF3B30),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}
