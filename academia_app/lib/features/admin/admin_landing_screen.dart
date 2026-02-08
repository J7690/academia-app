import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/landing_content_provider.dart';
import '../../services/hero_render_service.dart';
import '../../services/videoasset_upload_service.dart';
import 'hero_studio_models.dart';

class AdminLandingScreen extends StatefulWidget {
  const AdminLandingScreen({super.key});

  @override
  State<AdminLandingScreen> createState() => _AdminLandingScreenState();
}

class _AdminLandingScreenState extends State<AdminLandingScreen> {
  final TextEditingController _badgeController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();
  final TextEditingController _videoUrlController = TextEditingController();
  final TextEditingController _primaryColorController = TextEditingController();
  final TextEditingController _secondaryColorController = TextEditingController();
  final TextEditingController _accentColorController = TextEditingController();

  bool _initializedFromConfig = false;

  bool _heroLoading = false;
  String? _heroError;
  List<HeroPlaylistItem> _heroItems = const <HeroPlaylistItem>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LandingContentProvider>().loadAdminLandingContent();
      _loadHeroPlaylist();
    });
  }

  @override
  void dispose() {
    _badgeController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _videoUrlController.dispose();
    _primaryColorController.dispose();
    _secondaryColorController.dispose();
    _accentColorController.dispose();
    super.dispose();
  }

  void _initControllersFromConfig(Map<String, dynamic>? config) {
    if (_initializedFromConfig) return;
    if (config == null) return;
    _initializedFromConfig = true;

    _badgeController.text = config['hero_badge_text']?.toString() ?? '';
    _titleController.text = config['hero_title']?.toString() ?? '';
    _subtitleController.text = config['hero_subtitle']?.toString() ?? '';
    _videoUrlController.text = config['video_url']?.toString() ?? '';
    _primaryColorController.text = config['primary_color']?.toString() ?? '';
    _secondaryColorController.text = config['secondary_color']?.toString() ?? '';
    _accentColorController.text = config['accent_color']?.toString() ?? '';
  }

  Future<void> _loadHeroPlaylist() async {
    setState(() {
      _heroLoading = true;
      _heroError = null;
    });
    try {
      final items = await HeroRenderService.getPlaylist(
        slot: 'landing_hero_main',
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

  Future<void> _saveConfig(LandingContentProvider provider) async {
    final configId = provider.config?['id']?.toString();
    await provider.upsertConfig(
      configId: configId,
      heroBadgeText: _badgeController.text.trim().isEmpty
          ? null
          : _badgeController.text.trim(),
      heroTitle:
          _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
      heroSubtitle: _subtitleController.text.trim().isEmpty
          ? null
          : _subtitleController.text.trim(),
      videoUrl: _videoUrlController.text.trim().isEmpty
          ? null
          : _videoUrlController.text.trim(),
      primaryColor: _primaryColorController.text.trim().isEmpty
          ? null
          : _primaryColorController.text.trim(),
      secondaryColor: _secondaryColorController.text.trim().isEmpty
          ? null
          : _secondaryColorController.text.trim(),
      accentColor: _accentColorController.text.trim().isEmpty
          ? null
          : _accentColorController.text.trim(),
    );
    if (mounted && provider.error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuration enregistrée.')),
      );
    }
  }

  Future<void> _pickAndUploadHeroVideo(LandingContentProvider provider) async {
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fichier vidéo trop volumineux (max 200 Mo).'),
        ),
      );
      return;
    }
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de lire le contenu du fichier vidéo.'),
        ),
      );
      return;
    }

    final publicUrl = await provider.uploadLandingFile(
      bytes: Uint8List.fromList(bytes),
      fileName: file.name,
      mimeType: file.extension,
      folder: 'hero-video',
    );

    if (!mounted) return;

    if (publicUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.error ?? 'Erreur lors de l\'upload de la vidéo.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _videoUrlController.text = publicUrl;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vidéo uploadée pour la landing, sauvegarde en cours...')), 
    );

    await _saveConfig(provider);
  }

  Future<void> _clearHeroVideo(LandingContentProvider provider) async {
    _videoUrlController.clear();
    await _saveConfig(provider);
  }

  Future<void> _showVideoDialog(
    LandingContentProvider provider, {
    HeroPlaylistItem? existing,
  }) async {
    final existingItem = existing;

    String? uploadedVideoAssetId;
    String uploadedUrl = existingItem?.baseVideoUrl ??
        existingItem?.baseImageUrl ??
        '';
    final titleController =
        TextEditingController(text: existingItem?.title ?? '');
    final sortController = TextEditingController(
      text: existingItem?.sortOrder.toString() ?? '',
    );
    bool isActive = existingItem?.isActive ?? true;
    String mediaType = (existingItem?.mediaType.toLowerCase() == 'image')
        ? 'image'
        : 'video';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                existingItem == null
                    ? 'Nouveau média (playlist hero)'
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
                            final publicUrl = await provider.uploadLandingFile(
                              bytes: Uint8List.fromList(bytes),
                              fileName: file.name,
                              mimeType: file.extension,
                              folder: 'playlist-videos',
                            );

                            if (!context.mounted) return;

                            if (publicUrl == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    provider.error ??
                                        'Erreur lors de l\'upload du média de playlist.',
                                  ),
                                ),
                              );
                              return;
                            }

                            setStateDialog(() {
                              uploadedVideoAssetId = null;
                              uploadedUrl = publicUrl;
                            });
                          } else {
                            try {
                              final videoAssetId =
                                  await VideoAssetUploadService.ingestVideoFromBytes(
                                bytes: Uint8List.fromList(bytes),
                                fileName: file.name,
                                mimeType: file.extension,
                                origin: 'admin_landing_hero_playlist',
                                contextType: null,
                                contextId: null,
                                fileSizeBytes: file.size,
                              );

                              if (!context.mounted) return;

                              setStateDialog(() {
                                uploadedVideoAssetId = videoAssetId;
                                uploadedUrl = 'video_asset:' + videoAssetId;
                              });
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
                'Une vidéo doit être uploadée pour la playlist hero.',
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
                'Un média doit être uploadé pour la playlist hero.',
              ),
            ),
          );
        }
        return;
      }
    }

    final sortOrder = int.tryParse(sortController.text.trim());

    try {
      String id;
      if (mediaType == 'video') {
        id = await HeroRenderService.upsertPlaylistItemWithVideoAsset(
          itemId: existingItem?.id,
          slot: 'landing_hero_main',
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
          itemId: existingItem?.id,
          slot: 'landing_hero_main',
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

      // ignore: avoid_print
      print('AdminLanding: hero playlist item saved id=$id');
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

  Future<void> _showLandingCarouselVideoDialog(
    LandingContentProvider provider, {
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
                    ? 'Nouvelle vidéo (carrousel landing)'
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
                              origin: 'admin_landing_carousel_video',
                              contextType: 'landing_video',
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
                        label: const Text('Uploader une vidéo (VideoAsset)'),
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
              'Une vidéo doit être uploadée pour le carrousel landing.',
            ),
          ),
        );
      }
      return;
    }

    await provider.upsertVideo(
      videoId: existing?['id']?.toString(),
      videoAssetId: effectiveVideoAssetId,
      title: titleController.text.trim().isEmpty
          ? null
          : titleController.text.trim(),
      sortOrder: sortOrder,
      isActive: isActive,
      mediaType: 'video',
    );
  }

  Future<void> _showAnnouncementDialog(
    LandingContentProvider provider, {
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
          title: Text(existing == null ? 'Nouvelle annonce' : 'Modifier l\'annonce'),
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

  Future<void> _showWhyDialog(
    LandingContentProvider provider, {
    Map<String, dynamic>? existing,
  }) async {
    final titleController =
        TextEditingController(text: existing?['title']?.toString() ?? '');
    final subtitleController =
        TextEditingController(text: existing?['subtitle']?.toString() ?? '');
    final iconController =
        TextEditingController(text: existing?['icon_key']?.toString() ?? '');
    final sortController = TextEditingController(
      text: existing?['sort_order']?.toString() ?? '',
    );
    bool isActive = existing == null || existing['is_active'] != false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing == null ? 'Nouvelle carte' : 'Modifier la carte'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Titre'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: subtitleController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Sous-titre'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: iconController,
                  decoration: const InputDecoration(
                    labelText: 'Clé icône (files, bell, university, check, ...)',
                  ),
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
    final title = titleController.text.trim();
    if (title.isEmpty) return;

    final sortOrder = int.tryParse(sortController.text.trim());
    await provider.upsertWhyCard(
      whyId: existing?['id']?.toString(),
      title: title,
      subtitle: subtitleController.text.trim().isEmpty
          ? null
          : subtitleController.text.trim(),
      iconKey: iconController.text.trim().isEmpty
          ? null
          : iconController.text.trim(),
      sortOrder: sortOrder,
      isActive: isActive,
    );
  }

  Future<void> _showPartnerDialog(
    LandingContentProvider provider, {
    Map<String, dynamic>? existing,
  }) async {
    final nameController =
        TextEditingController(text: existing?['name']?.toString() ?? '');
    final logoController =
        TextEditingController(text: '');
    final websiteController =
        TextEditingController(text: existing?['website_url']?.toString() ?? '');
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
                existing == null ? 'Nouveau partenaire' : 'Modifier le partenaire',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nom (facultatif)'),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            allowMultiple: false,
                            withData: true,
                            type: FileType.custom,
                            allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
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
                                  'Impossible de lire le contenu du fichier logo.',
                                ),
                              ),
                            );
                            return;
                          }

                          final publicUrl = await provider.uploadLandingFile(
                            bytes: Uint8List.fromList(bytes),
                            fileName: file.name,
                            mimeType: file.extension,
                            folder: 'partner-logos',
                          );

                          if (!context.mounted) return;

                          if (publicUrl == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  provider.error ??
                                      'Erreur lors de l\'upload du logo partenaire.',
                                ),
                              ),
                            );
                            return;
                          }

                          setStateDialog(() {
                            logoController.text = publicUrl;
                          });
                        },
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Uploader un logo'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        logoController.text.isNotEmpty
                            ? 'Logo sélectionné.'
                            : 'Aucun logo sélectionné.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: websiteController,
                      decoration: const InputDecoration(
                        labelText: 'URL du site (facultatif)',
                      ),
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
      },
    );

    if (result != true) return;

    final sortOrder = int.tryParse(sortController.text.trim());
    await provider.upsertPartner(
      partnerId: existing?['id']?.toString(),
      name: nameController.text.trim().isEmpty
          ? null
          : nameController.text.trim(),
      logoUrl: logoController.text.trim().isEmpty
          ? null
          : logoController.text.trim(),
      websiteUrl: websiteController.text.trim().isEmpty
          ? null
          : websiteController.text.trim(),
      sortOrder: sortOrder,
      isActive: isActive,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LandingContentProvider>(
      builder: (context, provider, child) {
        _initControllersFromConfig(provider.config);

        return Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),
          appBar: AppBar(
            elevation: 0,
            centerTitle: false,
            title: const Text('Page d\'accueil - Landing'),
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
                onPressed: provider.loadAdminLandingContent,
                icon: const Icon(Icons.refresh),
                tooltip: 'Recharger',
              ),
            ],
          ),
          body: provider.isLoading && provider.config == null
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
                      Text(
                        'Configuration du hero',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _badgeController,
                        decoration: const InputDecoration(
                          labelText: 'Badge (ex: Prépare ton parcours universitaire)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _titleController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Titre principal',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _subtitleController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Sous-titre',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          onPressed: provider.isSaving
                              ? null
                              : () => _pickAndUploadHeroVideo(provider),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Uploader une vidéo'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        // L'URL vidéo du hero est désormais gérée uniquement via l'upload
                        // Supabase. On n'expose plus de champ éditable pour éviter les liens
                        // externes.
                        enabled: false,
                        controller: _videoUrlController,
                        decoration: const InputDecoration(
                          labelText: 'URL vidéo hero (gérée automatiquement)',
                        ),
                      ),
                      if (_videoUrlController.text.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: provider.isSaving
                                ? null
                                : () => _clearHeroVideo(provider),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Supprimer la vidéo'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _primaryColorController,
                              decoration: const InputDecoration(
                                labelText: 'Couleur primaire (#A3D65C, 0xFFA3D65C...)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _secondaryColorController,
                              decoration: const InputDecoration(
                                labelText: 'Couleur secondaire',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _accentColorController,
                        decoration: const InputDecoration(
                          labelText: 'Couleur accent (CTA, bande rouge...)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: provider.isSaving
                              ? null
                              : () => _saveConfig(provider),
                          icon: const Icon(Icons.save),
                          label: const Text('Enregistrer la configuration'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Divider(color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Vidéos du hero (playlist publicitaire)',
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
                          const Text('Aucun média configuré pour le hero.')
                        else
                          Column(
                            children: _heroItems.map((item) {
                              final mediaTypeLower =
                                  item.mediaType.toLowerCase();
                              final isImage = mediaTypeLower == 'image';
                              final url = (isImage
                                      ? (item.baseImageUrl ?? '')
                                      : (item.baseVideoUrl ?? ''))
                                  .trim();
                              final title = item.title ?? '';
                              final active = item.isActive;
                              final sortOrder = item.sortOrder;
                              final urlIsEmpty = url.isEmpty;
                              final urlLooksHttp = url.startsWith('http://') ||
                                  url.startsWith('https://');
                              // Pour les vidéos basées sur VideoAsset, baseVideoUrl
                              // peut légitimement être vide. On ne considère donc
                              // comme "non supporté" que :
                              // - les images sans URL;
                              // - les vidéos avec une URL non vide mais non http(s).
                              final unsupported = isImage
                                  ? urlIsEmpty
                                  : (!urlIsEmpty && !urlLooksHttp);

                              final subtitleBuffer = StringBuffer()
                                ..writeln('Type: ' +
                                    (isImage ? 'Image' : 'Vidéo'));

                              if (isImage) {
                                subtitleBuffer.writeln(
                                  'URL: ${url.isEmpty ? '(vide)' : url}',
                                );
                              } else {
                                // Les vidéos basées sur VideoAsset peuvent ne pas avoir
                                // d'URL directe (baseVideoUrl). La lecture utilise le
                                // manifest VideoAsset côté frontend.
                                subtitleBuffer.writeln(
                                  'URL: ${url.isEmpty ? '(gérée via VideoAsset)' : url}',
                                );
                              }

                              subtitleBuffer.write(
                                'Ordre: ${sortOrder}  •  ' +
                                    (active ? 'Active' : 'Inactive'),
                              );
                              if (unsupported) {
                                subtitleBuffer.writeln(
                                  '\n[!] Média potentiellement non supporté (URL vide ou invalide)',
                                );
                              }

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(
                                    title.isNotEmpty ? title : url,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    subtitleBuffer.toString(),
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
                                        icon: const Icon(Icons.delete_outline),
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
                              'Vidéos du carrousel landing',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: provider.isSaving
                                ? null
                                : () => _showLandingCarouselVideoDialog(provider),
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (provider.videos.isEmpty)
                        const Text(
                          'Aucune vidéo configurée pour le carrousel landing.',
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
                                          : () => _showLandingCarouselVideoDialog(
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
                                                      'Cette action supprimera cette vidéo du carrousel landing.',
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
                              'Annonces (bande rouge)',
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
                        const Text('Aucune annonce configurée.')
                      else
                        Column(
                          children: provider.announcements.map((a) {
                            final text = (a['text'] ?? '').toString();
                            final active = a['is_active'] == true;
                            final sortOrder = a['sort_order'];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(text),
                                subtitle: Text(
                                  'Ordre: ${sortOrder ?? '-'}  •  ' +
                                      (active ? 'Actif' : 'Inactif'),
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
                      const SizedBox(height: 24),
                      Divider(color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Cartes "Pourquoi créer un compte ?"',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: provider.isSaving
                                ? null
                                : () => _showWhyDialog(provider),
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (provider.whyCards.isEmpty)
                        const Text('Aucune carte configurée.')
                      else
                        Column(
                          children: provider.whyCards.map((w) {
                            final title = (w['title'] ?? '').toString();
                            final subtitle = (w['subtitle'] ?? '').toString();
                            final active = w['is_active'] == true;
                            final sortOrder = w['sort_order'];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(title),
                                subtitle: Text(
                                  '${subtitle.isEmpty ? '' : '$subtitle\n'}Ordre: ${sortOrder ?? '-'}  •  ' +
                                      (active ? 'Active' : 'Inactive'),
                                ),
                                isThreeLine: subtitle.isNotEmpty,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: provider.isSaving
                                          ? null
                                          : () => _showWhyDialog(
                                                provider,
                                                existing: w,
                                              ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: provider.isSaving
                                          ? null
                                          : () => provider.deleteWhyCard(
                                                w['id']?.toString() ?? '',
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
                              'Partenaires (logos sous les programmes)',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: provider.isSaving
                                ? null
                                : () => _showPartnerDialog(provider),
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (provider.partners.isEmpty)
                        const Text('Aucun partenaire configuré.')
                      else
                        Column(
                          children: provider.partners.map((p) {
                            final name = (p['name'] ?? '').toString();
                            final logo = (p['logo_url'] ?? '').toString();
                            final website = (p['website_url'] ?? '').toString();
                            final active = p['is_active'] == true;
                            final sortOrder = p['sort_order'];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(name.isEmpty ? '(Sans nom)' : name),
                                subtitle: Text(
                                  'Logo: ${logo.isEmpty ? '—' : logo}\nSite: ${website.isEmpty ? '—' : website}\nOrdre: ${sortOrder ?? '-'}  •  ' +
                                      (active ? 'Actif' : 'Inactif'),
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: provider.isSaving
                                          ? null
                                          : () => _showPartnerDialog(
                                                provider,
                                                existing: p,
                                              ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: provider.isSaving
                                          ? null
                                          : () => provider.deletePartner(
                                                p['id']?.toString() ?? '',
                                              ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
