import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/content_media_service.dart';

/// Espace commercial : les infos diffusées par son manager (ou l'admin)
/// + la médiathèque mise à sa disposition. Accessible depuis une
/// notification « commercial_broadcast » (routeur) ou depuis son dashboard.
class CommercialManagerInfoScreen extends StatefulWidget {
  const CommercialManagerInfoScreen({super.key});

  @override
  State<CommercialManagerInfoScreen> createState() =>
      _CommercialManagerInfoScreenState();
}

class _CommercialManagerInfoScreenState
    extends State<CommercialManagerInfoScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Espace commercial'),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.campaign), text: 'Infos'),
            Tab(icon: Icon(Icons.perm_media), text: 'Médiathèque'),
          ]),
        ),
        body: const TabBarView(children: [
          _AnnouncementsView(),
          _MediaView(),
        ]),
      ),
    );
  }
}

class _AnnouncementsView extends StatefulWidget {
  const _AnnouncementsView();
  @override
  State<_AnnouncementsView> createState() => _AnnouncementsViewState();
}

class _AnnouncementsViewState extends State<_AnnouncementsView> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Supabase.instance.client
          .rpc('app_commercial_list_announcements');
      if (r is Map && r['success'] == true) {
        _items = (r['announcements'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markRead(String id) async {
    try {
      await Supabase.instance.client.rpc('app_commercial_mark_announcement_read',
          params: {'p_announcement_id': id});
    } catch (_) {}
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return const Center(child: Text('Aucune information pour le moment'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: _items.map((a) {
          final read = a['is_read'] == true;
          return Card(
            color: read ? null : Colors.indigo.shade50,
            child: ListTile(
              leading: Icon(read ? Icons.mark_email_read : Icons.markunread,
                  color: read ? Colors.grey : Colors.indigo),
              title: Text(a['title']?.toString() ?? '—',
                  style: TextStyle(
                      fontWeight: read ? FontWeight.normal : FontWeight.bold)),
              subtitle: Text(a['body']?.toString() ?? ''),
              trailing: read
                  ? null
                  : TextButton(
                      onPressed: () => _markRead(a['id'].toString()),
                      child: const Text('Lu')),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MediaView extends StatefulWidget {
  const _MediaView();
  @override
  State<_MediaView> createState() => _MediaViewState();
}

class _MediaViewState extends State<_MediaView> {
  bool _loading = true;
  List<Map<String, dynamic>> _assets = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Supabase.instance.client
          .rpc('app_commercial_list_content_assets');
      if (r is Map && r['success'] == true) {
        _assets = (r['assets'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String? _mediaUrl(Map<String, dynamic> a) {
    final ext = a['external_url']?.toString();
    if (ext != null && ext.isNotEmpty) return ext;
    final path = a['storage_path']?.toString();
    if (path != null && path.isNotEmpty) {
      // storage_path relatif au bucket marketing (public).
      return Supabase.instance.client.storage.from('marketing').getPublicUrl(path);
    }
    return null;
  }

  Future<void> _download(Map<String, dynamic> a) async {
    final url = _mediaUrl(a);
    if (url == null) return;
    _snack('Téléchargement en cours…');
    try {
      final ok = await ContentMediaService.instance.downloadToGallery(
        assetId: a['id'].toString(),
        url: url,
        title: a['title']?.toString() ?? 'media',
      );
      _snack(ok ? 'Enregistré dans votre galerie' : 'Échec de l\'enregistrement');
    } catch (e) {
      _snack('Erreur : $e');
    }
  }

  Future<void> _share(Map<String, dynamic> a) async {
    final url = _mediaUrl(a);
    if (url == null) return;
    try {
      await ContentMediaService.instance.shareMedia(
        assetId: a['id'].toString(),
        url: url,
        title: a['title']?.toString() ?? 'media',
        description: a['description']?.toString(),
      );
    } catch (e) {
      _snack('Erreur : $e');
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_assets.isEmpty) {
      return const Center(child: Text('Aucun média disponible'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: _assets.map((a) {
          final thumb = a['thumbnail_url']?.toString();
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 170,
                  child: thumb != null && thumb.isNotEmpty
                      ? Image.network(thumb, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 40))
                      : Container(
                          color: Colors.indigo.shade50,
                          child: Icon(
                              a['asset_type'] == 'video'
                                  ? Icons.play_circle
                                  : Icons.description,
                              size: 48)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a['title']?.toString() ?? '—',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      if ((a['description']?.toString() ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(a['description'].toString(),
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ),
                    ],
                  ),
                ),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _download(a),
                      icon: const Icon(Icons.download),
                      label: const Text('Télécharger'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _share(a),
                      icon: const Icon(Icons.share),
                      label: const Text('Partager / Publier'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
