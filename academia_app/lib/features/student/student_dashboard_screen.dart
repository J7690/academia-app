import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/student_applications_provider.dart';
import '../../providers/student_opportunities_provider.dart';
import '../../services/notification_sound_service.dart';
import '../../utils/responsive.dart';
import 'student_home_mobile.dart';
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
import 'student_dashboard_nav_controller.dart';

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
  VoidCallback? _navListener;

  @override
  void initState() {
    super.initState();
    StudentDashboardNavController.setIndex(_currentIndex);
    _navListener = () {
      final newIndex = StudentDashboardNavController.currentIndex;
      if (newIndex != _currentIndex) {
        setState(() {
          _currentIndex = newIndex;
        });
        if (newIndex == 0) {
          _markStudentHomeSeen();
        }
      }
    };
    StudentDashboardNavController.indexNotifier.addListener(_navListener!);
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
    if (_navListener != null) {
      StudentDashboardNavController.indexNotifier.removeListener(_navListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    return Consumer<StudentApplicationsProvider>(
      builder: (context, applicationsProvider, child) {
        final unread = applicationsProvider.unreadCount;

        Widget? bottomNav;
        if (isMobile) {
          if (_currentIndex != 4) {
            bottomNav = _buildMobileBottomNav(unread);
          }
        } else {
          bottomNav = _buildDesktopBottomNav(unread);
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),
          body: _buildCurrentTabBody(isMobile),
          bottomNavigationBar: bottomNav,
        );
      },
    );
  }

  Widget _buildCurrentTabBody(bool isMobile) {
    late final Widget child;

    if (isMobile) {
      switch (_currentIndex) {
        case 0:
          child = const StudentHomeMobileTab();
          break;
        case 1:
          child = const StudentApplicationsTab();
          break;
        case 2:
          child = const StudentOpportunitiesTab();
          break;
        case 3:
          child = const StudentCommunitiesTab();
          break;
        case 4:
          child = const StudentChallengesFeedScreen();
          break;
        case 5:
          child = const StudentPartnersTab();
          break;
        case 6:
          child = const StudentCoursesTab();
          break;
        case 7:
          child = const StudentOnlineTrainingsTab();
          break;
        case 8:
          child = const StudentLiveSessionsTab();
          break;
        case 9:
          child = const StudentBobodoTab();
          break;
        default:
          child = const StudentHomeMobileTab();
      }

      return SafeArea(
        top: true,
        bottom: false,
        left: false,
        right: false,
        child: child,
      );
    } else {
      switch (_currentIndex) {
        case 0:
          child = const StudentHomeTab();
          break;
        case 1:
          child = const StudentApplicationsTab();
          break;
        case 2:
          child = const StudentOpportunitiesTab();
          break;
        case 3:
          child = const StudentCommunitiesTab();
          break;
        case 4:
          child = const StudentChallengesFeedScreen();
          break;
        case 5:
          child = const StudentPartnersTab();
          break;
        case 6:
          child = const StudentCoursesTab();
          break;
        case 7:
          child = const StudentOnlineTrainingsTab();
          break;
        case 8:
          child = const StudentLiveSessionsTab();
          break;
        case 9:
          child = const StudentBobodoTab();
          break;
        default:
          child = const StudentHomeTab();
      }
      return child;
    }
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
    StudentDashboardNavController.setIndex(index);
    if (index == 0) {
      _markStudentHomeSeen();
    }
  }

  Widget _buildDesktopBottomNav(int unread) {
    return Container(
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
        onDestinationSelected: _onDestinationSelected,
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
    );
  }

  Widget _buildMobileBottomNav(int unread) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SizedBox(
          height: 76,
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.92,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F3FA),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        offset: Offset(0, 12),
                        blurRadius: 32,
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        _buildMobileNavItem(
                          index: 0,
                          label: 'Accueil',
                          icon: _HomeNavIcon(
                            icon: Icons.home_outlined,
                            hasNew: _hasNewHomeContent,
                          ),
                          selectedIcon: _HomeNavIcon(
                            icon: Icons.home,
                            hasNew: _hasNewHomeContent,
                          ),
                        ),
                        _buildMobileNavItem(
                          index: 1,
                          label: 'Candidatures',
                          icon: _NavBadgeIcon(
                            icon: Icons.assignment_outlined,
                            count: unread,
                          ),
                          selectedIcon: _NavBadgeIcon(
                            icon: Icons.assignment,
                            count: unread,
                          ),
                        ),
                        _buildMobileNavItem(
                          index: 2,
                          label: 'Opportunités',
                          icon: const Icon(Icons.work_outline),
                          selectedIcon: const Icon(Icons.work),
                        ),
                        _buildMobileNavItem(
                          index: 3,
                          label: 'Communautés',
                          icon: const Icon(Icons.groups_outlined),
                          selectedIcon: const Icon(Icons.groups),
                        ),
                        _buildMobileNavItem(
                          index: 4,
                          label: 'Challenges',
                          icon: const Icon(Icons.emoji_events_outlined),
                          selectedIcon: const Icon(Icons.emoji_events),
                        ),
                        _buildMobileNavItem(
                          index: 5,
                          label: 'Universités',
                          icon: const Icon(Icons.apartment_outlined),
                          selectedIcon: const Icon(Icons.apartment),
                        ),
                        _buildMobileNavItem(
                          index: 6,
                          label: 'Cours',
                          icon: const Icon(Icons.menu_book_outlined),
                          selectedIcon: const Icon(Icons.menu_book),
                        ),
                        _buildMobileNavItem(
                          index: 7,
                          label: 'Formations',
                          icon: const Icon(Icons.play_circle_outline),
                          selectedIcon: const Icon(Icons.play_circle),
                        ),
                        _buildMobileNavItem(
                          index: 8,
                          label: 'Lives',
                          icon: const Icon(Icons.videocam_outlined),
                          selectedIcon: const Icon(Icons.videocam),
                        ),
                        _buildMobileNavItem(
                          index: 9,
                          label: 'Bobodo',
                          icon: const Icon(Icons.smart_toy_outlined),
                          selectedIcon: const Icon(Icons.smart_toy),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileNavItem({
    required int index,
    required String label,
    required Widget icon,
    required Widget selectedIcon,
  }) {
    const double iconSize = 24;
    const double fontSize = 11;
    final bool isSelected = _currentIndex == index;

    final Color selectedColor = const Color(0xFF0A2540);
    final Color unselectedColor = const Color(0xFF60748F);

    final Widget effectiveIcon = isSelected ? selectedIcon : icon;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: AnimatedScale(
        scale: isSelected ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _onDestinationSelected(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:
                  isSelected ? Colors.white.withOpacity(0.9) : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconTheme(
                  data: IconThemeData(
                    color: isSelected ? selectedColor : unselectedColor,
                    size: iconSize,
                  ),
                  child: effectiveIcon,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? selectedColor : unselectedColor,
                    fontSize: fontSize,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
