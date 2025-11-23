import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/student_home_content_provider.dart';

class AdminStudentHomeScreen extends StatefulWidget {
  const AdminStudentHomeScreen({super.key});

  @override
  State<AdminStudentHomeScreen> createState() => _AdminStudentHomeScreenState();
}

class _AdminStudentHomeScreenState extends State<AdminStudentHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentHomeContentProvider>().loadAdminStudentHomeContent();
    });
  }

  Future<void> _showVideoDialog(
    StudentHomeContentProvider provider, {
    Map<String, dynamic>? existing,
  }) async {
    final urlController =
        TextEditingController(text: existing?['video_url']?.toString() ?? '');
    final titleController =
        TextEditingController(text: existing?['title']?.toString() ?? '');
    final sortController = TextEditingController(
      text: existing?['sort_order']?.toString() ?? '',
    );
    bool isActive = existing == null || existing['is_active'] != false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            existing == null
                ? 'Nouvelle vidéo (accueil étudiant)'
                : 'Modifier la vidéo',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'URL vidéo (mp4, webm, m3u8...)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titre (facultatif)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: sortController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ordre (optionnel)',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Active'),
                    const Spacer(),
                    Switch(
                      value: isActive,
                      onChanged: (v) {
                        isActive = v;
                        (context as Element).markNeedsBuild();
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
    final url = urlController.text.trim();
    if (url.isEmpty) return;

    final sortOrder = int.tryParse(sortController.text.trim());
    await provider.upsertVideo(
      videoId: existing?['id']?.toString(),
      videoUrl: url,
      title:
          titleController.text.trim().isEmpty ? null : titleController.text.trim(),
      sortOrder: sortOrder,
      isActive: isActive,
    );
  }

  Future<void> _showAnnouncementDialog(
    StudentHomeContentProvider provider, {
    Map<String, dynamic>? existing,
  }) async {
    final textController =
        TextEditingController(text: existing?['text']?.toString() ?? '');
    final sortController = TextEditingController(
      text: existing?['sort_order']?.toString() ?? '',
    );
    bool isActive = existing == null || existing['is_active'] != false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            existing == null
                ? 'Nouvelle annonce (accueil étudiant)'
                : 'Modifier l\'annonce',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Texte de l\'annonce',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: sortController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ordre (optionnel)',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Active'),
                    const Spacer(),
                    Switch(
                      value: isActive,
                      onChanged: (v) {
                        isActive = v;
                        (context as Element).markNeedsBuild();
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
    final text = textController.text.trim();
    if (text.isEmpty) return;

    final sortOrder = int.tryParse(sortController.text.trim());
    await provider.upsertAnnouncement(
      announcementId: existing?['id']?.toString(),
      text: text,
      sortOrder: sortOrder,
      isActive: isActive,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentHomeContentProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),
          appBar: AppBar(
            elevation: 0,
            centerTitle: false,
            title: const Text('Accueil étudiant - Vidéos & bande roulante'),
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
            actions: [
              IconButton(
                onPressed: provider.loadAdminStudentHomeContent,
                icon: const Icon(Icons.refresh),
                tooltip: 'Recharger',
              ),
            ],
          ),
          body: provider.isLoading &&
                  provider.videos.isEmpty &&
                  provider.announcements.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (provider.error != null) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(provider.error!),
                        ),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Vidéos de l\'accueil étudiant (playlist publicitaire)',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: provider.isSaving
                                ? null
                                : () => _showVideoDialog(provider),
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (provider.videos.isEmpty)
                        const Text('Aucune vidéo configurée pour l\'accueil étudiant.')
                      else
                        Column(
                          children: provider.videos.map((v) {
                            final url = (v['video_url'] ?? '').toString();
                            final title = (v['title'] ?? '').toString();
                            final active = v['is_active'] == true;
                            final sortOrder = v['sort_order'];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(
                                  title.isNotEmpty ? title : url,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  'URL: $url\nOrdre: ${sortOrder ?? '-'}  •  ' +
                                      (active ? 'Active' : 'Inactive'),
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: provider.isSaving
                                          ? null
                                          : () => _showVideoDialog(
                                                provider,
                                                existing: v,
                                              ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: provider.isSaving
                                          ? null
                                          : () => provider.deleteVideo(
                                                v['id']?.toString() ?? '',
                                              ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 24),
                      Divider(color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Annonces (bande roulante accueil étudiant)',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: provider.isSaving
                                ? null
                                : () => _showAnnouncementDialog(provider),
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (provider.announcements.isEmpty)
                        const Text(
                            'Aucune annonce configurée pour la bande roulante étudiant.')
                      else
                        Column(
                          children: provider.announcements.map((a) {
                            final text = (a['text'] ?? '').toString();
                            final active = a['is_active'] == true;
                            final sortOrder = a['sort_order'];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(
                                  text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  'Ordre: ${sortOrder ?? '-'}  •  ' +
                                      (active ? 'Active' : 'Inactive'),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: provider.isSaving
                                          ? null
                                          : () => _showAnnouncementDialog(
                                                provider,
                                                existing: a,
                                              ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: provider.isSaving
                                          ? null
                                          : () => provider.deleteAnnouncement(
                                                a['id']?.toString() ?? '',
                                              ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
