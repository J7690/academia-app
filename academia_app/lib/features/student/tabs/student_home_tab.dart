import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../student_profile_screen.dart';
import '../student_university_site_screen.dart';
import '../../../providers/student_profile_provider.dart';
import '../../../providers/student_offers_provider.dart';
import '../../../providers/student_applications_provider.dart';
import '../../../providers/student_home_content_provider.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/hls_web_stub.dart'
    if (dart.library.html) '../../../widgets/hls_web.dart';

class StudentHomeTab extends StatefulWidget {
  const StudentHomeTab({super.key});

  @override
  State<StudentHomeTab> createState() => _StudentHomeTabState();
}

class _StudentHomeTabState extends State<StudentHomeTab> {
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _isHlsWeb = false;
  String? _currentHlsUrl;

  late final ScrollController _tickerController;
  Timer? _tickerTimer;

  List<String> _videoPlaylist = [];
  int _currentVideoIndex = 0;

  String _searchUniversityQuery = '';
  String _searchProgramQuery = '';
  String? _selectedDegreeLevel;

  final TextEditingController _universitySearchController = TextEditingController();
  final TextEditingController _programSearchController = TextEditingController();

  static const List<String> _fallbackAnnouncements = [
    'Ouverture des candidatures 2025',
    'Bourses pour étudiants internationaux',
    'Nouveaux programmes disponibles',
    'Accompagnement personnalisé',
  ];

  @override
  void initState() {
    super.initState();
    _tickerController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<StudentOffersProvider>().loadHomeOffers();
      context.read<StudentProfileProvider>().loadProfile();
      context.read<StudentApplicationsProvider>().loadApplications();

      final homeContent = context.read<StudentHomeContentProvider>();
      try {
        await homeContent.loadPublicStudentHomeContent();
      } catch (_) {}

      if (!mounted) return;
      _setupVideoPlaylist(homeContent.videos);
      _startTicker();
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _tickerController.dispose();
    _universitySearchController.dispose();
    _programSearchController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _setupVideoPlaylist(List<Map<String, dynamic>> videos) {
    final playlist = <String>[];
    for (final v in videos) {
      if (v['is_active'] == false) continue;
      final url = (v['video_url'] ?? '').toString().trim();
      if (url.isEmpty) continue;
      playlist.add(url);
    }

    if (playlist.isEmpty) {
      _videoPlaylist = [];
      _currentVideoIndex = 0;
      _videoController?.dispose();
      _videoController = null;
      _videoReady = false;
      _isHlsWeb = false;
      _currentHlsUrl = null;
      if (mounted) {
        setState(() {});
      }
      return;
    }

    _videoPlaylist = playlist;
    _currentVideoIndex = 0;
    _initVideo(_videoPlaylist[_currentVideoIndex]);
  }

  Future<void> _initVideo(String url) async {
    _videoController?.dispose();
    _videoReady = false;
    _isHlsWeb = false;
    _currentHlsUrl = null;
    if (mounted) {
      setState(() {});
    }

    final lowerUrl = url.toLowerCase();
    final isHls = lowerUrl.contains('.m3u8');

    if (kIsWeb && isHls) {
      setState(() {
        _videoController = null;
        _isHlsWeb = true;
        _currentHlsUrl = url;
        _videoReady = true;
      });
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();

      var hasCompleted = false;
      controller.addListener(() {
        final value = controller.value;
        if (!mounted) return;
        if (!value.isInitialized) return;
        final duration = value.duration;
        if (duration == Duration.zero) return;
        if (!value.isPlaying && value.position >= duration && !hasCompleted) {
          hasCompleted = true;
          _onVideoCompleted();
        }
      });

      controller
        ..setLooping(false)
        ..setVolume(0)
        ..play();

      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _videoController = controller;
        _videoReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _videoController = null;
        _videoReady = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible de lire cette vidéo. Utilise un lien direct vers un fichier vidéo (mp4, webm, …) ou un flux HLS public.',
          ),
        ),
      );
    }
  }

  void _onVideoCompleted() {
    if (_videoPlaylist.isEmpty) return;
    _currentVideoIndex = (_currentVideoIndex + 1) % _videoPlaylist.length;
    final nextUrl = _videoPlaylist[_currentVideoIndex];

    if (kIsWeb && _isHlsWeb) {
      setState(() {
        _currentHlsUrl = nextUrl;
      });
      return;
    }

    _initVideo(nextUrl);
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
                child: _StudentHomeHero(
                  videoReady: _videoReady,
                  videoController: _videoController,
                  isHlsWeb: _isHlsWeb,
                  currentHlsUrl: _currentHlsUrl,
                  onVideoCompleted: _onVideoCompleted,
                  videos: homeContent.videos,
                  currentVideoUrl:
                      _videoPlaylist.isNotEmpty && _currentVideoIndex < _videoPlaylist.length
                          ? _videoPlaylist[_currentVideoIndex]
                          : null,
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

            return CustomScrollView(
              slivers: slivers,
            );
          },
        );
      },
    );
  }
}

class _StudentHomeHero extends StatelessWidget {
  final bool videoReady;
  final VideoPlayerController? videoController;
  final bool isHlsWeb;
  final String? currentHlsUrl;
  final VoidCallback onVideoCompleted;
  final List<Map<String, dynamic>> videos;
  final String? currentVideoUrl;

  const _StudentHomeHero({
    required this.videoReady,
    required this.videoController,
    required this.isHlsWeb,
    required this.currentHlsUrl,
    required this.onVideoCompleted,
    required this.videos,
    required this.currentVideoUrl,
  });

  @override
  Widget build(BuildContext context) {
    String? title;
    if (currentVideoUrl != null && videos.isNotEmpty) {
      for (final v in videos) {
        final url = (v['video_url'] ?? '').toString().trim();
        if (url == currentVideoUrl) {
          title = v['title']?.toString();
          break;
        }
      }
    }

    final width = MediaQuery.of(context).size.width;
    double aspectRatio;
    if (width < 600) {
      aspectRatio = 16 / 9;
    } else if (width < 1000) {
      aspectRatio = 16 / 7;
    } else {
      aspectRatio = 16 / 5;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Stack(
            children: [
              Positioned.fill(
                child: videoReady && videoController != null
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: videoController!.value.size.width,
                          height: videoController!.value.size.height,
                          child: VideoPlayer(videoController!),
                        ),
                      )
                    : videoReady && isHlsWeb && kIsWeb && currentHlsUrl != null
                        ? const SizedBox.shrink()
                        : Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFA3D65C), Color(0xFF1EA75C)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
              ),
              if (videoReady && isHlsWeb && kIsWeb && currentHlsUrl != null)
                Positioned.fill(
                  child: HlsWebVideoPlayer(
                    url: currentHlsUrl!,
                    autoplay: true,
                    loop: false,
                    muted: true,
                    onEnded: onVideoCompleted,
                  ),
                ),
              Positioned.fill(
                child: Container(
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
              ),
              if (title != null && title.isNotEmpty)
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
          ),
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
          colors: [Color(0xFF15803D), Color(0xFF0F766E)],
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
                    color: Color(0xFFF9FAFB),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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
                      fontWeight: FontWeight.bold,
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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              '$city, $country',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (degree.isNotEmpty)
                  Chip(
                    label: Text(degree),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (mode.isNotEmpty)
                  Chip(
                    label: Text(mode),
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
                TextButton.icon(
                  onPressed: programId == null
                      ? null
                      : () async {
                          final applicationsProvider =
                              context.read<StudentApplicationsProvider>();
                          final success = await applicationsProvider
                              .createApplication(programId: programId);
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
