import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/student_applications_provider.dart';
import '../../providers/student_application_payments_provider.dart';
import '../../providers/student_communities_provider.dart';
import '../../services/app_badge_service.dart';
import '../../services/notification_sound_service.dart';
import '../../utils/responsive.dart';
import 'student_home_mobile.dart';
import 'tabs/student_home_tab.dart';
import 'tabs/student_applications_tab.dart';
import 'tabs/student_opportunities_tab.dart';
import 'tabs/student_communities_tab.dart';
import 'tabs/student_partners_tab.dart';
import 'tabs/student_bobodo_tab.dart';
import 'student_prep_concours_screen.dart';
import 'student_dashboard_nav_controller.dart';
import 'student_td_root_screen.dart';
import 'student_application_detail_screen.dart';
import 'tabs/student_challenges_tab.dart';
import 'tabs/student_courses_tab.dart';
import 'tabs/student_live_sessions_tab.dart';
import '../share/share_mode_provider.dart';
import '../../widgets/student_assistant_overlay.dart';
import '../../services/push_trigger_service.dart';
import '../../widgets/notification_permission_checker.dart';
import '../../widgets/support_fab.dart';

/// Dashboard étudiant avec onglets principaux
class StudentDashboardScreen extends StatefulWidget {
  final String? initialApplicationId;

  const StudentDashboardScreen({super.key, this.initialApplicationId});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  int _currentIndex = 0;
  int _countHome = 0;
  int _countChallenges = 0;
  int _countCourses = 0;
  int _countTrainings = 0;
  int _countLives = 0;
  int _countPayments = 0;
  int _countCommunities = 0;
  int _countPartners = 0;
  int _countBobodo = 0;
  Timer? _pollingTimer;
  int _lastStudentUnreadCount = 0;
  bool _studentUnreadInitialized = false;
  bool _studentHomeNotificationInitialized = false;
  VoidCallback? _navListener;
  String? _pendingApplicationId;

  @override
  void initState() {
    super.initState();
    _pendingApplicationId = widget.initialApplicationId;
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
        // Marketplace categories are loaded by the opportunities tab itself
      } catch (_) {}
      await _loadNotificationSummary();
      PushTriggerService.instance.triggerPendingPush();
      if (mounted) NotificationPermissionChecker.instance.checkAndRequest(context);

      final pendingAppId = _pendingApplicationId;
      if (pendingAppId != null && mounted) {
        _pendingApplicationId = null;
        await _openApplicationFromNotification(pendingAppId);
      }
    });

    _pollingTimer = Timer.periodic(const Duration(seconds: 45), (_) async {
      if (!mounted) return;
      try {
        await context.read<StudentApplicationsProvider>().loadApplications();
        await _checkStudentUnreadChange();
      } catch (_) {}
      await _loadNotificationSummary();
      PushTriggerService.instance.triggerPendingPush();
    });
  }

  Future<void> _openApplicationFromNotification(String applicationId) async {
    final applicationsProvider = context.read<StudentApplicationsProvider>();
    final apps = applicationsProvider.applications;
    Map<String, dynamic>? app;
    for (final a in apps) {
      if (a['id']?.toString() == applicationId) {
        app = a;
        break;
      }
    }

    if (app == null) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _currentIndex = 1;
    });
    StudentDashboardNavController.setIndex(1);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => StudentApplicationPaymentsProvider(),
          child: StudentApplicationDetailScreen(
            application: app!,
            initialTabIndex: 1,
          ),
        ),
      ),
    );
  }

  void _ensureStudentProfile() async {
    final client = Supabase.instance.client;
    try {
      await client.rpc('app_ensure_student_profile');
    } catch (_) {}
  }

  /// Extract new_count from a summary domain map, falling back to 1 if has_new is true.
  int _extractCount(dynamic domainData) {
    if (domainData is! Map) return 0;
    final hasNew = domainData['has_new'] == true;
    final rawCount = domainData['new_count'] ??
        domainData['unseen_count'] ??
        domainData['unread_count'] ??
        domainData['count'];
    int count = 0;
    if (rawCount is int) {
      count = rawCount;
    } else if (rawCount is String) {
      count = int.tryParse(rawCount) ?? 0;
    }
    if (hasNew && count == 0) count = 1;
    return count;
  }

  Future<void> _loadNotificationSummary() async {
    final client = Supabase.instance.client;
    try {
      final response = await client.rpc('app_get_notification_summary');
      if (response is! Map<String, dynamic>) return;
      if (response['success'] != true) return;
      final summary = response['summary'];
      if (summary is! Map) return;

      final homeCount = _extractCount(summary['student_home']) +
          _extractCount(summary['short_trainings']);
      final challengesCount = _extractCount(summary['student_challenges']);
      final coursesCount = _extractCount(summary['student_courses']);
      final trainingsCount = _extractCount(summary['student_online_trainings']);
      final livesCount = _extractCount(summary['student_lives']);
      final paymentsCount = _extractCount(summary['student_payments']);
      final communitiesCount = _extractCount(summary['student_communities']);
      final partnersCount = _extractCount(summary['student_universities']);
      final bobodoCount = _extractCount(summary['student_bobodo']);

      final totalBadge = homeCount +
          challengesCount +
          coursesCount +
          trainingsCount +
          livesCount +
          paymentsCount +
          communitiesCount +
          partnersCount +
          bobodoCount;

      // Update app icon badge (WhatsApp-style count on launcher icon)
      AppBadgeService.instance.updateBadge(totalBadge);

      if (!mounted) return;

      final previousTotal = _countHome +
          _countChallenges +
          _countCourses +
          _countTrainings +
          _countLives +
          _countPayments +
          _countCommunities +
          _countPartners +
          _countBobodo;

      if (!_studentHomeNotificationInitialized) {
        _studentHomeNotificationInitialized = true;
        setState(() {
          _countHome = homeCount;
          _countChallenges = challengesCount;
          _countCourses = coursesCount;
          _countTrainings = trainingsCount;
          _countLives = livesCount;
          _countPayments = paymentsCount;
          _countCommunities = communitiesCount;
          _countPartners = partnersCount;
          _countBobodo = bobodoCount;
        });
        return;
      }

      if (previousTotal == 0 && totalBadge > 0) {
        try {
          await NotificationSoundService.instance.playIfEnabled();
        } catch (_) {}
      }

      setState(() {
        _countHome = homeCount;
        _countChallenges = challengesCount;
        _countCourses = coursesCount;
        _countTrainings = trainingsCount;
        _countLives = livesCount;
        _countPayments = paymentsCount;
        _countCommunities = communitiesCount;
        _countPartners = partnersCount;
        _countBobodo = bobodoCount;
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
      _countHome = 0;
    });
  }

  Future<void> _markStudentCommunitiesSeen() async {
    final client = Supabase.instance.client;
    try {
      await client.rpc('app_mark_domain_seen', params: {
        'p_domain': 'student_communities',
      });
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _countCommunities = 0;
    });
  }

  Future<void> _markStudentPartnersSeen() async {
    final client = Supabase.instance.client;
    try {
      await client.rpc('app_mark_domain_seen', params: {
        'p_domain': 'student_universities',
      });
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _countPartners = 0;
    });
  }

  Future<void> _markStudentBobodoSeen() async {
    final client = Supabase.instance.client;
    try {
      await client.rpc('app_mark_domain_seen', params: {
        'p_domain': 'student_bobodo',
      });
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _countBobodo = 0;
    });
  }

  Future<void> _markStudentPrepConcoursSeen() async {
    final client = Supabase.instance.client;
    try {
      await client.rpc('app_mark_domain_seen', params: {
        'p_domain': 'student_prep_concours',
      });
    } catch (_) {}
    // Pas de booléen dédié pour concours dans la barre, rien à mettre à jour ici.
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
      try {
        HapticFeedback.mediumImpact();
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
    final bool isShareModeEnabled =
        context.select<ShareModeProvider, bool>((p) => p.isShareModeEnabled);
    return Consumer<StudentApplicationsProvider>(
      builder: (context, applicationsProvider, child) {
        final unread = applicationsProvider.unreadCount;

        Widget? bottomNav;
        // Masquer la barre du dashboard quand on est dans le feed vidéo
        // Challenges (index 8) — le feed a sa propre barre TikTok.
        final bool hideBottomNav = _currentIndex == 8;
        if (!hideBottomNav) {
          if (isMobile) {
            bottomNav = _buildMobileBottomNav(unread);
          } else {
            bottomNav = _buildDesktopBottomNav(unread);
          }
        }

        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFA),
          body: Stack(
            children: [
              _buildCurrentTabBody(isMobile),
              const StudentAssistantOverlay(),
              // FABs flottants — masqués sur Challenge (index 8)
              if (_currentIndex != 8)
                Positioned(
                  right: 16,
                  bottom: 96,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // FAB Bobodo (IA) — style Meta AI WhatsApp
                      FloatingActionButton(
                        heroTag: 'bobodo_fab',
                        onPressed: () {
                          _markStudentBobodoSeen();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const Scaffold(
                                body: SafeArea(child: StudentBobodoTab()),
                              ),
                            ),
                          );
                        },
                        backgroundColor: const Color(0xFF6C63FF),
                        elevation: 4,
                        child: const Icon(Icons.smart_toy, color: Colors.white, size: 26),
                      ),
                      const SizedBox(height: 12),
                      // FAB Support (messagerie admin)
                      SupportFab(),
                    ],
                  ),
                ),
            ],
          ),
          bottomNavigationBar: isShareModeEnabled ? null : bottomNav,
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
          child = const StudentPartnersTab();
          break;
        case 5:
          child = const StudentPrepConcoursScreen();
          break;
        case 6:
          child = const StudentTdRootScreen();
          break;
        case 7:
          child = const StudentChallengesTab();
          break;
        case 8:
          child = const StudentCoursesTab();
          break;
        case 9:
          child = const StudentLiveSessionsTab();
          break;
        default:
          child = const StudentHomeMobileTab();
      }

      // Le feed vidéo Challenges (index 7) gère son propre plein écran
      // et sa propre barre TikTok — pas de SafeArea.
      if (_currentIndex == 7) {
        return child;
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
          child = const StudentPartnersTab();
          break;
        case 5:
          child = const StudentPrepConcoursScreen();
          break;
        case 6:
          child = const StudentTdRootScreen();
          break;
        case 7:
          child = const StudentChallengesTab();
          break;
        case 8:
          child = const StudentCoursesTab();
          break;
        case 9:
          child = const StudentLiveSessionsTab();
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
    } else if (index == 3) {
      _markStudentCommunitiesSeen();
      try {
        final communitiesProvider =
            context.read<StudentCommunitiesProvider>();
        communitiesProvider.loadCommunities();
        communitiesProvider.loadMyCommunities();
        communitiesProvider.loadMyCommunitiesActivity();
        communitiesProvider.loadMyChats();
      } catch (_) {}
    } else if (index == 4) {
      _markStudentPartnersSeen();
    } else if (index == 5) {
      _markStudentPrepConcoursSeen();
    }
  }

  Widget _buildDesktopBottomNav(int unread) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFFE8F5E9)],
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
            icon: _NavBadgeIcon(
              icon: Icons.home_outlined,
              count: _countHome,
            ),
            selectedIcon: _NavBadgeIcon(
              icon: Icons.home,
              count: _countHome,
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
          NavigationDestination(
            icon: _NavBadgeIcon(
              icon: Icons.groups_outlined,
              count: _countCommunities,
            ),
            selectedIcon: _NavBadgeIcon(
              icon: Icons.groups,
              count: _countCommunities,
            ),
            label: 'Communautés',
          ),
          NavigationDestination(
            icon: _NavBadgeIcon(
              icon: Icons.apartment_outlined,
              count: _countPartners,
            ),
            selectedIcon: _NavBadgeIcon(
              icon: Icons.apartment,
              count: _countPartners,
            ),
            label: 'Universités',
          ),
          const NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Concours',
          ),
          NavigationDestination(
            icon: _NavBadgeIcon(
              icon: Icons.school_outlined,
              count: _countTrainings,
            ),
            selectedIcon: _NavBadgeIcon(
              icon: Icons.school,
              count: _countTrainings,
            ),
            label: 'TD',
          ),
          NavigationDestination(
            icon: _NavBadgeIcon(
              icon: Icons.emoji_events_outlined,
              count: _countChallenges,
            ),
            selectedIcon: _NavBadgeIcon(
              icon: Icons.emoji_events,
              count: _countChallenges,
            ),
            label: 'Challenges',
          ),
          NavigationDestination(
            icon: _NavBadgeIcon(
              icon: Icons.menu_book_outlined,
              count: _countCourses,
            ),
            selectedIcon: _NavBadgeIcon(
              icon: Icons.menu_book,
              count: _countCourses,
            ),
            label: 'Cours',
          ),
          NavigationDestination(
            icon: _NavBadgeIcon(
              icon: Icons.videocam_outlined,
              count: _countLives,
            ),
            selectedIcon: _NavBadgeIcon(
              icon: Icons.videocam,
              count: _countLives,
            ),
            label: 'Lives',
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        offset: Offset(0, 8),
                        blurRadius: 24,
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
                          label: 'Explorer',
                          icon: _NavBadgeIcon(
                            icon: Icons.explore_outlined,
                            count: _countHome,
                          ),
                          selectedIcon: _NavBadgeIcon(
                            icon: Icons.explore,
                            count: _countHome,
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
                          icon: _NavBadgeIcon(
                            icon: Icons.groups_outlined,
                            count: _countCommunities,
                          ),
                          selectedIcon: _NavBadgeIcon(
                            icon: Icons.groups,
                            count: _countCommunities,
                          ),
                        ),
                        _buildMobileNavItem(
                          index: 4,
                          label: 'Universités',
                          icon: _NavBadgeIcon(
                            icon: Icons.apartment_outlined,
                            count: _countPartners,
                          ),
                          selectedIcon: _NavBadgeIcon(
                            icon: Icons.apartment,
                            count: _countPartners,
                          ),
                        ),
                        _buildMobileNavItem(
                          index: 5,
                          label: 'Concours',
                          icon: const Icon(Icons.school_outlined),
                          selectedIcon: const Icon(Icons.school),
                        ),
                        _buildMobileNavItem(
                          index: 6,
                          label: 'TD',
                          icon: _NavBadgeIcon(
                            icon: Icons.school_outlined,
                            count: _countTrainings,
                          ),
                          selectedIcon: _NavBadgeIcon(
                            icon: Icons.school,
                            count: _countTrainings,
                          ),
                        ),
                        _buildMobileNavItem(
                          index: 7,
                          label: 'Challenges',
                          icon: _NavBadgeIcon(
                            icon: Icons.emoji_events_outlined,
                            count: _countChallenges,
                          ),
                          selectedIcon: _NavBadgeIcon(
                            icon: Icons.emoji_events,
                            count: _countChallenges,
                          ),
                        ),
                        _buildMobileNavItem(
                          index: 8,
                          label: 'Cours',
                          icon: _NavBadgeIcon(
                            icon: Icons.menu_book_outlined,
                            count: _countCourses,
                          ),
                          selectedIcon: _NavBadgeIcon(
                            icon: Icons.menu_book,
                            count: _countCourses,
                          ),
                        ),
                        _buildMobileNavItem(
                          index: 9,
                          label: 'Lives',
                          icon: _NavBadgeIcon(
                            icon: Icons.videocam_outlined,
                            count: _countLives,
                          ),
                          selectedIcon: _NavBadgeIcon(
                            icon: Icons.videocam,
                            count: _countLives,
                          ),
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
    const double iconSize = 22;
    const double fontSize = 10;
    final bool isSelected = _currentIndex == index;

    const Color selectedColor = Color(0xFF2E7D32);
    const Color unselectedColor = Color(0xFF9E9E9E);

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
                  isSelected ? const Color(0xFFE8F5E9) : Colors.transparent,
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
                const SizedBox(height: 3),
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

class _FeatureComingSoonTab extends StatelessWidget {
  final String title;

  const _FeatureComingSoonTab({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Cette fonctionnalité est en cours de développement.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    StudentDashboardNavController.setIndex(0);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text("Retour à l'accueil"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

