import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/student_applications_provider.dart';
import '../../providers/student_opportunities_provider.dart';
import '../../providers/student_application_payments_provider.dart';
import '../../providers/student_communities_provider.dart';
import '../../services/notification_sound_service.dart';
import '../../utils/responsive.dart';
import 'student_home_mobile.dart';
import 'tabs/student_home_tab.dart';
import 'tabs/student_applications_tab.dart';
import 'tabs/student_opportunities_tab.dart';
import 'tabs/student_communities_tab.dart';
import 'tabs/student_partners_tab.dart';
import 'tabs/student_bobodo_tab.dart';
import 'prep_concours/prep_concours_home_screen.dart';
import 'student_dashboard_nav_controller.dart';
import 'student_payments_screen.dart';
import 'student_application_detail_screen.dart';
import '../share/share_mode_provider.dart';

/// Dashboard étudiant avec onglets principaux
class StudentDashboardScreen extends StatefulWidget {
  final String? initialApplicationId;

  const StudentDashboardScreen({super.key, this.initialApplicationId});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  int _currentIndex = 0;
  bool _hasNewHomeContent = false;
  bool _hasNewChallenges = false;
  bool _hasNewCourses = false;
  bool _hasNewTrainings = false;
  bool _hasNewLives = false;
  bool _hasNewPayments = false;
  int _studentPaymentsCount = 0;
  bool _hasNewCommunities = false;
  bool _hasNewPartners = false;
  bool _hasNewBobodo = false;
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
        await context.read<StudentOpportunitiesProvider>().loadTypes();
      } catch (_) {}
      await _loadNotificationSummary();

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

  Future<void> _loadNotificationSummary() async {
    final client = Supabase.instance.client;
    try {
      final response = await client.rpc('app_get_notification_summary');
      if (response is! Map<String, dynamic>) return;
      if (response['success'] != true) return;
      final summary = response['summary'];
      if (summary is! Map) return;
      debugPrint('[StudentDashboard] notification summary keys: ' +
          summary.keys.map((e) => e.toString()).toList().toString());
      debugPrint('[StudentDashboard] student_payments summary: ' +
          (summary['student_payments']?.toString() ?? 'null'));
      final home = summary['student_home'];
      final shortTrainings = summary['short_trainings'];
      final challenges = summary['student_challenges'];
      final courses = summary['student_courses'];
      final trainings = summary['student_online_trainings'];
      final lives = summary['student_lives'];
      final payments = summary['student_payments'];
      final communities = summary['student_communities'];
      final partners = summary['student_universities'];
      final bobodo = summary['student_bobodo'];
      final prepConcours = summary['student_prep_concours'];

      final hasNewHome = home is Map && home['has_new'] == true;
      final hasNewShortTrainings =
          shortTrainings is Map && shortTrainings['has_new'] == true;
      final hasNewChallenges = challenges is Map && challenges['has_new'] == true;
      final hasNewCourses = courses is Map && courses['has_new'] == true;
      final hasNewTrainings = trainings is Map && trainings['has_new'] == true;
      final hasNewLives = lives is Map && lives['has_new'] == true;
      final hasNewCommunities =
          communities is Map && communities['has_new'] == true;
      final hasNewPartners = partners is Map && partners['has_new'] == true;
      final hasNewBobodo = bobodo is Map && bobodo['has_new'] == true;
      final hasNewPrepConcours =
          prepConcours is Map && prepConcours['has_new'] == true;
      final backendHasNewPayments =
          payments is Map && payments['has_new'] == true;

      int paymentsCount = 0;
      if (payments is Map) {
        final rawCount = payments['new_count'] ??
            payments['unseen_count'] ??
            payments['unread_count'] ??
            payments['count'];
        if (rawCount is int) {
          paymentsCount = rawCount;
        } else if (rawCount is String) {
          paymentsCount = int.tryParse(rawCount) ?? 0;
        }
      }

      if (backendHasNewPayments && paymentsCount == 0) {
        paymentsCount = 1;
      }

      final hasNewPayments = backendHasNewPayments || paymentsCount > 0;

      final hasNewHomeOrShort = hasNewHome || hasNewShortTrainings;
      final hasNewAny = hasNewHomeOrShort ||
          hasNewChallenges ||
          hasNewCourses ||
          hasNewTrainings ||
          hasNewLives ||
          hasNewPayments ||
          hasNewCommunities ||
          hasNewPartners ||
          hasNewBobodo ||
          hasNewPrepConcours;
      if (!mounted) return;
      if (!_studentHomeNotificationInitialized) {
        _studentHomeNotificationInitialized = true;
        setState(() {
          _hasNewHomeContent = hasNewAny;
          _hasNewChallenges = hasNewChallenges;
          _hasNewCourses = hasNewCourses;
          _hasNewTrainings = hasNewTrainings;
          _hasNewLives = hasNewLives;
          _hasNewPayments = hasNewPayments;
          _hasNewCommunities = hasNewCommunities;
          _hasNewPartners = hasNewPartners;
          _hasNewBobodo = hasNewBobodo;
          _studentPaymentsCount = paymentsCount;
        });
        return;
      }
      final previous = _hasNewHomeContent;
      if (!previous && hasNewAny) {
        try {
          await NotificationSoundService.instance.playIfEnabled();
        } catch (_) {}
      }
      setState(() {
        _hasNewHomeContent = hasNewAny;
        _hasNewChallenges = hasNewChallenges;
        _hasNewCourses = hasNewCourses;
        _hasNewTrainings = hasNewTrainings;
        _hasNewLives = hasNewLives;
        _hasNewPayments = hasNewPayments;
        _hasNewCommunities = hasNewCommunities;
        _hasNewPartners = hasNewPartners;
        _hasNewBobodo = hasNewBobodo;
        _studentPaymentsCount = paymentsCount;
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

  Future<void> _markStudentPaymentsSeen() async {
    final client = Supabase.instance.client;
    try {
      await client.rpc('app_mark_domain_seen', params: {
        'p_domain': 'student_payments',
      });
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _hasNewPayments = false;
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
      _hasNewCommunities = false;
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
      _hasNewPartners = false;
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
      _hasNewBobodo = false;
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
        if (isMobile) {
          bottomNav = _buildMobileBottomNav(unread);
        } else {
          bottomNav = _buildDesktopBottomNav(unread);
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),
          body: _buildCurrentTabBody(isMobile),
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
          child = const StudentBobodoTab();
          break;
        case 6:
          child = const PrepConcoursHomeScreen();
          break;
        case 7:
          child = ChangeNotifierProvider(
            create: (_) => StudentApplicationPaymentsProvider(),
            child: const StudentPaymentsScreen(),
          );
          break;
        case 8:
          child = const _FeatureComingSoonTab(title: 'Challenges');
          break;
        case 9:
          child = const _FeatureComingSoonTab(title: 'Cours');
          break;
        case 10:
          child = const _FeatureComingSoonTab(title: 'Formations');
          break;
        case 11:
          child = const _FeatureComingSoonTab(title: 'Lives');
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
          child = const StudentPartnersTab();
          break;
        case 5:
          child = const StudentBobodoTab();
          break;
        case 6:
          child = const PrepConcoursHomeScreen();
          break;
        case 7:
          child = ChangeNotifierProvider(
            create: (_) => StudentApplicationPaymentsProvider(),
            child: const StudentPaymentsScreen(),
          );
          break;
        case 8:
          child = const _FeatureComingSoonTab(title: 'Challenges');
          break;
        case 9:
          child = const _FeatureComingSoonTab(title: 'Cours');
          break;
        case 10:
          child = const _FeatureComingSoonTab(title: 'Formations');
          break;
        case 11:
          child = const _FeatureComingSoonTab(title: 'Lives');
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
      // Recharger l'état des communautés à chaque ouverture de l'onglet
      // pour que les nouveaux groupes / chats soient bien visibles.
      try {
        final communitiesProvider =
            context.read<StudentCommunitiesProvider>();
        communitiesProvider.loadCommunities();
        communitiesProvider.loadMyCommunities();
        communitiesProvider.loadMyCommunitiesActivity();
        communitiesProvider.loadMyChats();
      } catch (_) {
        // En cas d'erreur ponctuelle, on ne casse pas la navigation.
      }
    } else if (index == 4) {
      _markStudentPartnersSeen();
    } else if (index == 5) {
      _markStudentBobodoSeen();
    } else if (index == 6) {
      _markStudentPrepConcoursSeen();
    } else if (index == 7) {
      _markStudentPaymentsSeen();
    }
  }

  Widget _buildDesktopBottomNav(int unread) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7BC96F), Color(0xFFE8F5E9)],
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
          NavigationDestination(
            icon: _HomeNavIcon(
              icon: Icons.groups_outlined,
              hasNew: _hasNewCommunities,
            ),
            selectedIcon: _HomeNavIcon(
              icon: Icons.groups,
              hasNew: _hasNewCommunities,
            ),
            label: 'Communautés',
          ),
          NavigationDestination(
            icon: _HomeNavIcon(
              icon: Icons.apartment_outlined,
              hasNew: _hasNewPartners,
            ),
            selectedIcon: _HomeNavIcon(
              icon: Icons.apartment,
              hasNew: _hasNewPartners,
            ),
            label: 'Universités',
          ),
          NavigationDestination(
            icon: _HomeNavIcon(
              icon: Icons.smart_toy_outlined,
              hasNew: _hasNewBobodo,
            ),
            selectedIcon: _HomeNavIcon(
              icon: Icons.smart_toy,
              hasNew: _hasNewBobodo,
            ),
            label: 'Bobodo',
          ),
          const NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Concours',
          ),
          NavigationDestination(
            icon: _NavBadgeIcon(
              icon: Icons.payments_outlined,
              count: _studentPaymentsCount,
            ),
            selectedIcon: _NavBadgeIcon(
              icon: Icons.payments,
              count: _studentPaymentsCount,
            ),
            label: 'Paiements',
          ),
          NavigationDestination(
            icon: _HomeNavIcon(
              icon: Icons.emoji_events_outlined,
              hasNew: _hasNewChallenges,
            ),
            selectedIcon: _HomeNavIcon(
              icon: Icons.emoji_events,
              hasNew: _hasNewChallenges,
            ),
            label: 'Challenges',
          ),
          NavigationDestination(
            icon: _HomeNavIcon(
              icon: Icons.menu_book_outlined,
              hasNew: _hasNewCourses,
            ),
            selectedIcon: _HomeNavIcon(
              icon: Icons.menu_book,
              hasNew: _hasNewCourses,
            ),
            label: 'Cours',
          ),
          NavigationDestination(
            icon: _HomeNavIcon(
              icon: Icons.play_circle_outline,
              hasNew: _hasNewTrainings,
            ),
            selectedIcon: _HomeNavIcon(
              icon: Icons.play_circle,
              hasNew: _hasNewTrainings,
            ),
            label: 'Formations',
          ),
          NavigationDestination(
            icon: _HomeNavIcon(
              icon: Icons.videocam_outlined,
              hasNew: _hasNewLives,
            ),
            selectedIcon: _HomeNavIcon(
              icon: Icons.videocam,
              hasNew: _hasNewLives,
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
                          label: 'Universités',
                          icon: const Icon(Icons.apartment_outlined),
                          selectedIcon: const Icon(Icons.apartment),
                        ),
                        _buildMobileNavItem(
                          index: 5,
                          label: 'Bobodo',
                          icon: const Icon(Icons.smart_toy_outlined),
                          selectedIcon: const Icon(Icons.smart_toy),
                        ),
                        _buildMobileNavItem(
                          index: 6,
                          label: 'Concours',
                          icon: const Icon(Icons.school_outlined),
                          selectedIcon: const Icon(Icons.school),
                        ),
                        _buildMobileNavItem(
                          index: 7,
                          label: 'Paiements',
                          icon: _NavBadgeIcon(
                            icon: Icons.payments_outlined,
                            count: _studentPaymentsCount,
                          ),
                          selectedIcon: _NavBadgeIcon(
                            icon: Icons.payments,
                            count: _studentPaymentsCount,
                          ),
                        ),
                        _buildMobileNavItem(
                          index: 8,
                          label: 'Challenges',
                          icon: _HomeNavIcon(
                            icon: Icons.emoji_events_outlined,
                            hasNew: _hasNewChallenges,
                          ),
                          selectedIcon: _HomeNavIcon(
                            icon: Icons.emoji_events,
                            hasNew: _hasNewChallenges,
                          ),
                        ),
                        _buildMobileNavItem(
                          index: 9,
                          label: 'Cours',
                          icon: _HomeNavIcon(
                            icon: Icons.menu_book_outlined,
                            hasNew: _hasNewCourses,
                          ),
                          selectedIcon: _HomeNavIcon(
                            icon: Icons.menu_book,
                            hasNew: _hasNewCourses,
                          ),
                        ),
                        _buildMobileNavItem(
                          index: 10,
                          label: 'Formations',
                          icon: _HomeNavIcon(
                            icon: Icons.play_circle_outline,
                            hasNew: _hasNewTrainings,
                          ),
                          selectedIcon: _HomeNavIcon(
                            icon: Icons.play_circle,
                            hasNew: _hasNewTrainings,
                          ),
                        ),
                        _buildMobileNavItem(
                          index: 11,
                          label: 'Lives',
                          icon: _HomeNavIcon(
                            icon: Icons.videocam_outlined,
                            hasNew: _hasNewLives,
                          ),
                          selectedIcon: _HomeNavIcon(
                            icon: Icons.videocam,
                            hasNew: _hasNewLives,
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
                    backgroundColor: const Color(0xFF16A34A),
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
