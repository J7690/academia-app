import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../student_profile_screen.dart';
import '../student_university_site_screen.dart';
import '../application_request_dialog.dart';
import '../student_payments_screen.dart';
import '../student_home_mobile.dart' show StudentAssistantSection;
import '../../../providers/student_profile_provider.dart';
import '../../../providers/student_offers_provider.dart';
import '../../../providers/student_applications_provider.dart';
import '../../../providers/student_home_content_provider.dart';
import '../../../providers/student_home_slots_provider.dart';
import '../../../providers/online_courses_catalog_provider.dart';
import '../../../providers/student_online_courses_provider.dart';
import '../../../providers/student_weather_provider.dart';
import '../../../providers/student_announcements_provider.dart';
import '../../../providers/student_academic_calendar_provider.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/hero_media_carousel.dart';
import '../../../widgets/notification_sound_settings_dialog.dart';
import '../widgets/student_short_trainings_section.dart';
import '../widgets/student_home_online_courses_section.dart';
import '../../../providers/student_application_payments_provider.dart';
import 'student_opportunities_tab.dart';
import '../../share/share_service.dart';
import '../../share/share_mode_provider.dart';
import '../../share/widgets/share_signature.dart';

class StudentHomeTab extends StatefulWidget {
  const StudentHomeTab({super.key});

  @override
  State<StudentHomeTab> createState() => _StudentHomeTabState();
}

class _StudentHomeTabState extends State<StudentHomeTab> {
  late final ScrollController _tickerController;
  Timer? _tickerTimer;

  /// Playlist du hero étudiant, alimentée par app_public_hero_playlist.
  List<HeroMediaItem> _heroMediaItems = [];

  String? _heroTitle;

  String _searchUniversityQuery = '';
  String _searchProgramQuery = '';
  String? _selectedDegreeLevel;

  final TextEditingController _universitySearchController = TextEditingController();
  final TextEditingController _programSearchController = TextEditingController();

  final GlobalKey _shareBoundaryKey = GlobalKey();
  final ShareService _shareService = ShareService();

  static const List<String> _fallbackAnnouncements = [
    'Ouverture des candidatures 2025',
    'Bourses pour étudiants internationaux',
    'Nouveaux programmes disponibles',
    'Accompagnement personnalisé',
  ];

  static const String _studentHomeHeroCacheKey = 'student_home_hero_playlist_v1';

  Future<void> _loadHeroPlaylistFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_studentHomeHeroCacheKey);
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;

      final map = Map<String, dynamic>.from(decoded);
      final itemsRaw = map['items'];
      final cached = <HeroMediaItem>[];

      if (itemsRaw is List) {
        var sort = 0;
        for (final item in itemsRaw) {
          if (item is! Map) continue;
          final m = Map<String, dynamic>.from(item);
          final url = (m['url'] ?? '').toString().trim();
          if (url.isEmpty) continue;
          final mediaType = (m['mediaType'] ?? 'video').toString();
          cached.add(
            HeroMediaItem(
              id: 'cache_$sort',
              mediaType: mediaType,
              url: url,
              sortOrder: sort,
            ),
          );
          sort++;
        }
      }

      if (cached.isEmpty || !mounted) return;

      final cachedTitle = map['title']?.toString();

      setState(() {
        _heroMediaItems = cached;
        _heroTitle = cachedTitle;
      });
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _tickerController = ScrollController();
    _loadHeroPlaylistFromCache();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<StudentOffersProvider>().loadHomeOffers();
      context.read<StudentProfileProvider>().loadProfile();
      context.read<StudentApplicationsProvider>().loadApplications();

      final homeContent = context.read<StudentHomeContentProvider>();
      try {
        await homeContent.loadPublicStudentHomeContent();
      } catch (_) {}

      try {
        await context.read<OnlineCoursesCatalogProvider>().loadPublicCourses();
      } catch (_) {}
      try {
        await context.read<StudentOnlineCoursesProvider>().loadMyCourses();
      } catch (_) {}
      try {
        final slotsProvider = context.read<StudentHomeSlotsProvider>();
        await slotsProvider.loadSlotItems('desktop_short_trainings');
        await slotsProvider.loadSlotItems('desktop_online_courses');
        await slotsProvider.loadSlotItems('desktop_row_opportunities');
      } catch (_) {}

      // Chargement des données pour l'assistant (météo, annonces, calendrier)
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

      if (!mounted) return;
      await _setupMediaPlaylist();
      _startTicker();
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _tickerController.dispose();
    _universitySearchController.dispose();
    _programSearchController.dispose();
    super.dispose();
  }

  Future<void> _shareCurrentView() async {
    await _shareService.shareCurrentView(
      context: context,
      boundaryKey: _shareBoundaryKey,
      shareText: 'Découvert via Academia – Faciliter l’accès aux formations.',
    );
  }

  Future<void> _shareHeroCard() async {
    final title = _heroTitle?.trim().isNotEmpty == true
        ? _heroTitle!.trim()
        : 'Espace étudiant Academia';

    await _shareService.shareCustomCard(
      context: context,
      card: _StudentHomeShareHeroCard.buildWithTitle(title),
      shareText: 'Découvert via Academia – Faciliter l’accès aux formations.',
    );
  }

  Future<void> _shareDiscoverCard() async {
    await _shareService.shareCustomCard(
      context: context,
      card: const _StudentHomeShareDiscoverCard(),
      shareText: 'Découvert via Academia – Faciliter l’accès aux formations.',
    );
  }

  Future<void> _shareQuickAccessCard() async {
    await _shareService.shareCustomCard(
      context: context,
      card: const _StudentHomeShareQuickAccessCard(),
      shareText: 'Découvert via Academia – Faciliter l’accès aux formations.',
    );
  }

  void _openShareOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.web),
                title: const Text('Vue complète de la page'),
                subtitle: const Text(
                  'Capture tout l’écran d’accueil étudiant.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _shareCurrentView();
                },
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.star_rounded),
                title: const Text('Carte hero'),
                subtitle: const Text(
                  'Une carte visuelle mettant en avant le hero étudiant.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _shareHeroCard();
                },
              ),
              ListTile(
                leading: const Icon(Icons.school_outlined),
                title: const Text('Carte découverte formations'),
                subtitle: const Text(
                  'Présente les formations, cours en ligne et opportunités.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _shareDiscoverCard();
                },
              ),
              ListTile(
                leading: const Icon(Icons.dashboard_customize_outlined),
                title: const Text('Carte accès rapide'),
                subtitle: const Text(
                  'Met en avant les principales sections de ton espace.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _shareQuickAccessCard();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _setupMediaPlaylist() async {
    final client = Supabase.instance.client;

    final playlist = <HeroMediaItem>[];
    String? title;

    try {
      debugPrint(
        'StudentHome: calling app_public_hero_playlist(slot=student_home_hero_main)',
      );
      final dynamic response = await client.rpc(
        'app_public_hero_playlist',
        params: {'p_slot': 'student_home_hero_main'},
      );

      if (response is! Map<String, dynamic>) {
        debugPrint(
          'StudentHome: invalid hero playlist response type='
          '${response.runtimeType}',
        );
        return;
      }
      if (response['success'] != true) {
        debugPrint(
          'StudentHome: app_public_hero_playlist returned non-success: '
          'success=${response['success']} error=${response['error']}',
        );
        return;
      }

      final items = response['items'];
      if (items is! List) {
        debugPrint('StudentHome: hero playlist items is not a List');
        return;
      }

      for (final raw in items) {
        if (raw is! Map) continue;
        final row = Map<String, dynamic>.from(raw);

        final rawType = (row['media_type'] ?? 'video').toString().toLowerCase();
        final isImage = rawType == 'image';

        final playbackRaw = row['playback'];
        Map<String, dynamic>? playback;
        if (playbackRaw is Map) {
          playback = Map<String, dynamic>.from(playbackRaw);
        }

        final bestUrl = (playback?['best_url'] ?? '').toString().trim();
        final posterUrl = (playback?['poster_url'] ?? '').toString().trim();
        final baseVideoUrl = (row['base_video_url'] ?? '').toString().trim();
        final baseImageUrl = (row['base_image_url'] ?? '').toString().trim();

        String? resolvedUrl;
        String mediaType;

        if (isImage) {
          if (baseImageUrl.isEmpty) continue;
          resolvedUrl = baseImageUrl;
          mediaType = 'image';
        } else {
          resolvedUrl = bestUrl.isNotEmpty ? bestUrl : baseVideoUrl;
          if (resolvedUrl.isEmpty) {
            continue;
          }
          mediaType = 'video';
        }

        final id = (row['id'] ?? '').toString();
        final sortOrder = (row['sort_order'] as int?) ?? playlist.length;

        debugPrint(
          'StudentHome: hero item from app_public_hero_playlist slot=student_home_hero_main '
          'id=' + id + ' type=' + mediaType + ' url=' + resolvedUrl,
        );

        playlist.add(
          HeroMediaItem(
            id: id.isNotEmpty ? id : 'auto_${playlist.length}',
            mediaType: mediaType,
            url: resolvedUrl,
            posterUrl: posterUrl.isNotEmpty ? posterUrl : null,
            sortOrder: sortOrder,
          ),
        );

        title ??= row['title']?.toString();
      }
      debugPrint(
        'StudentHome: hero playlist built with \\${playlist.length} items from app_public_hero_playlist',
      );
    } catch (e) {
      debugPrint(
        'StudentHome: error while loading hero playlist from app_public_hero_playlist: '
        '\\$e',
      );
    }

    if (playlist.isEmpty) {
      debugPrint(
        'StudentHome: hero playlist is empty after app_public_hero_playlist, '
        'mounted=$mounted',
      );
      _heroMediaItems = [];
      if (mounted) {
        setState(() {
          _heroTitle = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _heroMediaItems = playlist;
        _heroTitle = title;
      });
    } else {
      _heroMediaItems = playlist;
      _heroTitle = title;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, dynamic>{
        'title': _heroTitle,
        'items': playlist
            .map((e) => {
                  'url': e.url,
                  'mediaType': e.mediaType,
                })
            .toList(),
      };
      await prefs.setString(
        _studentHomeHeroCacheKey,
        jsonEncode(data),
      );
    } catch (_) {}
  }

  void _startTicker() {
    _tickerTimer?.cancel();
    const step = 4.0;
    const tick = Duration(milliseconds: 40);
    const animDuration = Duration(milliseconds: 40);

    _tickerTimer = Timer.periodic(tick, (_) {
      if (!_tickerController.hasClients) return;
      final position = _tickerController.position;
      if (!position.haveDimensions) return;
      final maxScroll = position.maxScrollExtent;
      if (maxScroll <= 0) return;

      final current = _tickerController.offset;
      double next = current + step;

      if (next >= maxScroll) {
        next = 0;
      }

      _tickerController.animateTo(
        next,
        duration: animDuration,
        curve: Curves.linear,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        if (constraints.maxWidth < 600) {
          crossAxisCount = 1;
        } else if (constraints.maxWidth < 1000) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 3;
        }

        return Consumer2<StudentOffersProvider, StudentHomeContentProvider>(
          builder: (context, offersProvider, homeContent, child) {
            if (offersProvider.isLoading && offersProvider.homeOffers.isEmpty) {
              return const LoadingWidget(
                message: 'Chargement des offres de formation...',
              );
            }

            if (offersProvider.error != null) {
              return CustomErrorWidget(
                error: offersProvider.error!,
                onRetry: () => offersProvider.loadHomeOffers(),
              );
            }

            final offers = offersProvider.homeOffers;

            final allDegreeLevels = <String>{};
            for (final offer in offers) {
              final level = (offer['degree_level'] ?? '').toString().trim();
              if (level.isNotEmpty) {
                allDegreeLevels.add(level);
              }
            }
            final degreeLevels = allDegreeLevels.toList()..sort();

            final filteredOffers = offers.where((offer) {
              final title = (offer['program_title'] ?? '').toString().toLowerCase();
              final description =
                  (offer['program_description'] ?? '').toString().toLowerCase();
              final universityName =
                  (offer['university_name'] ?? '').toString().toLowerCase();
              final city = (offer['city'] ?? '').toString().toLowerCase();
              final country = (offer['country'] ?? '').toString().toLowerCase();

              final programQuery = _searchProgramQuery.trim().toLowerCase();
              if (programQuery.isNotEmpty &&
                  !title.contains(programQuery) &&
                  !description.contains(programQuery)) {
                return false;
              }

              final universityQuery = _searchUniversityQuery.trim().toLowerCase();
              final combinedUni = '$universityName $city $country';
              if (universityQuery.isNotEmpty &&
                  !combinedUni.contains(universityQuery)) {
                return false;
              }

              if (_selectedDegreeLevel != null &&
                  _selectedDegreeLevel!.trim().isNotEmpty) {
                final level =
                    (offer['degree_level'] ?? '').toString().toLowerCase();
                if (level != _selectedDegreeLevel!.toLowerCase()) {
                  return false;
                }
              }

              return true;
            }).toList(growable: false);

            final slivers = <Widget>[
              SliverToBoxAdapter(child: _ProfileHeader()),
              SliverToBoxAdapter(
                child: _StudentHomeHeroCarousel(
                  heroItems: _heroMediaItems,
                  heroTitle: _heroTitle,
                  onShare: _openShareOptions,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: _StudentHomeTicker(
                    controller: _tickerController,
                    announcements: homeContent.announcements,
                    fallbackAnnouncements: _fallbackAnnouncements,
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: StudentAssistantSection(),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: StudentShortTrainingsSection(),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: StudentHomeOnlineCoursesSection(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _DesktopOpportunitiesSection(),
                ),
              ),
            ];

            if (offers.isEmpty) {
              slivers.add(
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Aucune offre disponible pour le moment.'),
                    ),
                  ),
                ),
              );
            } else {
              slivers.add(
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _programSearchController,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.school_outlined),
                            hintText:
                                'Rechercher une filière ou un programme (ex: Informatique, Gestion...)',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(24)),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchProgramQuery = value;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _universitySearchController,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.apartment_outlined),
                            hintText:
                                'Rechercher une université (nom, ville, pays)...',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(24)),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchUniversityQuery = value;
                            });
                          },
                        ),
                        if (degreeLevels.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilterChip(
                                label: const Text('Tous les niveaux'),
                                selected: _selectedDegreeLevel == null,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedDegreeLevel = null;
                                  });
                                },
                              ),
                              ...degreeLevels.map((level) {
                                return FilterChip(
                                  label: Text(level),
                                  selected: _selectedDegreeLevel == level,
                                  onSelected: (_) {
                                    setState(() {
                                      if (_selectedDegreeLevel == level) {
                                        _selectedDegreeLevel = null;
                                      } else {
                                        _selectedDegreeLevel = level;
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _searchProgramQuery = '';
                                _searchUniversityQuery = '';
                                _selectedDegreeLevel = null;
                                _programSearchController.clear();
                                _universitySearchController.clear();
                              });
                            },
                            icon: const Icon(Icons.filter_alt_off),
                            label: const Text('Réinitialiser les filtres'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              slivers.add(
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: filteredOffers.isEmpty
                      ? const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Aucune offre ne correspond à vos critères.',
                              ),
                            ),
                          ),
                        )
                      : SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 3 / 2,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final offer = filteredOffers[index];
                              return _OfferCard(offer: offer);
                            },
                            childCount: filteredOffers.length,
                          ),
                        ),
                ),
              );
            }

            return RepaintBoundary(
              key: _shareBoundaryKey,
              child: Stack(
                children: [
                  CustomScrollView(
                    slivers: slivers,
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
      },
    );
  }
}

class _StudentHomeShareHeroCard extends StatelessWidget {
  final String title;

  const _StudentHomeShareHeroCard({required this.title});

  static Widget buildWithTitle(String title) {
    return _StudentHomeShareHeroCard(title: title);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7BC96F), Color(0xFF34D399)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Academia – Espace étudiant',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Positioned(
              right: 16,
              bottom: 16,
              child: ShareSignature(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentHomeShareDiscoverCard extends StatelessWidget {
  const _StudentHomeShareDiscoverCard();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Découvre des formations et opportunités',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A2540),
                  ),
                ),
                SizedBox(height: 12),
                _SharePillRow(
                  icon: Icons.school_outlined,
                  label: 'Formations courtes',
                ),
                SizedBox(height: 8),
                _SharePillRow(
                  icon: Icons.computer_outlined,
                  label: 'Cours en ligne',
                ),
                SizedBox(height: 8),
                _SharePillRow(
                  icon: Icons.work_outline,
                  label: 'Opportunités',
                ),
                SizedBox(height: 16),
                Text(
                  'Tout en un seul espace étudiant, gratuitement.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
            const Positioned(
              right: 0,
              bottom: 0,
              child: ShareSignature(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentHomeShareQuickAccessCard extends StatelessWidget {
  const _StudentHomeShareQuickAccessCard();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A2540),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Ton hub académique sur Academia',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 12),
                _ShareBullet(text: '🎓 Formations'),
                _ShareBullet(text: '💻 Cours en ligne'),
                _ShareBullet(text: '🚀 Opportunités'),
                _ShareBullet(text: '👥 Communautés'),
              ],
            ),
            const Positioned(
              right: 0,
              bottom: 0,
              child: ShareSignature(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharePillRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SharePillRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE5F9E7),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: const Color(0xFF0A2540)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0A2540),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShareBullet extends StatelessWidget {
  final String text;

  const _ShareBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _StudentHomeHeroCarousel extends StatelessWidget {
  final List<HeroMediaItem> heroItems;
  final String? heroTitle;
  final VoidCallback? onShare;

  const _StudentHomeHeroCarousel({
    required this.heroItems,
    required this.heroTitle,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final rawTitle = heroTitle?.trim() ?? '';
    final title = rawTitle.isNotEmpty ? rawTitle : 'Espace étudiant Academia';

    debugPrint(
      'StudentHomeHeroCarousel: building with heroItems=' +
          heroItems.length.toString(),
    );

    final width = MediaQuery.of(context).size.width;
    double aspectRatio;
    if (width < 600) {
      aspectRatio = 16 / 9;
    } else if (width < 1000) {
      aspectRatio = 16 / 7;
    } else {
      aspectRatio = 16 / 5;
    }

    final isShareModeEnabled =
        context.select<ShareModeProvider, bool>((p) => p.isShareModeEnabled);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: HeroMediaCarousel(
          items: heroItems,
          aspectRatio: aspectRatio,
          useAspectRatio: true,
          autoplay: true,
          loopVideos: false,
          mutedByDefault: kIsWeb,
          showControls: false,
          defaultImageDuration: const Duration(seconds: 5),
          overlayBuilder: (context, currentItem) {
            final hasMedia = currentItem != null;
            return Stack(
              fit: StackFit.expand,
              children: [
                if (!hasMedia)
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF7BC96F), Color(0xFFE8F5E9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.45),
                        Colors.black.withOpacity(0.1),
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
                if (onShare != null && !isShareModeEnabled)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Material(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: onShare,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.share,
                                size: 16,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Partager',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (title.isNotEmpty)
                  Positioned(
                    left: 16,
                    right: 16,
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
            );
          },
        ),
      ),
    );
  }
}

class _StudentHomeTicker extends StatelessWidget {
  final ScrollController controller;
  final List<Map<String, dynamic>> announcements;
  final List<String> fallbackAnnouncements;

  const _StudentHomeTicker({
    required this.controller,
    required this.announcements,
    required this.fallbackAnnouncements,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7BC96F), Color(0xFFE8F5E9)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: SizedBox(
        height: 32,
        child: ListView.builder(
          controller: controller,
          scrollDirection: Axis.horizontal,
          itemCount: () {
            final baseCount = announcements.isNotEmpty
                ? announcements.length
                : fallbackAnnouncements.length;
            if (baseCount <= 0) return 0;
            return baseCount * 20;
          }(),
          itemBuilder: (context, index) {
            final hasAnnouncements = announcements.isNotEmpty;
            final baseCount = hasAnnouncements
                ? announcements.length
                : fallbackAnnouncements.length;
            if (baseCount == 0) {
              return const SizedBox.shrink();
            }
            final effectiveIndex = index % baseCount;
            String text;
            if (hasAnnouncements) {
              final a = announcements[effectiveIndex];
              text = (a['text'] ?? '').toString();
              if (text.isEmpty) {
                text = fallbackAnnouncements[
                    effectiveIndex % fallbackAnnouncements.length];
              }
            } else {
              text = fallbackAnnouncements[effectiveIndex];
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF000000),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DesktopOpportunitiesSection extends StatelessWidget {
  const _DesktopOpportunitiesSection();

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentHomeSlotsProvider>(
      builder: (context, slotsProvider, child) {
        final rawItems = slotsProvider
            .getItemsForSlot('desktop_row_opportunities')
            .where((item) => item['opportunity'] is Map)
            .toList(growable: false);

        if (slotsProvider.isLoading && rawItems.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8),
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

        return Card(
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
            padding: const EdgeInsets.all(16.0),
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
                    children: const [
                      // Badge marketing
                      _DesktopOpportunitiesHeader(),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Liste des cartes opportunités (verticale, jusqu'à 3)
                ...opportunities.take(3).map(
                  (op) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _DesktopOpportunityCard(opportunity: op),
                  ),
                ),
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
        );
      },
    );
  }
}

class _DesktopOpportunitiesHeader extends StatelessWidget {
  const _DesktopOpportunitiesHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        // Badge
        _TopOpportunitiesBadge(),
        SizedBox(height: 8),
        Text(
          'Opportunités à saisir',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A2540),
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Les meilleures occasions pour booster ton parcours : stages, emplois et missions sélectionnés pour toi.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF6F6F6F),
          ),
        ),
      ],
    );
  }
}

class _TopOpportunitiesBadge extends StatelessWidget {
  const _TopOpportunitiesBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _DesktopOpportunityCard extends StatelessWidget {
  final Map<String, dynamic> opportunity;

  const _DesktopOpportunityCard({required this.opportunity});

  @override
  Widget build(BuildContext context) {
    final title = (opportunity['title'] ?? '').toString();
    final type = (opportunity['type'] ?? '').toString();
    final location = (opportunity['location'] ?? '').toString();
    final startsAtRaw = opportunity['starts_at']?.toString();

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

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const StudentOpportunitiesTab(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
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
    );
  }
}

class _ProfileHeader extends StatelessWidget {
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
        final appsText = appsProvider.isLoading && appsCount == 0
            ? 'Candidatures : chargement...'
            : 'Candidatures : $appsCount';

        final locationText = (country.isNotEmpty || city.isNotEmpty)
            ? [city, country].where((e) => e.isNotEmpty).join(', ')
            : 'Localisation non renseignée';

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage:
                        avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            initial,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Chip(
                              label: Text(
                                locationText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF006D3C),
                                ),
                              ),
                              backgroundColor: const Color(0xFFE5F9E7),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            Chip(
                              label: Text(
                                appsText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                              backgroundColor: const Color(0xFFFEF3C7),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(
                            value: context.read<StudentProfileProvider>(),
                            child: const StudentProfileScreen(),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Mon profil'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider(
                            create: (_) => StudentApplicationPaymentsProvider(),
                            child: const StudentPaymentsScreen(),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Mes paiements'),
                  ),
                  IconButton(
                    tooltip: 'Paramètres',
                    icon: const Icon(Icons.settings),
                    onPressed: () {
                      NotificationSoundSettingsDialog.show(context);
                    },
                  ),
                  IconButton(
                    tooltip: 'Se déconnecter',
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      final client = Supabase.instance.client;
                      await client.auth.signOut();
                    },
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

class _OfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;

  const _OfferCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    final programId = offer['program_id']?.toString();
    final title = offer['program_title']?.toString() ?? '';
    final university = offer['university_name']?.toString() ?? '';
    final city = offer['city']?.toString() ?? '';
    final country = offer['country']?.toString() ?? '';
    final degree = offer['degree_level']?.toString() ?? '';
    final mode = offer['mode']?.toString() ?? '';
    final description = offer['program_description']?.toString() ?? '';
    final universitySlug = offer['university_slug']?.toString();
    final highlighted = (offer['highlighted'] == true);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0x80F6A623),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0A2540),
                    ),
                  ),
                ),
                if (highlighted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'En vedette',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              university,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0A2540),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$city, $country',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4B5563),
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (degree.isNotEmpty)
                  Chip(
                    label: Text(
                      degree,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3275D0),
                      ),
                    ),
                    backgroundColor: const Color(0xFFE0EDFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: const BorderSide(
                        color: Color(0xFF3275D0),
                        width: 1,
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (mode.isNotEmpty)
                  Chip(
                    label: Text(
                      mode,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3275D0),
                      ),
                    ),
                    backgroundColor: const Color(0xFFE0EDFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: const BorderSide(
                        color: Color(0xFF3275D0),
                        width: 1,
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: (universitySlug == null || universitySlug.isEmpty)
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StudentUniversitySiteScreen(
                                universitySlug: universitySlug,
                                universityName: university.isNotEmpty ? university : null,
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.school_outlined),
                  label: const Text('Voir le mini-site'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: programId == null
                      ? null
                      : () async {
                          final request = await showApplicationRequestDialog(
                            context,
                            programTitle: title,
                            initialDegreeLevel:
                                degree.isNotEmpty ? degree : null,
                            initialStudyMode: mode.isNotEmpty ? mode : null,
                          );
                          if (!context.mounted) return;
                          if (request == null) {
                            return;
                          }

                          final applicationsProvider =
                              context.read<StudentApplicationsProvider>();
                          final success = await applicationsProvider
                              .createApplication(
                            programId: programId,
                            requestedDegreeLevel:
                                request.requestedDegreeLevel,
                            requestedStudyMode: request.requestedStudyMode,
                            requestedSchedule: request.requestedSchedule,
                            discountRequested: request.discountRequested,
                            discountDetails: request.discountDetails,
                            studentComment: request.studentComment,
                          );
                          if (!context.mounted) return;
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Candidature créée avec succès.'),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  applicationsProvider.error ??
                                      'Erreur lors de la création de la candidature.',
                                ),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3275D0),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.send),
                  label: const Text('Candidater'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
