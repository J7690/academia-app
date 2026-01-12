import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_universities_provider.dart';
import '../../providers/admin_university_site_provider.dart';
import '../../providers/admin_programs_provider.dart';
import '../../providers/admin_courses_provider.dart';
import '../../widgets/mini_site_hero_video.dart';
import 'admin_programs_screen.dart';

class AdminUniversitySitesScreen extends StatefulWidget {
  const AdminUniversitySitesScreen({super.key});

  @override
  State<AdminUniversitySitesScreen> createState() => _AdminUniversitySitesScreenState();
}

class _AdminUniversitySitesScreenState extends State<AdminUniversitySitesScreen> {
  String? _selectedUniversityId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<AdminUniversitiesProvider>().loadUniversities();
      } catch (_) {}
      try {
        context.read<AdminProgramsProvider>().loadPrograms();
      } catch (_) {}
      try {
        context.read<AdminCoursesProvider>().loadCourses();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 260,
          child: Consumer<AdminUniversitiesProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading && provider.universities.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (provider.error != null) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(provider.error!),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: provider.loadUniversities,
                        child: const Text('Recharger les universités'),
                      ),
                    ],
                  ),
                );
              }

              final universities = provider.universities;
              if (universities.isEmpty) {
                return const Center(
                  child: Text('Aucune université partenaire.'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: universities.length,
                itemBuilder: (context, index) {
                  final uni = universities[index];
                  final id = uni['id']?.toString();
                  final selected = id != null && id == _selectedUniversityId;

                  return Card(
                    elevation: 0,
                    color: selected ? const Color(0xFFE5F9E7) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(uni['name']?.toString() ?? ''),
                      subtitle: Text(
                        '${uni['city'] ?? ''}, ${uni['country'] ?? ''}',
                      ),
                      onTap: () {
                        if (id == null) return;
                        setState(() {
                          _selectedUniversityId = id;
                        });
                        context
                            .read<AdminUniversitySiteProvider>()
                            .loadSiteForUniversity(id);
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _AdminUniversitySitePanel(selectedUniversityId: _selectedUniversityId),
        ),
      ],
    );
  }
}

class _AdminUniversitySitePanel extends StatelessWidget {
  final String? selectedUniversityId;

  const _AdminUniversitySitePanel({required this.selectedUniversityId});

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminUniversitySiteProvider>(
      builder: (context, provider, child) {
        if (selectedUniversityId == null) {
          return const Center(
            child: Text('Sélectionnez une université pour gérer son mini-site.'),
          );
        }

        if (provider.isLoading && provider.university == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null && provider.university == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(provider.error!),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      final id = provider.currentUniversityId ?? selectedUniversityId;
                      if (id != null) {
                        provider.loadSiteForUniversity(id);
                      }
                    },
                    child: const Text('Recharger le mini-site'),
                  ),
                ],
              ),
            ),
          );
        }

        final university = provider.university;
        final blocks = provider.blocks;
        final media = provider.media;
        final events = provider.events;
        final news = provider.news;
        final staff = provider.staff;

        if (university == null) {
          return const Center(
            child: Text('Mini-site non configuré pour cette université.'),
          );
        }

        final name = university['name']?.toString() ?? '';
        final city = university['city']?.toString() ?? '';
        final country = university['country']?.toString() ?? '';
        final description = university['description']?.toString() ?? '';
        final websiteUrl = university['website_url']?.toString() ?? '';

        return DefaultTabController(
          length: 6,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (city.isNotEmpty || country.isNotEmpty)
                            Text(
                              [city, country].where((e) => e.isNotEmpty).join(', '),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          if (websiteUrl.isNotEmpty)
                            Text(
                              websiteUrl,
                              style: const TextStyle(fontSize: 12, color: Colors.blue),
                            ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(description),
                          ],
                        ],
                      ),
                    ),
                    if (provider.error != null)
                      Expanded(
                        child: Text(
                          provider.error!,
                          textAlign: TextAlign.end,
                        ),
                      ),
                  ],
                ),
              ),
              TabBar(
                isScrollable: true,
                indicator: BoxDecoration(
                  color: const Color(0xFF1EA75C),
                  borderRadius: BorderRadius.circular(999),
                ),
                indicatorPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black87,
                tabs: const [
                  Tab(text: 'Aperçu'),
                  Tab(text: 'Contenus'),
                  Tab(text: 'Médias'),
                  Tab(text: 'Événements'),
                  Tab(text: 'Actualités'),
                  Tab(text: 'Équipe'),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  children: [
                    const _AdminUniversitySitePreview(),
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Row(
                          children: [
                            Text(
                              'Blocs éditoriaux',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () =>
                                  _showAdminEditBlockDialog(context, provider),
                              icon: const Icon(Icons.add),
                              label: const Text('Ajouter un bloc'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (blocks.isEmpty)
                          const Text('Aucun bloc éditorial.')
                        else
                          ...blocks.map((b) {
                            final title = b['title']?.toString() ?? '';
                            final key = b['key']?.toString() ?? '';
                            final content = b['content']?.toString() ?? '';
                            final isActive = b['is_active'] != false;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title.isNotEmpty ? title : key,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Chip(
                                          label: Text(
                                              isActive ? 'Actif' : 'Inactif'),
                                        ),
                                      ],
                                    ),
                                    if (content.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        content,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () =>
                                              _showAdminEditBlockDialog(
                                            context,
                                            provider,
                                            block: b,
                                          ),
                                          icon: const Icon(Icons.edit),
                                          label: const Text('Modifier'),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          onPressed: () async {
                                            final id = b['id']?.toString();
                                            if (id == null) return;
                                            final ok =
                                                await provider.deleteBlock(id);
                                            if (!context.mounted) return;
                                            if (!ok) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    provider.error ??
                                                        'Erreur lors de la suppression du bloc.',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.delete_outline),
                                          label: const Text('Supprimer'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Text(
                              'Médias',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () =>
                                  _showAdminEditMediaDialog(context, provider),
                              label: const Text('Ajouter un média'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (media.isEmpty)
                          const Text('Aucun média configuré.')
                        else
                          ...media.map((m) {
                            final title = m['title']?.toString() ?? '';
                            final description = m['description']?.toString() ?? '';
                            final mediaType = m['media_type']?.toString() ?? '';
                            final isActive = m['is_active'] != false;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title.isNotEmpty
                                                ? title
                                                : 'Média',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Chip(
                                          label: Text(mediaType.isNotEmpty
                                              ? mediaType
                                              : 'Type'),
                                        ),
                                        const SizedBox(width: 8),
                                        Chip(
                                          label: Text(
                                              isActive ? 'Actif' : 'Inactif'),
                                        ),
                                      ],
                                    ),
                                    if (description.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        description,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () =>
                                              _showAdminEditMediaDialog(
                                            context,
                                            provider,
                                            media: m,
                                          ),
                                          icon: const Icon(Icons.edit),
                                          label: const Text('Modifier'),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          onPressed: () async {
                                            final id = m['id']?.toString();
                                            if (id == null) return;
                                            final ok =
                                                await provider.deleteMedia(id);
                                            if (!context.mounted) return;
                                            if (!ok) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    provider.error ??
                                                        'Erreur lors de la suppression du média.',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.delete_outline),
                                          label: const Text('Supprimer'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Text(
                              'Événements du mini-site',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () =>
                                  _showAdminEditEventDialog(context, provider),
                              icon: const Icon(Icons.add),
                              label: const Text('Ajouter un événement'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (events.isEmpty)
                          const Text('Aucun événement configuré.')
                        else
                          ...events.map((e) {
                            final title = e['title']?.toString() ?? '';
                            final description =
                                e['description']?.toString() ?? '';
                            final type = e['event_type']?.toString() ?? '';
                            final location = e['location']?.toString() ?? '';
                            final startAt = e['start_at']?.toString() ?? '';
                            final endAt = e['end_at']?.toString() ?? '';
                            final isHighlighted = e['is_highlighted'] == true;
                            final isActive = e['is_active'] != false;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (type.isNotEmpty)
                                          Chip(label: Text(type)),
                                        const SizedBox(width: 8),
                                        Chip(
                                            label: Text(
                                                isActive ? 'Actif' : 'Inactif')),
                                        const SizedBox(width: 8),
                                        if (isHighlighted)
                                          const Chip(
                                            label: Text('En vedette'),
                                          ),
                                      ],
                                    ),
                                    if (location.isNotEmpty ||
                                        startAt.isNotEmpty ||
                                        endAt.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        [
                                          if (location.isNotEmpty) location,
                                          if (startAt.isNotEmpty)
                                            'Début: $startAt',
                                          if (endAt.isNotEmpty) 'Fin: $endAt',
                                        ].join(' · '),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    if (description.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        description,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () =>
                                              _showAdminEditEventDialog(
                                            context,
                                            provider,
                                            event: e,
                                          ),
                                          icon: const Icon(Icons.edit),
                                          label: const Text('Modifier'),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          onPressed: () async {
                                            final id = e['id']?.toString();
                                            if (id == null) return;
                                            final ok =
                                                await provider.deleteEvent(id);
                                            if (!context.mounted) return;
                                            if (!ok) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    provider.error ??
                                                        'Erreur lors de la suppression de l\'événement.',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.delete_outline),
                                          label: const Text('Supprimer'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Text(
                              'Actualités',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () =>
                                  _showAdminEditNewsDialog(context, provider),
                              icon: const Icon(Icons.add),
                              label: const Text('Ajouter une actualité'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (news.isEmpty)
                          const Text('Aucune actualité configurée.')
                        else
                          ...news.map((n) {
                            final title = n['title']?.toString() ?? '';
                            final summary = n['summary']?.toString() ?? '';
                            final content = n['content']?.toString() ?? '';
                            final slug = n['slug']?.toString() ?? '';
                            final publishedAt =
                                n['published_at']?.toString() ?? '';
                            final isActive = n['is_active'] != false;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Chip(
                                            label: Text(isActive
                                                ? 'Publiée'
                                                : 'Masquée')),
                                      ],
                                    ),
                                    if (slug.isNotEmpty ||
                                        publishedAt.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text([
                                        if (slug.isNotEmpty) 'Slug: $slug',
                                        if (publishedAt.isNotEmpty)
                                          'Publié le: $publishedAt',
                                      ].join(' · ')),
                                    ],
                                    if (summary.isNotEmpty ||
                                        content.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        summary.isNotEmpty
                                            ? summary
                                            : content,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () =>
                                              _showAdminEditNewsDialog(
                                            context,
                                            provider,
                                            news: n,
                                          ),
                                          icon: const Icon(Icons.edit),
                                          label: const Text('Modifier'),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          onPressed: () async {
                                            final id = n['id']?.toString();
                                            if (id == null) return;
                                            final ok =
                                                await provider.deleteNews(id);
                                            if (!context.mounted) return;
                                            if (!ok) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    provider.error ??
                                                        'Erreur lors de la suppression de l\'actualité.',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.delete_outline),
                                          label: const Text('Supprimer'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Text(
                              'Équipe',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () =>
                                  _showAdminEditStaffDialog(context, provider),
                              icon: const Icon(Icons.add),
                              label: const Text("Ajouter un membre de l'équipe"),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (staff.isEmpty)
                          const Text("Aucun membre d'équipe configuré.")
                        else
                          ...staff.map((s) {
                            final fullName = s['full_name']?.toString() ?? '';
                            final role = s['role']?.toString() ?? '';
                            final bio = s['bio']?.toString() ?? '';
                            final sortOrder = s['sort_order']?.toString() ?? '';
                            final isActive = s['is_active'] != false;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            fullName,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (role.isNotEmpty)
                                          Chip(label: Text(role)),
                                        const SizedBox(width: 8),
                                        Chip(
                                            label: Text(
                                                isActive ? 'Actif' : 'Inactif')),
                                        if (sortOrder.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Chip(label: Text('Ordre $sortOrder')),
                                        ],
                                      ],
                                    ),
                                    if (bio.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        bio,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () =>
                                              _showAdminEditStaffDialog(
                                            context,
                                            provider,
                                            staff: s,
                                          ),
                                          icon: const Icon(Icons.edit),
                                          label: const Text('Modifier'),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          onPressed: () async {
                                            final id = s['id']?.toString();
                                            if (id == null) return;
                                            final ok =
                                                await provider.deleteStaff(id);
                                            if (!context.mounted) return;
                                            if (!ok) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    provider.error ??
                                                        "Erreur lors de la suppression du membre de l'équipe.",
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.delete_outline),
                                          label: const Text('Supprimer'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                    _AdminSiteMediaTab(provider: provider),
                    _AdminSiteEventsTab(provider: provider),
                    _AdminSiteNewsTab(provider: provider),
                    _AdminSiteStaffTab(provider: provider),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminUniversitySitePreview extends StatelessWidget {
  const _AdminUniversitySitePreview();

  @override
  Widget build(BuildContext context) {
    return Consumer3<
        AdminUniversitySiteProvider, AdminProgramsProvider, AdminCoursesProvider>(
      builder: (context, siteProvider, programsProvider, coursesProvider, child) {
        if (siteProvider.isLoading && siteProvider.university == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final university = siteProvider.university;
        if (university == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Mini-site non configuré pour cette université.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final blocks = siteProvider.blocks;
        final media = siteProvider.media;
        final events = siteProvider.events;
        final news = siteProvider.news;
        final staff = siteProvider.staff;

        final universityId = siteProvider.currentUniversityId;
        final allPrograms = programsProvider.programs;
        final allCourses = coursesProvider.courses;

        final universityPrograms = universityId == null
            ? <Map<String, dynamic>>[]
            : allPrograms
                .where((p) => p['university_id']?.toString() == universityId)
                .toList(growable: false);

        final highlightedPrograms = universityPrograms
            .where((p) => p['highlighted'] == true)
            .toList(growable: false);
        final otherPrograms = universityPrograms
            .where((p) => p['highlighted'] != true)
            .toList(growable: false);

        final programIds = universityPrograms
            .map((p) => p['id']?.toString())
            .whereType<String>()
            .toSet();
        final universityCourses = allCourses
            .where((c) {
              final pid = c['program_id']?.toString();
              return pid != null && programIds.contains(pid);
            })
            .toList(growable: false);

        final name = university['name']?.toString() ?? '';
        final city = university['city']?.toString() ?? '';
        final country = university['country']?.toString() ?? '';
        final description = university['description']?.toString() ?? '';
        final websiteUrl = university['website_url']?.toString() ?? '';
        final logoUrl = university['logo_url']?.toString() ?? '';

        final locationText = [city, country]
            .where((e) => e.trim().isNotEmpty)
            .join(', ');

        final contactEmail = university['contact_email']?.toString() ?? '';
        final contactPhone = university['contact_phone']?.toString() ?? '';
        final address = university['address']?.toString() ?? '';

        Map<String, dynamic> socialLinks = {};
        final rawSocialLinks = university['social_links'];
        if (rawSocialLinks is Map) {
          socialLinks = Map<String, dynamic>.from(rawSocialLinks);
        }

        final aboutBlocks = blocks
            .where((b) => (b['key']?.toString() ?? '').toLowerCase() == 'about')
            .toList(growable: false);
        final otherBlocks = blocks
            .where((b) => (b['key']?.toString() ?? '').toLowerCase() != 'about')
            .toList(growable: false);

        final primaryColor = Theme.of(context).colorScheme.primary;

        return Container
          (
          color: const Color(0xFFF9FAFB),
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
                                  name,
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
                                if (websiteUrl.isNotEmpty) ...[ 
                                  const SizedBox(height: 4),
                                  Text(
                                    websiteUrl,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Aperçu du mini-site',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFFE53935),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (media.isNotEmpty) ...[
                        MiniSiteHeroVideo(
                          media: media,
                          title: name,
                          location: locationText,
                          tagline: null,
                          logoUrl: logoUrl.isNotEmpty ? logoUrl : null,
                          heroPosterMediaId: null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (media.isNotEmpty) ...[
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Médias / ambiance du campus',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                DefaultTabController.of(context).animateTo(2);
                              },
                              icon: const Icon(
                                Icons.photo_library_outlined,
                                size: 16,
                              ),
                              label: const Text('Gérer les médias'),
                            ),
                          ],
                        ],
                        const SizedBox(height: 8),
                        Card(
                          color: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: primaryColor.withOpacity(0.35),
                              width: 1.4,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 4,
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.9),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    children: media.map((m) {
                                      final title = m['title']?.toString() ?? '';
                                      final mediaType =
                                          m['media_type']?.toString() ?? '';
                                      return Align(
                                        alignment: Alignment.centerLeft,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4.0),
                                          child: Wrap(
                                            spacing: 8,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.image_outlined,
                                                size: 18,
                                                color: Color(0xFF6B7280),
                                              ),
                                              Text(title.isNotEmpty
                                                  ? title
                                                  : 'Média'),
                                              if (mediaType.isNotEmpty)
                                                Chip(label: Text(mediaType)),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Présentation de l\'université',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Card(
                        color: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: primaryColor.withOpacity(0.35),
                            width: 1.4,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 4,
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.9),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
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
                                      name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (description.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(description),
                                    ],
                                    if (aboutBlocks.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: aboutBlocks.map((b) {
                                          final title =
                                              b['title']?.toString() ?? '';
                                          final content =
                                              b['content']?.toString() ?? '';
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 8.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (title.isNotEmpty)
                                                  Text(
                                                    title,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                if (content.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(content),
                                                ],
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (universityPrograms.isNotEmpty) ...[
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Programmes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                // Ouvre l'écran global de gestion des programmes
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (context) =>
                                        const AdminProgramsScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.school_outlined, size: 16),
                              label: const Text('Gérer les programmes'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Card(
                          color: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: primaryColor.withOpacity(0.35),
                              width: 1.4,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 4,
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.9),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (highlightedPrograms.isNotEmpty) ...[
                                        const Text(
                                          'Programmes phares',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        _buildProgramsList(
                                          highlightedPrograms,
                                          universityCourses,
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                      if (otherPrograms.isNotEmpty)
                                        _buildProgramsList(
                                          otherPrograms,
                                          universityCourses,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (events.isNotEmpty) ...[
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Événements',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                DefaultTabController.of(context).animateTo(3);
                              },
                              icon: const Icon(Icons.event, size: 16),
                              label: const Text('Gérer les événements'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Card(
                          color: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: primaryColor.withOpacity(0.35),
                              width: 1.4,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 4,
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.9),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    children: events.map((event) {
                                      final title =
                                          event['title']?.toString() ?? '';
                                      final location =
                                          event['location']?.toString() ?? '';
                                      final startAt =
                                          event['start_at']?.toString() ?? '';
                                      final endAt =
                                          event['end_at']?.toString() ?? '';

                                      final meta = [
                                        if (startAt.isNotEmpty)
                                          'Début: $startAt',
                                        if (endAt.isNotEmpty) 'Fin: $endAt',
                                        if (location.isNotEmpty) location,
                                      ]
                                          .where((e) => e.isNotEmpty)
                                          .join(' · ');

                                      return Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 8.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (meta.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                meta,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF6B7280),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (news.isNotEmpty) ...[
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Actualités',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                DefaultTabController.of(context).animateTo(4);
                              },
                              icon: const Icon(Icons.article_outlined, size: 16),
                              label: const Text('Gérer les actualités'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Card(
                          color: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: primaryColor.withOpacity(0.35),
                              width: 1.4,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 4,
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.9),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    children: news.map((item) {
                                      final title =
                                          item['title']?.toString() ?? '';
                                      final summary =
                                          item['summary']?.toString() ?? '';
                                      final publishedAt =
                                          item['published_at']?.toString() ?? '';

                                      return Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 8.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (publishedAt.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                publishedAt,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF6B7280),
                                                ),
                                              ),
                                            ],
                                            if (summary.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                summary,
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
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
                          color: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: primaryColor.withOpacity(0.35),
                              width: 1.4,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 4,
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.9),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: otherBlocks.map((b) {
                                      final title =
                                          b['title']?.toString() ?? '';
                                      final content =
                                          b['content']?.toString() ?? '';
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 8.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (title.isNotEmpty)
                                              Text(
                                                title,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            if (content.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(content),
                                            ],
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (staff.isNotEmpty) ...[
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Équipe',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                DefaultTabController.of(context).animateTo(5);
                              },
                              icon: const Icon(Icons.group_outlined, size: 16),
                              label: const Text('Gérer l\'équipe'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Card(
                          color: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: primaryColor.withOpacity(0.35),
                              width: 1.4,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 4,
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.9),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    children: staff.map((s) {
                                      final fullName =
                                          s['full_name']?.toString() ?? '';
                                      final role = s['role']?.toString() ?? '';
                                      final bio = s['bio']?.toString() ?? '';

                                      return Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 8.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              fullName,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (role.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                role,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF6B7280),
                                                ),
                                              ),
                                            ],
                                            if (bio.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                bio,
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (contactEmail.isNotEmpty ||
                          contactPhone.isNotEmpty ||
                          address.isNotEmpty ||
                          socialLinks.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Contact & informations',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Card(
                          color: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: primaryColor.withOpacity(0.35),
                              width: 1.4,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 4,
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.9),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (address.isNotEmpty) ...[
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(
                                              Icons.location_on_outlined,
                                              size: 16,
                                              color: Color(0xFF006D3C),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(address)),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      if (contactEmail.isNotEmpty) ...[
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.mail_outline,
                                              size: 16,
                                              color: Color(0xFF006D3C),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(contactEmail),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                      ],
                                      if (contactPhone.isNotEmpty) ...[
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.phone_outlined,
                                              size: 16,
                                              color: Color(0xFF006D3C),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(contactPhone),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      if (socialLinks.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          children:
                                              socialLinks.entries.map((entry) {
                                            final platform =
                                                entry.key.toString();
                                            return Chip(
                                              avatar: const Icon(
                                                Icons.link,
                                                size: 16,
                                              ),
                                              label: Text(platform),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
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
    );
  }

  Widget _buildProgramsList(
    List<Map<String, dynamic>> programs,
    List<Map<String, dynamic>> courses,
  ) {
    return Column(
      children: programs.map((program) {
        final title = program['title']?.toString() ?? '';
        final degree = program['degree_level']?.toString() ?? '';
        final mode = program['mode']?.toString() ?? '';
        final isActive = program['is_active'] == true;
        final programId = program['id']?.toString();
        final programCourses = programId == null
            ? <Map<String, dynamic>>[]
            : courses
                .where((c) => c['program_id']?.toString() == programId)
                .toList(growable: false);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
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
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (degree.isNotEmpty) Chip(label: Text(degree)),
                  if (mode.isNotEmpty) Chip(label: Text(mode)),
                  Chip(label: Text(isActive ? 'Actif' : 'Inactif')),
                  if (programCourses.isNotEmpty)
                    Chip(label: Text('${programCourses.length} cours')),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _AdminSiteMediaTab extends StatelessWidget {
  final AdminUniversitySiteProvider provider;

  const _AdminSiteMediaTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final media = provider.media;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(
              'Médias',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () =>
                  _showAdminEditMediaDialog(context, provider),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un média'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (media.isEmpty)
          const Text('Aucun média configuré.')
        else
          ...media.map((m) {
            final title = m['title']?.toString() ?? '';
            final description = m['description']?.toString() ?? '';
            final url = m['url']?.toString() ?? '';
            final mediaType = m['media_type']?.toString() ?? '';
            final isActive = m['is_active'] != false;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title.isNotEmpty ? title : 'Média',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            mediaType.isNotEmpty ? mediaType : 'Type',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(isActive ? 'Actif' : 'Inactif'),
                        ),
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (url.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        url,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              _showAdminEditMediaDialog(
                            context,
                            provider,
                            media: m,
                          ),
                          icon: const Icon(Icons.edit),
                          label: const Text('Modifier'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () async {
                            final id = m['id']?.toString();
                            if (id == null) return;
                            final ok = await provider.deleteMedia(id);
                            if (!context.mounted) return;
                            if (!ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    provider.error ??
                                        'Erreur lors de la suppression du média.',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Supprimer'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _AdminSiteEventsTab extends StatelessWidget {
  final AdminUniversitySiteProvider provider;

  const _AdminSiteEventsTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final events = provider.events;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(
              'Événements du mini-site',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () =>
                  _showAdminEditEventDialog(context, provider),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un événement'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (events.isEmpty)
          const Text('Aucun événement configuré.')
        else
          ...events.map((e) {
            final title = e['title']?.toString() ?? '';
            final description = e['description']?.toString() ?? '';
            final type = e['event_type']?.toString() ?? '';
            final location = e['location']?.toString() ?? '';
            final startAt = e['start_at']?.toString() ?? '';
            final endAt = e['end_at']?.toString() ?? '';
            final isHighlighted = e['is_highlighted'] == true;
            final isActive = e['is_active'] != false;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (type.isNotEmpty) Chip(label: Text(type)),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(isActive ? 'Actif' : 'Inactif'),
                        ),
                        const SizedBox(width: 8),
                        if (isHighlighted)
                          const Chip(
                            label: Text('En vedette'),
                          ),
                      ],
                    ),
                    if (location.isNotEmpty ||
                        startAt.isNotEmpty ||
                        endAt.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (location.isNotEmpty) location,
                          if (startAt.isNotEmpty) 'Début: $startAt',
                          if (endAt.isNotEmpty) 'Fin: $endAt',
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              _showAdminEditEventDialog(
                            context,
                            provider,
                            event: e,
                          ),
                          icon: const Icon(Icons.edit),
                          label: const Text('Modifier'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () async {
                            final id = e['id']?.toString();
                            if (id == null) return;
                            final ok = await provider.deleteEvent(id);
                            if (!context.mounted) return;
                            if (!ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    provider.error ??
                                        'Erreur lors de la suppression de l\'événement.',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Supprimer'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _AdminSiteNewsTab extends StatelessWidget {
  final AdminUniversitySiteProvider provider;

  const _AdminSiteNewsTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final news = provider.news;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(
              'Actualités',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () =>
                  _showAdminEditNewsDialog(context, provider),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une actualité'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (news.isEmpty)
          const Text('Aucune actualité configurée.')
        else
          ...news.map((n) {
            final title = n['title']?.toString() ?? '';
            final summary = n['summary']?.toString() ?? '';
            final content = n['content']?.toString() ?? '';
            final slug = n['slug']?.toString() ?? '';
            final publishedAt = n['published_at']?.toString() ?? '';
            final isActive = n['is_active'] != false;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            isActive ? 'Publiée' : 'Masquée',
                          ),
                        ),
                      ],
                    ),
                    if (slug.isNotEmpty ||
                        publishedAt.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (slug.isNotEmpty) 'Slug: $slug',
                          if (publishedAt.isNotEmpty)
                            'Publié le: $publishedAt',
                        ].join(' · '),
                      ),
                    ],
                    if (summary.isNotEmpty ||
                        content.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        summary.isNotEmpty ? summary : content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              _showAdminEditNewsDialog(
                            context,
                            provider,
                            news: n,
                          ),
                          icon: const Icon(Icons.edit),
                          label: const Text('Modifier'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () async {
                            final id = n['id']?.toString();
                            if (id == null) return;
                            final ok = await provider.deleteNews(id);
                            if (!context.mounted) return;
                            if (!ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    provider.error ??
                                        'Erreur lors de la suppression de l\'actualité.',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Supprimer'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _AdminSiteStaffTab extends StatelessWidget {
  final AdminUniversitySiteProvider provider;

  const _AdminSiteStaffTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final staff = provider.staff;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(
              'Équipe',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () =>
                  _showAdminEditStaffDialog(context, provider),
              icon: const Icon(Icons.add),
              label:
                  const Text("Ajouter un membre de l'équipe"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (staff.isEmpty)
          const Text("Aucun membre d'équipe configuré.")
        else
          ...staff.map((s) {
            final fullName = s['full_name']?.toString() ?? '';
            final role = s['role']?.toString() ?? '';
            final bio = s['bio']?.toString() ?? '';
            final sortOrder = s['sort_order']?.toString() ?? '';
            final isActive = s['is_active'] != false;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            fullName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (role.isNotEmpty) Chip(label: Text(role)),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(isActive ? 'Actif' : 'Inactif'),
                        ),
                        if (sortOrder.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Chip(label: Text('Ordre $sortOrder')),
                        ],
                      ],
                    ),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        bio,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              _showAdminEditStaffDialog(
                            context,
                            provider,
                            staff: s,
                          ),
                          icon: const Icon(Icons.edit),
                          label: const Text('Modifier'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () async {
                            final id = s['id']?.toString();
                            if (id == null) return;
                            final ok = await provider.deleteStaff(id);
                            if (!context.mounted) return;
                            if (!ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    provider.error ??
                                        "Erreur lors de la suppression du membre de l'équipe.",
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Supprimer'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

Future<void> _showAdminEditBlockDialog(
  BuildContext context,
  AdminUniversitySiteProvider provider, {
  Map<String, dynamic>? block,
}) async {
  final keyController = TextEditingController(text: block?['key']?.toString() ?? '');
  final titleController = TextEditingController(text: block?['title']?.toString() ?? '');
  final contentController = TextEditingController(text: block?['content']?.toString() ?? '');

  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(block == null ? 'Ajouter un bloc' : 'Modifier le bloc'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keyController,
                decoration: const InputDecoration(
                  labelText: 'Clé (about, admission, campus...)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Titre',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: contentController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Contenu',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              final key = keyController.text.trim();
              final title = titleController.text.trim();
              final content = contentController.text.trim();

              if (key.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('La clé du bloc est obligatoire.'),
                  ),
                );
                return;
              }

              final ok = await provider.upsertBlock(
                blockId: block?['id']?.toString(),
                key: key,
                title: title.isNotEmpty ? title : null,
                content: content.isNotEmpty ? content : null,
              );
              if (!context.mounted) return;
              if (ok) {
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      provider.error ?? 'Erreur lors de la sauvegarde du bloc.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      );
    },
  );
}

Future<void> _showAdminEditEventDialog(
  BuildContext context,
  AdminUniversitySiteProvider provider, {
  Map<String, dynamic>? event,
}) async {
  final titleController = TextEditingController(text: event?['title']?.toString() ?? '');
  final descriptionController =
      TextEditingController(text: event?['description']?.toString() ?? '');
  final typeController = TextEditingController(text: event?['event_type']?.toString() ?? '');
  final locationController = TextEditingController(text: event?['location']?.toString() ?? '');
  final startAtController =
      TextEditingController(text: event?['start_at']?.toString() ?? '');
  final endAtController = TextEditingController(text: event?['end_at']?.toString() ?? '');
  bool isHighlighted = event?['is_highlighted'] == true;
  bool isActive = event?['is_active'] != false;

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(event == null ? 'Ajouter un événement' : 'Modifier l\'événement'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Titre de l\'événement *',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: typeController,
                    decoration: const InputDecoration(
                      labelText: 'Type (portes ouvertes, webinaire...)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Lieu (présentiel / en ligne...)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: startAtController,
                    decoration: const InputDecoration(
                      labelText: 'Début (ISO 8601, optionnel)',
                      hintText: '2025-03-15T09:00:00Z',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: endAtController,
                    decoration: const InputDecoration(
                      labelText: 'Fin (ISO 8601, optionnel)',
                      hintText: '2025-03-15T12:00:00Z',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: isHighlighted,
                        onChanged: (value) {
                          setState(() {
                            isHighlighted = value ?? false;
                          });
                        },
                      ),
                      const Text('Mettre en avant'),
                    ],
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: isActive,
                        onChanged: (value) {
                          setState(() {
                            isActive = value ?? true;
                          });
                        },
                      ),
                      const Text('Événement actif'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  final description = descriptionController.text.trim();
                  final type = typeController.text.trim();
                  final location = locationController.text.trim();
                  final startText = startAtController.text.trim();
                  final endText = endAtController.text.trim();

                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Le titre de l\'événement est obligatoire.'),
                      ),
                    );
                    return;
                  }

                  DateTime? startAt;
                  DateTime? endAt;

                  if (startText.isNotEmpty) {
                    startAt = DateTime.tryParse(startText);
                    if (startAt == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Format de date de début invalide.'),
                        ),
                      );
                      return;
                    }
                  }

                  if (endText.isNotEmpty) {
                    endAt = DateTime.tryParse(endText);
                    if (endAt == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Format de date de fin invalide.'),
                        ),
                      );
                      return;
                    }
                  }

                  final ok = await provider.upsertEvent(
                    eventId: event?['id']?.toString(),
                    title: title,
                    description: description.isNotEmpty ? description : null,
                    eventType: type.isNotEmpty ? type : null,
                    startAt: startAt,
                    endAt: endAt,
                    location: location.isNotEmpty ? location : null,
                    isHighlighted: isHighlighted,
                    isActive: isActive,
                  );
                  if (!context.mounted) return;
                  if (ok) {
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          provider.error ??
                              "Erreur lors de la sauvegarde de l'événement (admin).",
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _showAdminEditNewsDialog(
  BuildContext context,
  AdminUniversitySiteProvider provider, {
  Map<String, dynamic>? news,
}) async {
  final titleController = TextEditingController(text: news?['title']?.toString() ?? '');
  final slugController = TextEditingController(text: news?['slug']?.toString() ?? '');
  final summaryController =
      TextEditingController(text: news?['summary']?.toString() ?? '');
  final contentController =
      TextEditingController(text: news?['content']?.toString() ?? '');
  final publishedAtController =
      TextEditingController(text: news?['published_at']?.toString() ?? '');
  final heroMediaIdRaw = news?['hero_media_id']?.toString();
  String? selectedHeroMediaId = heroMediaIdRaw?.isNotEmpty == true ? heroMediaIdRaw : null;
  bool isActive = news?['is_active'] != false;

  await showDialog<void>(
    context: context,
    builder: (context) {
      final mediaItems = provider.media;

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(news == null ? 'Ajouter une actualité' : 'Modifier l\'actualité'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Titre de l\'actualité *',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: slugController,
                    decoration: const InputDecoration(
                      labelText: 'Slug (optionnel, unique)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: summaryController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Résumé (court)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: contentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Contenu (détail)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: publishedAtController,
                    decoration: const InputDecoration(
                      labelText: 'Date de publication (ISO 8601, optionnel)',
                      hintText: '2025-03-15T10:00:00Z',
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (mediaItems.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: selectedHeroMediaId != null &&
                              mediaItems.any((m) => m['id']?.toString() == selectedHeroMediaId)
                          ? selectedHeroMediaId
                          : null,
                      items: mediaItems
                          .map((m) {
                            final id = m['id']?.toString();
                            if (id == null) return null;
                            final title = m['title']?.toString() ?? '';
                            final type = m['media_type']?.toString() ?? '';
                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text(
                                [title, type].where((e) => e.isNotEmpty).join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          })
                          .whereType<DropdownMenuItem<String>>()
                          .toList(),
                      decoration: const InputDecoration(
                        labelText: 'Média hero (optionnel)',
                      ),
                      onChanged: (value) {
                        setState(() {
                          selectedHeroMediaId = value;
                        });
                      },
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: isActive,
                        onChanged: (value) {
                          setState(() {
                            isActive = value ?? true;
                          });
                        },
                      ),
                      const Text('Actualité publiée'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  final slug = slugController.text.trim();
                  final summary = summaryController.text.trim();
                  final content = contentController.text.trim();
                  final publishedText = publishedAtController.text.trim();

                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Le titre de l\'actualité est obligatoire.'),
                      ),
                    );
                    return;
                  }

                  DateTime? publishedAt;
                  if (publishedText.isNotEmpty) {
                    publishedAt = DateTime.tryParse(publishedText);
                    if (publishedAt == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Format de date de publication invalide.'),
                        ),
                      );
                      return;
                    }
                  }

                  final ok = await provider.upsertNews(
                    newsId: news?['id']?.toString(),
                    title: title,
                    slug: slug.isNotEmpty ? slug : null,
                    summary: summary.isNotEmpty ? summary : null,
                    content: content.isNotEmpty ? content : null,
                    publishedAt: publishedAt,
                    heroMediaId: selectedHeroMediaId,
                    isActive: isActive,
                  );
                  if (!context.mounted) return;
                  if (ok) {
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          provider.error ??
                              "Erreur lors de la sauvegarde de l'actualité (admin).",
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _showAdminEditStaffDialog(
  BuildContext context,
  AdminUniversitySiteProvider provider, {
  Map<String, dynamic>? staff,
}) async {
  final fullNameController =
      TextEditingController(text: staff?['full_name']?.toString() ?? '');
  final roleController = TextEditingController(text: staff?['role']?.toString() ?? '');
  final bioController = TextEditingController(text: staff?['bio']?.toString() ?? '');
  final emailController = TextEditingController(text: staff?['email']?.toString() ?? '');
  final phoneController = TextEditingController(text: staff?['phone']?.toString() ?? '');
  final sortOrderController =
      TextEditingController(text: staff?['sort_order']?.toString() ?? '');
  final photoMediaIdRaw = staff?['photo_media_id']?.toString();
  String? selectedPhotoMediaId =
      photoMediaIdRaw?.isNotEmpty == true ? photoMediaIdRaw : null;
  bool isActive = staff?['is_active'] != false;

  await showDialog<void>(
    context: context,
    builder: (context) {
      final mediaItems = provider.media;

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
                staff == null ? "Ajouter un membre de l'équipe" : "Modifier le membre de l'équipe"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom complet *',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: roleController,
                    decoration: const InputDecoration(
                      labelText: 'Rôle / fonction',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: bioController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Bio courte',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email (optionnel)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone (optionnel)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: sortOrderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Ordre d'affichage",
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (mediaItems.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: selectedPhotoMediaId != null &&
                              mediaItems.any((m) => m['id']?.toString() == selectedPhotoMediaId)
                          ? selectedPhotoMediaId
                          : null,
                      items: mediaItems
                          .map((m) {
                            final id = m['id']?.toString();
                            if (id == null) return null;
                            final title = m['title']?.toString() ?? '';
                            final type = m['media_type']?.toString() ?? '';
                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text(
                                [title, type].where((e) => e.isNotEmpty).join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          })
                          .whereType<DropdownMenuItem<String>>()
                          .toList(),
                      decoration: const InputDecoration(
                        labelText: 'Média photo (optionnel)',
                      ),
                      onChanged: (value) {
                        setState(() {
                          selectedPhotoMediaId = value;
                        });
                      },
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: isActive,
                        onChanged: (value) {
                          setState(() {
                            isActive = value ?? true;
                          });
                        },
                      ),
                      const Text('Membre actif'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () async {
                  final fullName = fullNameController.text.trim();
                  final role = roleController.text.trim();
                  final bio = bioController.text.trim();
                  final email = emailController.text.trim();
                  final phone = phoneController.text.trim();
                  final sortText = sortOrderController.text.trim();

                  if (fullName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Le nom complet est obligatoire.'),
                      ),
                    );
                    return;
                  }

                  final sortOrder = sortText.isEmpty ? null : int.tryParse(sortText);

                  final ok = await provider.upsertStaff(
                    staffId: staff?['id']?.toString(),
                    fullName: fullName,
                    role: role.isNotEmpty ? role : null,
                    bio: bio.isNotEmpty ? bio : null,
                    photoMediaId: selectedPhotoMediaId,
                    email: email.isNotEmpty ? email : null,
                    phone: phone.isNotEmpty ? phone : null,
                    sortOrder: sortOrder,
                    isActive: isActive,
                  );
                  if (!context.mounted) return;
                  if (ok) {
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          provider.error ??
                              "Erreur lors de la sauvegarde du membre de l'équipe (admin).",
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _showAdminEditMediaDialog(
  BuildContext context,
  AdminUniversitySiteProvider provider, {
  Map<String, dynamic>? media,
}) async {
  final rawType = media?['media_type']?.toString() ?? 'video';
  final lowerInitialType = rawType.toLowerCase();
  String initialType;
  if (lowerInitialType.contains('image')) {
    initialType = 'image';
  } else if (lowerInitialType.contains('video') ||
      lowerInitialType.contains('vidéo')) {
    initialType = 'video';
  } else if (lowerInitialType.contains('brochure')) {
    initialType = 'brochure';
  } else if (lowerInitialType.contains('pdf')) {
    initialType = 'pdf';
  } else if (lowerInitialType.contains('doc')) {
    initialType = 'doc';
  } else if (lowerInitialType.contains('autre')) {
    initialType = 'autre';
  } else {
    initialType = 'video';
  }
  final titleController = TextEditingController(
    text: media?['title']?.toString() ?? '',
  );
  final descriptionController = TextEditingController(
    text: media?['description']?.toString() ?? '',
  );
  final urlController = TextEditingController(
    text: media?['url']?.toString() ?? '',
  );
  bool isActive = media?['is_active'] != false;

  await showDialog<void>(
    context: context,
    builder: (context) {
      Uint8List? pickedBytes;
      String? pickedFileName;
      String? pickedMimeType;
      final existingStoragePath = media?['storage_path']?.toString();
      String selectedType = initialType;

      return StatefulBuilder(
        builder: (context, setState) {
          final lowerType = selectedType.toLowerCase();
          final isFileMedia = lowerType == 'video' ||
              lowerType == 'image' ||
              lowerType == 'brochure' ||
              lowerType == 'pdf' ||
              lowerType == 'doc';

          return AlertDialog(
            title: Text(media == null ? 'Ajouter un média' : 'Modifier le média'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    items: const [
                      DropdownMenuItem(
                        value: 'video',
                        child: Text('Vidéo (fichier Supabase)'),
                      ),
                      DropdownMenuItem(
                        value: 'image',
                        child: Text('Image (fichier Supabase)'),
                      ),
                      DropdownMenuItem(
                        value: 'brochure',
                        child: Text('Brochure (PDF, fichier)'),
                      ),
                      DropdownMenuItem(
                        value: 'pdf',
                        child: Text('Document PDF (fichier)'),
                      ),
                      DropdownMenuItem(
                        value: 'doc',
                        child: Text('Document (Word, fichier)'),
                      ),
                      DropdownMenuItem(
                        value: 'autre',
                        child: Text('Autre (URL externe)'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        selectedType = value;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Type de média',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Titre',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                    ),
                  ),
                  if (!isFileMedia) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: urlController,
                      decoration: const InputDecoration(
                        labelText: 'URL (pour les médias non fichiers, optionnel)',
                        hintText: 'https://...',
                      ),
                    ),
                  ],
                  if (isFileMedia) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Pour les vidéos, images, brochures et documents, utilisez uniquement '
                      "l'upload Supabase Storage ci-dessous. Les URLs externes ne sont plus autorisées.",
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: isActive,
                        onChanged: (value) {
                          setState(() {
                            isActive = value ?? true;
                          });
                        },
                      ),
                      const Text('Média actif'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              allowMultiple: false,
                              withData: true,
                              type: FileType.custom,
                              allowedExtensions: const [
                                'mp4',
                                'mov',
                                'webm',
                                'jpg',
                                'jpeg',
                                'png',
                              ],
                            );
                            if (result == null || result.files.isEmpty) {
                              return;
                            }
                            final file = result.files.first;
                            final bytes = file.bytes;
                            if (bytes == null) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Impossible de lire le contenu du fichier sélectionné.',
                                  ),
                                ),
                              );
                              return;
                            }
                            setState(() {
                              pickedBytes = bytes;
                              pickedFileName = file.name;
                              pickedMimeType = file.extension;
                            });
                          },
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Choisir un fichier (image/vidéo, Supabase Storage)'),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pickedFileName != null
                              ? 'Fichier sélectionné : $pickedFileName'
                              : (existingStoragePath != null &&
                                      existingStoragePath.isNotEmpty
                                  ? 'Un fichier est déjà associé à ce média.'
                                  : 'Aucun fichier sélectionné.'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () async {
                  final type = selectedType;
                  final title = titleController.text.trim();
                  final description = descriptionController.text.trim();
                  final lowerTypeSave = type.toLowerCase();
                  final isFileMediaSave = lowerTypeSave == 'video' ||
                      lowerTypeSave == 'image' ||
                      lowerTypeSave == 'brochure' ||
                      lowerTypeSave == 'pdf' ||
                      lowerTypeSave == 'doc';

                  String? url;
                  if (!isFileMediaSave) {
                    final urlText = urlController.text.trim();
                    url = urlText.isNotEmpty ? urlText : null;
                  }

                  if (type.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Le type de média est obligatoire.'),
                      ),
                    );
                    return;
                  }

                  String? storagePath = existingStoragePath;
                  if (pickedBytes != null && pickedFileName != null) {
                    final uploadedPath = await provider.uploadMediaFile(
                      bytes: pickedBytes!,
                      fileName: pickedFileName!,
                      mimeType: pickedMimeType,
                    );
                    if (!context.mounted) return;
                    if (uploadedPath == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            provider.error ??
                                'Erreur lors de l\'upload du fichier média.',
                          ),
                        ),
                      );
                      return;
                    }
                    storagePath = uploadedPath;
                  }

                  if (isFileMediaSave) {
                    final pathTrim = (storagePath ?? '').trim();
                    if (pathTrim.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Pour les vidéos, images, brochures et documents, un fichier doit être uploadé via Supabase Storage.',
                          ),
                        ),
                      );
                      return;
                    }
                  }

                  final ok = await provider.upsertMedia(
                    mediaId: media?['id']?.toString(),
                    mediaType: type,
                    title: title.isNotEmpty ? title : null,
                    description: description.isNotEmpty ? description : null,
                    url: url,
                    storagePath: storagePath,
                    thumbnailUrl: null,
                    sortOrder: null,
                    isActive: isActive,
                  );
                  if (!context.mounted) return;
                  if (ok) {
                    Navigator.of(context).pop();
                  } else {
                    final rawError = provider.error;
                    String message;
                    switch (rawError) {
                      case 'invalid_media_type':
                        message =
                            'Supabase: le type de média est invalide ou manquant (invalid_media_type).';
                        break;
                      case 'storage_required':
                        message =
                            'Supabase: un fichier uploadé (storage_path) est obligatoire pour ce type de média (storage_required).';
                        break;
                      case 'mux_not_allowed':
                        message =
                            "Supabase: Mux n'est plus autorisé comme source média (mux_not_allowed).";
                        break;
                      case 'media_url_not_allowed':
                        message =
                            'Supabase: les URLs externes ne sont pas autorisées pour ce type de média (media_url_not_allowed).';
                        break;
                      case 'not_authenticated':
                        message =
                            "Supabase: l'utilisateur connecté n'est pas authentifié (not_authenticated).";
                        break;
                      case 'not_university':
                        message =
                            "Supabase: le compte connecté n'a pas le rôle université (not_university).";
                        break;
                      case 'university_not_configured':
                        message =
                            "Supabase: l'université liée à ce compte n'est pas configurée (university_not_configured).";
                        break;
                      case 'media_not_found':
                        message =
                            'Supabase: le média ciblé est introuvable (media_not_found).';
                        break;
                      default:
                        message = provider.error ??
                            'Erreur lors de la sauvegarde du média.';
                        break;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(message),
                      ),
                    );
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      );
    },
  );
}
