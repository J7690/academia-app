import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/student_university_site_provider.dart';
import '../../providers/student_applications_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart';
import 'mini_site_media_viewer_screen.dart';

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
          final banners = (site['banners'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

          final name = university['name']?.toString() ?? '';
          final city = university['city']?.toString() ?? '';
          final country = university['country']?.toString() ?? '';
          final description = university['description']?.toString() ?? '';
          final logoUrl = university['logo_url']?.toString() ?? '';

          final heroTitle = (config['hero_title']?.toString() ?? '').trim();
          final heroSubtitle = (config['hero_subtitle']?.toString() ?? '').trim();

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

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroSection(
                  title: heroTitle.isNotEmpty
                      ? heroTitle
                      : (name.isNotEmpty ? name : (widget.universityName ?? '')),
                  city: city,
                  country: country,
                  subtitle: heroSubtitle.isNotEmpty ? heroSubtitle : description,
                  logoUrl: logoUrl,
                ),
                if (topBanners.isNotEmpty)
                  _SectionContainer(
                    title: 'En vedette',
                    child: _BannerCarousel(banners: topBanners, media: media),
                  ),
                if (aboutBlocks.isNotEmpty)
                  _SectionContainer(
                    title: 'À propos de l\'université',
                    child: _BlocksList(blocks: aboutBlocks),
                  ),
                if (highlightedPrograms.isNotEmpty)
                  _SectionContainer(
                    title: 'Programmes phares',
                    child: _ProgramsGrid(programs: highlightedPrograms),
                  ),
                if (otherPrograms.isNotEmpty)
                  _SectionContainer(
                    title: 'Tous les programmes proposés',
                    child: _ProgramsGrid(programs: otherPrograms),
                  ),
                if (middleBanners.isNotEmpty)
                  _SectionContainer(
                    title: 'Informations clés',
                    child: _BannerStrips(banners: middleBanners, media: media),
                  ),
                if (media.isNotEmpty)
                  _SectionContainer(
                    title: 'Vidéos et supports',
                    child: _MediaStrip(media: media),
                  ),
                if (otherBlocks.isNotEmpty)
                  _SectionContainer(
                    title: 'Informations complémentaires',
                    child: _BlocksList(blocks: otherBlocks),
                  ),
                if (bottomBanners.isNotEmpty)
                  _SectionContainer(
                    title: 'À ne pas manquer',
                    child: _BannerStrips(banners: bottomBanners, media: media),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
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
                      final storagePath =
                          associatedMedia!['storage_path']?.toString() ?? '';
                      if (storagePath.isEmpty) {
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
                            media: associatedMedia!,
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
                  final storagePath =
                      associatedMedia!['storage_path']?.toString() ?? '';
                  if (storagePath.isEmpty) {
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
                        media: associatedMedia!,
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

  const _HeroSection({
    required this.title,
    required this.city,
    required this.country,
    required this.subtitle,
    required this.logoUrl,
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

  const _ProgramsGrid({required this.programs});

  @override
  Widget build(BuildContext context) {
    if (programs.isEmpty) {
      return const SizedBox.shrink();
    }
    final isWide = MediaQuery.of(context).size.width > 700;
    if (isWide) {
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: programs.map((program) {
          return SizedBox(
            width: 320,
            child: _ProgramCard(program: program),
          );
        }).toList(),
      );
    }
    return Column(
      children: programs.map((program) {
        return _ProgramCard(program: program);
      }).toList(),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final Map<String, dynamic> program;

  const _ProgramCard({required this.program});

  @override
  Widget build(BuildContext context) {
    final title = program['title']?.toString() ?? '';
    final degree = program['degree_level']?.toString() ?? '';
    final mode = program['mode']?.toString() ?? '';
    final programId = program['id']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: programId == null
                    ? null
                    : () async {
                        final applicationsProvider =
                            context.read<StudentApplicationsProvider>();
                        final success = await applicationsProvider.createApplication(
                          programId: programId,
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
              ),
            ),
          ],
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

          return SizedBox(
            width: 260,
            child: InkWell(
              onTap: storagePath.isEmpty
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
