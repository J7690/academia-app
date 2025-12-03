import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_course_library_provider.dart';
import '../student/course_resource_viewer_screen.dart';

class AdminCourseLibraryScreen extends StatefulWidget {
  const AdminCourseLibraryScreen({super.key});

  @override
  State<AdminCourseLibraryScreen> createState() => _AdminCourseLibraryScreenState();
}

class _AdminCourseLibraryScreenState extends State<AdminCourseLibraryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminCourseLibraryProvider>().loadLibrary();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Bibliothèque de cours - Admin'),
        elevation: 0,
        centerTitle: false,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFA3D65C), Color(0xFF1EA75C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Consumer<AdminCourseLibraryProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.domains.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(provider.error!),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: provider.loadLibrary,
                    child: const Text('Recharger'),
                  ),
                ],
              ),
            );
          }

          final domains = provider.domains;
          if (domains.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Aucun domaine configuré pour la bibliothèque de cours.'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _showDomainDialog(context, provider),
                    child: const Text('Créer un premier domaine'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: domains.length,
            itemBuilder: (context, index) {
              final domain = domains[index];
              final domainId = domain['domain_id']?.toString();
              final title = domain['title']?.toString() ?? '';
              final description = domain['description']?.toString() ?? '';
              final isActive = domain['is_active'] != false;
              final units = (domain['units'] as List<dynamic>? ?? const [])
                  .whereType<Map<String, dynamic>>()
                  .toList(growable: false);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
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
                                if (description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    description,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isActive)
                            const Chip(
                              label: Text('Actif'),
                              backgroundColor: Color(0xFFE5F9E7),
                            )
                          else
                            const Chip(
                              label: Text('Inactif'),
                              backgroundColor: Color(0xFFFEE2E2),
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'Modifier le domaine',
                            onPressed: () {
                              _showDomainDialog(context, provider, existing: domain);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Sous-matières',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (domainId != null)
                            TextButton.icon(
                              onPressed: () {
                                _showUnitDialog(context, provider, domainId: domainId);
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Ajouter'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (units.isEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Aucune sous-matière pour ce domaine.',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            if (domainId != null)
                              ElevatedButton.icon(
                                onPressed: () {
                                  _showUnitDialog(
                                    context,
                                    provider,
                                    domainId: domainId,
                                  );
                                },
                                icon: const Icon(Icons.add),
                                label:
                                    const Text('Créer une première sous-matière'),
                              ),
                          ],
                        )
                      else
                        Column(
                          children: units
                              .map(
                                (unit) => _buildUnitTile(
                                  context,
                                  provider,
                                  domainId: domainId,
                                  unit: unit,
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final provider = context.read<AdminCourseLibraryProvider>();
          _showDomainDialog(context, provider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un domaine'),
      ),
    );
  }

  Widget _buildUnitTile(
    BuildContext context,
    AdminCourseLibraryProvider provider, {
    required String? domainId,
    required Map<String, dynamic> unit,
  }) {
    final unitId = unit['unit_id']?.toString();
    final title = unit['title']?.toString() ?? '';
    final description = unit['description']?.toString() ?? '';
    final isActive = unit['is_active'] != false;
    final resources = (unit['resources'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFFF9FAFB),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
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
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isActive)
                  const Chip(
                    label: Text('Actif'),
                    backgroundColor: Color(0xFFE5F9E7),
                  )
                else
                  const Chip(
                    label: Text('Inactif'),
                    backgroundColor: Color(0xFFFEE2E2),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Modifier la sous-matière',
                  onPressed: () {
                    if (domainId == null) return;
                    _showUnitDialog(
                      context,
                      provider,
                      domainId: domainId,
                      existing: unit,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Ressources',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (unitId != null)
                  TextButton.icon(
                    onPressed: () {
                      _showResourceDialog(
                        context,
                        provider,
                        unitId: unitId,
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (resources.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aucune ressource pour cette sous-matière.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  if (unitId != null)
                    ElevatedButton.icon(
                      onPressed: () {
                        _showResourceDialog(
                          context,
                          provider,
                          unitId: unitId,
                        );
                      },
                      icon: const Icon(Icons.add),
                      label:
                          const Text('Ajouter un premier support de cours'),
                    ),
                ],
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  int crossAxisCount;
                  if (width < 600) {
                    crossAxisCount = 1;
                  } else if (width < 1000) {
                    crossAxisCount = 2;
                  } else {
                    crossAxisCount = 3;
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 3,
                    ),
                    itemCount: resources.length,
                    itemBuilder: (context, index) {
                      final res = resources[index];
                      return _buildResourceTile(
                        context,
                        provider,
                        unitId: unitId,
                        res: res,
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceTile(
    BuildContext context,
    AdminCourseLibraryProvider provider, {
    required String? unitId,
    required Map<String, dynamic> res,
  }) {
    final title = res['title']?.toString() ?? '';
    final description = res['description']?.toString() ?? '';
    final type = (res['resource_type'] ?? '').toString().toLowerCase();
    final isActive = res['is_active'] != false;
    final storagePath = res['storage_path']?.toString() ?? '';
    String fileName = '';
    if (storagePath.isNotEmpty) {
      final segments = storagePath.split('/');
      if (segments.isNotEmpty) {
        fileName = segments.last;
      }
    }

    IconData icon;
    Color cardColor;
    if (type.contains('video')) {
      icon = Icons.play_circle_fill;
      cardColor = const Color(0xFFE6F4EA);
    } else if (type.contains('audio')) {
      icon = Icons.audiotrack;
      cardColor = const Color(0xFFE3F2FD);
    } else {
      icon = Icons.insert_drive_file;
      cardColor = const Color(0xFFF5F5F5);
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      tileColor: cardColor,
      leading: Icon(icon, color: const Color(0xFF1EA75C)),
      title: Text(title),
      subtitle: (description.isEmpty && fileName.isEmpty)
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (description.isNotEmpty) Text(description),
                if (fileName.isNotEmpty)
                  Text(
                    fileName,
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive)
            const Chip(
              label: Text('Actif'),
              backgroundColor: Color(0xFFE5F9E7),
            )
          else
            const Chip(
              label: Text('Inactif'),
              backgroundColor: Color(0xFFFEE2E2),
            ),
          IconButton(
            icon: const Icon(Icons.visibility),
            tooltip: 'Prévisualiser la ressource',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CourseResourceViewerScreen(resource: res),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Modifier la ressource',
            onPressed: () {
              if (unitId == null) return;
              _showResourceDialog(
                context,
                provider,
                unitId: unitId,
                existing: res,
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showDomainDialog(
    BuildContext context,
    AdminCourseLibraryProvider provider, {
    Map<String, dynamic>? existing,
  }) async {
    final titleController =
        TextEditingController(text: existing?['title']?.toString() ?? '');
    final descriptionController =
        TextEditingController(text: existing?['description']?.toString() ?? '');
    final sortController = TextEditingController(
      text: existing?['sort_order']?.toString() ?? '',
    );
    bool isActive = existing == null || existing['is_active'] != false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing == null ? 'Nouveau domaine' : 'Modifier le domaine'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Titre du domaine'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Description (optionnelle)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: sortController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Ordre (optionnel)'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Actif'),
                    const Spacer(),
                    StatefulBuilder(
                      builder: (context, setStateDialog) {
                        return Switch(
                          value: isActive,
                          onChanged: (v) {
                            setStateDialog(() {
                              isActive = v;
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final title = titleController.text.trim();
    if (title.isEmpty) return;

    final sortOrder = int.tryParse(sortController.text.trim());
    await provider.upsertDomain(
      domainId: existing?['domain_id']?.toString(),
      title: title,
      description:
          descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
      sortOrder: sortOrder,
      isActive: isActive,
    );
  }

  Future<void> _showUnitDialog(
    BuildContext context,
    AdminCourseLibraryProvider provider, {
    required String domainId,
    Map<String, dynamic>? existing,
  }) async {
    final titleController =
        TextEditingController(text: existing?['title']?.toString() ?? '');
    final descriptionController =
        TextEditingController(text: existing?['description']?.toString() ?? '');
    final sortController = TextEditingController(
      text: existing?['sort_order']?.toString() ?? '',
    );
    bool isActive = existing == null || existing['is_active'] != false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
              existing == null ? 'Nouvelle sous-matière' : 'Modifier la sous-matière'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Titre de la sous-matière'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Description (optionnelle)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: sortController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Ordre (optionnel)'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Actif'),
                    const Spacer(),
                    StatefulBuilder(
                      builder: (context, setStateDialog) {
                        return Switch(
                          value: isActive,
                          onChanged: (v) {
                            setStateDialog(() {
                              isActive = v;
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final title = titleController.text.trim();
    if (title.isEmpty) return;

    final sortOrder = int.tryParse(sortController.text.trim());
    await provider.upsertUnit(
      unitId: existing?['unit_id']?.toString(),
      domainId: domainId,
      title: title,
      description:
          descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
      sortOrder: sortOrder,
      isActive: isActive,
    );
  }

  Future<void> _showResourceDialog(
    BuildContext context,
    AdminCourseLibraryProvider provider, {
    required String unitId,
    Map<String, dynamic>? existing,
  }) async {
    final titleController =
        TextEditingController(text: existing?['title']?.toString() ?? '');
    final descriptionController =
        TextEditingController(text: existing?['description']?.toString() ?? '');
    final typeController =
        TextEditingController(text: existing?['resource_type']?.toString() ?? '');
    final storageBucketController =
        TextEditingController(text: existing?['storage_bucket']?.toString() ?? '');
    final storagePathController =
        TextEditingController(text: existing?['storage_path']?.toString() ?? '');
    final externalUrlController =
        TextEditingController(text: existing?['external_url']?.toString() ?? '');
    final sortController = TextEditingController(
      text: existing?['sort_order']?.toString() ?? '',
    );
    bool isActive = existing == null || existing['is_active'] != false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final lowerType = typeController.text.toLowerCase();
            final isFileResource = lowerType.contains('video') ||
                lowerType.contains('vidéo') ||
                lowerType.contains('audio') ||
                lowerType.contains('document') ||
                lowerType.contains('doc') ||
                lowerType.contains('pdf') ||
                lowerType.contains('image');
            return AlertDialog(
              title:
                  Text(existing == null ? 'Nouvelle ressource' : 'Modifier la ressource'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration:
                          const InputDecoration(labelText: 'Titre de la ressource'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'Description (optionnelle)'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: typeController,
                      decoration: const InputDecoration(
                        labelText:
                            'Type de ressource (obligatoire : video, audio, document, ...)',
                      ),
                      onChanged: (_) {
                        setStateDialog(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            allowMultiple: false,
                            withData: true,
                            type: FileType.custom,
                            allowedExtensions: const [
                              'pdf',
                              'doc',
                              'docx',
                              'ppt',
                              'pptx',
                              'mp4',
                              'mov',
                              'webm',
                              'mp3',
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
                                  'Impossible de lire le contenu du fichier.',
                                ),
                              ),
                            );
                            return;
                          }

                          final uploadResult = await provider.uploadCourseFile(
                            bytes: bytes,
                            fileName: file.name,
                            mimeType: file.extension,
                            folder: 'course-library',
                          );

                          if (!context.mounted) return;

                          if (uploadResult == null) {
                            final err = provider.error ??
                                'Erreur lors de l\'upload du fichier de cours.';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(err)),
                            );
                            return;
                          }

                          setStateDialog(() {
                            storageBucketController.text =
                                uploadResult['bucket'] ?? '';
                            storagePathController.text =
                                uploadResult['path'] ?? '';

                            if (titleController.text.trim().isEmpty) {
                              final baseName = file.name;
                              final dotIndex = baseName.lastIndexOf('.');
                              final withoutExt = dotIndex > 0
                                  ? baseName.substring(0, dotIndex)
                                  : baseName;
                              titleController.text = withoutExt;
                            }

                            if (typeController.text.trim().isEmpty) {
                              final ext = (file.extension ?? '').toLowerCase();
                              if (ext == 'mp3') {
                                typeController.text = 'audio';
                              } else if (ext == 'mp4' ||
                                  ext == 'mov' ||
                                  ext == 'webm') {
                                typeController.text = 'video';
                              } else {
                                typeController.text = 'document';
                              }
                            }
                          });
                        },
                        icon: const Icon(Icons.upload_file),
                        label:
                            const Text('Uploader un fichier (Supabase Storage)'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: storageBucketController,
                      decoration: const InputDecoration(
                        labelText: 'Bucket storage (ex: landing-media)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: storagePathController,
                      decoration: const InputDecoration(
                        labelText: 'Chemin storage (optionnel)',
                      ),
                    ),
                    if (!isFileResource) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: externalUrlController,
                        decoration: const InputDecoration(
                          labelText: 'URL externe (optionnel)',
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: sortController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Ordre (optionnel)'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Actif'),
                        const Spacer(),
                        Switch(
                          value: isActive,
                          onChanged: (v) {
                            setStateDialog(() {
                              isActive = v;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    final title = titleController.text.trim();
    final type = typeController.text.trim();
    final lowerType = type.toLowerCase();
    final isFileResource = lowerType.contains('video') ||
        lowerType.contains('vidéo') ||
        lowerType.contains('audio') ||
        lowerType.contains('document') ||
        lowerType.contains('doc') ||
        lowerType.contains('pdf') ||
        lowerType.contains('image');

    if (title.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Le titre de la ressource est obligatoire.'),
          ),
        );
      }
      return;
    }

    if (type.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Le type de la ressource est obligatoire (video, audio, document, ...).',
            ),
          ),
        );
      }
      return;
    }

    if (isFileResource) {
      final bucket = storageBucketController.text.trim();
      final path = storagePathController.text.trim();
      if (bucket.isEmpty || path.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Pour les vidéos, audios et documents, un fichier doit être uploadé (bucket + chemin).',
              ),
            ),
          );
        }
        return;
      }
    }

    final sortOrder = int.tryParse(sortController.text.trim());
    final success = await provider.upsertResource(
      resourceId: existing?['resource_id']?.toString(),
      unitId: unitId,
      title: title,
      description:
          descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
      resourceType: type,
      storageBucket:
          storageBucketController.text.trim().isEmpty
              ? null
              : storageBucketController.text.trim(),
      storagePath:
          storagePathController.text.trim().isEmpty
              ? null
              : storagePathController.text.trim(),
      externalUrl: isFileResource
          ? null
          : (externalUrlController.text.trim().isEmpty
              ? null
              : externalUrlController.text.trim()),
      sortOrder: sortOrder,
      isActive: isActive,
    );

    if (!success && context.mounted) {
      final rawError = provider.error;
      String message;
      switch (rawError) {
        case 'resource_type_required':
          message =
              'Supabase: le type de la ressource est obligatoire (resource_type_required).';
          break;
        case 'invalid_title':
          message =
              'Supabase: le titre de la ressource est vide ou invalide (invalid_title).';
          break;
        case 'unit_required':
          message = 'Supabase: la sous-matière cible est manquante (unit_required).';
          break;
        case 'unit_not_found':
          message =
              'Supabase: la sous-matière associée à cette ressource est introuvable (unit_not_found).';
          break;
        case 'storage_required':
          message =
              'Supabase: un fichier uploadé (storage_bucket + storage_path) est obligatoire pour ce type de ressource (storage_required).';
          break;
        case 'external_url_not_allowed':
          message =
              'Supabase: les URLs externes ne sont pas autorisées pour ce type de ressource (external_url_not_allowed).';
          break;
        case 'mux_not_allowed':
          message =
              'Supabase: Mux n\'est plus autorisé comme source vidéo (mux_not_allowed).';
          break;
        case 'not_admin':
          message =
              'Supabase: l\'utilisateur connecté n\'est pas reconnu comme administrateur (not_admin).';
          break;
        case 'not_authenticated':
          message =
              'Supabase: la session n\'est pas authentifiée (not_authenticated).';
          break;
        default:
          message = rawError ??
              'Erreur lors de l\'enregistrement de la ressource (voir Supabase).';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}
