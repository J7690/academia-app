import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';

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
import '../../providers/student_communities_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/bobodo_state.dart';
import '../../widgets/bobodo_view.dart';
import '../../widgets/notification_sound_settings_dialog.dart';
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
import 'student_search_screen.dart';
import 'student_community_detail_screen.dart';
import 'prep_concours/prep_concours_home_screen.dart';
import 'tabs/student_online_trainings_tab.dart';
import 'widgets/student_mobile_scaffold.dart';
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
      try {
        context.read<StudentCommunitiesProvider>().loadCommunities();
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
                horizontalPadding: 0,
                children: [
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _MobileTopNavBar(),
                  ),
                  const SizedBox(height: 6),
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
    return Consumer2<StudentProfileProvider, StudentApplicationsProvider>(
      builder: (context, profileProvider, appsProvider, _) {
        final profile = profileProvider.profile;
        final fullName = profile?['full_name']?.toString() ?? '';
        final avatarUrl = profile?['avatar_url']?.toString() ?? '';
        final initial =
            (fullName.isNotEmpty ? fullName[0] : '?').toUpperCase();
        final greeting = fullName.isNotEmpty
            ? 'Bonjour, ${fullName.split(' ').first}'
            : 'Bienvenue';
        final appsCount = appsProvider.applications.length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE0E0E0),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Avatar
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StudentProfileScreen(),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFE8F5E9),
                  backgroundImage:
                      avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.isEmpty
                      ? Text(
                          initial,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Color(0xFF2E7D32),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              // Greeting + candidatures badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      greeting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                    if (appsCount > 0)
                      Text(
                        '$appsCount candidature${appsCount > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF757575),
                        ),
                      ),
                  ],
                ),
              ),
              // Share
              Consumer<ShareModeProvider>(
                builder: (context, shareMode, _) {
                  if (shareMode.isShareModeEnabled) {
                    return const SizedBox.shrink();
                  }
                  final isBusy = shareMode.isBusy;
                  return _TopNavIconButton(
                    icon: Icons.share_outlined,
                    onTap: isBusy
                        ? null
                        : () {
                            final parent = context
                                .findAncestorStateOfType<
                                    _StudentHomeMobileTabState>();
                            parent?._shareCurrentView();
                          },
                  );
                },
              ),
              // More
              _TopNavIconButton(
                icon: Icons.more_horiz,
                onTap: () => _onTapSimple(() {
                  _openMoreMenu();
                }),
              ),
            ],
          ),
        );
      },
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
              color: const Color(0xFF2E7D32),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2E7D32),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.5),
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
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF2E7D32),
                width: 2,
              ),
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
                      color: Color(0xFF2E7D32),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Assistant étudiant',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
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
                        Flexible(
                          child: Container(
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
                                Flexible(
                                  child: Text(
                                    'Localisation par défaut : Ouagadougou',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
        FadeInLeft(
          duration: const Duration(milliseconds: 500),
          child: const _MobileShortTrainingsRow(),
        ),
        const SizedBox(height: 8),
        FadeInRight(
          duration: const Duration(milliseconds: 500),
          delay: const Duration(milliseconds: 100),
          child: const _MobileOnlineCoursesRow(),
        ),
        const SizedBox(height: 10),
        FadeIn(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 200),
          child: ZoomIn(
            duration: const Duration(milliseconds: 800),
            delay: const Duration(milliseconds: 200),
            from: 0.95,
            child: const _MobileHomeHero(),
          ),
        ),
        const SizedBox(height: 12),
        FadeInUp(
          duration: const Duration(milliseconds: 400),
          delay: const Duration(milliseconds: 300),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _MobileHomeTicker(),
          ),
        ),
        const SizedBox(height: 16),
        FadeInDown(
          duration: const Duration(milliseconds: 400),
          delay: const Duration(milliseconds: 350),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _MobileSmartSearchBar(),
          ),
        ),
        const SizedBox(height: 12),
        FadeInUp(
          duration: const Duration(milliseconds: 500),
          delay: const Duration(milliseconds: 400),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: StudentHomeFormationsSection(),
          ),
        ),
        const SizedBox(height: 16),
        FadeInUp(
          duration: const Duration(milliseconds: 500),
          delay: const Duration(milliseconds: 450),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _MobileAcademicCalendarSection(),
          ),
        ),
        const SizedBox(height: 16),
        FadeInUp(
          duration: const Duration(milliseconds: 500),
          delay: const Duration(milliseconds: 500),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _MobilePrepConcoursSection(),
          ),
        ),
        const SizedBox(height: 16),
        FadeInUp(
          duration: const Duration(milliseconds: 500),
          delay: const Duration(milliseconds: 550),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _MobileCommunitiesSection(),
          ),
        ),
        const SizedBox(height: 16),
        FadeInUp(
          duration: const Duration(milliseconds: 500),
          delay: const Duration(milliseconds: 600),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _MobileQuickStatsSection(),
          ),
        ),
        const SizedBox(height: 16),
        FadeInUp(
          duration: const Duration(milliseconds: 500),
          delay: const Duration(milliseconds: 650),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _MobileOpportunitiesSection(),
          ),
        ),
      ],
    );
  }
}

class _MobileSmartSearchBar extends StatefulWidget {
  const _MobileSmartSearchBar();

  @override
  State<_MobileSmartSearchBar> createState() => _MobileSmartSearchBarState();
}

class _MobileSmartSearchBarState extends State<_MobileSmartSearchBar>
    with TickerProviderStateMixin {
  static const _hints = [
    'Rechercher une formation...',
    'Rechercher une université...',
    'Rechercher par ville...',
    'Cours en ligne...',
    'Formations courtes...',
  ];

  late final AnimationController _slideController;
  late final AnimationController _glowController;
  late Timer _hintTimer;
  int _hintIndex = 0;
  int _nextHintIndex = 1;
  bool _showNext = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _hintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _cycleHint();
    });
  }

  void _cycleHint() async {
    if (!mounted) return;
    _nextHintIndex = (_hintIndex + 1) % _hints.length;
    setState(() {
      _showNext = true;
    });
    await _slideController.forward();
    if (!mounted) return;
    setState(() {
      _hintIndex = _nextHintIndex;
      _showNext = false;
    });
    _slideController.reset();
  }

  @override
  void dispose() {
    _hintTimer.cancel();
    _slideController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const StudentSearchScreen(),
          ),
        );
      },
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          final glowOpacity = 0.15 + 0.15 * _glowController.value;
          return Container(
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0F2027),
                  Color(0xFF203A43),
                  Color(0xFF2C5364),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7D32).withOpacity(glowOpacity),
                  offset: const Offset(0, 3),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
                const BoxShadow(
                  color: Color(0x30000000),
                  offset: Offset(0, 2),
                  blurRadius: 6,
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: child,
          );
        },
        child: Row(
          children: [
            // Glowing search icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.search,
                color: Color(0xFF66BB6A),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // Slide-up animated hint
            Expanded(
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: _slideController,
                  builder: (context, _) {
                    final slideOut = _slideController.value;
                    return Stack(
                      children: [
                        // Current hint (slides up and fades out)
                        Transform.translate(
                          offset: Offset(0, -20 * slideOut),
                          child: Opacity(
                            opacity: (1.0 - slideOut).clamp(0.0, 1.0),
                            child: Text(
                              _hints[_hintIndex],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.55),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                        // Next hint (slides up from below)
                        if (_showNext)
                          Transform.translate(
                            offset: Offset(0, 20 * (1.0 - slideOut)),
                            child: Opacity(
                              opacity: slideOut.clamp(0.0, 1.0),
                              child: Text(
                                _hints[_nextHintIndex],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.55),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Filter icon
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.tune,
                color: Colors.white.withOpacity(0.6),
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section 1: Calendrier académique — prochains événements
// ---------------------------------------------------------------------------
class _MobileAcademicCalendarSection extends StatelessWidget {
  const _MobileAcademicCalendarSection();

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentAcademicCalendarProvider>(
      builder: (context, provider, _) {
        final events = provider.events;
        if (provider.isLoadingEvents && events.isEmpty) {
          return const SizedBox.shrink();
        }
        if (events.isEmpty) return const SizedBox.shrink();

        // Filter upcoming events (today or future)
        final now = DateTime.now();
        final upcoming = events.where((e) {
          final dateStr = (e['event_date'] ?? e['start_date'] ?? '').toString();
          final date = DateTime.tryParse(dateStr);
          return date != null && !date.isBefore(DateTime(now.year, now.month, now.day));
        }).take(3).toList();

        if (upcoming.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_month_rounded,
                    size: 18, color: Color(0xFF1565C0)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Calendrier académique',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF212121),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const StudentAcademicCalendarScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Voir tout',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...upcoming.map((event) {
              final title = (event['title'] ?? '').toString();
              final dateStr =
                  (event['event_date'] ?? event['start_date'] ?? '').toString();
              final date = DateTime.tryParse(dateStr);
              final formattedDate = date != null
                  ? DateFormat('dd MMM yyyy', 'fr_FR').format(date)
                  : '';
              final eventType = (event['event_type'] ?? '').toString();

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F8FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFE3ECFA),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (date != null)
                              Text(
                                '${date.day}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1565C0),
                                  height: 1,
                                ),
                              ),
                            if (date != null)
                              Text(
                                DateFormat('MMM', 'fr_FR')
                                    .format(date)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1565C0),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF212121),
                              ),
                            ),
                            if (formattedDate.isNotEmpty || eventType.isNotEmpty)
                              Text(
                                [formattedDate, eventType]
                                    .where((s) => s.isNotEmpty)
                                    .join(' · '),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF757575),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Section 2: Prépa Concours — bannière CTA
// ---------------------------------------------------------------------------
class _MobilePrepConcoursSection extends StatelessWidget {
  const _MobilePrepConcoursSection();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const PrepConcoursHomeScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFF4A148C), Color(0xFF7C43BD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A148C).withOpacity(0.2),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Prépa Concours',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Prépare tes concours avec des exercices et corrections',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section 3: Communautés actives — aperçu
// ---------------------------------------------------------------------------
class _MobileCommunitiesSection extends StatelessWidget {
  const _MobileCommunitiesSection();

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentCommunitiesProvider>(
      builder: (context, provider, _) {
        final communities = provider.communities;
        if (provider.isLoading && communities.isEmpty) {
          return const SizedBox.shrink();
        }
        if (communities.isEmpty) return const SizedBox.shrink();

        final visible = communities.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.groups_rounded,
                    size: 18, color: Color(0xFF00695C)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Communautés actives',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF212121),
                    ),
                  ),
                ),
                Text(
                  '${communities.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF00695C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...visible.map((community) {
              final name = (community['name'] ?? '').toString();
              final memberCount =
                  (community['member_count'] ?? 0) as int? ?? 0;
              final category = (community['category'] ?? '').toString();
              final communityId = (community['id'] ?? '').toString();

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GestureDetector(
                  onTap: () {
                    if (communityId.isNotEmpty) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StudentCommunityDetailScreen(
                            communityId: communityId,
                            initialName: name,
                            initialDescription: category,
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F7F5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFD5E8E3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00695C).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.group_rounded,
                            size: 18,
                            color: Color(0xFF00695C),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF212121),
                                ),
                              ),
                              Text(
                                [
                                  if (category.isNotEmpty) category,
                                  '$memberCount membre${memberCount > 1 ? 's' : ''}',
                                ].join(' · '),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF757575),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: Color(0xFF9E9E9E),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Section 4: Statistiques rapides — mini-dashboard + accordéons profil/assistant
// ---------------------------------------------------------------------------
class _MobileQuickStatsSection extends StatefulWidget {
  const _MobileQuickStatsSection();

  @override
  State<_MobileQuickStatsSection> createState() =>
      _MobileQuickStatsSectionState();
}

class _MobileQuickStatsSectionState extends State<_MobileQuickStatsSection> {
  bool _profileExpanded = false;
  bool _assistantExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Consumer4<HomeFormationsProvider, StudentApplicationsProvider,
        OnlineCoursesCatalogProvider, StudentCommunitiesProvider>(
      builder: (context, formations, applications, courses, communities, _) {
        final stats = <_StatItem>[
          _StatItem(
            icon: Icons.school_rounded,
            label: 'Formations',
            value: '${formations.formations.length}',
            color: const Color(0xFF2E7D32),
          ),
          _StatItem(
            icon: Icons.description_outlined,
            label: 'Candidatures',
            value: '${applications.applications.length}',
            color: const Color(0xFF1565C0),
          ),
          _StatItem(
            icon: Icons.play_circle_outline,
            label: 'Cours',
            value: '${courses.courses.length}',
            color: const Color(0xFFE65100),
          ),
          _StatItem(
            icon: Icons.groups_rounded,
            label: 'Communautés',
            value: '${communities.communities.length}',
            color: const Color(0xFF00695C),
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.insights_rounded,
                    size: 18, color: Color(0xFF616161)),
                SizedBox(width: 6),
                Text(
                  'En un coup d\'oeil',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF212121),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: stats.asMap().entries.map((entry) {
                final i = entry.key;
                final stat = entry.value;
                return Expanded(
                  child: FadeInUp(
                    duration: const Duration(milliseconds: 400),
                    delay: Duration(milliseconds: 100 * i),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: stat.color.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: stat.color.withOpacity(0.12),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(stat.icon, size: 20, color: stat.color),
                          const SizedBox(height: 4),
                          Text(
                            stat.value,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: stat.color,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            stat.label,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF757575),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            // --- Accordion: Mon profil ---
            FadeInUp(
              duration: const Duration(milliseconds: 400),
              delay: const Duration(milliseconds: 400),
              child: _buildAccordionTile(
                icon: Icons.person_outline_rounded,
                title: 'Mon profil',
                summary: _profileSummary(context),
                color: const Color(0xFF1565C0),
                expanded: _profileExpanded,
                onTap: () => setState(() => _profileExpanded = !_profileExpanded),
                expandedChild: _buildProfileContent(context),
              ),
            ),
            const SizedBox(height: 6),
            // --- Accordion: Mon assistant ---
            FadeInUp(
              duration: const Duration(milliseconds: 400),
              delay: const Duration(milliseconds: 500),
              child: _buildAccordionTile(
                icon: Icons.assistant_outlined,
                title: 'Mon assistant',
                summary: _assistantSummary(context),
                color: const Color(0xFF2E7D32),
                expanded: _assistantExpanded,
                onTap: () =>
                    setState(() => _assistantExpanded = !_assistantExpanded),
                expandedChild: const _AccordionAssistantContent(),
              ),
            ),
          ],
        );
      },
    );
  }

  String _profileSummary(BuildContext context) {
    final profile =
        context.read<StudentProfileProvider>().profile;
    final fullName = profile?['full_name']?.toString() ?? '';
    final appsCount =
        context.read<StudentApplicationsProvider>().applications.length;
    if (fullName.isNotEmpty) {
      return '$fullName · $appsCount candidature${appsCount != 1 ? 's' : ''}';
    }
    return '$appsCount candidature${appsCount != 1 ? 's' : ''}';
  }

  String _assistantSummary(BuildContext context) {
    final weather =
        context.read<StudentWeatherProvider>().weather;
    final unread =
        context.read<StudentAnnouncementsProvider>().unreadCount;
    final upcoming =
        context.read<StudentAcademicCalendarProvider>().upcomingFollowedCount;
    final parts = <String>[];
    if (weather is Map<String, dynamic>) {
      final temp = weather['temperature'];
      if (temp != null) {
        final rounded = (temp is num) ? temp.round() : temp;
        parts.add('$rounded°C');
      }
    }
    if (unread > 0) {
      parts.add('$unread annonce${unread > 1 ? 's' : ''}');
    }
    if (upcoming > 0) {
      parts.add('$upcoming événement${upcoming > 1 ? 's' : ''}');
    }
    return parts.isNotEmpty ? parts.join(' · ') : 'Météo, annonces, calendrier';
  }

  Widget _buildAccordionTile({
    required IconData icon,
    required String title,
    required String summary,
    required Color color,
    required bool expanded,
    required VoidCallback onTap,
    required Widget expandedChild,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: color.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withOpacity(expanded ? 0.25 : 0.12),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      if (!expanded)
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF757575),
                          ),
                        ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: color.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: expandedChild,
              ),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context) {
    return Consumer2<StudentProfileProvider, StudentApplicationsProvider>(
      builder: (context, profileProvider, appsProvider, child) {
        final profile = profileProvider.profile;
        final fullName = profile?['full_name']?.toString() ?? '';
        final avatarUrl = profile?['avatar_url']?.toString() ?? '';
        final country = profile?['country']?.toString() ?? '';
        final city = profile?['city']?.toString() ?? '';
        final initial =
            (fullName.isNotEmpty ? fullName[0] : '?').toUpperCase();
        final title = fullName.isNotEmpty
            ? 'Bonjour, $fullName'
            : 'Bienvenue sur Academia';

        final apps = appsProvider.applications;
        final appsCount = apps.length;

        final locationText = (country.isNotEmpty || city.isNotEmpty)
            ? [city, country].where((e) => e.isNotEmpty).join(', ')
            : 'Localisation non renseignée';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    radius: 20,
                    backgroundImage:
                        avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            initial,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        locationText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF757575),
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
                        fontSize: 10,
                        color: Color(0xFF757575),
                      ),
                    ),
                    Text(
                      '$appsCount',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Padding(
                  padding: EdgeInsets.only(right: 6.0),
                  child: BobodoView(
                    state: BobodoState.idle,
                    size: 32,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Je t\u2019aide à garder une vue d\u2019ensemble : profil, candidatures, paiements et challenges.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _AccordionAssistantContent extends StatelessWidget {
  const _AccordionAssistantContent();

  @override
  Widget build(BuildContext context) {
    return Consumer3<StudentWeatherProvider, StudentAnnouncementsProvider,
        StudentAcademicCalendarProvider>(
      builder: (context, weatherProvider, announcementsProvider,
          calendarProvider, _) {
        final weather = weatherProvider.weather;
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
              weatherDetailsLine =
                  'Lever ${fmt.format(sunrise)} · Coucher ${fmt.format(sunset)}';
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
              final String uvText = uvIndex % 1 == 0
                  ? uvIndex.toInt().toString()
                  : uvIndex.toStringAsFixed(1);
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
                  'Journée très chaude, hydrate-toi bien et privilégie l\u2019ombre.';
            } else if (weatherAdviceLine == null && code != null) {
              if (_isRainyCode(code)) {
                weatherAdviceLine =
                    'Pluie prévue, pense à anticiper tes déplacements.';
              }
            }
          } catch (_) {}
        }

        final unreadAnnouncements = announcementsProvider.unreadCount;
        final bool hasAnnouncements = unreadAnnouncements > 0 ||
            announcementsProvider.announcements.isNotEmpty;
        String announcementsLine =
            'Aucune annonce importante pour le moment';
        if (hasAnnouncements) {
          if (unreadAnnouncements > 0) {
            announcementsLine =
                '$unreadAnnouncements annonce${unreadAnnouncements > 1 ? 's' : ''} importante${unreadAnnouncements > 1 ? 's' : ''}';
          } else if (announcementsProvider.announcements.isNotEmpty) {
            final first = announcementsProvider.announcements.first;
            final title = first['title']?.toString() ?? '';
            if (title.isNotEmpty) announcementsLine = title;
          }
        }

        final upcomingCount = calendarProvider.upcomingFollowedCount;
        String calendarLine =
            'Aucun événement académique enregistré';
        if (upcomingCount > 0) {
          calendarLine =
              '$upcomingCount événement${upcomingCount > 1 ? 's' : ''} à venir';
        } else if (calendarProvider.events.isNotEmpty) {
          final first = calendarProvider.events.first;
          final title = first['title']?.toString() ?? '';
          if (title.isNotEmpty) calendarLine = title;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (weatherLine != null) ...[
              Row(
                children: [
                  Icon(weatherIcon, size: 16, color: weatherIconColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      weatherLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              if (weatherDetailsLine != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 22),
                  child: Text(
                    weatherDetailsLine,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF757575)),
                  ),
                ),
              if (weatherAdviceLine != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 22),
                  child: Text(
                    weatherAdviceLine,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF2563EB)),
                  ),
                ),
              const SizedBox(height: 4),
            ],
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const StudentAnnouncementsScreen()),
              ),
              child: Row(
                children: [
                  const Icon(Icons.campaign_outlined,
                      size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      announcementsLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) =>
                        const StudentAcademicCalendarScreen()),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_outlined,
                      size: 16, color: Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      calendarLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}

class _MobileShortTrainingsRow extends StatelessWidget {
  const _MobileShortTrainingsRow();

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
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (provider.error != null && sessions.isEmpty) {
          return const SizedBox.shrink();
        }

        if (sessions.isEmpty) {
          return const SizedBox.shrink();
        }

        final items = sessions.take(6).toList(growable: false);
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Formations courtes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF212121),
                      ),
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF2E7D32),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Color(0xFF2E7D32),
                      size: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final spacing = 10.0;
                  final cardWidth =
                      (constraints.maxWidth - spacing) / 2;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: 10,
                    children: items.asMap().entries.map((entry) {
                      final isLeft = entry.key % 2 == 0;
                      final child = SizedBox(
                        width: cardWidth,
                        child: _ShortTrainingMobileCard(
                          session: entry.value,
                        ),
                      );
                      return isLeft
                          ? FadeInLeft(
                              duration: const Duration(milliseconds: 400),
                              delay: Duration(milliseconds: 100 * entry.key),
                              child: child,
                            )
                          : FadeInRight(
                              duration: const Duration(milliseconds: 400),
                              delay: Duration(milliseconds: 100 * entry.key),
                              child: child,
                            );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShortTrainingMobileCard extends StatelessWidget {
  final Map<String, dynamic> session;

  const _ShortTrainingMobileCard({
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final title = session['title']?.toString() ?? '';
    final category = session['category']?.toString() ?? '';
    final imageUrl = session['image_url']?.toString() ?? '';

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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2E7D32),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image area
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Container(
              color: const Color(0xFFE8F5E9),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.school_outlined,
                          size: 32,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.school_outlined,
                        size: 32,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
            ),
          ),
          // Info area
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF212121),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (category.isNotEmpty)
                      Expanded(
                        child: Text(
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF757575),
                          ),
                        ),
                      ),
                    if (priceText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          priceText,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileOnlineCoursesRow extends StatelessWidget {
  const _MobileOnlineCoursesRow();

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
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (catalog.error != null && courses.isEmpty) {
          return const SizedBox.shrink();
        }

        if (courses.isEmpty) {
          return const SizedBox.shrink();
        }

        final enrolledIds = myCoursesProvider.myCourses
            .map((c) => c['course_id']?.toString())
            .whereType<String>()
            .toSet();

        final items = courses.take(6).toList(growable: false);
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Formations en ligne',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF212121),
                      ),
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF2E7D32),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Color(0xFF2E7D32),
                      size: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final spacing = 10.0;
                  final cardWidth =
                      (constraints.maxWidth - spacing) / 2;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: 10,
                    children: items.asMap().entries.map((entry) {
                      final course = entry.value;
                      final alreadyEnrolled =
                          enrolledIds.contains(course['id']?.toString());
                      final isLeft = entry.key % 2 == 0;
                      final child = SizedBox(
                        width: cardWidth,
                        child: _OnlineCourseMobileCard(
                          course: course,
                          alreadyEnrolled: alreadyEnrolled,
                        ),
                      );
                      return isLeft
                          ? FadeInLeft(
                              duration: const Duration(milliseconds: 400),
                              delay: Duration(milliseconds: 100 * entry.key),
                              child: child,
                            )
                          : FadeInRight(
                              duration: const Duration(milliseconds: 400),
                              delay: Duration(milliseconds: 100 * entry.key),
                              child: child,
                            );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OnlineCourseMobileCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final bool alreadyEnrolled;

  const _OnlineCourseMobileCard({
    required this.course,
    required this.alreadyEnrolled,
  });

  @override
  Widget build(BuildContext context) {
    final title = (course['title'] ?? '').toString();
    final category = (course['category'] ?? '').toString();
    final level = (course['level'] ?? '').toString();
    final imageUrl = (course['thumbnail_url'] ?? course['image_url'] ?? '').toString();

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

    final metaParts = <String>[];
    if (category.isNotEmpty) metaParts.add(category);
    if (level.isNotEmpty) metaParts.add(level);
    final metaText = metaParts.take(2).join(' · ');

    return GestureDetector(
      onTap: () {
        final courseId = course['id']?.toString();
        if (courseId != null && courseId.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OnlineCourseDetailScreen(
                courseId: courseId,
                initialTitle: (course['title'] ?? '').toString(),
                initiallyEnrolled: alreadyEnrolled,
              ),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF2E7D32),
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image area
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: const Color(0xFFE3F2FD),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                size: 32,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.play_circle_outline,
                              size: 32,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                  ),
                  if (alreadyEnrolled)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Inscrit',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info area
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF212121),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (metaText.isNotEmpty)
                        Expanded(
                          child: Text(
                            metaText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF757575),
                            ),
                          ),
                        ),
                      if (priceText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            priceText,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
            color: const Color(0xFFE8F5E9),
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
                        color: Color(0xFF2E7D32),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        text,
                        style: const TextStyle(
                          color: Color(0xFF212121),
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
