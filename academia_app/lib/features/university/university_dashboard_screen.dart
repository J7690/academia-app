import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/university_applications_provider.dart';
import '../../providers/selected_university_application_provider.dart';
import '../../providers/university_site_provider.dart';
import '../../providers/university_programs_provider.dart';
import '../student/mini_site_media_viewer_screen.dart';
import 'university_application_detail_screen.dart';

class UniversityDashboardScreen extends StatelessWidget {
  const UniversityDashboardScreen({super.key});

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? '';
    final metadata = user?.userMetadata ?? <String, dynamic>{};

    return DefaultTabController(
      length: 2,
      child: Consumer<UniversityApplicationsProvider>(
        builder: (context, applicationsProvider, child) {
          final unread = applicationsProvider.unreadTotal;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Dashboard Université'),
              actions: [
                IconButton(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout),
                  tooltip: 'Se déconnecter',
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabs: [
                  Tab(child: _UniversityTabLabel(text: 'Candidatures', count: unread)),
                  const Tab(text: 'Mini-site & offres'),
                ],
              ),
            ),
            body: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: Colors.black.withOpacity(0.04),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email: $email', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('Metadata: ${metadata.toString()}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      const _UniversityCandidaturesWorkspace(),
                      const _UniversitySiteWorkspace(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Future<void> _showEditConfigDialog(
  BuildContext context,
  UniversitySiteProvider provider,
) async {
  final current = provider.config ?? <String, dynamic>{};
  final titleController =
      TextEditingController(text: current['hero_title']?.toString() ?? '');
  final subtitleController =
      TextEditingController(text: current['hero_subtitle']?.toString() ?? '');
  final primaryColorController =
      TextEditingController(text: current['hero_primary_color']?.toString() ?? '');
  final secondaryColorController =
      TextEditingController(text: current['hero_secondary_color']?.toString() ?? '');

  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Configuration du hero'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Titre *',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: subtitleController,
                decoration: const InputDecoration(
                  labelText: 'Sous-titre',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: primaryColorController,
                decoration: const InputDecoration(
                  labelText: 'Couleur primaire (hex, optionnel)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: secondaryColorController,
                decoration: const InputDecoration(
                  labelText: 'Couleur secondaire (hex, optionnel)',
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
              final title = titleController.text.trim();
              final subtitle = subtitleController.text.trim();
              final primaryColor = primaryColorController.text.trim();
              final secondaryColor = secondaryColorController.text.trim();

              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Le titre du hero est obligatoire.'),
                  ),
                );
                return;
              }

              final ok = await provider.upsertConfig(
                heroTitle: title,
                heroSubtitle: subtitle.isNotEmpty ? subtitle : null,
                heroPrimaryColor: primaryColor.isNotEmpty ? primaryColor : null,
                heroSecondaryColor: secondaryColor.isNotEmpty ? secondaryColor : null,
                heroPosterMediaId: current['hero_poster_media_id']?.toString(),
              );
              if (!context.mounted) return;
              if (ok) {
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      provider.error ?? 'Erreur lors de la sauvegarde de la configuration.',
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

Future<void> _showEditBannerDialog(
  BuildContext context,
  UniversitySiteProvider provider, {
  Map<String, dynamic>? banner,
  List<Map<String, dynamic>> media = const [],
}) async {
  final positionController =
      TextEditingController(text: banner?['position']?.toString() ?? 'top_carousel');
  final titleController =
      TextEditingController(text: banner?['title']?.toString() ?? '');
  final subtitleController =
      TextEditingController(text: banner?['subtitle']?.toString() ?? '');
  final sortOrderController = TextEditingController(
    text: banner?['sort_order']?.toString() ?? '',
  );
  bool isActive = banner?['is_active'] != false;
  String? selectedMediaId = banner?['media_id']?.toString();

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(banner == null ? 'Ajouter une bannière' : 'Modifier la bannière'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: positionController,
                    decoration: const InputDecoration(
                      labelText: 'Position (top_carousel, middle_strip, bottom_strip)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Titre *',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: subtitleController,
                    decoration: const InputDecoration(
                      labelText: 'Sous-titre',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: sortOrderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Ordre d\'affichage',
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (media.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: selectedMediaId != null &&
                              media.any((m) => m['id']?.toString() == selectedMediaId)
                          ? selectedMediaId
                          : null,
                      items: media.map((m) {
                        final id = m['id']?.toString();
                        final title = m['title']?.toString() ?? '';
                        final type = m['media_type']?.toString() ?? '';
                        if (id == null) {
                          return null;
                        }
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(
                            [title, type].where((e) => e.isNotEmpty).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).whereType<DropdownMenuItem<String>>().toList(),
                      decoration: const InputDecoration(
                        labelText: 'Média associé (optionnel)',
                      ),
                      onChanged: (value) {
                        setState(() {
                          selectedMediaId = value;
                        });
                      },
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
                      const Text('Bannière active'),
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
                  final position = positionController.text.trim();
                  final title = titleController.text.trim();
                  final subtitle = subtitleController.text.trim();
                  final sortText = sortOrderController.text.trim();

                  if (position.isEmpty || title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('La position et le titre sont obligatoires.'),
                      ),
                    );
                    return;
                  }

                  final sortOrder =
                      sortText.isEmpty ? null : int.tryParse(sortText);

                  final ok = await provider.upsertBanner(
                    bannerId: banner?['id']?.toString(),
                    position: position,
                    title: title,
                    subtitle: subtitle.isNotEmpty ? subtitle : null,
                    mediaId: selectedMediaId,
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
                              'Erreur lors de la sauvegarde de la bannière.',
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

class _UniversityTabLabel extends StatelessWidget {
  final String text;
  final int count;

  const _UniversityTabLabel({required this.text, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return Text(text);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count > 9 ? '9+' : '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _UniversityCandidaturesWorkspace extends StatefulWidget {
  const _UniversityCandidaturesWorkspace();

  @override
  State<_UniversityCandidaturesWorkspace> createState() => _UniversityCandidaturesWorkspaceState();
}

class _UniversityCandidaturesWorkspaceState extends State<_UniversityCandidaturesWorkspace> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<UniversityApplicationsProvider>().loadApplications();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Consumer<UniversityApplicationsProvider>(
            builder: (context, provider, child) {
              final receivedCount = provider.unreadReceived;
              final treatedCount = provider.unreadTreated;
              return TabBar(
                tabs: [
                  Tab(
                    child: _UniversityTabLabel(
                      text: 'Reçues',
                      count: receivedCount,
                    ),
                  ),
                  Tab(
                    child: _UniversityTabLabel(
                      text: 'Traitées',
                      count: treatedCount,
                    ),
                  ),
                ],
              );
            },
          ),
          const Divider(height: 1),
          const Expanded(
            child: TabBarView(
              children: [
                _UniversityApplicationsBucket(received: true),
                _UniversityApplicationsBucket(received: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UniversityApplicationsBucket extends StatelessWidget {
  final bool received;

  const _UniversityApplicationsBucket({required this.received});

  @override
  Widget build(BuildContext context) {
    return Consumer2<UniversityApplicationsProvider, SelectedUniversityApplicationProvider>(
      builder: (context, applicationsProvider, selectionProvider, child) {
        if (applicationsProvider.isLoading && applicationsProvider.applications.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (applicationsProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(applicationsProvider.error!),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: applicationsProvider.loadApplications,
                  child: const Text('Recharger'),
                ),
              ],
            ),
          );
        }

        final all = applicationsProvider.applications;
        final apps = all.where((app) {
          final status = app['status']?.toString();
          if (received) {
            return status == 'submitted';
          }
          return status == 'under_review' ||
              status == 'accepted' ||
              status == 'rejected' ||
              status == 'canceled';
        }).toList();

        if (apps.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                received
                    ? 'Aucune candidature reçue pour le moment.'
                    : 'Aucune candidature traitée pour le moment.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final selected = selectionProvider.selectedApplication;
        late Map<String, dynamic> effectiveSelected;
        if (selected != null && apps.any((a) => a['id'] == selected['id'])) {
          effectiveSelected = selected;
        } else {
          effectiveSelected = apps.first;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            selectionProvider.selectApplication(effectiveSelected);
          });
        }

        return Column(
          children: [
            Expanded(
              flex: 1,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: apps.length,
                itemBuilder: (context, index) {
                  final app = apps[index];
                  final isSelected = app['id'] == effectiveSelected['id'];
                  return Card(
                    elevation: isSelected ? 4 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isSelected
                          ? BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            )
                          : BorderSide.none,
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        selectionProvider.selectApplication(app);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    app['program_title']?.toString() ?? 'Programme inconnu',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (app['has_unread_for_university'] == true)
                                  const Icon(Icons.mark_unread_chat_alt,
                                      size: 18, color: Colors.red),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Étudiant : ${app['student_full_name'] ?? ''}'),
                            if (app['last_message_at'] != null)
                              Text('Dernier message : ${app['last_message_at']}'),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Expanded(
              flex: 2,
              child: UniversityApplicationDetailPanel(
                application: effectiveSelected,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _UniversitySiteWorkspace extends StatefulWidget {
  const _UniversitySiteWorkspace();

  @override
  State<_UniversitySiteWorkspace> createState() => _UniversitySiteWorkspaceState();
}

class _UniversitySiteWorkspaceState extends State<_UniversitySiteWorkspace> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<UniversitySiteProvider>().loadSite();
      } catch (_) {}
      try {
        context.read<UniversityProgramsProvider>().loadPrograms();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Aperçu'),
              Tab(text: 'Configuration'),
              Tab(text: 'Contenus'),
              Tab(text: 'Médias'),
              Tab(text: 'Programmes'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: const [
                _UniversitySitePreview(),
                _UniversitySiteConfigTab(),
                _UniversitySiteBlocksTab(),
                _UniversitySiteMediaTab(),
                _UniversitySiteProgramsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UniversitySitePreview extends StatelessWidget {
  const _UniversitySitePreview();

  @override
  Widget build(BuildContext context) {
    return Consumer2<UniversitySiteProvider, UniversityProgramsProvider>(
      builder: (context, siteProvider, programsProvider, child) {
        if (siteProvider.isLoading && siteProvider.university == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (siteProvider.error != null && siteProvider.university == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(siteProvider.error!),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: siteProvider.loadSite,
                    child: const Text('Recharger le mini-site'),
                  ),
                ],
              ),
            ),
          );
        }

        final university = siteProvider.university;
        final config = siteProvider.config;
        final blocks = siteProvider.blocks;
        final media = siteProvider.media;
        final programs = programsProvider.programs;

        if (university == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Mini-site non encore configuré pour cette université.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: siteProvider.loadSite,
                    child: const Text('Initialiser / recharger'),
                  ),
                ],
              ),
            ),
          );
        }

        final name = university['name']?.toString() ?? '';
        final city = university['city']?.toString() ?? '';
        final country = university['country']?.toString() ?? '';
        final description = university['description']?.toString() ?? '';
        final websiteUrl = university['website_url']?.toString() ?? '';
        final heroTitle = (config?['hero_title']?.toString() ?? '').trim();
        final heroSubtitle = (config?['hero_subtitle']?.toString() ?? '').trim();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              heroTitle.isNotEmpty ? heroTitle : name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (city.isNotEmpty || country.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                [city, country].where((e) => e.isNotEmpty).join(', '),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            if (websiteUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                websiteUrl,
                style: const TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ],
            if (heroSubtitle.isNotEmpty || description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(heroSubtitle.isNotEmpty ? heroSubtitle : description),
            ],
            const SizedBox(height: 16),
            if (blocks.isNotEmpty) ...[
              const Text(
                'Blocs éditoriaux',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...blocks.map((b) {
                final title = b['title']?.toString() ?? '';
                final content = b['content']?.toString() ?? '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title.isNotEmpty)
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        if (content.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            content,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
            if (media.isNotEmpty) ...[
              const Text(
                'Médias',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...media.map((m) {
                final title = m['title']?.toString() ?? '';
                final description = m['description']?.toString() ?? '';
                final url = m['url']?.toString() ?? '';
                final storagePath = m['storage_path']?.toString() ?? '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: storagePath.isEmpty
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MiniSiteMediaViewerScreen(media: m),
                              ),
                            );
                          },
                    title: Text(title.isNotEmpty ? title : 'Média'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (description.isNotEmpty) Text(description),
                        if (url.isNotEmpty)
                          Text(
                            url,
                            style: const TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
            if (programs.isNotEmpty) ...[
              const Text(
                'Programmes configurés',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...programs.map((program) {
                final title = program['title']?.toString() ?? '';
                final degree = program['degree_level']?.toString() ?? '';
                final mode = program['mode']?.toString() ?? '';
                final isActive = program['is_active'] == true;
                final highlighted = program['highlighted'] == true;

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
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (degree.isNotEmpty) Chip(label: Text(degree)),
                            if (mode.isNotEmpty) Chip(label: Text(mode)),
                            Chip(
                              label: Text(isActive ? 'Actif' : 'Inactif'),
                            ),
                            if (highlighted)
                              const Chip(
                                label: Text('En vedette'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        );
      },
    );
  }
}

class _UniversitySiteConfigTab extends StatelessWidget {
  const _UniversitySiteConfigTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<UniversitySiteProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.university == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final university = provider.university;
        final config = provider.config;
        final banners = provider.banners;

        if (university == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Mini-site non encore configuré pour cette université.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final name = university['name']?.toString() ?? '';
        final hasTopCarousel = banners.any((b) =>
            (b['position']?.toString() ?? '') == 'top_carousel' && b['is_active'] != false);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Configuration du mini-site pour $name',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hero',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Titre : ${config?['hero_title'] ?? '-'}'),
                    Text('Sous-titre : ${config?['hero_subtitle'] ?? '-'}'),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _showEditConfigDialog(context, provider),
                        icon: const Icon(Icons.edit),
                        label: const Text('Modifier la configuration'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!hasTopCarousel)
              Card(
                color: Colors.orange.withOpacity(0.08),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Aucune bannière de type "top_carousel" n\'est encore configurée. '
                          'Pour un mini-site complet, ajoutez au moins une bannière "En vedette".',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bannières / carrousels',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () =>
                      _showEditBannerDialog(context, provider, media: provider.media),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter une bannière'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (banners.isEmpty)
              const Text('Aucune bannière configurée pour le moment.')
            else
              ...banners.map((b) {
                final position = b['position']?.toString() ?? '';
                final title = b['title']?.toString() ?? '';
                final subtitle = b['subtitle']?.toString() ?? '';

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
                            Chip(label: Text(position)),
                          ],
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(subtitle),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () =>
                                  _showEditBannerDialog(context, provider,
                                      banner: b, media: provider.media),
                              icon: const Icon(Icons.edit),
                              label: const Text('Modifier'),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () async {
                                final id = b['id']?.toString();
                                if (id == null) return;
                                final ok = await provider.deleteBanner(id);
                                if (!context.mounted) return;
                                if (!ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        provider.error ??
                                            'Erreur lors de la suppression de la bannière.',
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
      },
    );
  }
}

class _UniversitySiteBlocksTab extends StatelessWidget {
  const _UniversitySiteBlocksTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<UniversitySiteProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.blocks.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final blocks = provider.blocks;

        if (blocks.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showEditBlockDialog(context, provider),
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter un bloc'),
                    ),
                    const SizedBox(width: 8),
                    if (provider.error != null)
                      Expanded(child: Text(provider.error!)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Aucun bloc éditorial configuré pour le moment.'),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showEditBlockDialog(context, provider),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un bloc'),
                  ),
                  const SizedBox(width: 8),
                  if (provider.error != null)
                    Expanded(child: Text(provider.error!)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: blocks.length,
                itemBuilder: (context, index) {
                  final block = blocks[index];
                  final title = block['title']?.toString() ?? '';
                  final key = block['key']?.toString() ?? '';
                  final content = block['content']?.toString() ?? '';
                  final isActive = block['is_active'] != false;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
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
                                label: Text(isActive ? 'Actif' : 'Inactif'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            content,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _showEditBlockDialog(
                                  context,
                                  provider,
                                  block: block,
                                ),
                                icon: const Icon(Icons.edit),
                                label: const Text('Modifier'),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () async {
                                  final id = block['id']?.toString();
                                  if (id == null) return;
                                  final ok = await provider.deleteBlock(id);
                                  if (!context.mounted) return;
                                  if (!ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
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
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _UniversitySiteMediaTab extends StatelessWidget {
  const _UniversitySiteMediaTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<UniversitySiteProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.media.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final media = provider.media;

        if (media.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showEditMediaDialog(context, provider),
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter un média'),
                    ),
                    const SizedBox(width: 8),
                    if (provider.error != null)
                      Expanded(child: Text(provider.error!)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Aucun média configuré pour le moment.'),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showEditMediaDialog(context, provider),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un média'),
                  ),
                  const SizedBox(width: 8),
                  if (provider.error != null)
                    Expanded(child: Text(provider.error!)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: media.length,
                itemBuilder: (context, index) {
                  final m = media[index];
                  final title = m['title']?.toString() ?? '';
                  final description = m['description']?.toString() ?? '';
                  final url = m['url']?.toString() ?? '';
                  final mediaType = m['media_type']?.toString() ?? '';
                  final isActive = m['is_active'] != false;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
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
                              Chip(label: Text(mediaType.isNotEmpty ? mediaType : 'Type')),
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
                              style: const TextStyle(fontSize: 12, color: Colors.blue),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _showEditMediaDialog(
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
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _UniversitySiteProgramsTab extends StatelessWidget {
  const _UniversitySiteProgramsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<UniversityProgramsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.programs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null && provider.programs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(provider.error!),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: provider.loadPrograms,
                  child: const Text('Recharger les programmes'),
                ),
              ],
            ),
          );
        }

        final programs = provider.programs;

        if (programs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: provider.loadPrograms,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recharger les programmes'),
                ),
                const SizedBox(height: 16),
                const Text('Aucun programme configuré pour le moment.'),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showEditProgramDialog(context, provider),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un programme'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: provider.loadPrograms,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Recharger'),
                  ),
                  const SizedBox(width: 8),
                  if (provider.error != null)
                    Expanded(child: Text(provider.error!)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: programs.length,
                itemBuilder: (context, index) {
                  final program = programs[index];
                  final title = program['title']?.toString() ?? '';
                  final degree = program['degree_level']?.toString() ?? '';
                  final mode = program['mode']?.toString() ?? '';
                  final isActive = program['is_active'] == true;
                  final highlighted = program['highlighted'] == true;

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
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (degree.isNotEmpty) Chip(label: Text(degree)),
                              if (mode.isNotEmpty) Chip(label: Text(mode)),
                              Chip(
                                label: Text(isActive ? 'Actif' : 'Inactif'),
                              ),
                              if (highlighted)
                                const Chip(
                                  label: Text('En vedette'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _showEditProgramDialog(
                                context,
                                provider,
                                program: program,
                              ),
                              icon: const Icon(Icons.edit),
                              label: const Text('Modifier'),
                            ),
                          ),
                        ],
                      ),
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

Future<void> _showEditBlockDialog(
  BuildContext context,
  UniversitySiteProvider provider, {
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

Future<void> _showEditMediaDialog(
  BuildContext context,
  UniversitySiteProvider provider, {
  Map<String, dynamic>? media,
}) async {
  final typeController = TextEditingController(text: media?['media_type']?.toString() ?? 'video');
  final titleController = TextEditingController(text: media?['title']?.toString() ?? '');
  final descriptionController =
      TextEditingController(text: media?['description']?.toString() ?? '');
  final urlController = TextEditingController(text: media?['url']?.toString() ?? '');
  final thumbnailController =
      TextEditingController(text: media?['thumbnail_url']?.toString() ?? '');

  await showDialog<void>(
    context: context,
    builder: (context) {
      Uint8List? pickedBytes;
      String? pickedFileName;
      String? pickedMimeType;
      final existingStoragePath = media?['storage_path']?.toString();

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(media == null ? 'Ajouter un média' : 'Modifier le média'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: typeController,
                    decoration: const InputDecoration(
                      labelText: 'Type de média (video, image, brochure...)',
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
                  const SizedBox(height: 8),
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'URL (YouTube, lien externe...)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: thumbnailController,
                    decoration: const InputDecoration(
                      labelText: 'URL de vignette (optionnel)',
                    ),
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
                          label: const Text('Choisir un fichier (image/vidéo)'),
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
                  final type = typeController.text.trim();
                  final title = titleController.text.trim();
                  final description = descriptionController.text.trim();
                  final url = urlController.text.trim();
                  final thumbnail = thumbnailController.text.trim();

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

                  final ok = await provider.upsertMedia(
                    mediaId: media?['id']?.toString(),
                    mediaType: type,
                    title: title.isNotEmpty ? title : null,
                    description: description.isNotEmpty ? description : null,
                    url: url.isNotEmpty ? url : null,
                    storagePath: storagePath,
                    thumbnailUrl: thumbnail.isNotEmpty ? thumbnail : null,
                  );
                  if (!context.mounted) return;
                  if (ok) {
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          provider.error ??
                              'Erreur lors de la sauvegarde du média.',
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

Future<void> _showEditProgramDialog(
  BuildContext context,
  UniversityProgramsProvider provider, {
  Map<String, dynamic>? program,
}) async {
  final titleController = TextEditingController(text: program?['title']?.toString() ?? '');
  final descriptionController =
      TextEditingController(text: program?['description']?.toString() ?? '');
  final degreeController =
      TextEditingController(text: program?['degree_level']?.toString() ?? '');
  final modeController = TextEditingController(text: program?['mode']?.toString() ?? '');
  final durationController = TextEditingController(
    text: program?['duration_months']?.toString() ?? '',
  );
  final feesController = TextEditingController(
    text: program?['tuition_fees']?.toString() ?? '',
  );
  bool highlighted = program?['highlighted'] == true;
  bool isActive = program?['is_active'] != false;

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(program == null ? 'Ajouter un programme' : 'Modifier le programme'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Titre du programme *',
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
                    controller: degreeController,
                    decoration: const InputDecoration(
                      labelText: 'Niveau (Licence, Master...)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: modeController,
                    decoration: const InputDecoration(
                      labelText: 'Mode (présentiel, en ligne...)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Durée (mois)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: feesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Frais de scolarité',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: highlighted,
                        onChanged: (value) {
                          setState(() {
                            highlighted = value ?? false;
                          });
                        },
                      ),
                      const Text('Mettre en vedette'),
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
                      const Text('Programme actif'),
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
                  final degree = degreeController.text.trim();
                  final mode = modeController.text.trim();
                  final durationText = durationController.text.trim();
                  final feesText = feesController.text.trim();

                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Le titre du programme est obligatoire.'),
                      ),
                    );
                    return;
                  }

                  final duration =
                      durationText.isEmpty ? null : int.tryParse(durationText);
                  final fees = feesText.isEmpty ? null : num.tryParse(feesText);

                  final ok = await provider.upsertProgram(
                    programId: program?['id']?.toString(),
                    title: title,
                    description: description.isNotEmpty ? description : null,
                    degreeLevel: degree.isNotEmpty ? degree : null,
                    mode: mode.isNotEmpty ? mode : null,
                    durationMonths: duration,
                    tuitionFees: fees,
                    highlighted: highlighted,
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
                              'Erreur lors de la sauvegarde du programme.',
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
