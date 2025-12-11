import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/hero_render_service.dart';
import 'hero_studio_models.dart';

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
        ...tv.map(
          (r) => _RenderHistoryEntry(
            engine: 'tv',
            status: r.status,
            renderUrl: r.renderUrl ?? '',
            thumbnailUrl: r.thumbnailUrl ?? '',
            createdAt: r.finishedAt ?? r.createdAt,
          ),
        ),
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
      final tvOverlays = await HeroRenderService.getTvTimeline(
        playlistItemId: current.id,
      );
      final mapped = tvOverlays
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

    // Mode TV : on synchronise chaque calque avec hero_overlays_tv
    for (var i = 0; i < layers.length; i++) {
      final l = layers[i];
      final id = l['id']?.toString();
      final type = (l['type'] ?? 'text').toString();
      final sortOrder = (l['sort_order'] is int)
          ? l['sort_order'] as int
          : int.tryParse(l['sort_order']?.toString() ?? '') ?? i;

      double parseSeconds(dynamic v, double fallback) {
        if (v == null) return fallback;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString()) ?? fallback;
      }

      final start = parseSeconds(l['start_at_seconds'], 0.0);
      var end = parseSeconds(l['end_at_seconds'], start + 5.0);
      if (end <= start) {
        end = start + 5.0;
      }

      final text = (l['text'] ?? '').toString();
      final align = (l['align'] ?? 'bottom_left').toString();

      final cfg = <String, dynamic>{
        'text': text,
        'align': align,
      };

      await HeroRenderService.upsertTvOverlay(
        id: id?.isEmpty == true ? null : id,
        playlistItemId: current.id,
        overlayType: type,
        config: cfg,
        startAtSeconds: start,
        endAtSeconds: end,
        sortOrder: sortOrder,
      );
    }

    await _loadCurrentOverlays();
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
    // ignore: avoid_print
    print(
      'HeroStudioScreen._startUnifiedRender: engineMode=$_engineMode '
      'playlistItemId=${_selected?.id} slot=${widget.slot}',
    );
    if (_engineMode == 'tv') {
      await _startTvRender();
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

  Future<void> _startTvRender() async {
    final current = _selected;
    if (current == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // ignore: avoid_print
      print(
        'HeroStudioScreen._startTvRender: playlistItemId=${current.id} slot=${widget.slot}',
      );
      await HeroRenderService.startTvRender(
        playlistItemId: current.id,
        slot: widget.slot,
        meta: <String, dynamic>{'source': 'admin_ui'},
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
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed:
                          _isLoading || _selected == null ? null : _startUnifiedRender,
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Lancer le rendu'),
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
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed:
                          _isLoading || _selected == null ? null : _startUnifiedRender,
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Lancer le rendu'),
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

  const HeroOverlayEditorPanel({
    super.key,
    required this.overlays,
    required this.onOverlaysChanged,
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

    Future<void> applyChanges() async {
      final s = int.tryParse(startController.text.trim()) ?? 0;
      final eRaw = int.tryParse(endController.text.trim());
      final e = eRaw == null || eRaw <= s ? s + 5 : eRaw;
      final type = currentType;
      final align = currentAlign;
      final text = textController.text.trim();

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
          return copy;
        }
        return Map<String, dynamic>.from(l);
      }).toList(growable: false);

      await widget.onOverlaysChanged(
        updatedLayers,
      );
    }

    return Padding(
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
                  items: const [
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
