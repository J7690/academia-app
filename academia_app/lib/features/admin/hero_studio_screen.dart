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

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  Future<void> _loadPlaylist() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await HeroRenderService.getPlaylist(slot: widget.slot);
      setState(() {
        _items = items;
        if (_items.isNotEmpty) {
          _selected = _items.first;
          _currentRender = _selected!.lastRender;
        }
      });
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

  Future<void> _refreshSelectedConfig() async {
    final current = _selected;
    if (current == null) return;
    try {
      final updated = await HeroRenderService.getItemConfig(current.id);
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
    } catch (e) {
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
      setState(() {
        _currentRender = render;
      });
      await _refreshSelectedConfig();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hero Studio Télé (${widget.slot})'),
      ),
      body: Row(
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
                      ElevatedButton.icon(
                        onPressed: _isLoading || _selected == null ? null : _startRender,
                        icon: const Icon(Icons.movie_creation_outlined),
                        label: const Text('Lancer le rendu Hero'),
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
                          item: _selected,
                          onOverlaysChanged: (ov) async {
                            final current = _selected;
                            if (current == null) return;
                            await HeroRenderService.saveOverlays(
                              playlistItemId: current.id,
                              overlays: ov,
                            );
                            await _refreshSelectedConfig();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 120,
                  child: HeroTimeline(
                    item: _selected,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
          onTap: () {
            setState(() {
              _selected = item;
              _currentRender = item.lastRender;
            });
          },
        );
      },
    );
  }
}

class HeroTimeline extends StatelessWidget {
  final HeroPlaylistItem? item;

  const HeroTimeline({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final overlays = item?.overlays?.layers ?? const <Map<String, dynamic>>[];
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
  final HeroPlaylistItem? item;
  final Future<void> Function(HeroOverlays overlays) onOverlaysChanged;

  const HeroOverlayEditorPanel({
    super.key,
    required this.item,
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
    final overlays = widget.item?.overlays?.layers ?? const <Map<String, dynamic>>[];
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
        HeroOverlays(layers: updatedLayers),
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
