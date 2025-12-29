import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/student_home_content_provider.dart';
import '../../services/hero_render_service.dart';
import '../../services/videoasset_upload_service.dart';
import 'hero_studio_models.dart';

class AdminStudentHomeScreen extends StatefulWidget {
  const AdminStudentHomeScreen({super.key});

  @override
  State<AdminStudentHomeScreen> createState() => _AdminStudentHomeScreenState();
}

class _AdminStudentHomeScreenState extends State<AdminStudentHomeScreen> {
  bool _heroLoading = false;
  String? _heroError;
  List<HeroPlaylistItem> _heroItems = const <HeroPlaylistItem>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentHomeContentProvider>().loadAdminStudentHomeContent();
      _loadHeroPlaylist();
    });
  }

  Future<void> _loadHeroPlaylist() async {
    setState(() {
      _heroLoading = true;
      _heroError = null;
    });
    try {
      final items = await HeroRenderService.getPlaylist(
        slot: 'student_home_hero_main',
      );
      if (!mounted) return;
      setState(() {
        _heroItems = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _heroError = e.toString();
        _heroItems = const <HeroPlaylistItem>[];
      });
    } finally {
      if (mounted) {
        setState(() {
          _heroLoading = false;
        });
      }
    }
  }

  Future<void> _showVideoDialog(
    StudentHomeContentProvider provider, {
    HeroPlaylistItem? existing,
  }) async {
    String? uploadedVideoAssetId;
    String uploadedUrl = existing?.baseVideoUrl ??
        existing?.baseImageUrl ??
        '';
    final titleController =
        TextEditingController(text: existing?.title ?? '');
    final sortController = TextEditingController(
      text: existing?.sortOrder.toString() ?? '',
    );
    bool isActive = existing?.isActive ?? true;
    String mediaType = (existing?.mediaType.toLowerCase() == 'image')
        ? 'image'
        : 'video';

    print(
      'AdminStudentHome: open media dialog '
      'existingId=${existing?.id} '
      'initialMediaType=$mediaType '
      'initialUrl=$uploadedUrl',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                existing == null
                    ? 'Nouveau média (accueil étudiant)'
                    : 'Modifier le média',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text('Type de média'),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: mediaType,
                          onChanged: (value) {
                            if (value == null) return;
                            setStateDialog(() {
                              mediaType = value;
                              uploadedUrl = '';
                            });
                          },
                          items: const [
                            DropdownMenuItem(
                              value: 'video',
                              child: Text('Vidéo'),
                            ),
                            DropdownMenuItem(
                              value: 'image',
                              child: Text('Image'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final isImage = mediaType == 'image';
                          print(
                            'AdminStudentHome: pick file '
                            'isImage=$isImage mediaType=$mediaType',
                          );
                          final result = await FilePicker.platform.pickFiles(
                            allowMultiple: false,
                            withData: true,
                            type: FileType.custom,
                            allowedExtensions: isImage
                                ? const ['jpg', 'jpeg', 'png', 'webp']
                                : const ['mp4', 'mov', 'webm'],
                          );

                          if (result == null || result.files.isEmpty) {
                            return;
                          }

                          final file = result.files.first;
                          final bytes = file.bytes;
                          print(
                            'AdminStudentHome: file picked '
                            'name=${file.name} size=${file.size} '
                            'extension=${file.extension}',
                          );
                          const maxSizeBytes = 200 * 1024 * 1024;
                          if (file.size > maxSizeBytes) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Fichier trop volumineux (max 200 Mo).',
                                ),
                              ),
                            );
                            return;
                          }
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
                          if (isImage) {
                            print(
                              'AdminStudentHome: calling '
                              'uploadStudentHomeFile (image) for ${file.name}',
                            );
                            final publicUrl = await provider.uploadStudentHomeFile(
                              bytes: Uint8List.fromList(bytes),
                              fileName: file.name,
                              mimeType: file.extension,
                              folder: 'hero-videos',
                            );

                            if (!context.mounted) return;

                            if (publicUrl == null) {
                              print(
                                'AdminStudentHome: uploadStudentHomeFile '
                                'returned null, error=${provider.error}',
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    provider.error ??
                                        'Erreur lors de l\'upload du média d\'accueil.',
                                  ),
                                ),
                              );
                              return;
                            }

                            setStateDialog(() {
                              uploadedVideoAssetId = null;
                              uploadedUrl = publicUrl;
                            });
                            print(
                              'AdminStudentHome: uploadedUrl set '
                              'mediaType=$mediaType url=$uploadedUrl',
                            );
                          } else {
                            try {
                              print(
                                'AdminStudentHome: ingest VideoAsset for ${file.name}',
                              );
                              final videoAssetId =
                                  await VideoAssetUploadService.ingestVideoFromBytes(
                                bytes: Uint8List.fromList(bytes),
                                fileName: file.name,
                                mimeType: file.extension,
                                origin: 'admin_student_home_hero_playlist',
                                contextType: null,
                                contextId: null,
                                fileSizeBytes: file.size,
                              );

                              if (!context.mounted) return;

                              setStateDialog(() {
                                uploadedVideoAssetId = videoAssetId;
                                uploadedUrl = 'video_asset:' + videoAssetId;
                              });
                              print(
                                'AdminStudentHome: videoAssetId set '
                                'mediaType=$mediaType id=$uploadedVideoAssetId',
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString(),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.upload_file),
                        label:
                            const Text('Uploader un média (Supabase Storage)'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        uploadedUrl.isNotEmpty
                            ? (mediaType == 'image'
                                ? 'Image sélectionnée.'
                                : 'Vidéo sélectionnée.')
                            : 'Aucun média sélectionné.',
                        style: const TextStyle(fontSize: 12),
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
    if (mediaType == 'video') {
      final assetId = uploadedVideoAssetId?.trim() ?? '';
      if (assetId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Une vidéo doit être uploadée pour l\'accueil étudiant.',
              ),
            ),
          );
        }
        return;
      }
    } else {
      final url = uploadedUrl.trim();
      if (url.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Un média doit être uploadé pour l\'accueil étudiant.',
              ),
            ),
          );
        }
        return;
      }
    }

    final sortOrder = int.tryParse(sortController.text.trim());
    print(
      'AdminStudentHome: saving hero media '
      'existingId=${existing?.id} '
      'mediaType=$mediaType sortOrder=$sortOrder '
      'isActive=$isActive uploadedUrl=$uploadedUrl '
      'uploadedVideoAssetId=$uploadedVideoAssetId',
    );

    try {
      String id;
      if (mediaType == 'video') {
        id = await HeroRenderService.upsertPlaylistItemWithVideoAsset(
          itemId: existing?.id,
          slot: 'student_home_hero_main',
          videoAssetId: uploadedVideoAssetId!,
          title: titleController.text.trim().isEmpty
              ? null
              : titleController.text.trim(),
          subtitle: null,
          sortOrder: sortOrder,
          isActive: isActive,
        );
      } else {
        final url = uploadedUrl.trim();
        id = await HeroRenderService.upsertPlaylistItemFromUrl(
          itemId: existing?.id,
          slot: 'student_home_hero_main',
          mediaType: mediaType,
          url: url,
          title: titleController.text.trim().isEmpty
              ? null
              : titleController.text.trim(),
          subtitle: null,
          sortOrder: sortOrder,
          isActive: isActive,
        );
      }

      print('AdminStudentHome: hero playlist item saved id=$id');
      await _loadHeroPlaylist();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    }
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

  Future<void> _showStudentHomeCarouselVideoDialog(
    StudentHomeContentProvider provider, {
    Map<String, dynamic>? existing,
  }) async {
    String? uploadedVideoAssetId;
    final existingVideoAssetId = existing?['video_asset_id']?.toString();

    final titleController =
        TextEditingController(text: existing?['title']?.toString() ?? '');
    final sortController = TextEditingController(
      text: existing?['sort_order']?.toString() ?? '',
    );
    bool isActive = existing == null || existing['is_active'] != false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                existing == null
                    ? 'Nouvelle vidéo (carrousel accueil étudiant)'
                    : 'Modifier la vidéo',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            allowMultiple: false,
                            withData: true,
                            type: FileType.custom,
                            allowedExtensions: const ['mp4', 'mov', 'webm'],
                          );

                          if (result == null || result.files.isEmpty) {
                            return;
                          }

                          final file = result.files.first;
                          final bytes = file.bytes;
                          const maxSizeBytes = 200 * 1024 * 1024;
                          if (file.size > maxSizeBytes) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Fichier trop volumineux (max 200 Mo).',
                                ),
                              ),
                            );
                            return;
                          }
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

                          try {
                            final videoAssetId =
                                await VideoAssetUploadService.ingestVideoFromBytes(
                              bytes: Uint8List.fromList(bytes),
                              fileName: file.name,
                              mimeType: file.extension,
                              origin: 'admin_student_home_carousel_video',
                              contextType: 'student_home_video',
                              contextId: existing?['id']?.toString(),
                              fileSizeBytes: file.size,
                            );

                            if (!context.mounted) return;

                            setStateDialog(() {
                              uploadedVideoAssetId = videoAssetId;
                            });
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.upload_file),
                        label:
                            const Text('Uploader une vidéo (VideoAsset)'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        (uploadedVideoAssetId ?? existingVideoAssetId) != null &&
                                (uploadedVideoAssetId ??
                                        existingVideoAssetId)!
                                    .toString()
                                    .isNotEmpty
                            ? 'Vidéo sélectionnée.'
                            : 'Aucune vidéo sélectionnée.',
                        style: const TextStyle(fontSize: 12),
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

    final sortOrder = int.tryParse(sortController.text.trim());
    final effectiveVideoAssetId =
        (uploadedVideoAssetId ?? existingVideoAssetId)?.trim() ?? '';

    if (effectiveVideoAssetId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Une vidéo doit être uploadée pour le carrousel étudiant.',
            ),
          ),
        );
      }
      return;
    }

    await provider.upsertVideo(
      videoId: existing?['id']?.toString(),
      videoAssetId: effectiveVideoAssetId,
      title: titleController.text.trim().isNotEmpty
          ? titleController.text.trim()
          : null,
      sortOrder: sortOrder,
      isActive: isActive,
      mediaType: 'video',
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
                  _heroItems.isEmpty &&
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
                            onPressed: provider.isSaving || _heroLoading
                                ? null
                                : () => _showVideoDialog(provider),
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_heroLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else ...[
                        if (_heroError != null) ...[
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _heroError!,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                        if (_heroItems.isEmpty)
                          const Text(
                            'Aucun média configuré pour le hero de l\'accueil étudiant.',
                          )
                        else
                          Column(
                            children: _heroItems.map((item) {
                              final isImage =
                                  item.mediaType.toLowerCase() == 'image';
                              final url = isImage
                                  ? (item.baseImageUrl ?? '')
                                  : (item.baseVideoUrl ?? '');
                              final title = item.title ?? '';
                              final active = item.isActive;
                              final sortOrder = item.sortOrder;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(
                                    title.isNotEmpty ? title : url,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    'Type: ' +
                                        (isImage ? 'Image' : 'Vidéo') +
                                        '\nURL: $url\nOrdre: ${sortOrder}  •  ' +
                                        (active ? 'Active' : 'Inactive'),
                                  ),
                                  isThreeLine: true,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: provider.isSaving || _heroLoading
                                            ? null
                                            : () => _showVideoDialog(
                                                  provider,
                                                  existing: item,
                                                ),
                                      ),
                                      IconButton(
                                        icon:
                                            const Icon(Icons.delete_outline),
                                        onPressed:
                                            provider.isSaving || _heroLoading
                                                ? null
                                                : () async {
                                                    final confirm =
                                                        await showDialog<bool>(
                                                      context: context,
                                                      builder: (context) {
                                                        return AlertDialog(
                                                          title: const Text(
                                                              'Supprimer le média ?'),
                                                          content: const Text(
                                                              'Cette action supprimera cet item de la playlist hero.'),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                          context)
                                                                      .pop(
                                                                          false),
                                                              child: const Text(
                                                                  'Annuler'),
                                                            ),
                                                            ElevatedButton(
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                          context)
                                                                      .pop(
                                                                          true),
                                                              child: const Text(
                                                                  'Supprimer'),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    );
                                                    if (confirm != true) {
                                                      return;
                                                    }
                                                    try {
                                                      await HeroRenderService
                                                          .deletePlaylistItem(
                                                        item.id,
                                                      );
                                                      await _loadHeroPlaylist();
                                                    } catch (e) {
                                                      if (!mounted) return;
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            e.toString(),
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                      const SizedBox(height: 24),
                      Divider(color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Vidéos du carrousel accueil étudiant',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: provider.isSaving
                                ? null
                                : () => _showStudentHomeCarouselVideoDialog(
                                      provider,
                                    ),
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (provider.videos.isEmpty)
                        const Text(
                          'Aucune vidéo configurée pour le carrousel accueil étudiant.',
                        )
                      else
                        Column(
                          children: provider.videos.map((v) {
                            final title = (v['title'] ?? '').toString();
                            final active = v['is_active'] == true;
                            final sortOrder = v['sort_order'];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(
                                  title.isNotEmpty ? title : '(Sans titre)',
                                  maxLines: 1,
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
                                          : () => _showStudentHomeCarouselVideoDialog(
                                                provider,
                                                existing: v,
                                              ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: provider.isSaving
                                          ? null
                                          : () async {
                                              final confirm =
                                                  await showDialog<bool>(
                                                context: context,
                                                builder: (context) {
                                                  return AlertDialog(
                                                    title: const Text(
                                                        'Supprimer la vidéo ?'),
                                                    content: const Text(
                                                      'Cette action supprimera cette vidéo du carrousel accueil étudiant.',
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                                    context)
                                                                .pop(false),
                                                        child: const Text(
                                                            'Annuler'),
                                                      ),
                                                      ElevatedButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                                    context)
                                                                .pop(true),
                                                        child: const Text(
                                                            'Supprimer'),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                              if (confirm != true) {
                                                return;
                                              }
                                              final id =
                                                  v['id']?.toString() ?? '';
                                              if (id.isEmpty) {
                                                return;
                                              }
                                              final ok =
                                                  await provider.deleteVideo(
                                                id,
                                              );
                                              if (!mounted) return;
                                              if (!ok && provider.error != null) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      provider.error!,
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
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
