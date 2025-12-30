import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/student_university_site_provider.dart';
import '../../providers/student_applications_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/mini_site_hero_video.dart';
import 'mini_site_media_viewer_screen.dart';
import 'application_request_dialog.dart';

class StudentUniversitySiteScreen extends StatefulWidget {
  final String universitySlug;
  final String? universityName;

  const StudentUniversitySiteScreen({super.key, required this.universitySlug, this.universityName});

  @override
  State<StudentUniversitySiteScreen> createState() => _StudentUniversitySiteScreenState();
}

class _StudentUniversitySiteScreenState extends State<StudentUniversitySiteScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentUniversitySiteProvider>().loadUniversitySiteBySlug(widget.universitySlug);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.universityName ?? 'Mini-site université'),
      ),
      body: Consumer<StudentUniversitySiteProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.site == null) {
            return const LoadingWidget(message: "Chargement du mini-site de l'université...");
          }

          if (provider.error != null && provider.site == null) {
            return CustomErrorWidget(
              error: provider.error!,
              onRetry: () {
                context
                    .read<StudentUniversitySiteProvider>()
                    .loadUniversitySiteBySlug(widget.universitySlug);
              },
            );
          }

          final site = provider.site;
          if (site == null) {
            return const Center(
              child: Text("Mini-site indisponible pour cette université."),
            );
          }

          final university = (site['university'] as Map<String, dynamic>?) ?? {};
          final config = (site['config'] as Map<String, dynamic>?) ?? {};
          final blocks = (site['blocks'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final media = (site['media'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final programs = (site['programs'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final courses = (site['courses'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final banners = (site['banners'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final events = (site['events'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final news = (site['news'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final staff = (site['staff'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

          final name = university['name']?.toString() ?? '';
          final city = university['city']?.toString() ?? '';
          final country = university['country']?.toString() ?? '';
          final description = university['description']?.toString() ?? '';
          final logoUrl = university['logo_url']?.toString() ?? '';
          final tagline = university['tagline']?.toString() ?? '';
          final mission = university['mission']?.toString() ?? '';
          final vision = university['vision']?.toString() ?? '';
          final contactEmail = university['contact_email']?.toString() ?? '';
          final contactPhone = university['contact_phone']?.toString() ?? '';
          final address = university['address']?.toString() ?? '';

          Map<String, dynamic> keyFigures = {};
          final rawKeyFigures = university['key_figures'];
          if (rawKeyFigures is Map) {
            keyFigures = Map<String, dynamic>.from(rawKeyFigures);
          }

          Map<String, dynamic> socialLinks = {};
          final rawSocialLinks = university['social_links'];
          if (rawSocialLinks is Map) {
            socialLinks = Map<String, dynamic>.from(rawSocialLinks);
          }

          final heroTitle = (config['hero_title']?.toString() ?? '').trim();
          final heroSubtitle = (config['hero_subtitle']?.toString() ?? '').trim();
          final heroPosterMediaId = config['hero_poster_media_id']?.toString();

          final aboutBlocks =
              blocks.where((b) => (b['key']?.toString() ?? '').toLowerCase() == 'about').toList();
          final otherBlocks =
              blocks.where((b) => (b['key']?.toString() ?? '').toLowerCase() != 'about').toList();

          final highlightedPrograms =
              programs.where((p) => p['highlighted'] == true).toList(growable: false);
          final otherPrograms = programs
              .where((p) => p['highlighted'] != true)
              .toList(growable: false);

          final topBanners = banners
              .where((b) => (b['position']?.toString() ?? '') == 'top_carousel')
              .toList(growable: false);
          final middleBanners = banners
              .where((b) => (b['position']?.toString() ?? '') == 'middle_strip')
              .toList(growable: false);
          final bottomBanners = banners
              .where((b) => (b['position']?.toString() ?? '') == 'bottom_strip')
              .toList(growable: false);

          final displayName =
              name.isNotEmpty ? name : (widget.universityName ?? '');

          final locationText = [city, country]
              .where((e) => e.trim().isNotEmpty)
              .join(', ');

          final heroTagline = tagline.isNotEmpty
              ? tagline
              : (mission.isNotEmpty
                  ? mission
                  : vision);

          // Ne pas ré-afficher sous forme de carte le média utilisé comme poster du hero.
          final List<Map<String, dynamic>> mediaForStrip;
          if (heroPosterMediaId != null && heroPosterMediaId.trim().isNotEmpty) {
            mediaForStrip = media
                .where((m) => m['id']?.toString() != heroPosterMediaId)
                .toList(growable: false);
          } else {
            mediaForStrip = media;
          }

          return Container(
            color: const Color(0xFFF3F4F6),
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF006D3C),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    locationText,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        MiniSiteHeroVideo(
                          media: media,
                          title: displayName,
                          location: locationText,
                          tagline: heroTagline.isNotEmpty ? heroTagline : null,
                          logoUrl: logoUrl.isNotEmpty ? logoUrl : null,
                          heroPosterMediaId: heroPosterMediaId,
                        ),
                        const SizedBox(height: 16),
                        if (mediaForStrip.isNotEmpty || topBanners.isNotEmpty) ...[
                          const Text(
                            'Médias / ambiance du campus',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: _MediaStrip(media: mediaForStrip),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        const Text(
                          'Présentation de l\'université',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (logoUrl.isNotEmpty)
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        logoUrl,
                                        height: 48,
                                        width: 48,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, _, __) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                Text(
                                  heroTitle.isNotEmpty
                                      ? heroTitle
                                      : displayName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tagline.isNotEmpty
                                      ? tagline
                                      : (mission.isNotEmpty ? mission : vision),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  heroSubtitle.isNotEmpty
                                      ? heroSubtitle
                                      : description,
                                ),
                                if (keyFigures.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  _KeyFiguresChips(keyFigures: keyFigures),
                                ],
                                if (aboutBlocks.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  _BlocksList(blocks: aboutBlocks),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (programs.isNotEmpty) ...[
                          const Text(
                            'Programmes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (highlightedPrograms.isNotEmpty) ...[
                                    const Text(
                                      'Programmes phares',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _ProgramsGrid(
                                      programs: highlightedPrograms,
                                      courses: courses,
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  if (otherPrograms.isNotEmpty)
                                    _ProgramsGrid(
                                      programs: otherPrograms,
                                      courses: courses,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (events.isNotEmpty) ...[
                          const Text(
                            'Événements',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: _EventsList(events: events),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (news.isNotEmpty) ...[
                          const Text(
                            'Actualités',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: _NewsList(news: news),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (middleBanners.isNotEmpty) ...[
                          const Text(
                            'Informations clés',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: _BannerStrips(
                                banners: middleBanners,
                                media: media,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (otherBlocks.isNotEmpty) ...[
                          const Text(
                            'Informations complémentaires',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: _BlocksList(blocks: otherBlocks),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (staff.isNotEmpty) ...[
                          const Text(
                            'Équipe',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: _StaffList(staff: staff),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (bottomBanners.isNotEmpty) ...[
                          const Text(
                            'À ne pas manquer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: _BannerStrips(
                                banners: bottomBanners,
                                media: media,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (contactEmail.isNotEmpty ||
                            contactPhone.isNotEmpty ||
                            address.isNotEmpty ||
                            socialLinks.isNotEmpty) ...[
                          const Text(
                            'Contact & informations',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: _ContactSection(
                                email: contactEmail,
                                phone: contactPhone,
                                address: address,
                                socialLinks: socialLinks,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1EA75C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Retour'),
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerCarousel extends StatelessWidget {
  final List<Map<String, dynamic>> banners;
  final List<Map<String, dynamic>> media;

  const _BannerCarousel({required this.banners, required this.media});

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 140,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.9),
        itemCount: banners.length,
        itemBuilder: (context, index) {
          final b = banners[index];
          final title = b['title']?.toString() ?? '';
          final subtitle = b['subtitle']?.toString() ?? '';

          Map<String, dynamic>? associatedMedia;
          final mediaId = b['media_id']?.toString();
          if (mediaId != null && mediaId.isNotEmpty) {
            for (final m in media) {
              if (m['id']?.toString() == mediaId) {
                associatedMedia = m;
                break;
              }
            }
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: associatedMedia == null
                  ? null
                  : () {
                      final mediaMap = associatedMedia!;
                      final storagePath =
                          mediaMap['storage_path']?.toString() ?? '';
                      final directUrl =
                          mediaMap['url']?.toString().trim() ?? '';
                      if (storagePath.isEmpty && directUrl.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Ce média n\'est pas encore disponible.',
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MiniSiteMediaViewerScreen(
                            media: mediaMap,
                          ),
                        ),
                      );
                    },
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BannerStrips extends StatelessWidget {
  final List<Map<String, dynamic>> banners;
  final List<Map<String, dynamic>> media;

  const _BannerStrips({required this.banners, required this.media});

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: banners.map((b) {
        final title = b['title']?.toString() ?? '';
        final subtitle = b['subtitle']?.toString() ?? '';
        Map<String, dynamic>? associatedMedia;
        final mediaId = b['media_id']?.toString();
        if (mediaId != null && mediaId.isNotEmpty) {
          for (final m in media) {
            if (m['id']?.toString() == mediaId) {
              associatedMedia = m;
              break;
            }
          }
        }

        return InkWell(
          onTap: associatedMedia == null
              ? null
              : () {
                  final mediaMap = associatedMedia!;
                  final storagePath =
                      mediaMap['storage_path']?.toString() ?? '';
                  final directUrl =
                      mediaMap['url']?.toString().trim() ?? '';
                  if (storagePath.isEmpty && directUrl.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Ce média n\'est pas encore disponible.',
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MiniSiteMediaViewerScreen(
                        media: mediaMap,
                      ),
                    ),
                  );
                },
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final String title;
  final String city;
  final String country;
  final String subtitle;
  final String logoUrl;
  final String tagline;

  const _HeroSection({
    required this.title,
    required this.city,
    required this.country,
    required this.subtitle,
    required this.logoUrl,
    required this.tagline,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = [city, country].where((e) => e.trim().isNotEmpty).join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.85),
            theme.colorScheme.primary.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (logoUrl.isNotEmpty)
            Align(
              alignment: Alignment.topRight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  logoUrl,
                  height: 56,
                  width: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              location,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (tagline.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              tagline,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionContainer extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionContainer({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _BlocksList extends StatelessWidget {
  final List<Map<String, dynamic>> blocks;

  const _BlocksList({required this.blocks});

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: blocks.map((b) {
        final title = b['title']?.toString() ?? '';
        final content = b['content']?.toString() ?? '';
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
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (content.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(content),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ProgramsGrid extends StatelessWidget {
  final List<Map<String, dynamic>> programs;
  final List<Map<String, dynamic>> courses;

  const _ProgramsGrid({required this.programs, required this.courses});

  @override
  Widget build(BuildContext context) {
    if (programs.isEmpty) {
      return const SizedBox.shrink();
    }
    final width = MediaQuery.of(context).size.width;
    // Sur mobile : une seule colonne, hauteur libre (ListView) pour éviter tout overflow.
    if (width < 600) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: programs.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final program = programs[index];
          return _ProgramCard(
            program: program,
            courses: courses,
          );
        },
      );
    }

    // Sur écrans plus larges : grille réactive avec cartes compactes.
    int crossAxisCount;
    double childAspectRatio;
    if (width < 1000) {
      crossAxisCount = 2;
      childAspectRatio = 1.6;
    } else {
      crossAxisCount = 3;
      childAspectRatio = 1.8;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: programs.length,
      itemBuilder: (context, index) {
        final program = programs[index];
        return _ProgramCard(
          program: program,
          courses: courses,
        );
      },
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final Map<String, dynamic> program;
  final List<Map<String, dynamic>> courses;

  const _ProgramCard({required this.program, required this.courses});

  @override
  Widget build(BuildContext context) {
    final title = program['title']?.toString() ?? '';
    final degree = program['degree_level']?.toString() ?? '';
    final mode = program['mode']?.toString() ?? '';
    final programId = program['id']?.toString();
    final programCourses = programId == null
        ? <Map<String, dynamic>>[]
        : courses
            .where((course) => course['program_id']?.toString() == programId)
            .toList(growable: false);

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
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (degree.isNotEmpty) Chip(label: Text(degree)),
                if (mode.isNotEmpty) Chip(label: Text(mode)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: programId == null || programCourses.isEmpty
                      ? null
                      : () {
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) {
                              return _ProgramCoursesSheet(
                                programTitle: title,
                                courses: programCourses,
                              );
                            },
                          );
                        },
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Voir les cours'),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
                TextButton.icon(
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
                          final success = await applicationsProvider.createApplication(
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
                  icon: const Icon(Icons.send),
                  label: const Text('Candidater'),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgramCoursesSheet extends StatelessWidget {
  final String programTitle;
  final List<Map<String, dynamic>> courses;

  const _ProgramCoursesSheet({required this.programTitle, required this.courses});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cours du programme',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (programTitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    programTitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 12),
                if (courses.isEmpty)
                  const Text('Aucun cours détaillé pour ce programme.')
                else
                  ...courses.map((course) {
                    final title = course['title']?.toString() ?? '';
                    final description = course['description']?.toString() ?? '';
                    final credits = course['credits'];
                    final prerequisites = course['prerequisites']?.toString() ?? '';
                    final instructor = course['instructor']?.toString() ?? '';

                    final metaParts = <String>[];
                    if (credits is int) {
                      metaParts.add('$credits crédits');
                    } else if (credits is String && credits.isNotEmpty) {
                      metaParts.add('$credits crédits');
                    }
                    if (instructor.isNotEmpty) {
                      metaParts.add(instructor);
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (metaParts.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                metaParts.join(' • '),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            if (prerequisites.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Prérequis: $prerequisites',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                description,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaStrip extends StatelessWidget {
  final List<Map<String, dynamic>> media;

  const _MediaStrip({required this.media});

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: media.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final m = media[index];
          final title = m['title']?.toString() ?? '';
          final description = m['description']?.toString() ?? '';
          final mediaType = m['media_type']?.toString() ?? '';
          final storagePath = m['storage_path']?.toString() ?? '';
          final directUrl = m['url']?.toString() ?? '';
          final hasMediaSource = storagePath.isNotEmpty || directUrl.isNotEmpty;

          return SizedBox(
            width: 260,
            child: InkWell(
              onTap: !hasMediaSource
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MiniSiteMediaViewerScreen(media: m),
                        ),
                      );
                    },
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _MediaTypeIcon(mediaType: mediaType),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title.isNotEmpty ? title : 'Média',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Expanded(
                          child: Text(
                            description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]
                      else
                        const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MediaTypeIcon extends StatelessWidget {
  final String mediaType;

  const _MediaTypeIcon({required this.mediaType});

  @override
  Widget build(BuildContext context) {
    final type = mediaType.toLowerCase();
    IconData icon;
    if (type.contains('video')) {
      icon = Icons.play_circle_fill;
    } else if (type.contains('image') || type.contains('photo')) {
      icon = Icons.image;
    } else if (type.contains('brochure') || type.contains('pdf')) {
      icon = Icons.picture_as_pdf;
    } else {
      icon = Icons.insert_drive_file;
    }
    return Icon(icon, size: 24);
  }
}

class _KeyFiguresChips extends StatelessWidget {
  final Map<String, dynamic> keyFigures;

  const _KeyFiguresChips({required this.keyFigures});

  @override
  Widget build(BuildContext context) {
    if (keyFigures.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = keyFigures.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries.map((entry) {
        final label = entry.key.replaceAll('_', ' ');
        final value = entry.value == null ? '' : entry.value.toString();
        return Chip(
          label: Text('$label: $value'),
        );
      }).toList(),
    );
  }
}

class _EventsList extends StatelessWidget {
  final List<Map<String, dynamic>> events;

  const _EventsList({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: events.map((event) {
        final title = event['title']?.toString() ?? '';
        final description = event['description']?.toString() ?? '';
        final location = event['location']?.toString() ?? '';
        final startAt = event['start_at']?.toString() ?? '';
        final endAt = event['end_at']?.toString() ?? '';

        final metaParts = <String>[];
        if (location.isNotEmpty) {
          metaParts.add(location);
        }
        if (startAt.isNotEmpty && endAt.isNotEmpty) {
          metaParts.add('$startAt - $endAt');
        } else if (startAt.isNotEmpty) {
          metaParts.add(startAt);
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (metaParts.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    metaParts.join(' • '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _NewsList extends StatelessWidget {
  final List<Map<String, dynamic>> news;

  const _NewsList({required this.news});

  @override
  Widget build(BuildContext context) {
    if (news.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: news.map((item) {
        final title = item['title']?.toString() ?? '';
        final summary = item['summary']?.toString() ?? '';
        final content = item['content']?.toString() ?? '';
        final publishedAt = item['published_at']?.toString() ?? '';
        final description = summary.isNotEmpty ? summary : content;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (publishedAt.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    publishedAt,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StaffList extends StatelessWidget {
  final List<Map<String, dynamic>> staff;

  const _StaffList({required this.staff});

  @override
  Widget build(BuildContext context) {
    if (staff.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: staff.map((member) {
        final name = member['full_name']?.toString() ?? '';
        final role = member['role']?.toString() ?? '';
        final bio = member['bio']?.toString() ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (role.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    role,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    bio,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ContactSection extends StatelessWidget {
  final String email;
  final String phone;
  final String address;
  final Map<String, dynamic> socialLinks;

  const _ContactSection({
    required this.email,
    required this.phone,
    required this.address,
    required this.socialLinks,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    if (email.isNotEmpty) {
      rows.add(const _ContactRow(icon: Icons.email_outlined));
      rows.add(_ContactRow(icon: Icons.email_outlined, label: email));
    }
    if (phone.isNotEmpty) {
      rows.add(_ContactRow(icon: Icons.phone, label: phone));
    }
    if (address.isNotEmpty) {
      rows.add(_ContactRow(icon: Icons.location_on_outlined, label: address));
    }

    final linkEntries = socialLinks.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...rows,
        if (linkEntries.isNotEmpty) ...[
          if (rows.isNotEmpty) const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: linkEntries.map((e) {
              final name = e.key;
              return Chip(
                label: Text(name),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ContactRow({
    required this.icon,
    this.label = '',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
