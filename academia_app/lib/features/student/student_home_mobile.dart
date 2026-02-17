import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../video/academia_playback_engine.dart';
import '../../providers/student_profile_provider.dart';
import '../../providers/student_applications_provider.dart';
import '../../providers/student_offers_provider.dart';
import '../../providers/student_home_content_provider.dart';
import '../../providers/student_home_slots_provider.dart';
import '../../providers/online_courses_catalog_provider.dart';
import '../../providers/student_online_courses_provider.dart';
import '../../providers/home_formations_provider.dart';
import '../../providers/student_short_trainings_provider.dart';
import '../../providers/student_weather_provider.dart';
import '../../providers/student_announcements_provider.dart';
import '../../providers/student_academic_calendar_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/notification_sound_settings_dialog.dart';
import '../../widgets/bobodo_state.dart';
import '../../widgets/bobodo_view.dart';
import 'student_application_detail_screen.dart';
import 'tabs/student_applications_tab.dart';
import 'tabs/student_opportunities_tab.dart';
import 'tabs/student_challenges_tab.dart' as challenges_tab;
import 'tabs/student_partners_tab.dart' as partners_tab;
import 'student_university_site_screen.dart';
import 'student_profile_screen.dart';
import 'student_announcements_screen.dart';
import 'student_academic_calendar_screen.dart';
import 'online_course_detail_screen.dart';
import 'tabs/student_online_trainings_tab.dart';
import 'widgets/student_mobile_scaffold.dart';
import '../../providers/student_application_payments_provider.dart';
import 'student_payments_screen.dart';
import 'widgets/formations_section.dart';
import '../share/share_service.dart';
import '../share/share_mode_provider.dart';
import '../share/widgets/share_signature.dart';

class StudentHomeMobileTab extends StatefulWidget {
  const StudentHomeMobileTab({super.key});

  @override
  State<StudentHomeMobileTab> createState() => _StudentHomeMobileTabState();
}

class _StudentHomeMobileTabState extends State<StudentHomeMobileTab> {
  bool _initialized = false;

  final GlobalKey _shareBoundaryKey = GlobalKey();
  final ShareService _shareService = ShareService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _initialized) return;
      _initialized = true;

      try {
        context.read<StudentOffersProvider>().loadHomeOffers();
      } catch (_) {}
      try {
        context.read<StudentProfileProvider>().loadProfile();
      } catch (_) {}
      try {
        context.read<StudentApplicationsProvider>().loadApplications();
      } catch (_) {}
      try {
        context.read<StudentHomeContentProvider>().loadPublicStudentHomeContent();
      } catch (_) {}
      try {
        context.read<OnlineCoursesCatalogProvider>().loadPublicCourses();
      } catch (_) {}
      try {
        context.read<StudentOnlineCoursesProvider>().loadMyCourses();
      } catch (_) {}
      try {
        final shortTrainingsProvider =
            context.read<StudentShortTrainingsProvider>();
        await shortTrainingsProvider.loadPublicSessions();
        await shortTrainingsProvider.loadMyTrainings();
      } catch (_) {}
      try {
        final slotsProvider = context.read<StudentHomeSlotsProvider>();
        await slotsProvider.loadSlotItems('mobile_row_short_trainings');
        await slotsProvider.loadSlotItems('mobile_row_online_courses');
        await slotsProvider.loadSlotItems('mobile_row_opportunities');
      } catch (_) {}
      try {
        await context
            .read<StudentWeatherProvider>()
            .loadWeatherFromStudentProfile();
      } catch (_) {}
      try {
        final announcementsProvider =
            context.read<StudentAnnouncementsProvider>();
        await announcementsProvider.refreshUnreadCount();
        await announcementsProvider.loadAnnouncements(limit: 10);
      } catch (_) {}
      try {
        final calendarProvider =
            context.read<StudentAcademicCalendarProvider>();
        await calendarProvider.loadEvents();
        await calendarProvider.loadSummary();
      } catch (_) {}
    });
  }

  Future<void> _shareCurrentView() async {
    await _shareService.shareCurrentView(
      context: context,
      boundaryKey: _shareBoundaryKey,
      shareText: 'Découvert via Academia – Faciliter l’accès aux formations.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<StudentOffersProvider, HomeFormationsProvider>(
      builder: (context, offersProvider, formationsProvider, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          formationsProvider.syncFromHomeOffers(offersProvider.homeOffers);
        });

        return RepaintBoundary(
          key: _shareBoundaryKey,
          child: Stack(
            children: [
              StudentMobileScrollablePage(
                children: [
                  const SizedBox(height: 8),
                  const _MobileTopNavBar(),
                  const SizedBox(height: 16),
                  _MobileProfileCard(),
                  const SizedBox(height: 16),
                  const _MobileAssistantSection(),
                  const SizedBox(height: 16),
                  _MobileSectionsGrid(),
                  const SizedBox(height: 24),
                ],
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: IgnorePointer(
                  child: Consumer<ShareModeProvider>(
                    builder: (context, shareMode, _) {
                      if (!shareMode.isShareModeEnabled) {
                        return const SizedBox.shrink();
                      }
                      return const ShareSignature();
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _describeWeatherCode(int code) {
  if (code == 0) return 'Ciel dégagé';
  if (code == 1 || code == 2) return 'Plutôt ensoleillé';
  if (code == 3) return 'Ciel nuageux';
  if (code == 45 || code == 48) return 'Brouillard';
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
    return 'Pluie';
  }
  if (code >= 71 && code <= 77) return 'Neige';
  if (code == 95 || code == 96 || code == 99) {
    return 'Orages';
  }
  return 'Conditions variables';
}

IconData _iconForWeatherCode(int code) {
  if (code == 0) return Icons.wb_sunny_outlined;
  if (code == 1 || code == 2) return Icons.wb_sunny_outlined;
  if (code == 3) return Icons.cloud_outlined;
  if (code == 45 || code == 48) return Icons.waves_outlined;
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
    return Icons.grain_outlined;
  }
  if (code >= 71 && code <= 77) return Icons.ac_unit_outlined;
  if (code == 95 || code == 96 || code == 99) {
    return Icons.thunderstorm_outlined;
  }
  return Icons.wb_cloudy_outlined;
}

Color _colorForWeatherCode(int code) {
  if (code == 0 || code == 1 || code == 2) {
    return const Color(0xFFF59E0B);
  }
  if (code == 3 || code == 45 || code == 48) {
    return const Color(0xFF6B7280);
  }
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
    return const Color(0xFF2563EB);
  }
  if (code >= 71 && code <= 77) {
    return const Color(0xFF38BDF8);
  }
  if (code == 95 || code == 96 || code == 99) {
    return const Color(0xFFEC4899);
  }
  return const Color(0xFF6B7280);
}

bool _isRainyCode(int code) {
  return (code >= 51 && code <= 67) || (code >= 80 && code <= 82);
}

class _MobileTopNavBar extends StatefulWidget {
  const _MobileTopNavBar();

  @override
  State<_MobileTopNavBar> createState() => _MobileTopNavBarState();
}

class _MobileTopNavBarState extends State<_MobileTopNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapSimple(VoidCallback? action) async {
    if (action == null) return;
    try {
      await _controller.forward(from: 0);
    } finally {
      _controller.reverse();
    }
    action();
  }

  void _openSearchFormations() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String query = '';

        return StatefulBuilder(
          builder: (context, setState) {
            final formations =
                context.watch<HomeFormationsProvider>().formations;
            final lowerQuery = query.toLowerCase();
            final filtered = lowerQuery.isEmpty
                ? formations
                : formations.where((f) {
                    final title = f.title.toLowerCase();
                    final uni = f.universityName.toLowerCase();
                    final degree = (f.degreeLevel ?? '').toLowerCase();
                    return title.contains(lowerQuery) ||
                        uni.contains(lowerQuery) ||
                        degree.contains(lowerQuery);
                  }).toList(growable: false);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 4,
                        width: 40,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const Text(
                        'Rechercher une formation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        autofocus: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText:
                              'Nom de la filière, université, niveau...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(24)),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            query = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 260,
                        child: formations.isEmpty
                            ? const Center(
                                child: Text(
                                  'Les formations apparaîtront ici dès qu’elles seront disponibles.',
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final formation = filtered[index];
                                  return ListTile(
                                    leading:
                                        const Icon(Icons.school_rounded),
                                    title: Text(
                                      formation.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      formation.universityName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () {
                                      Navigator.of(ctx).pop();
                                      final slug = formation.universitySlug;
                                      if (slug == null || slug.isEmpty) {
                                        return;
                                      }
                                      Navigator.of(this.context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              StudentUniversitySiteScreen(
                                            universitySlug: slug,
                                            universityName:
                                                formation.universityName,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notifications'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Centre de notifications à venir.',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Paramètres'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  NotificationSoundSettingsDialog.show(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Déconnexion'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final client = Supabase.instance.client;
                  await client.auth.signOut();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = 1.0 + 0.18 * _controller.value;
    final containerWidth = MediaQuery.of(context).size.width * 0.9;
    final isCompact = containerWidth < 260;

    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Container(
          width: containerWidth,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.22),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                offset: Offset(0, 10),
                blurRadius: 30,
              ),
            ],
          ),
          child: Row(
            children: [
              if (!isCompact)
                _TopNavIconButton(
                  icon: Icons.notifications_none,
                  onTap: () => _onTapSimple(() {
                    // Navigation future vers notifications si besoin.
                  }),
                ),
              if (!isCompact) const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _onTapSimple(() {
                    _openSearchFormations();
                  }),
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      'Rechercher une formation, une filière...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6F6F6F),
                      ),
                    ),
                  ),
                ),
              ),
              if (!isCompact) const SizedBox(width: 8),
              if (!isCompact)
                Consumer<ShareModeProvider>(
                  builder: (context, shareMode, _) {
                    if (shareMode.isShareModeEnabled) {
                      return const SizedBox.shrink();
                    }
                    final isBusy = shareMode.isBusy;
                    return _TopNavIconButton(
                      icon: Icons.share,
                      onTap: isBusy
                          ? null
                          : () {
                              final parent = context
                                  .findAncestorStateOfType<_StudentHomeMobileTabState>();
                              parent?._shareCurrentView();
                            },
                    );
                  },
                ),
              if (!isCompact) const SizedBox(width: 4),
              if (!isCompact)
                _TopNavIconButton(
                  icon: Icons.person_outline,
                  onTap: () => _onTapSimple(() {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const StudentProfileScreen(),
                      ),
                    );
                  }),
                ),
              if (!isCompact) const SizedBox(width: 4),
              if (!isCompact)
                _TopNavIconButton(
                  icon: Icons.more_horiz,
                  onTap: () => _onTapSimple(() {
                    _openMoreMenu();
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopNavIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _TopNavIconButton({
    required this.icon,
    this.onTap,
  });

  @override
  State<_TopNavIconButton> createState() => _TopNavIconButtonState();
}

class _TopNavIconButtonState extends State<_TopNavIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    final action = widget.onTap;
    if (action == null) return;
    try {
      await _controller.forward(from: 0);
    } finally {
      _controller.reverse();
    }
    action();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + 0.18 * _controller.value;
        final glowOpacity = 0.3 * _controller.value;
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.7),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(glowOpacity),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _handleTap,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              widget.icon,
              size: 20,
              color: const Color(0xFF0A2540),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileHomeHero extends StatefulWidget {
  const _MobileHomeHero();

  @override
  State<_MobileHomeHero> createState() => _MobileHomeHeroState();
}

class _HomeHeroMediaItem {
  final String url;
  final bool isImage;

  const _HomeHeroMediaItem({required this.url, required this.isImage});
}

class _MobileHomeHeroState extends State<_MobileHomeHero> {
  String? _heroUrl;
  bool _heroIsImage = false;
  final List<_HomeHeroMediaItem> _playlist = <_HomeHeroMediaItem>[];
  int _currentIndex = 0;
  Timer? _rotationTimer;

  static const Duration _slideDuration = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final client = Supabase.instance.client;
        final localPlaylist = <_HomeHeroMediaItem>[];

        try {
          debugPrint(
            'StudentHomeMobile: calling app_public_hero_playlist('
            'slot=student_home_hero_main)',
          );
          final dynamic response = await client.rpc(
            'app_public_hero_playlist',
            params: {'p_slot': 'student_home_hero_main'},
          );

          if (response is! Map<String, dynamic>) {
            debugPrint(
              'StudentHomeMobile: invalid hero playlist response type='
              '${response.runtimeType}',
            );
          } else if (response['success'] != true) {
            debugPrint(
              'StudentHomeMobile: app_public_hero_playlist returned '
              'non-success: success=${response['success']} '
              'error=${response['error']}',
            );
          } else {
            final items = response['items'];
            if (items is! List) {
              debugPrint(
                'StudentHomeMobile: hero playlist items is not a List',
              );
            } else {
              for (final raw in items) {
                if (raw is! Map) continue;
                final row = Map<String, dynamic>.from(raw);

                final rawType =
                    (row['media_type'] ?? 'video').toString().toLowerCase();
                final isImage = rawType == 'image';

                final playbackRaw = row['playback'];
                Map<String, dynamic>? playback;
                if (playbackRaw is Map) {
                  playback = Map<String, dynamic>.from(playbackRaw);
                }

                final bestUrl =
                    (playback?['best_url'] ?? '').toString().trim();
                final baseVideoUrl =
                    (row['base_video_url'] ?? '').toString().trim();
                final baseImageUrl =
                    (row['base_image_url'] ?? '').toString().trim();

                String? resolvedUrl;
                bool resolvedIsImage;

                if (isImage) {
                  if (baseImageUrl.isEmpty) {
                    continue;
                  }
                  resolvedUrl = baseImageUrl;
                  resolvedIsImage = true;
                } else {
                  resolvedUrl =
                      bestUrl.isNotEmpty ? bestUrl : baseVideoUrl;
                  if (resolvedUrl.isEmpty) {
                    continue;
                  }
                  resolvedIsImage = false;
                }

                debugPrint(
                  'StudentHomeMobile: hero item from app_public_hero_playlist '
                  'slot=student_home_hero_main type='
                  '${resolvedIsImage ? 'image' : 'video'} '
                  'url=' + resolvedUrl,
                );

                localPlaylist.add(
                  _HomeHeroMediaItem(
                    url: resolvedUrl,
                    isImage: resolvedIsImage,
                  ),
                );
              }
            }
          }
        } catch (e) {
          debugPrint(
            'StudentHomeMobile: error while loading hero playlist from '
            'app_public_hero_playlist: $e',
          );
        }

        if (!mounted) return;

        if (localPlaylist.isNotEmpty) {
          _playlist
            ..clear()
            ..addAll(localPlaylist);
          _goToIndex(0);
        }
      } catch (_) {}
    });
  }

  void _goToIndex(int index) {
    if (!mounted || _playlist.isEmpty) return;
    _rotationTimer?.cancel();

    _currentIndex = index % _playlist.length;
    final item = _playlist[_currentIndex];

    setState(() {
      _heroUrl = item.url;
      _heroIsImage = item.isImage;
    });

    _rotationTimer = Timer(_slideDuration, () {
      if (!mounted || _playlist.isEmpty) return;
      final nextIndex = (_currentIndex + 1) % _playlist.length;
      _goToIndex(nextIndex);
    });
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heroUrl = _heroUrl;
    if (heroUrl == null || heroUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    final isImage = _heroIsImage;
    const title = '';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            offset: Offset(0, 10),
            blurRadius: 30,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF62A8FF),
                        Color(0xFF9ED7FF),
                      ],
                    ),
                  ),
                ),
              ),
              if (isImage)
                Positioned.fill(
                  child: Image.network(
                    heroUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, _, __) {
                      return const SizedBox.shrink();
                    },
                  ),
                )
              else
                Positioned.fill(
                  child: AcademiaPlaybackEngine.view(
                    url: heroUrl,
                    autoplay: true,
                    looping: false,
                    muted: kIsWeb,
                    showControls: false,
                    showErrorText: false,
                    fit: BoxFit.cover,
                  ),
                ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.35),
                        Colors.transparent,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ),
              if (title.isNotEmpty)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 16,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileAssistantSection extends StatelessWidget {
  const _MobileAssistantSection();

  @override
  Widget build(BuildContext context) {
    return Consumer3<
        StudentWeatherProvider,
        StudentAnnouncementsProvider,
        StudentAcademicCalendarProvider>(
      builder: (
        context,
        weatherProvider,
        announcementsProvider,
        calendarProvider,
        _,
      ) {
        final weather = weatherProvider.weather;
        final bool hasAnnouncements =
            announcementsProvider.unreadCount > 0 ||
                announcementsProvider.announcements.isNotEmpty;
        final bool hasCalendar =
            calendarProvider.upcomingFollowedCount > 0 ||
                calendarProvider.events.isNotEmpty;
        String? weatherLine;
        String? weatherDetailsLine;
        String? weatherAdviceLine;
        IconData weatherIcon = Icons.wb_sunny_outlined;
        Color weatherIconColor = const Color(0xFFF59E0B);
        if (weather is Map<String, dynamic>) {
          try {
            final dynamic tempRaw = weather['temperature'];
            final dynamic codeRaw = weather['weatherCode'];
            final dynamic sunriseRaw = weather['sunrise'];
            final dynamic sunsetRaw = weather['sunset'];
            final dynamic uvRaw = weather['uvIndex'];

            final double? temp = tempRaw is num
                ? tempRaw.toDouble()
                : double.tryParse(tempRaw?.toString() ?? '');
            final int? code = codeRaw is num
                ? codeRaw.toInt()
                : int.tryParse(codeRaw?.toString() ?? '');
            final DateTime? sunrise =
                DateTime.tryParse(sunriseRaw?.toString() ?? '');
            final DateTime? sunset =
                DateTime.tryParse(sunsetRaw?.toString() ?? '');
            final double? uvIndex = uvRaw is num
                ? uvRaw.toDouble()
                : double.tryParse(uvRaw?.toString() ?? '');

            final String city =
                weatherProvider.location?['city']?.toString() ?? '';

            String description = '';
            if (code != null) {
              description = _describeWeatherCode(code);
              weatherIcon = _iconForWeatherCode(code);
              weatherIconColor = _colorForWeatherCode(code);
            }

            if (temp != null) {
              final int rounded = temp.round();
              if (description.isNotEmpty) {
                if (city.isNotEmpty) {
                  weatherLine = '$rounded°C, $description · $city';
                } else {
                  weatherLine = '$rounded°C, $description';
                }
              } else if (city.isNotEmpty) {
                weatherLine = '$rounded°C · $city';
              } else {
                weatherLine = '$rounded°C';
              }
            }

            if (sunrise != null && sunset != null) {
              final DateFormat fmt = DateFormat.Hm();
              final String sr = fmt.format(sunrise);
              final String ss = fmt.format(sunset);
              weatherDetailsLine = 'Lever $sr · Coucher $ss';
            }

            if (uvIndex != null) {
              String uvLabel;
              if (uvIndex >= 8) {
                uvLabel = 'très élevé';
              } else if (uvIndex >= 6) {
                uvLabel = 'élevé';
              } else if (uvIndex >= 3) {
                uvLabel = 'modéré';
              } else {
                uvLabel = 'faible';
              }
              final String uvText =
                  uvIndex % 1 == 0 ? uvIndex.toInt().toString() : uvIndex.toStringAsFixed(1);
              final String line = 'Indice UV: $uvText ($uvLabel)';
              weatherDetailsLine = weatherDetailsLine == null
                  ? line
                  : '$weatherDetailsLine · $line';

              if (uvIndex >= 8) {
                weatherAdviceLine =
                    'Soleil très fort, protège-toi bien (casquette, crème).';
              }
            }

            if (weatherAdviceLine == null && temp != null && temp >= 35) {
              weatherAdviceLine =
                  'Journée très chaude, hydrate-toi bien et privilégie l’ombre.';
            } else if (weatherAdviceLine == null && code != null) {
              if (_isRainyCode(code)) {
                weatherAdviceLine =
                    'Pluie prévue, pense à anticiper tes déplacements.';
              }
            }
          } catch (_) {
            // En cas de format inattendu, on reste silencieux.
          }
        }

        final bool isDefaultLocation =
            weatherProvider.location?['is_default_location'] == true;

        final unreadAnnouncements = announcementsProvider.unreadCount;
        String announcementsLine =
            'Aucune annonce importante pour le moment';
        if (hasAnnouncements) {
          if (unreadAnnouncements > 0) {
            announcementsLine =
                '$unreadAnnouncements annonce${unreadAnnouncements > 1 ? 's' : ''} importante${unreadAnnouncements > 1 ? 's' : ''}';
          } else if (announcementsProvider.announcements.isNotEmpty) {
            final first = announcementsProvider.announcements.first;
            final title = first['title']?.toString() ?? '';
            if (title.isNotEmpty) {
              announcementsLine = title;
            }
          }
        }

        final upcomingCount = calendarProvider.upcomingFollowedCount;
        String calendarLine =
            'Aucun événement académique enregistré pour le moment';
        if (hasCalendar) {
          if (upcomingCount > 0) {
            calendarLine =
                '$upcomingCount événement${upcomingCount > 1 ? 's' : ''} à venir que vous suivez';
          } else if (calendarProvider.events.isNotEmpty) {
            final first = calendarProvider.events.first;
            final title = first['title']?.toString() ?? '';
            final startAt = first['start_at']?.toString() ?? '';
            if (title.isNotEmpty && startAt.isNotEmpty) {
              calendarLine = '$title · $startAt';
            } else if (title.isNotEmpty) {
              calendarLine = title;
            }
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  offset: Offset(0, 8),
                  blurRadius: 24,
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.assistant_outlined,
                      size: 20,
                      color: Color(0xFF0A2540),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Assistant étudiant',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0A2540),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (isDefaultLocation && weatherLine != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.location_on_outlined,
                                size: 12,
                                color: Color(0xFF6B7280),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Localisation par défaut : Ouagadougou',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const StudentProfileScreen(),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Text(
                              'Modifier dans mon profil',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (weatherLine != null)
                  Row(
                    children: [
                      Icon(
                        weatherIcon,
                        size: 18,
                        color: weatherIconColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          weatherLine,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                if (weatherDetailsLine != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      weatherDetailsLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                if (weatherAdviceLine != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      weatherAdviceLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                if (weatherLine != null)
                  const SizedBox(height: 6),
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const StudentAnnouncementsScreen(),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(
                        Icons.campaign_outlined,
                        size: 18,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          announcementsLine,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const StudentAcademicCalendarScreen(),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_outlined,
                        size: 18,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          calendarLine,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class StudentAssistantSection extends StatelessWidget {
  const StudentAssistantSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MobileAssistantSection();
  }
}

class _MobileSectionsGrid extends StatelessWidget {
  const _MobileSectionsGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _MobileShortTrainingsRow(),
        const SizedBox(height: 16),
        const _MobileOnlineCoursesRow(),
        const SizedBox(height: 16),
        const _MobileHomeHero(),
        const SizedBox(height: 12),
        const _MobileHomeTicker(),
        const SizedBox(height: 16),
        const StudentHomeFormationsSection(),
        const SizedBox(height: 16),
        _MobileOpportunitiesSection(),
      ],
    );
  }
}

class _MobileShortTrainingsRow extends StatefulWidget {
  const _MobileShortTrainingsRow();

  @override
  State<_MobileShortTrainingsRow> createState() => _MobileShortTrainingsRowState();
}

class _MobileShortTrainingsRowState extends State<_MobileShortTrainingsRow> {
  final ScrollController _controller = ScrollController();
  static const double _step = 1.0;
  static const Duration _tick = Duration(milliseconds: 80);
  static const Duration _animDuration = Duration(milliseconds: 80);
  Timer? _timer;
  static const String _prefsKeyOffset = 'student_home_short_trainings_offset';
  bool _offsetRestored = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_tick, (_) {
      if (!_controller.hasClients) return;
      final position = _controller.position;
      if (!position.haveDimensions) return;
      final maxScroll = position.maxScrollExtent;
      if (maxScroll <= 0) return;

      final current = _controller.offset;
      double next = current + _step;
      if (next >= maxScroll) {
        next = 0;
      }

      _controller.animateTo(
        next,
        duration: _animDuration,
        curve: Curves.linear,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _saveOffset();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _restoreOffset() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_prefsKeyOffset);
    if (!mounted || saved == null || saved <= 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      final maxScroll = _controller.position.maxScrollExtent;
      if (maxScroll <= 0) return;
      final target = saved > maxScroll ? maxScroll : saved;
      _controller.jumpTo(target);
    });
  }

  Future<void> _saveOffset() async {
    if (!_controller.hasClients) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKeyOffset, _controller.offset);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentShortTrainingsProvider>(
      builder: (context, provider, child) {
        final slotsProvider = context.watch<StudentHomeSlotsProvider>();
        final slotItems =
            slotsProvider.getItemsForSlot('mobile_row_short_trainings');

        List<Map<String, dynamic>> sessions;
        if (slotItems.isNotEmpty) {
          sessions = slotItems
              .map((item) => item['short_training_session'])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: false);
        } else {
          sessions = provider.publicSessions;
        }

        if (provider.isLoading && sessions.isEmpty) {
          return const SizedBox(
            height: 130,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (provider.error != null && sessions.isEmpty) {
          return const SizedBox.shrink();
        }

        if (sessions.isEmpty) {
          return const SizedBox.shrink();
        }

        if (!_offsetRestored) {
          _offsetRestored = true;
          _restoreOffset();
        }

        final items = sessions.take(10).toList(growable: false);
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }

        final effectiveItemCount = items.length * 10;

        bool hasRichContent = items.any((session) {
          final title = (session['title'] ?? '').toString();
          final category = (session['category'] ?? '').toString();
          final modality = (session['modality'] ?? '').toString();
          final location = (session['location'] ?? '').toString();
          final startAt = (session['start_at'] ?? '').toString();
          final totalLength = title.length +
              category.length +
              modality.length +
              location.length +
              startAt.length;
          return totalLength > 80;
        });
        final bool compact = !hasRichContent;
        final double rowHeight = compact ? 115 : 130;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Formations courtes Nexium Group',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: rowHeight,
              child: ListView.builder(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                itemCount: effectiveItemCount,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  if (items.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final session = items[index % items.length];
                  final isLast = index == effectiveItemCount - 1;
                  return Padding(
                    padding: EdgeInsets.only(right: isLast ? 0 : 12),
                    child: _ShortTrainingMobileCard(
                      session: session,
                      compact: compact,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ShortTrainingMobileCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final bool compact;

  const _ShortTrainingMobileCard({
    required this.session,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = session['title']?.toString() ?? '';
    final category = session['category']?.toString() ?? '';
    final modality = session['modality']?.toString() ?? '';
    final location = session['location']?.toString() ?? '';
    final startAt = session['start_at']?.toString() ?? '';

    final dynamic rawPrice = session['price'];
    num? priceValue;
    if (rawPrice is num) {
      priceValue = rawPrice;
    }
    String? priceText;
    if (priceValue != null) {
      final bool isInt = priceValue % 1 == 0;
      final formatted =
          isInt ? priceValue.toInt().toString() : priceValue.toString();
      priceText = '$formatted FCFA';
    }

    final metaParts = <String>[];
    if (category.isNotEmpty) metaParts.add(category);
    if (modality.isNotEmpty) metaParts.add(modality);
    if (location.isNotEmpty) metaParts.add(location);
    if (startAt.isNotEmpty) metaParts.add(startAt);
    final metaText = metaParts.take(3).join(' • ');

    final screenWidth = MediaQuery.of(context).size.width;
    double cardWidth = screenWidth * (compact ? 0.60 : 0.68);
    if (cardWidth < (compact ? 180 : 200)) {
      cardWidth = compact ? 180 : 200;
    } else if (cardWidth > (compact ? 280 : 320)) {
      cardWidth = compact ? 280 : 320;
    }

    final bool isCompact = compact;

    return SizedBox(
      width: cardWidth,
      child: Card(
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF7E6), Color(0xFFFFFFFF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFC94A),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: compact ? 8 : 10,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (metaText.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              metaText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (priceText != null) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0ECFF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Frais : $priceText',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.bolt,
                  size: 28,
                  color: const Color(0xFFFFC94A).withOpacity(0.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileOnlineCoursesRow extends StatefulWidget {
  const _MobileOnlineCoursesRow();

  @override
  State<_MobileOnlineCoursesRow> createState() => _MobileOnlineCoursesRowState();
}

class _MobileOnlineCoursesRowState extends State<_MobileOnlineCoursesRow> {
  final ScrollController _controller = ScrollController();
  static const double _step = 1.0;
  static const Duration _tick = Duration(milliseconds: 80);
  static const Duration _animDuration = Duration(milliseconds: 80);
  Timer? _timer;
  static const String _prefsKeyOffset = 'student_home_online_courses_offset';
  bool _offsetRestored = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_tick, (_) {
      if (!_controller.hasClients) return;
      final position = _controller.position;
      if (!position.haveDimensions) return;
      final maxScroll = position.maxScrollExtent;
      if (maxScroll <= 0) return;

      final current = _controller.offset;
      double next = current + _step;
      if (next >= maxScroll) {
        next = 0;
      }

      _controller.animateTo(
        next,
        duration: _animDuration,
        curve: Curves.linear,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _saveOffset();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _restoreOffset() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_prefsKeyOffset);
    if (!mounted || saved == null || saved <= 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      final maxScroll = _controller.position.maxScrollExtent;
      if (maxScroll <= 0) return;
      final target = saved > maxScroll ? maxScroll : saved;
      _controller.jumpTo(target);
    });
  }

  Future<void> _saveOffset() async {
    if (!_controller.hasClients) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKeyOffset, _controller.offset);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<OnlineCoursesCatalogProvider, StudentOnlineCoursesProvider>(
      builder: (context, catalog, myCoursesProvider, child) {
        final slotsProvider = context.watch<StudentHomeSlotsProvider>();
        final slotItems =
            slotsProvider.getItemsForSlot('mobile_row_online_courses');

        List<Map<String, dynamic>> courses;
        if (slotItems.isNotEmpty) {
          courses = slotItems
              .map((item) => item['online_course'])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: false);
        } else {
          courses = catalog.courses;
        }

        if (catalog.isLoading && courses.isEmpty) {
          return const SizedBox(
            height: 130,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (catalog.error != null && courses.isEmpty) {
          return const SizedBox.shrink();
        }

        if (courses.isEmpty) {
          return const SizedBox.shrink();
        }

        if (!_offsetRestored) {
          _offsetRestored = true;
          _restoreOffset();
        }

        final enrolledIds = myCoursesProvider.myCourses
            .map((c) => c['course_id']?.toString())
            .whereType<String>()
            .toSet();

        final items = courses.take(20).toList(growable: false);
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }

        final effectiveItemCount = items.length * 10;

        bool hasRichContent = items.any((course) {
          final title = (course['title'] ?? '').toString();
          final shortDescription =
              (course['short_description'] ?? '').toString();
          final category = (course['category'] ?? '').toString();
          final level = (course['level'] ?? '').toString();
          final totalLength = title.length +
              shortDescription.length +
              category.length +
              level.length;
          return totalLength > 100;
        });
        final bool compact = !hasRichContent;
        final double rowHeight = compact ? 115 : 130;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Formations en ligne',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: rowHeight,
              child: ListView.builder(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                itemCount: effectiveItemCount,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  if (items.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final course = items[index % items.length];
                  final isLast = index == effectiveItemCount - 1;
                  final alreadyEnrolled =
                      enrolledIds.contains(course['id']?.toString());
                  return Padding(
                    padding: EdgeInsets.only(right: isLast ? 0 : 12),
                    child: _OnlineCourseMobileCard(
                      course: course,
                      alreadyEnrolled: alreadyEnrolled,
                      compact: compact,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OnlineCourseMobileCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final bool alreadyEnrolled;
  final bool compact;

  const _OnlineCourseMobileCard({
    required this.course,
    required this.alreadyEnrolled,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = (course['title'] ?? '').toString();
    final shortDescription = (course['short_description'] ?? '').toString();
    final level = (course['level'] ?? '').toString();
    final category = (course['category'] ?? '').toString();

    final metaParts = <String>[];
    if (category.isNotEmpty) metaParts.add(category);
    if (level.isNotEmpty) metaParts.add(level);
    final metaText = metaParts.take(2).join(' • ');

    final dynamic rawPrice = course['price'];
    num? priceValue;
    if (rawPrice is num) {
      priceValue = rawPrice;
    }
    String? priceText;
    if (priceValue != null) {
      final bool isInt = priceValue % 1 == 0;
      final formatted =
          isInt ? priceValue.toInt().toString() : priceValue.toString();
      priceText = '$formatted FCFA';
    }

    final contactPhone = (course['contact_phone'] ?? '').toString().trim();
    final contactWhatsapp =
        (course['contact_whatsapp'] ?? '').toString().trim();
    final contactEmail = (course['contact_email'] ?? '').toString().trim();
    final contactWebsite =
        (course['contact_website'] ?? '').toString().trim();

    final screenWidth = MediaQuery.of(context).size.width;
    double cardWidth = screenWidth * (compact ? 0.60 : 0.68);
    if (cardWidth < (compact ? 180 : 200)) {
      cardWidth = compact ? 180 : 200;
    } else if (cardWidth > (compact ? 280 : 320)) {
      cardWidth = compact ? 280 : 320;
    }
    final bool isCompact = compact;

    return SizedBox(
      width: cardWidth,
      child: Card(
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFFE8F0FF), Color(0xFFF5F3FF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: isCompact ? 8 : 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (shortDescription.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              shortDescription,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                              ),
                            ),
                          ],
                          if (metaText.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              metaText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: isCompact ? 6 : 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (alreadyEnrolled) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F7EC),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Inscrit',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ),
                          ] else ...[
                            const SizedBox.shrink(),
                          ],
                          if (priceText != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0ECFF),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Tarif : $priceText',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.play_circle_fill,
                  size: 30,
                  color: const Color(0xFF2563EB).withOpacity(0.25),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileHomeTicker extends StatefulWidget {
  const _MobileHomeTicker();

  @override
  State<_MobileHomeTicker> createState() => _MobileHomeTickerState();
}

class _MobileHomeTickerState extends State<_MobileHomeTicker> {
  final ScrollController _controller = ScrollController();
  static const double _step = 4.0;
  static const Duration _tick = Duration(milliseconds: 40);
  static const Duration _animDuration = Duration(milliseconds: 40);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_tick, (_) {
      if (!_controller.hasClients) return;
      final position = _controller.position;
      if (!position.haveDimensions) return;
      final maxScroll = position.maxScrollExtent;
      if (maxScroll <= 0) return;

      final current = _controller.offset;
      double next = current + _step;
      if (next >= maxScroll) {
        next = 0;
      }

      _controller.animateTo(
        next,
        duration: _animDuration,
        curve: Curves.linear,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentHomeContentProvider>(
      builder: (context, homeContent, child) {
        final texts = homeContent.announcements
            .map((a) => (a['text'] ?? '').toString().trim())
            .where((t) => t.isNotEmpty)
            .toList(growable: false);

        if (texts.isEmpty) {
          return const SizedBox.shrink();
        }

        final baseCount = texts.length;
        final itemCount = baseCount * 20;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            height: 32,
            child: ListView.builder(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              itemCount: itemCount,
              itemBuilder: (context, index) {
                if (baseCount == 0) {
                  return const SizedBox.shrink();
                }
                final effectiveIndex = index % baseCount;
                final text = texts[effectiveIndex];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.bolt,
                        size: 16,
                        color: Color(0xFFFFC94A),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        text,
                        style: const TextStyle(
                          color: Color(0xFF0A2540),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _MobileProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<StudentProfileProvider, StudentApplicationsProvider>(
      builder: (context, profileProvider, appsProvider, child) {
        final profile = profileProvider.profile;
        final fullName = profile?['full_name']?.toString() ?? '';
        final avatarUrl = profile?['avatar_url']?.toString() ?? '';
        final country = profile?['country']?.toString() ?? '';
        final city = profile?['city']?.toString() ?? '';
        final initial = (fullName.isNotEmpty ? fullName[0] : '?').toUpperCase();
        final title = fullName.isNotEmpty
            ? 'Bonjour, $fullName'
            : 'Bienvenue sur Academia';

        final apps = appsProvider.applications;
        final appsCount = apps.length;

        final locationText = (country.isNotEmpty || city.isNotEmpty)
            ? [city, country].where((e) => e.isNotEmpty).join(', ')
            : 'Localisation non renseignée';

        return Card(
          color: Colors.white.withOpacity(0.9),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StudentProfileScreen(),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        radius: 22,
                        backgroundImage:
                            avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl.isEmpty
                            ? Text(
                                initial,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            locationText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6F6F6F),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Candidatures',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6F6F6F),
                          ),
                        ),
                        Text(
                          '$appsCount',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: BobodoView(
                        state: BobodoState.idle,
                        size: 40,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Je t’aide à garder une vue d’ensemble : profil, candidatures, paiements et challenges. On avance ensemble, une étape et un badge à la fois.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MobileMyTrainingsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<StudentOnlineCoursesProvider, OnlineCoursesCatalogProvider>(
      builder: (context, myCoursesProvider, catalogProvider, child) {
        final myCourses = myCoursesProvider.myCourses;
        final catalogCourses = catalogProvider.courses;

        return Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mes formations',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Retrouve rapidement tes cours et formations en ligne en cours.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6F6F6F),
                  ),
                ),
                const SizedBox(height: 8),
                if (myCoursesProvider.isLoading && myCourses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  )
                else if (myCourses.isEmpty)
                  const Text(
                    'Tu ne suis pas encore de formation en ligne.',
                    style: TextStyle(fontSize: 12),
                  )
                else
                  ...myCourses.take(3).map((c) {
                    final title = (c['title'] ?? '').toString();
                    final courseId = (c['course_id'] ?? '').toString();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        if (courseId.isEmpty) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OnlineCourseDetailScreen(
                              courseId: courseId,
                              initialTitle: title,
                              initiallyEnrolled: true,
                            ),
                          ),
                        );
                      },
                    );
                  }),
                if (catalogCourses.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const StudentOnlineTrainingsTab(),
                        ),
                      );
                    },
                    child: const Text(
                      'Voir le catalogue des formations en ligne',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MobileApplicationsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<StudentApplicationsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.applications.isEmpty) {
          return const Card(
            color: Colors.white,
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(12.0),
              child: LoadingWidget(message: 'Chargement de tes candidatures...'),
            ),
          );
        }

        if (provider.error != null && provider.applications.isEmpty) {
          return Card(
            color: Colors.white,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: CustomErrorWidget(
                error: provider.error!,
                onRetry: provider.loadApplications,
              ),
            ),
          );
        }

        final apps = provider.applications;

        return Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mes candidatures',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Suis l’état de tes candidatures aux programmes.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6F6F6F),
                  ),
                ),
                const SizedBox(height: 8),
                if (apps.isEmpty)
                  const Text(
                    'Tu n’as pas encore de candidature en cours.',
                    style: TextStyle(fontSize: 12),
                  )
                else
                  ...apps.take(3).map((app) {
                    final id = app['id']?.toString() ?? '';
                    final status = app['status']?.toString() ?? '';
                    final programTitle = app['program_title']?.toString() ?? '';
                    final universityName = app['university_name']?.toString() ?? '';

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.assignment_outlined),
                      title: Text(
                        programTitle.isNotEmpty ? programTitle : 'Candidature',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        universityName.isNotEmpty
                            ? universityName
                            : 'Statut : $status',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => StudentApplicationDetailScreen(
                              application: app,
                            ),
                          ),
                        );
                      },
                    );
                  }),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const StudentApplicationsTab(),
                        ),
                      );
                    },
                    child: const Text(
                      'Voir toutes les candidatures',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MobileOpportunitiesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<StudentHomeSlotsProvider>(
      builder: (context, slotsProvider, child) {
        final rawItems = slotsProvider
            .getItemsForSlot('mobile_row_opportunities')
            .where((item) => item['opportunity'] is Map)
            .toList(growable: false);

        if (slotsProvider.isLoading && rawItems.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Center(
              child: SizedBox(
                height: 28,
                width: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (rawItems.isEmpty) {
          // Aucun slot opportunités configuré pour l'instant : ne rien afficher.
          return const SizedBox.shrink();
        }

        final opportunities = rawItems
            .map((item) => Map<String, dynamic>.from(
                  item['opportunity'] as Map,
                ))
            .toList(growable: false);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(
                color: Color(0x80F6A623),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const StudentOpportunitiesTab(),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7E6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '🔥 Top opportunités du moment',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Opportunités à saisir',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0A2540),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Les meilleures occasions pour booster ton parcours : stages, emplois et missions sélectionnés pour toi.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6F6F6F),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...opportunities.take(3).map((op) {
                    final title = (op['title'] ?? '').toString();
                    final type = (op['type'] ?? '').toString();
                    final location = (op['location'] ?? '').toString();
                    final startsAtRaw = op['starts_at']?.toString();

                    String? formattedStart;
                    if (startsAtRaw != null && startsAtRaw.isNotEmpty) {
                      try {
                        final parsed = DateTime.tryParse(startsAtRaw);
                        if (parsed != null) {
                          formattedStart =
                              DateFormat('d MMMM y', 'fr_FR').format(parsed.toLocal());
                        } else {
                          formattedStart = startsAtRaw;
                        }
                      } catch (_) {
                        formattedStart = startsAtRaw;
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const StudentOpportunitiesTab(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0A2540),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (type.isNotEmpty)
                                    Flexible(
                                      child: Text(
                                        type,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF4B5563),
                                        ),
                                      ),
                                    ),
                                  if (type.isNotEmpty && location.isNotEmpty)
                                    const Text(
                                      ' • ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  if (location.isNotEmpty)
                                    Flexible(
                                      child: Text(
                                        location,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF4B5563),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (formattedStart != null && formattedStart.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Début : $formattedStart',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StudentOpportunitiesTab(),
                          ),
                        );
                      },
                      child: const Text(
                        'Voir toutes les opportunités',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MobileChallengesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Challenges & vidéos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Participe à des missions, concours et découvre les vidéos de challenges.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6F6F6F),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const challenges_tab.StudentChallengesTab(),
                    ),
                  );
                },
                child: const Text(
                  'Voir les challenges',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobilePartnersSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<StudentOffersProvider>(
      builder: (context, offersProvider, child) {
        final universities = offersProvider.universities;

        return Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Universités partenaires',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Découvre les universités partenaires et leurs programmes.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6F6F6F),
                  ),
                ),
                const SizedBox(height: 8),
                if (universities.isNotEmpty)
                  ...universities.take(2).map((uni) {
                    final name = uni['name']?.toString() ?? '';
                    final city = uni['city']?.toString() ?? '';
                    final country = uni['country']?.toString() ?? '';
                    final slug = uni['slug']?.toString();
                    final location =
                        [city, country].where((e) => e.isNotEmpty).join(', ');

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6F6F6F),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        if (slug == null || slug.isEmpty) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => StudentUniversitySiteScreen(
                              universitySlug: slug,
                              universityName: name,
                            ),
                          ),
                        );
                      },
                    );
                  })
                else
                  const Text(
                    'Les universités partenaires seront affichées ici.',
                    style: TextStyle(fontSize: 12),
                  ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const partners_tab.StudentPartnersTab(),
                        ),
                      );
                    },
                    child: const Text(
                      'Voir toutes les universités partenaires',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
