import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_universities_provider.dart';
import '../../providers/admin_university_site_provider.dart';

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
      context.read<AdminUniversitiesProvider>().loadUniversities();
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
                    color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
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

        return Column(
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
            const Divider(height: 1),
            Expanded(
              child: ListView(
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
                        onPressed: () => _showAdminEditBlockDialog(context, provider),
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter un bloc'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (blocks.isEmpty)
                    const Text('Aucun bloc éditorial.'),
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
                                  label: Text(isActive ? 'Actif' : 'Inactif'),
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
                                  onPressed: () => _showAdminEditBlockDialog(
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
                        onPressed: () => _showAdminEditMediaDialog(context, provider),
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter un média'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (media.isEmpty)
                    const Text('Aucun média configuré.'),
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
                                  onPressed: () => _showAdminEditMediaDialog(
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
              ),
            ),
          ],
        );
      },
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

Future<void> _showAdminEditMediaDialog(
  BuildContext context,
  AdminUniversitySiteProvider provider, {
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

              final ok = await provider.upsertMedia(
                mediaId: media?['id']?.toString(),
                mediaType: type,
                title: title.isNotEmpty ? title : null,
                description: description.isNotEmpty ? description : null,
                url: url.isNotEmpty ? url : null,
                thumbnailUrl: thumbnail.isNotEmpty ? thumbnail : null,
              );
              if (!context.mounted) return;
              if (ok) {
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      provider.error ?? 'Erreur lors de la sauvegarde du média.',
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
