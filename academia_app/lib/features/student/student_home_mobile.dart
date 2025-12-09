import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/student_profile_provider.dart';
import '../../providers/student_applications_provider.dart';
import '../../providers/student_offers_provider.dart';
import '../../providers/student_home_content_provider.dart';
import '../../providers/online_courses_catalog_provider.dart';
import '../../providers/student_online_courses_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/academia_video_widget.dart';
import 'student_application_detail_screen.dart';
import 'tabs/student_applications_tab.dart';
import 'tabs/student_opportunities_tab.dart';
import 'tabs/student_challenges_tab.dart' as challenges_tab;
import 'tabs/student_partners_tab.dart' as partners_tab;
import 'student_university_site_screen.dart';
import 'student_profile_screen.dart';
import 'online_course_detail_screen.dart';
import 'tabs/student_online_trainings_tab.dart';
import 'widgets/student_mobile_scaffold.dart';

class StudentHomeMobileTab extends StatefulWidget {
  const StudentHomeMobileTab({super.key});

  @override
  State<StudentHomeMobileTab> createState() => _StudentHomeMobileTabState();
}

class _StudentHomeMobileTabState extends State<StudentHomeMobileTab> {
  bool _initialized = false;

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
    });
  }

  @override
  Widget build(BuildContext context) {
    return StudentMobileScrollablePage(
      children: [
        const _MobileHomeHero(),
        const SizedBox(height: 12),
        const _MobileHomeTicker(),
        const SizedBox(height: 16),
        _MobileProfileCard(),
        const SizedBox(height: 16),
        _MobileMyTrainingsSection(),
        const SizedBox(height: 16),
        _MobileApplicationsSection(),
        const SizedBox(height: 16),
        _MobileOpportunitiesSection(),
        const SizedBox(height: 16),
        _MobileChallengesSection(),
        const SizedBox(height: 16),
        _MobilePartnersSection(),
        const SizedBox(height: 24),
      ],
    );
  }
}
class _MobileHomeHero extends StatefulWidget {
  const _MobileHomeHero();

  @override
  State<_MobileHomeHero> createState() => _MobileHomeHeroState();
}

class _MobileHomeHeroState extends State<_MobileHomeHero> {
  static const Duration _slideDuration = Duration(seconds: 5);
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_slideDuration, (_) {
      if (!mounted) return;
      setState(() {
        _index++;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentHomeContentProvider>(
      builder: (context, homeContent, child) {
        final rawVideos = homeContent.videos;
        if (rawVideos.isEmpty) {
          return const SizedBox.shrink();
        }

        final videos = rawVideos
            .where((v) => v['is_active'] != false)
            .map((v) => v as Map<String, dynamic>)
            .where((v) => (v['video_url'] ?? '').toString().trim().isNotEmpty)
            .toList(growable: false);

        if (videos.isEmpty) {
          return const SizedBox.shrink();
        }

        final effectiveIndex = _index % videos.length;
        final selected = videos[effectiveIndex];

        final url = (selected['video_url'] ?? '').toString().trim();
        final rawType = (selected['media_type'] ?? 'video').toString().toLowerCase();
        final isImage = rawType == 'image';
        final title = (selected['title'] ?? '').toString();

        if (url.isEmpty && title.isEmpty) {
          return const SizedBox.shrink();
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFA3D65C), Color(0xFF1EA75C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                if (isImage && url.isNotEmpty)
                  Positioned.fill(
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (context, _, __) {
                        return const SizedBox.shrink();
                      },
                    ),
                  )
                else if (!isImage && url.isNotEmpty)
                  Positioned.fill(
                    child: AcademiaVideoWidget(
                      url: url,
                      autoplay: true,
                      loop: true,
                      muted: true,
                      showControls: false,
                      resizeMode: 'cover',
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
                if (title.isNotEmpty)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 12,
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
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
                    Text(
                      'Candidatures',
                      style: const TextStyle(
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
              'Opportunités',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Stages, emplois et autres opportunités pour les étudiants.',
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
                      builder: (_) => const StudentOpportunitiesTab(),
                    ),
                  );
                },
                child: const Text(
                  'Voir les opportunités',
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
