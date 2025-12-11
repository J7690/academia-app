import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/hero_render_service.dart';
import 'hero_studio_models.dart';
import 'hero_tv_templates_catalog.dart';

class HeroStudioScreen extends StatefulWidget {
  final String slot;

  const HeroStudioScreen({
    super.key,
    required this.slot,
  });

  @override
  State<HeroStudioScreen> createState() => _HeroStudioScreenState();
}

class _HeroStudioScreenState extends State<HeroStudioScreen> {
  bool _isLoading = false;
  String? _error;
  List<HeroPlaylistItem> _items = const <HeroPlaylistItem>[];
  HeroPlaylistItem? _selected;
  HeroRender? _currentRender;
  String _engineMode = 'classic'; // 'classic' ou 'tv'
  String _tvMode = 'classic'; // 'classic' ou 'pro' lorsque _engineMode == 'tv'
  List<Map<String, dynamic>> _currentOverlays = const <Map<String, dynamic>>[];
  List<_RenderHistoryEntry> _renderHistory = const <_RenderHistoryEntry>[];

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  Future<void> _loadRenderHistory() async {
    final current = _selected;
    if (current == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _renderHistory = const <_RenderHistoryEntry>[];
      });
      return;
    }

    try {
      final classic = await HeroRenderService.getHeroRenderHistory(
        playlistItemId: current.id,
      );
      final tv = await HeroRenderService.getTvRenderHistory(
        playlistItemId: current.id,
      );

      final entries = <_RenderHistoryEntry>[
        ...classic.map(
          (r) => _RenderHistoryEntry(
            engine: 'classic',
            status: r.status,
            renderUrl: r.renderUrl ?? '',
            thumbnailUrl: r.thumbnailUrl ?? '',
            createdAt: r.createdAt,
          ),
        ),
        ...tv.map((r) {
          final url = r.renderUrl ?? '';
          String engineLabel;
          if (url.contains('tv_pro_preview_540p')) {
            engineLabel = 'tv_pro_preview';
          } else if (url.contains('tv_pro_final.mp4') || url.contains('tv_pro')) {
            engineLabel = 'tv_pro';
          } else if (url.contains('tv_preview_540p')) {
            engineLabel = 'tv_preview';
          } else {
            engineLabel = 'tv';
          }
          return _RenderHistoryEntry(
            engine: engineLabel,
            status: r.status,
            renderUrl: url,
            thumbnailUrl: r.thumbnailUrl ?? '',
            createdAt: r.finishedAt ?? r.createdAt,
          );
        }),
      ];

      entries.sort((a, b) {
        final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
      if (!mounted) {
        return;
      }
      setState(() {
        _renderHistory = entries;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _renderHistory = const <_RenderHistoryEntry>[];
      });
    }
  }

  Future<void> _loadCurrentOverlays() async {
    final current = _selected;
    if (current == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentOverlays = const <Map<String, dynamic>>[];
      });
      return;
    }

    if (_engineMode == 'classic') {
      final layers = current.overlays?.layers ?? const <Map<String, dynamic>>[];
      if (!mounted) {
        return;
      }
      setState(() {
        _currentOverlays = layers;
      });
      return;
    }

    try {
      // 1) Timeline TV au format JSON (nouvelle API)
      final jsonOverlays = await HeroRenderService.getTvTimelineJsonOverlays(
        playlistItemId: current.id,
      );

      List<Map<String, dynamic>> mapped;

      if (jsonOverlays.isNotEmpty) {
        mapped = jsonOverlays
            .map((raw) {
              final map = Map<String, dynamic>.from(raw);
              final id = map['id']?.toString();
              final type = (map['type'] ?? map['overlay_type'] ?? 'text').toString();

              double parseSeconds(dynamic v, double fallback) {
                if (v == null) return fallback;
                if (v is num) return v.toDouble();
                return double.tryParse(v.toString()) ?? fallback;
              }

              final start = parseSeconds(map['start_at_seconds'], 0.0);
              var end = parseSeconds(map['end_at_seconds'], start + 5.0);
              if (end <= start) {
                end = start + 5.0;
              }

              final text = (map['text'] ?? map['title'] ?? '').toString();
              final align = (map['align'] ?? map['position'] ?? 'bottom_left').toString();

              final sortOrder = map['sort_order'] is int
                  ? map['sort_order'] as int
                  : int.tryParse(map['sort_order']?.toString() ?? '') ?? 0;

              map['id'] = id;
              map['type'] = type;
              map['start_at_seconds'] = start;
              map['end_at_seconds'] = end;
              map['text'] = text;
              map['align'] = align;
              map['sort_order'] = sortOrder;

              return map;
            })
            .toList(growable: false);
      } else {
        // 2) Fallback : ancienne timeline TV basée sur hero_overlays_tv
        final tvOverlays = await HeroRenderService.getTvTimeline(
          playlistItemId: current.id,
        );
        mapped = tvOverlays
            .map((o) => <String, dynamic>{
                  'id': o.id,
                  'type': o.overlayType,
                  'start_at_seconds': o.startAtSeconds,
                  'end_at_seconds': o.endAtSeconds,
                  'text': (o.config['text'] ?? o.config['title'] ?? '').toString(),
                  'align': (o.config['align'] ?? o.config['position'] ?? 'bottom_left')
                      .toString(),
                  'sort_order': o.sortOrder,
                })
            .toList(growable: false);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _currentOverlays = mapped;
      });
    } catch (e) {
      // ignore: avoid_print
      print('HeroStudioScreen._loadCurrentOverlays TV error=$e');
      if (!mounted) {
        return;
      }
      setState(() {
        _currentOverlays = const <Map<String, dynamic>>[];
      });
    }
  }

  Future<void> _saveOverlaysForCurrentEngine(
    List<Map<String, dynamic>> layers,
  ) async {
    final current = _selected;
    if (current == null) return;

    if (_engineMode == 'classic') {
      await HeroRenderService.saveOverlays(
        playlistItemId: current.id,
        overlays: HeroOverlays(layers: layers),
      );
      await _refreshSelectedConfig();
      return;
    }

    // Mode TV : on sauvegarde la timeline complète en JSON (nouvelle API)
    await HeroRenderService.saveTvTimelineJson(
      playlistItemId: current.id,
      overlays: layers,
    );

    await _loadCurrentOverlays();
  }

  Future<void> _applyTvTemplateByCode(String code) async {
    if (_engineMode != 'tv') {
      return;
    }
    final current = _selected;
    if (current == null) {
      return;
    }
    if (current.mediaType.toLowerCase() != 'video') {
      return;
    }

    HeroTvTemplate? template;
    for (final t in kHeroTvTemplates) {
      if (t.code == code) {
        template = t;
        break;
      }
    }
    if (template == null) {
      return;
    }

    final layers = template.overlays
        .map((layer) => Map<String, dynamic>.from(layer))
        .toList(growable: false);

    await _saveOverlaysForCurrentEngine(layers);
  }

  Future<void> _loadPlaylist() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await HeroRenderService.getPlaylist(slot: widget.slot);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        if (_items.isNotEmpty) {
          _selected = _items.first;
          _currentRender = _selected!.lastRender;
        }
      });
      await _loadCurrentOverlays();
      await _loadRenderHistory();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startUnifiedRender() async {
    final current = _selected;
    if (current == null) return;

    final hasBaseVideo = (current.baseVideoUrl != null &&
        current.baseVideoUrl!.trim().isNotEmpty);
    final isVideo = current.mediaType.toLowerCase() == 'video';

    if (!isVideo || !hasBaseVideo) {
      if (!mounted) return;
      setState(() {
        _error =
            'Impossible de lancer un rendu : cet item Hero n\'a pas de vidéo de base configurée.';
      });
      return;
    }

    // ignore: avoid_print
    print(
      'HeroStudioScreen._startUnifiedRender: engineMode=$_engineMode '
      'playlistItemId=${current.id} slot=${widget.slot}',
    );
    if (_engineMode == 'tv') {
      if (_tvMode == 'pro') {
        await _startTvProRender();
      } else {
        await _startTvRender();
      }
    } else {
      await _startRender();
    }
  }

  Future<void> _openEditItemDialog({HeroPlaylistItem? existing}) async {
    final isNew = existing == null;

    final slotController = TextEditingController(
      text: existing?.slot ?? widget.slot,
    );
    final mediaTypeController = TextEditingController(
      text: existing?.mediaType ?? 'video',
    );
    final titleController = TextEditingController(
      text: existing?.title ?? '',
    );
    final subtitleController = TextEditingController(
      text: existing?.subtitle ?? '',
    );
    final sortOrderController = TextEditingController(
      text: existing?.sortOrder.toString() ?? '0',
    );
    bool isActive = existing?.isActive ?? true;
    bool localIsActive = isActive;

    Uint8List? pickedVideoBytes;
    String? pickedVideoFileName;
    String? pickedVideoMimeType;
    Uint8List? pickedImageBytes;
    String? pickedImageFileName;
    String? pickedImageMimeType;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(isNew ? 'Nouvel item Hero' : 'Modifier l\'item Hero'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: slotController,
                      decoration: const InputDecoration(labelText: 'Slot'),
                    ),
                    TextField(
                      controller: mediaTypeController,
                      decoration: const InputDecoration(
                        labelText: 'Type de média (video/image)',
                      ),
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
                            allowedExtensions: const ['mp4', 'mov', 'webm'],
                          );

                          if (result == null || result.files.isEmpty) {
                            return;
                          }

                          final file = result.files.first;
                          final bytes = file.bytes;
                          if (bytes == null) {
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Impossible de lire le contenu du fichier vidéo.',
                                ),
                              ),
                            );
                            return;
                          }

                          setStateDialog(() {
                            pickedVideoBytes = Uint8List.fromList(bytes);
                            pickedVideoFileName = file.name;
                            pickedVideoMimeType = file.extension;
                          });
                        },
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Importer la vidéo'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        pickedVideoFileName != null
                            ? 'Vidéo sélectionnée : $pickedVideoFileName'
                            : (existing?.baseVideoUrl != null &&
                                    existing!.baseVideoUrl!.isNotEmpty
                                ? 'Vidéo existante conservée.'
                                : 'Aucune vidéo sélectionnée.'),
                        style: const TextStyle(fontSize: 12),
                      ),
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
                            allowedExtensions: const ['jpg', 'jpeg', 'png'],
                          );

                          if (result == null || result.files.isEmpty) {
                            return;
                          }

                          final file = result.files.first;
                          final bytes = file.bytes;
                          if (bytes == null) {
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Impossible de lire le contenu du fichier image.',
                                ),
                              ),
                            );
                            return;
                          }

                          setStateDialog(() {
                            pickedImageBytes = Uint8List.fromList(bytes);
                            pickedImageFileName = file.name;
                            pickedImageMimeType = file.extension;
                          });
                        },
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Importer l’image'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        pickedImageFileName != null
                            ? 'Image sélectionnée : $pickedImageFileName'
                            : (existing?.baseImageUrl != null &&
                                    existing!.baseImageUrl!.isNotEmpty
                                ? 'Image existante conservée.'
                                : 'Aucune image sélectionnée.'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Titre'),
                    ),
                    TextField(
                      controller: subtitleController,
                      decoration: const InputDecoration(labelText: 'Sous-titre'),
                    ),
                    TextField(
                      controller: sortOrderController,
                      decoration: const InputDecoration(labelText: 'Ordre'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: localIsActive,
                          onChanged: (v) {
                            if (v == null) return;
                            setStateDialog(() {
                              localIsActive = v;
                            });
                          },
                        ),
                        const Text('Actif'),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: () {
                    isActive = localIsActive;
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) {
      return;
    }
    final finalMediaType = (mediaTypeController.text.trim().isEmpty
            ? (existing?.mediaType ?? 'video')
            : mediaTypeController.text.trim())
        .toLowerCase();
    final willBeActive = isActive;
    final hasExistingVideo = (() {
      final url = existing?.baseVideoUrl;
      if (url == null) return false;
      return url.trim().isNotEmpty;
    })();
    final willUploadVideo =
        pickedVideoBytes != null && pickedVideoFileName != null;

    if (finalMediaType == 'video' && willBeActive && !willUploadVideo && !hasExistingVideo) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pour un item vidéo actif, une vidéo doit être importée ou conservée.',
          ),
        ),
      );
      setState(() {
        _error =
            "[playlist_validation] Une vidéo active doit avoir une URL vidéo de base (base_video_url). Importez une vidéo ou décochez 'Actif' avant d'enregistrer.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sortOrder = int.tryParse(sortOrderController.text.trim());
      String? baseVideoUrl = existing?.baseVideoUrl;
      String? baseImageUrl = existing?.baseImageUrl;

      if (pickedVideoBytes != null && pickedVideoFileName != null) {
        final uploaded = await HeroRenderService.uploadHeroMediaFile(
          bytes: pickedVideoBytes!,
          fileName: pickedVideoFileName!,
          mimeType: pickedVideoMimeType,
          folder: 'videos',
          playlistItemId: existing?.id,
          slot: slotController.text.trim(),
        );
        baseVideoUrl = uploaded ?? baseVideoUrl;
      }

      if (pickedImageBytes != null && pickedImageFileName != null) {
        final uploaded = await HeroRenderService.uploadHeroMediaFile(
          bytes: pickedImageBytes!,
          fileName: pickedImageFileName!,
          mimeType: pickedImageMimeType,
          folder: 'images',
          playlistItemId: existing?.id,
          slot: slotController.text.trim(),
        );
        baseImageUrl = uploaded ?? baseImageUrl;
      }

      final id = await HeroRenderService.upsertPlaylistItem(
        itemId: existing?.id,
        slot: slotController.text.trim(),
        mediaType: mediaTypeController.text.trim().isEmpty
            ? (existing?.mediaType ?? 'video')
            : mediaTypeController.text.trim(),
        baseVideoUrl: baseVideoUrl,
        baseImageUrl: baseImageUrl,
        title: titleController.text.trim().isEmpty
            ? existing?.title
            : titleController.text.trim(),
        subtitle: subtitleController.text.trim().isEmpty
            ? existing?.subtitle
            : subtitleController.text.trim(),
        sortOrder: sortOrder,
        isActive: isActive,
      );

      await _loadPlaylist();

      setState(() {
        if (_items.isEmpty) {
          _selected = null;
          _currentRender = null;
        } else {
          _selected = _items.firstWhere(
            (e) => e.id == id,
            orElse: () => _items.first,
          );
          _currentRender = _selected?.lastRender;
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startTvRender({bool preview = false}) async {
    final current = _selected;
    if (current == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // ignore: avoid_print
      print(
        'HeroStudioScreen._startTvRender: playlistItemId=${current.id} slot=${widget.slot} preview=$preview',
      );
      final meta = <String, dynamic>{'source': 'admin_ui'};
      if (preview) {
        meta['mode'] = 'preview';
      }
      await HeroRenderService.startTvRender(
        playlistItemId: current.id,
        slot: widget.slot,
        meta: meta,
      );
      await _refreshSelectedConfig();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startTvPreviewRender() async {
    if (_tvMode == 'pro') {
      await _startTvProRender(preview: true);
    } else {
      await _startTvRender(preview: true);
    }
  }

  Future<void> _startTvProRender({bool preview = false}) async {
    final current = _selected;
    if (current == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // ignore: avoid_print
      print(
        'HeroStudioScreen._startTvProRender: playlistItemId=${current.id} slot=${widget.slot} preview=$preview',
      );
      final meta = <String, dynamic>{
        'source': 'admin_ui',
        'engine': 'tv_pro',
      };
      if (preview) {
        meta['mode'] = 'preview';
      }
      await HeroRenderService.startTvProRender(
        playlistItemId: current.id,
        slot: widget.slot,
        meta: meta,
      );
      await _refreshSelectedConfig();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshSelectedConfig() async {
    final current = _selected;
    if (current == null) return;
    try {
      final updated = await HeroRenderService.getItemConfig(current.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _selected = updated;
        _currentRender = updated.lastRender;
        final idx = _items.indexWhere((e) => e.id == updated.id);
        if (idx >= 0) {
          final list = _items.toList();
          list[idx] = updated;
          _items = list;
        }
      });
      await _loadCurrentOverlays();
      await _loadRenderHistory();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _startRender() async {
    final current = _selected;
    if (current == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final render = await HeroRenderService.startRender(
        playlistItemId: current.id,
        slot: widget.slot,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _currentRender = render;
      });
      await _refreshSelectedConfig();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Studio Hero / TV (${widget.slot})'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;
          if (isMobile) {
            return _buildMobileLayout();
          }
          return _buildDesktopLayout();
        },
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 280,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      const Text('Playlist'),
                      const Spacer(),
                      IconButton(
                        onPressed: _isLoading ? null : () => _openEditItemDialog(),
                        icon: const Icon(Icons.add),
                        tooltip: 'Ajouter un item',
                      ),
                      IconButton(
                        onPressed: _isLoading ? null : _loadPlaylist,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildPlaylistList(),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                ToggleButtons(
                  isSelected: [
                    _engineMode == 'classic',
                    _engineMode == 'tv',
                  ],
                  onPressed: (index) {
                    setState(() {
                      _engineMode = index == 0 ? 'classic' : 'tv';
                      if (_engineMode != 'tv') {
                        _tvMode = 'classic';
                      }
                    });
                  },
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('Rendu classique'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('Rendu TV'),
                    ),
                  ],
                ),
                if (_engineMode == 'tv') ...[
                  const SizedBox(width: 8),
                  ToggleButtons(
                    isSelected: [
                      _tvMode == 'classic',
                      _tvMode == 'pro',
                    ],
                    onPressed: (index) {
                      setState(() {
                        _tvMode = index == 0 ? 'classic' : 'pro';
                      });
                    },
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('TV Classic'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('TV PRO'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(width: 8),
                if (_engineMode == 'tv')
                  PopupMenuButton<String>(
                    tooltip: 'Appliquer un template TV',
                    icon: const Icon(Icons.movie_filter),
                    onSelected: (code) async {
                      await _applyTvTemplateByCode(code);
                    },
                    itemBuilder: (context) {
                      return kHeroTvTemplates
                          .map(
                            (t) => PopupMenuItem<String>(
                              value: t.code,
                              child: Text(t.label),
                            ),
                          )
                          .toList(growable: false);
                    },
                  ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Builder(
                      builder: (context) {
                        final current = _selected;
                        final canRender = !_isLoading &&
                            current != null &&
                            current.mediaType.toLowerCase() == 'video' &&
                            (current.baseVideoUrl != null &&
                                current.baseVideoUrl!.trim().isNotEmpty);
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (_engineMode == 'tv')
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: OutlinedButton.icon(
                                  onPressed: canRender ? _startTvPreviewRender : null,
                                  icon: const Icon(Icons.visibility),
                                  label: const Text('Prévisualisation TV (540p)'),
                                ),
                              ),
                            ElevatedButton.icon(
                              onPressed: canRender ? _startUnifiedRender : null,
                              icon: const Icon(Icons.play_circle_outline),
                              label: const Text('Lancer le rendu'),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_currentRender != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'Dernier rendu: ${_currentRender!.status}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          SizedBox(
            height: 220,
            child: HeroPreviewPlayer(
              item: _selected,
              render: _currentRender,
            ),
          ),
          SizedBox(
            height: 260,
            child: HeroOverlayEditorPanel(
              overlays: _currentOverlays,
              onOverlaysChanged: (layers) async {
                await _saveOverlaysForCurrentEngine(layers);
              },
              isTvPro: _engineMode == 'tv' && _tvMode == 'pro',
              slot: widget.slot,
              playlistItemId: _selected?.id,
            ),
          ),
          SizedBox(
            height: 120,
            child: HeroTimeline(
              overlays: _currentOverlays,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'Historique des rendus',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          SizedBox(
            height: 240,
            child: HeroRenderHistoryPanel(
              items: _renderHistory,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        SizedBox(
          width: 280,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    const Text('Playlist'),
                    const Spacer(),
                    IconButton(
                      onPressed: _isLoading ? null : () => _openEditItemDialog(),
                      icon: const Icon(Icons.add),
                      tooltip: 'Ajouter un item',
                    ),
                    IconButton(
                      onPressed: _isLoading ? null : _loadPlaylist,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildPlaylistList(),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    ToggleButtons(
                      isSelected: [
                        _engineMode == 'classic',
                        _engineMode == 'tv',
                      ],
                      onPressed: (index) {
                        setState(() {
                          _engineMode = index == 0 ? 'classic' : 'tv';
                          if (_engineMode != 'tv') {
                            _tvMode = 'classic';
                          }
                        });
                      },
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('Rendu classique'),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('Rendu TV'),
                        ),
                      ],
                    ),
                    if (_engineMode == 'tv') ...[
                      const SizedBox(width: 8),
                      ToggleButtons(
                        isSelected: [
                          _tvMode == 'classic',
                          _tvMode == 'pro',
                        ],
                        onPressed: (index) {
                          setState(() {
                            _tvMode = index == 0 ? 'classic' : 'pro';
                          });
                        },
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('TV Classic'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('TV PRO'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(width: 16),
                    if (_engineMode == 'tv')
                      PopupMenuButton<String>(
                        tooltip: 'Appliquer un template TV',
                        icon: const Icon(Icons.movie_filter),
                        onSelected: (code) async {
                          await _applyTvTemplateByCode(code);
                        },
                        itemBuilder: (context) {
                          return kHeroTvTemplates
                              .map(
                                (t) => PopupMenuItem<String>(
                                  value: t.code,
                                  child: Text(t.label),
                                ),
                              )
                              .toList(growable: false);
                        },
                      ),
                    Builder(
                      builder: (context) {
                        final current = _selected;
                        final canRender = !_isLoading &&
                            current != null &&
                            current.mediaType.toLowerCase() == 'video' &&
                            (current.baseVideoUrl != null &&
                                current.baseVideoUrl!.trim().isNotEmpty);
                        return Row(
                          children: [
                            if (_engineMode == 'tv')
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: OutlinedButton.icon(
                                  onPressed: canRender ? _startTvPreviewRender : null,
                                  icon: const Icon(Icons.visibility),
                                  label: const Text('Prévisualisation TV (540p)'),
                                ),
                              ),
                            ElevatedButton.icon(
                              onPressed: canRender ? _startUnifiedRender : null,
                              icon: const Icon(Icons.play_circle_outline),
                              label: const Text('Lancer le rendu'),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    if (_currentRender != null)
                      Text(
                        'Dernier rendu: ${_currentRender!.status}',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: HeroPreviewPlayer(
                        item: _selected,
                        render: _currentRender,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 2,
                      child: HeroOverlayEditorPanel(
                        overlays: _currentOverlays,
                        onOverlaysChanged: (layers) async {
                          await _saveOverlaysForCurrentEngine(layers);
                        },
                        isTvPro: _engineMode == 'tv' && _tvMode == 'pro',
                        slot: widget.slot,
                        playlistItemId: _selected?.id,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 120,
                child: HeroTimeline(
                  overlays: _currentOverlays,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        'Historique des rendus',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: HeroRenderHistoryPanel(
                        items: _renderHistory,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistList() {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const Center(
        child: Text('Aucun item Hero configuré pour ce slot.'),
      );
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _items[index];
        final isSelected = _selected?.id == item.id;
        return ListTile(
          title: Text(item.title ?? '(Sans titre)'),
          subtitle: Text('${item.mediaType} · slot=${item.slot}'),
          selected: isSelected,
          trailing: PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') {
                await _openEditItemDialog(existing: item);
              } else if (value == 'deactivate') {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                try {
                  await HeroRenderService.deactivatePlaylistItem(item);
                  await _loadPlaylist();
                } catch (e) {
                  setState(() {
                    _error = e.toString();
                  });
                } finally {
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                }
              } else if (value == 'delete') {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                try {
                  await HeroRenderService.deletePlaylistItem(item.id);
                  await _loadPlaylist();
                } catch (e) {
                  setState(() {
                    _error = e.toString();
                  });
                } finally {
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: Text('Modifier'),
              ),
              PopupMenuItem(
                value: 'deactivate',
                child: Text('Désactiver'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('Supprimer'),
              ),
            ],
          ),
          onTap: () {
            setState(() {
              _selected = item;
              _currentRender = item.lastRender;
            });
            _loadCurrentOverlays();
            _loadRenderHistory();
          },
        );
      },
    );
  }
}

class _RenderHistoryEntry {
  final String engine;
  final String status;
  final String renderUrl;
  final String thumbnailUrl;
  final DateTime? createdAt;

  const _RenderHistoryEntry({
    required this.engine,
    required this.status,
    required this.renderUrl,
    required this.thumbnailUrl,
    required this.createdAt,
  });
}

class HeroRenderHistoryPanel extends StatelessWidget {
  final List<_RenderHistoryEntry> items;

  const HeroRenderHistoryPanel({super.key, required this.items});

  String _normalizeStatus(String status) {
    final lower = status.toLowerCase();
    if (lower == 'done') return 'success';
    return lower;
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text('Aucun rendu enregistré pour cet item.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          final statusLabel = _normalizeStatus(item.status);
          final ts = item.createdAt?.toLocal().toString().split('.').first ?? '';

          return ListTile(
            leading: item.thumbnailUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      item.thumbnailUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, _, __) => const Icon(Icons.image_not_supported),
                    ),
                  )
                : const Icon(Icons.movie_creation_outlined),
            title: Text(
              '${item.engine} · $statusLabel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ts.isNotEmpty)
                  Text(
                    ts,
                    style: const TextStyle(fontSize: 11),
                  ),
                if (item.renderUrl.isNotEmpty)
                  Text(
                    item.renderUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class HeroTimeline extends StatelessWidget {
  final List<Map<String, dynamic>> overlays;

  const HeroTimeline({super.key, required this.overlays});

  @override
  Widget build(BuildContext context) {
    if (overlays.isEmpty) {
      return const Center(
        child: Text('Aucun overlay configuré pour cet item.'),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final layer = overlays[index];
          final label = layer['id']?.toString() ?? 'Calque ${index + 1}';
          final start = layer['start_at_seconds'] ?? 0;
          final end = layer['end_at_seconds'] ?? 0;
          return Container(
            width: 160,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.blueGrey.shade800,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  't=$start → $end s',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (layer['type'] ?? 'layer').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: overlays.length,
      ),
    );
  }
}

class HeroOverlayEditorPanel extends StatefulWidget {
  final List<Map<String, dynamic>> overlays;
  final Future<void> Function(List<Map<String, dynamic>> overlays)
      onOverlaysChanged;
  final bool isTvPro;
  final String? slot;
  final String? playlistItemId;

  const HeroOverlayEditorPanel({
    super.key,
    required this.overlays,
    required this.onOverlaysChanged,
    this.isTvPro = false,
    this.slot,
    this.playlistItemId,
  });

  @override
  State<HeroOverlayEditorPanel> createState() => _HeroOverlayEditorPanelState();
}

class _HeroOverlayEditorPanelState extends State<HeroOverlayEditorPanel> {
  int _selectedIndex = 0;
  String? _selectedType;
  String? _selectedAlign;

  @override
  Widget build(BuildContext context) {
    final overlays = widget.overlays;
    if (overlays.isEmpty) {
      return const Center(
        child: Text('Aucun calque à éditer.'),
      );
    }

    if (_selectedIndex >= overlays.length) {
      _selectedIndex = overlays.length - 1;
    }

    final layer = overlays[_selectedIndex];
    final start = (layer['start_at_seconds'] ?? 0).toString();
    final end = (layer['end_at_seconds'] ?? 0).toString();
    final rawText = (layer['text'] ?? layer['title'] ?? '').toString();

    final sourceUrl = (layer['source_url'] ?? layer['url'] ?? layer['src'] ?? '').toString();
    final xValue = layer['x']?.toString() ?? '';
    final yValue = layer['y']?.toString() ?? '';
    final transform = layer['transform'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(layer['transform'] as Map)
        : <String, dynamic>{};
    final opacityValue = (transform['opacity'] ?? layer['opacity'])?.toString() ?? '';
    final animation = layer['animation'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(layer['animation'] as Map)
        : <String, dynamic>{};
    final animationModeValue = (animation['mode'] ?? '').toString();
    final transformScaleValue = transform['scale']?.toString() ?? '';
    final transformRotateValue = transform['rotate']?.toString() ?? '';
    final backgroundModeValue = (layer['background_mode'] ?? '').toString().toLowerCase();
    final colorizeCurves = layer['colorize_curves'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(layer['colorize_curves'] as Map)
        : <String, dynamic>{};
    final colorizeR = (colorizeCurves['r'] ?? '').toString();
    final colorizeG = (colorizeCurves['g'] ?? '').toString();
    final colorizeB = (colorizeCurves['b'] ?? '').toString();
    final pipOptions = layer['pip_options'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(layer['pip_options'] as Map)
        : <String, dynamic>{};
    final pipScaleValue = pipOptions['scale']?.toString() ?? '';
    final pipBorderWidthValue = pipOptions['border_width']?.toString() ?? '';
    final pipBorderColorValue = pipOptions['border_color']?.toString() ?? '';
    final pipCornerRadiusValue = pipOptions['corner_radius']?.toString() ?? '';
    final pipRoundedValue = (pipOptions['rounded_corners']?.toString() ?? '');
    final pipShadowValue = (pipOptions['shadow']?.toString() ?? '');
    final pipShadowDxValue = pipOptions['shadow_dx']?.toString() ?? '';
    final pipShadowDyValue = pipOptions['shadow_dy']?.toString() ?? '';

    final currentType = (() {
      final base = (_selectedType ?? (layer['type'] ?? 'text')).toString();
      return base.isEmpty ? 'text' : base;
    })();

    final currentAlign = (() {
      final base = (_selectedAlign ?? (layer['align'] ?? layer['position'] ?? 'bottom_left')).toString();
      return base.isEmpty ? 'bottom_left' : base;
    })();

    final startController = TextEditingController(text: start);
    final endController = TextEditingController(text: end);
    final textController = TextEditingController(text: rawText);
    final sourceUrlController = TextEditingController(text: sourceUrl);
    final xController = TextEditingController(text: xValue);
    final yController = TextEditingController(text: yValue);
    final opacityController = TextEditingController(text: opacityValue);
    final animationModeController = TextEditingController(text: animationModeValue);
    final transformScaleController = TextEditingController(text: transformScaleValue);
    final transformRotateController = TextEditingController(text: transformRotateValue);
    final backgroundModeController = TextEditingController(text: backgroundModeValue);
    final colorizeRController = TextEditingController(text: colorizeR);
    final colorizeGController = TextEditingController(text: colorizeG);
    final colorizeBController = TextEditingController(text: colorizeB);
    final pipScaleController = TextEditingController(text: pipScaleValue);
    final pipBorderWidthController = TextEditingController(text: pipBorderWidthValue);
    final pipBorderColorController = TextEditingController(text: pipBorderColorValue);
    final pipCornerRadiusController = TextEditingController(text: pipCornerRadiusValue);
    final pipRoundedController = TextEditingController(text: pipRoundedValue);
    final pipShadowController = TextEditingController(text: pipShadowValue);
    final pipShadowDxController = TextEditingController(text: pipShadowDxValue);
    final pipShadowDyController = TextEditingController(text: pipShadowDyValue);

    Future<void> applyChanges() async {
      final s = int.tryParse(startController.text.trim()) ?? 0;
      final eRaw = int.tryParse(endController.text.trim());
      final e = eRaw == null || eRaw <= s ? s + 5 : eRaw;
      final type = currentType;
      final align = currentAlign;
      final text = textController.text.trim();

      final srcText = sourceUrlController.text.trim();
      final xText = xController.text.trim();
      final yText = yController.text.trim();
      final opacityText = opacityController.text.trim();
      final animModeText = animationModeController.text.trim();
      final scaleText = transformScaleController.text.trim();
      final rotateText = transformRotateController.text.trim();
      final bgModeText = backgroundModeController.text.trim();
      final colorizeRText = colorizeRController.text.trim();
      final colorizeGText = colorizeGController.text.trim();
      final colorizeBText = colorizeBController.text.trim();
      final pipScaleText = pipScaleController.text.trim();
      final pipBorderWidthText = pipBorderWidthController.text.trim();
      final pipBorderColorText = pipBorderColorController.text.trim();
      final pipCornerRadiusText = pipCornerRadiusController.text.trim();
      final pipRoundedText = pipRoundedController.text.trim();
      final pipShadowText = pipShadowController.text.trim();
      final pipShadowDxText = pipShadowDxController.text.trim();
      final pipShadowDyText = pipShadowDyController.text.trim();

      final xParsed = double.tryParse(xText);
      final yParsed = double.tryParse(yText);
      final opacityParsed = double.tryParse(opacityText);
      final scaleParsed = double.tryParse(scaleText);
      final rotateParsed = double.tryParse(rotateText);
      final pipScaleParsed = double.tryParse(pipScaleText);
      final pipBorderWidthParsed = double.tryParse(pipBorderWidthText);
      final pipCornerRadiusParsed = double.tryParse(pipCornerRadiusText);
      final pipShadowDxParsed = double.tryParse(pipShadowDxText);
      final pipShadowDyParsed = double.tryParse(pipShadowDyText);

      final updatedLayers = overlays.map<Map<String, dynamic>>((l) {
        if (identical(l, layer)) {
          final copy = Map<String, dynamic>.from(l);
          copy['start_at_seconds'] = s;
          copy['end_at_seconds'] = e;
          copy['type'] = type;
          copy['align'] = align;
          if (text.isNotEmpty) {
            copy['text'] = text;
          }

          if (widget.isTvPro) {
            if (srcText.isNotEmpty) {
              copy['source_url'] = srcText;
            } else {
              copy.remove('source_url');
            }

            if (xParsed != null && yParsed != null) {
              copy['x'] = xParsed;
              copy['y'] = yParsed;
            } else {
              copy.remove('x');
              copy.remove('y');
            }

            final transformMap = copy['transform'] is Map<String, dynamic>
                ? Map<String, dynamic>.from(copy['transform'] as Map)
                : <String, dynamic>{};
            if (scaleParsed != null) {
              transformMap['scale'] = scaleParsed;
            } else {
              transformMap.remove('scale');
            }
            if (rotateParsed != null) {
              transformMap['rotate'] = rotateParsed;
            } else {
              transformMap.remove('rotate');
            }
            if (opacityParsed != null) {
              transformMap['opacity'] = opacityParsed;
            } else {
              transformMap.remove('opacity');
            }
            if (transformMap.isEmpty) {
              copy.remove('transform');
            } else {
              copy['transform'] = transformMap;
            }
            copy.remove('opacity');

            if (animModeText.isNotEmpty) {
              copy['animation'] = <String, dynamic>{
                'mode': animModeText,
              };
            } else {
              copy.remove('animation');
            }

            if (type == 'background') {
              if (bgModeText.isNotEmpty) {
                copy['background_mode'] = bgModeText.toLowerCase();
              } else {
                copy.remove('background_mode');
              }

              final curves = <String, dynamic>{};
              if (colorizeRText.isNotEmpty) {
                curves['r'] = colorizeRText;
              }
              if (colorizeGText.isNotEmpty) {
                curves['g'] = colorizeGText;
              }
              if (colorizeBText.isNotEmpty) {
                curves['b'] = colorizeBText;
              }
              if (curves.isEmpty) {
                copy.remove('colorize_curves');
              } else {
                copy['colorize_curves'] = curves;
              }
            }

            if (type == 'pip') {
              final pip = copy['pip_options'] is Map<String, dynamic>
                  ? Map<String, dynamic>.from(copy['pip_options'] as Map)
                  : <String, dynamic>{};
              if (pipScaleParsed != null) {
                pip['scale'] = pipScaleParsed;
              } else {
                pip.remove('scale');
              }
              if (pipBorderWidthParsed != null) {
                pip['border_width'] = pipBorderWidthParsed;
              } else {
                pip.remove('border_width');
              }
              if (pipBorderColorText.isNotEmpty) {
                pip['border_color'] = pipBorderColorText;
              } else {
                pip.remove('border_color');
              }
              if (pipCornerRadiusParsed != null) {
                pip['corner_radius'] = pipCornerRadiusParsed;
              } else {
                pip.remove('corner_radius');
              }
              if (pipRoundedText.isNotEmpty) {
                final v = pipRoundedText.toLowerCase();
                final b = v == 'true' || v == '1' || v == 'yes';
                pip['rounded_corners'] = b;
              } else {
                pip.remove('rounded_corners');
              }
              if (pipShadowText.isNotEmpty) {
                final v = pipShadowText.toLowerCase();
                final b = v == 'true' || v == '1' || v == 'yes';
                pip['shadow'] = b;
              } else {
                pip.remove('shadow');
              }
              if (pipShadowDxParsed != null) {
                pip['shadow_dx'] = pipShadowDxParsed;
              } else {
                pip.remove('shadow_dx');
              }
              if (pipShadowDyParsed != null) {
                pip['shadow_dy'] = pipShadowDyParsed;
              } else {
                pip.remove('shadow_dy');
              }
              if (pip.isEmpty) {
                copy.remove('pip_options');
              } else {
                copy['pip_options'] = pip;
              }
            }
          }
          return copy;
        }
        return Map<String, dynamic>.from(l);
      }).toList(growable: false);

      await widget.onOverlaysChanged(
        updatedLayers,
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          DropdownButton<int>(
            value: _selectedIndex,
            items: List.generate(overlays.length, (index) {
              final l = overlays[index];
              final label = l['id']?.toString() ?? 'Calque ${index + 1}';
              return DropdownMenuItem<int>(
                value: index,
                child: Text(label),
              );
            }),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedIndex = value;
                _selectedType = null;
                _selectedAlign = null;
              });
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: currentType,
                  items: widget.isTvPro
                      ? const [
                          DropdownMenuItem(value: 'text', child: Text('Texte')),
                          DropdownMenuItem(value: 'lower_third', child: Text('Bandeau bas')),
                          DropdownMenuItem(value: 'ticker', child: Text('Ticker TV')),
                          DropdownMenuItem(value: 'background', child: Text('Background')),
                          DropdownMenuItem(value: 'image', child: Text('Image')),
                          DropdownMenuItem(value: 'video', child: Text('Vidéo')),
                          DropdownMenuItem(value: 'pip', child: Text('PIP')),
                        ]
                      : const [
                          DropdownMenuItem(value: 'text', child: Text('Texte')),
                          DropdownMenuItem(value: 'lower_third', child: Text('Bandeau bas')),
                          DropdownMenuItem(value: 'ticker', child: Text('Ticker TV')),
                        ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedType = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: currentAlign,
                  items: const [
                    DropdownMenuItem(value: 'top_left', child: Text('Haut gauche')), 
                    DropdownMenuItem(value: 'top_right', child: Text('Haut droite')), 
                    DropdownMenuItem(value: 'bottom_left', child: Text('Bas gauche')), 
                    DropdownMenuItem(value: 'bottom_right', child: Text('Bas droite')), 
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedAlign = value;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: textController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Texte',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: startController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Début (s)',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: endController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Fin (s)',
            ),
          ),
          if (widget.isTvPro) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: sourceUrlController,
                    decoration: const InputDecoration(
                      labelText: 'URL média (source_url)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: widget.playlistItemId == null
                      ? null
                      : () async {
                          final playlistItemId = widget.playlistItemId;
                          final slot = widget.slot;
                          if (playlistItemId == null) {
                            return;
                          }
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
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Impossible de lire le fichier sélectionné.'),
                              ),
                            );
                            return;
                          }
                          try {
                            final uploaded = await HeroRenderService.uploadHeroMediaFile(
                              bytes: Uint8List.fromList(bytes),
                              fileName: file.name,
                              mimeType: file.extension,
                              folder: 'tv_pro_overlays',
                              playlistItemId: playlistItemId,
                              slot: slot,
                            );
                            if (uploaded == null || uploaded.isEmpty) {
                              return;
                            }
                            final currentOverlays = widget.overlays;
                            if (_selectedIndex >= currentOverlays.length) {
                              return;
                            }
                            final target = currentOverlays[_selectedIndex];
                            final updatedLayers = currentOverlays
                                .map<Map<String, dynamic>>((l) {
                                  if (identical(l, target)) {
                                    final copy = Map<String, dynamic>.from(l);
                                    copy['source_url'] = uploaded;
                                    return copy;
                                  }
                                  return Map<String, dynamic>.from(l);
                                })
                                .toList(growable: false);
                            await widget.onOverlaysChanged(updatedLayers);
                          } catch (e) {
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Importer'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: xController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Position X',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: yController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Position Y',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: opacityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Opacité (0-1)',
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: applyChanges,
              child: const Text('Appliquer overlay'),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class HeroPreviewPlayer extends StatelessWidget {
  final HeroPlaylistItem? item;
  final HeroRender? render;

  const HeroPreviewPlayer({
    super.key,
    required this.item,
    required this.render,
  });

  @override
  Widget build(BuildContext context) {
    final baseImage = item?.baseImageUrl;
    final renderThumb = render?.thumbnailUrl;
    final displayUrl = (renderThumb != null && renderThumb.isNotEmpty)
        ? renderThumb
        : (baseImage != null && baseImage.isNotEmpty)
            ? baseImage
            : null;

    return Center(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          children: [
            Positioned.fill(
              child: displayUrl != null
                  ? Image.network(
                      displayUrl,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.black12,
                    ),
            ),
            Positioned(
              left: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item?.title ?? 'Hero Studio',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (item?.subtitle != null && item!.subtitle!.isNotEmpty)
                    Text(
                      item!.subtitle!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
