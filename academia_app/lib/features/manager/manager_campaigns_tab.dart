import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Onglet « Campagnes » (M5) — coordination des campagnes de communication.
class ManagerCampaignsTab extends StatefulWidget {
  final bool isAdmin;
  const ManagerCampaignsTab({super.key, this.isAdmin = false});

  @override
  State<ManagerCampaignsTab> createState() => _ManagerCampaignsTabState();
}

class _ManagerCampaignsTabState extends State<ManagerCampaignsTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _campaigns = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Supabase.instance.client.rpc('app_list_campaigns');
      if (r is Map && r['success'] == true) {
        _campaigns = (r['campaigns'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openEditor() async {
    final titleCtrl = TextEditingController();
    final briefCtrl = TextEditingController();
    String status = 'active';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nouvelle campagne',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Titre')),
              TextField(controller: briefCtrl, decoration: const InputDecoration(labelText: 'Brief / consignes'), maxLines: 3),
              Row(children: [
                const Text('Statut : '),
                DropdownButton<String>(
                  value: status,
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('Brouillon')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'archived', child: Text('Archivée')),
                  ],
                  onChanged: (v) => setSheet(() => status = v ?? 'active'),
                ),
              ]),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty) return;
                  await Supabase.instance.client.rpc('app_manager_upsert_campaign', params: {
                    'p_id': null,
                    'p_title': titleCtrl.text.trim(),
                    'p_brief': briefCtrl.text.trim(),
                    'p_status': status,
                    'p_starts_on': null,
                    'p_ends_on': null,
                    'p_scope': 'team',
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Créer'),
              ),
              const SizedBox(height: 8),
            ],
          ),
          ),
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _campaigns.isEmpty
              ? const Center(child: Text('Aucune campagne'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: _campaigns.map((c) {
                      final st = c['status']?.toString() ?? '';
                      return Card(
                        child: ListTile(
                          leading: Icon(Icons.campaign,
                              color: st == 'active' ? Colors.green : Colors.grey),
                          title: Text(c['title']?.toString() ?? '—'),
                          subtitle: Text(c['brief']?.toString() ?? ''),
                          trailing: Chip(label: Text(st)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEditor,
        icon: const Icon(Icons.add),
        label: const Text('Campagne'),
      ),
    );
  }
}
