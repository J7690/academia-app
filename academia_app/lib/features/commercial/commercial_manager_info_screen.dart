import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> _logAccess(String id, String action) async {
    try {
      await Supabase.instance.client.rpc('app_log_content_asset_access',
          params: {'p_asset': id, 'p_action': action});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_assets.isEmpty) {
      return const Center(child: Text('Aucun média disponible'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(12),
        childAspectRatio: 0.85,
        children: _assets.map((a) {
          final thumb = a['thumbnail_url']?.toString();
          return InkWell(
            onTap: () => _logAccess(a['id'].toString(), 'view'),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: thumb != null && thumb.isNotEmpty
                        ? Image.network(thumb, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 40))
                        : Container(
                            color: Colors.indigo.shade50,
                            child: Icon(
                                a['asset_type'] == 'video'
                                    ? Icons.play_circle
                                    : Icons.description,
                                size: 40)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(a['title']?.toString() ?? '—',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
