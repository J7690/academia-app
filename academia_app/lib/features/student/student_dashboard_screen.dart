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
import '../../services/analytics_tracking_service.dart';
import '../../utils/responsive.dart';
import 'student_home_mobile.dart';
import 'tabs/student_home_tab.dart';
import 'tabs/student_applications_tab.dart';
import 'tabs/student_communities_tab.dart';
import 'tabs/student_partners_tab.dart';
import 'tabs/student_bobodo_tab.dart';
import 'student_prep_concours_screen.dart';
import 'student_dashboard_nav_controller.dart';
import 'student_td_root_screen.dart';
import 'student_application_detail_screen.dart';
import 'tabs/student_challenges_tab.dart';
import 'tabs/student_coming_soon_tab.dart';
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
    AnalyticsTrackingService.instance.init();
    AnalyticsTrackingService.instance.trackTab('student_dashboard', 0, 'Accueil');
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
        // Challenges (index 7) — le feed a sa propre barre TikTok.
        final bool hideBottomNav = _currentIndex == 7;
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
              // Overlay assistant + FABs — masqués sur Challenge (index 7)
              if (_currentIndex != 7)
                const StudentAssistantOverlay(),
              if (_currentIndex != 7)
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
          child = const StudentComingSoonTab(
            title: 'Opportunités',
            icon: Icons.work_outline,
            subtitle:
                'La section Opportunités est en cours de développement.\nElle sera bientôt accessible. Merci de votre patience !',
          );
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
          child = const StudentComingSoonTab(
            title: 'Cours',
            icon: Icons.menu_book_outlined,
            subtitle:
                'La bibliothèque de cours est en cours de développement.\nElle sera bientôt accessible. Merci de votre patience !',
          );
          break;
        case 9:
          child = const StudentComingSoonTab(
            title: 'Lives',
            icon: Icons.videocam_outlined,
            subtitle:
                'Les sessions live sont en cours de développement.\nElles seront bientôt accessibles. Merci de votre patience !',
          );
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
          child = const StudentComingSoonTab(
            title: 'Opportunités',
            icon: Icons.work_outline,
            subtitle:
                'La section Opportunités est en cours de développement.\nElle sera bientôt accessible. Merci de votre patience !',
          );
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
          child = const StudentComingSoonTab(
            title: 'Cours',
            icon: Icons.menu_book_outlined,
            subtitle:
                'La bibliothèque de cours est en cours de développement.\nElle sera bientôt accessible. Merci de votre patience !',
          );
          break;
        case 9:
          child = const StudentComingSoonTab(
            title: 'Lives',
            icon: Icons.videocam_outlined,
            subtitle:
                'Les sessions live sont en cours de développement.\nElles seront bientôt accessibles. Merci de votre patience !',
          );
          break;
        default:
          child = const StudentHomeTab();
      }
      return child;
    }
  }

  static const List<String> _tabNames = [
    'Accueil', 'Candidatures', 'Cours', 'Communautes',
    'Partenaires', 'Prep Concours', 'TD', 'Bobodo', 'Challenges', 'Lives',
  ];

  void _onDestinationSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
    StudentDashboardNavController.setIndex(index);
    AnalyticsTrackingService.instance.trackTab(
      'student_dashboard', index, index < _tabNames.length ? _tabNames[index] : 'tab_$index',
    );
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
    // Barre desktop unifiée avec le mobile : fond blanc, style Salomon Bottom
    // Bar. Les onglets gelés (Opportunités, Cours, Lives) sont à la fin, dans
    // l'ordre visuel `_visualOrder`.
    final List<_DesktopNavEntry> entries = [
      _DesktopNavEntry(
        semanticIndex: 0,
        label: 'Accueil',
        icon: _NavBadgeIcon(icon: Icons.home_outlined, count: _countHome),
        selectedIcon: _NavBadgeIcon(icon: Icons.home, count: _countHome),
      ),
      _DesktopNavEntry(
        semanticIndex: 1,
        label: 'Candidatures',
        icon: _NavBadgeIcon(icon: Icons.assignment_outlined, count: unread),
        selectedIcon: _NavBadgeIcon(icon: Icons.assignment, count: unread),
      ),
      _DesktopNavEntry(
        semanticIndex: 3,
        label: 'Communautés',
        icon: _NavBadgeIcon(
            icon: Icons.groups_outlined, count: _countCommunities),
        selectedIcon:
            _NavBadgeIcon(icon: Icons.groups, count: _countCommunities),
      ),
      _DesktopNavEntry(
        semanticIndex: 4,
        label: 'Universités',
        icon: _NavBadgeIcon(
            icon: Icons.school_outlined, count: _countPartners),
        selectedIcon: _NavBadgeIcon(icon: Icons.school, count: _countPartners),
      ),
      const _DesktopNavEntry(
        semanticIndex: 5,
        label: 'Concours',
        icon: Icon(Icons.workspace_premium_outlined),
        selectedIcon: Icon(Icons.workspace_premium),
      ),
      _DesktopNavEntry(
        semanticIndex: 6,
        label: 'TD',
        icon: _NavBadgeIcon(
            icon: Icons.menu_book_outlined, count: _countTrainings),
        selectedIcon:
            _NavBadgeIcon(icon: Icons.menu_book, count: _countTrainings),
      ),
      _DesktopNavEntry(
        semanticIndex: 7,
        label: 'Challenges',
        icon: _NavBadgeIcon(
            icon: Icons.play_circle_outline, count: _countChallenges),
        selectedIcon:
            _NavBadgeIcon(icon: Icons.play_circle, count: _countChallenges),
      ),
      const _DesktopNavEntry(
        semanticIndex: 2,
        label: 'Opportunités',
        icon: Icon(Icons.work_outline),
        selectedIcon: Icon(Icons.work),
      ),
      _DesktopNavEntry(
        semanticIndex: 8,
        label: 'Cours',
        icon: _NavBadgeIcon(
            icon: Icons.play_lesson_outlined, count: _countCourses),
        selectedIcon:
            _NavBadgeIcon(icon: Icons.play_lesson, count: _countCourses),
      ),
      _DesktopNavEntry(
        semanticIndex: 9,
        label: 'Lives',
        icon: _NavBadgeIcon(icon: Icons.live_tv_outlined, count: _countLives),
        selectedIcon: _NavBadgeIcon(icon: Icons.live_tv, count: _countLives),
      ),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Container(
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final e in entries)
                    _buildMobileNavItem(
                      index: e.semanticIndex,
                      label: e.label,
                      icon: e.icon,
                      selectedIcon: e.selectedIcon,
                    ),
                ],
              ),
            ),
          ),
        ),
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
                        // 0 - Accueil (convention TikTok/Instagram/LinkedIn)
                        _buildMobileNavItem(
                          index: 0,
                          label: 'Accueil',
                          icon: _NavBadgeIcon(
                            icon: Icons.home_outlined,
                            count: _countHome,
                          ),
                          selectedIcon: _NavBadgeIcon(
                            icon: Icons.home,
                            count: _countHome,
                          ),
                        ),
                        // 1 - Candidatures
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
                        // 3 - Communautés (WhatsApp / Facebook)
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
                        // 4 - Universités (icône school : convention éducation)
                        _buildMobileNavItem(
                          index: 4,
                          label: 'Universités',
                          icon: _NavBadgeIcon(
                            icon: Icons.school_outlined,
                            count: _countPartners,
                          ),
                          selectedIcon: _NavBadgeIcon(
                            icon: Icons.school,
                            count: _countPartners,
                          ),
                        ),
                        // 5 - Concours (trophée / premium)
                        _buildMobileNavItem(
                          index: 5,
                          label: 'Concours',
                          icon: const Icon(Icons.workspace_premium_outlined),
                          selectedIcon: const Icon(Icons.workspace_premium),
                        ),
                        // 6 - TD (livre d'exercices)
                        _buildMobileNavItem(
                          index: 6,
                          label: 'TD',
                          icon: _NavBadgeIcon(
                            icon: Icons.menu_book_outlined,
                            count: _countTrainings,
                          ),
                          selectedIcon: _NavBadgeIcon(
                            icon: Icons.menu_book,
                            count: _countTrainings,
                          ),
                        ),
                        // 7 - Challenges (feed vidéo TikTok)
                        _buildMobileNavItem(
                          index: 7,
                          label: 'Challenges',
                          icon: _NavBadgeIcon(
                            icon: Icons.play_circle_outline,
                            count: _countChallenges,
                          ),
                          selectedIcon: _NavBadgeIcon(
                            icon: Icons.play_circle,
                            count: _countChallenges,
                          ),
                        ),
                        // 2 - Opportunités (LinkedIn Jobs) [GELÉ]
                        _buildMobileNavItem(
                          index: 2,
                          label: 'Opportunités',
                          icon: const Icon(Icons.work_outline),
                          selectedIcon: const Icon(Icons.work),
                        ),
                        // 8 - Cours (Coursera / YT Learning) [GELÉ]
                        _buildMobileNavItem(
                          index: 8,
                          label: 'Cours',
                          icon: _NavBadgeIcon(
                            icon: Icons.play_lesson_outlined,
                            count: _countCourses,
                          ),
                          selectedIcon: _NavBadgeIcon(
                            icon: Icons.play_lesson,
                            count: _countCourses,
                          ),
                        ),
                        // 9 - Lives (TikTok Live) [GELÉ]
                        _buildMobileNavItem(
                          index: 9,
                          label: 'Lives',
                          icon: _NavBadgeIcon(
                            icon: Icons.live_tv_outlined,
                            count: _countLives,
                          ),
                          selectedIcon: _NavBadgeIcon(
                            icon: Icons.live_tv,
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

  // Palette de couleurs par onglet (index sémantique -> couleur d'accent).
  // Inspiration : Google Bottom Bar Navigation Pattern (Aurélien Salomon),
  // LinkedIn, TikTok, Coursera. Chaque onglet a une identité visuelle claire.
  static const Map<int, Color> _tabColors = {
    0: Color(0xFF2E7D32), // Accueil — vert Academia
    1: Color(0xFF3B82F6), // Candidatures — bleu (docs officiels)
    2: Color(0xFFF97316), // Opportunités — orange (LinkedIn Jobs)
    3: Color(0xFF10B981), // Communautés — émeraude (WhatsApp)
    4: Color(0xFF8B5CF6), // Universités — violet (savoir académique)
    5: Color(0xFFF59E0B), // Concours — ambre (trophée / premium)
    6: Color(0xFF0EA5E9), // TD — ciel (livre / étude)
    7: Color(0xFFE11D48), // Challenges — rose vif (TikTok)
    8: Color(0xFF6366F1), // Cours — indigo (Coursera)
    9: Color(0xFFDC2626), // Lives — rouge (live broadcast)
  };

  Widget _buildMobileNavItem({
    required int index,
    required String label,
    required Widget icon,
    required Widget selectedIcon,
  }) {
    final bool isSelected = _currentIndex == index;
    final Color accent = _tabColors[index] ?? const Color(0xFF2E7D32);
    const Color unselectedColor = Color(0xFF6B7280);

    return _SalomonNavItem(
      isSelected: isSelected,
      accentColor: accent,
      unselectedColor: unselectedColor,
      label: label,
      icon: icon,
      selectedIcon: selectedIcon,
      onTap: () => _onDestinationSelected(index),
    );
  }
}

/// Métadonnées d'un onglet pour la barre desktop (ordre visuel + icônes).
class _DesktopNavEntry {
  final int semanticIndex;
  final String label;
  final Widget icon;
  final Widget selectedIcon;

  const _DesktopNavEntry({
    required this.semanticIndex,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

/// Item de navigation style Salomon Bottom Bar :
/// - Non sélectionné : icône seule, couleur grise, largeur minimale.
/// - Sélectionné : le container s'étend horizontalement avec un fond de la
///   couleur d'accent (12% opacité), l'icône passe en couleur d'accent et le
///   label apparaît à côté de l'icône (fade + slide).
/// Animation : 320ms, easeOutCubic — feel identique à Google/YouTube Music.
class _SalomonNavItem extends StatelessWidget {
  final bool isSelected;
  final Color accentColor;
  final Color unselectedColor;
  final String label;
  final Widget icon;
  final Widget selectedIcon;
  final VoidCallback onTap;

  const _SalomonNavItem({
    required this.isSelected,
    required this.accentColor,
    required this.unselectedColor,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Duration duration = Duration(milliseconds: 320);
    const Curve curve = Curves.easeOutCubic;
    const double iconSize = 22;
    const double fontSize = 12.5;

    final Widget effectiveIcon = isSelected ? selectedIcon : icon;
    final Color iconColor = isSelected ? accentColor : unselectedColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          splashColor: accentColor.withOpacity(0.12),
          highlightColor: accentColor.withOpacity(0.06),
          onTap: onTap,
          child: AnimatedContainer(
            duration: duration,
            curve: curve,
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? 14 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withOpacity(0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icône : couleur animée + léger scale bounce à la sélection.
                TweenAnimationBuilder<double>(
                  duration: duration,
                  curve: Curves.elasticOut,
                  tween: Tween<double>(
                    begin: isSelected ? 0.85 : 1.0,
                    end: 1.0,
                  ),
                  builder: (context, scale, child) => Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                  child: IconTheme(
                    data: IconThemeData(color: iconColor, size: iconSize),
                    child: effectiveIcon,
                  ),
                ),
                // Label animé : apparaît à droite de l'icône quand sélectionné.
                AnimatedSize(
                  duration: duration,
                  curve: curve,
                  child: AnimatedOpacity(
                    duration: duration,
                    curve: curve,
                    opacity: isSelected ? 1.0 : 0.0,
                    child: isSelected
                        ? Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: accentColor,
                                fontSize: fontSize,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
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

