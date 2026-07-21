import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Onglet admin « Managers » — gestion du cycle de vie des managers :
/// suspendre (login bloqué), bloquer les actions (lecture seule), supprimer
/// (avec reprise transparente de l'équipe : aucun commercial orphelin).
class AdminManagersTab extends StatefulWidget {
  const AdminManagersTab({super.key});

  @override
  State<AdminManagersTab> createState() => _AdminManagersTabState();
}

class _AdminManagersTabState extends State<AdminManagersTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _managers = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Supabase.instance.client.rpc('app_admin_list_managers');
      if (r is Map && r['success'] == true) {
        _managers = (r['managers'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _call(String rpc, Map<String, dynamic> params, String okMsg) async {
    try {
      final r = await Supabase.instance.client.rpc(rpc, params: params);
      final ok = r is Map && r['success'] == true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? okMsg
              : 'Échec : ${(r is Map ? r['error'] : null) ?? 'inconnu'}'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
    _load();
  }

  Future<void> _confirmDelete(Map<String, dynamic> m) async {
    final teamSize = m['team_size'] ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce manager ?'),
        content: Text(
          'Les $teamSize commercial(aux) de son équipe seront repris automatiquement '
          '(rattachés à vous, admin) sans interruption. Le manager perdra l\'accès. '
          'Cette action est réversible sous 60 jours côté support.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _call('app_admin_delete_manager', {'p_manager': m['user_id']},
          'Manager supprimé, équipe reprise.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_managers.isEmpty) {
      return const Center(child: Text('Aucun manager'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: _managers.map((m) {
          final suspended = m['is_suspended'] == true;
          final deleted = m['is_deleted'] == true;
          final active = m['is_active'] == true;
          final blocked = !active;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: deleted
                            ? Colors.grey.shade300
                            : suspended
                                ? Colors.orange.shade100
                                : Colors.green.shade100,
                        child: Icon(Icons.manage_accounts,
                            color: deleted
                                ? Colors.grey
                                : suspended
                                    ? Colors.orange
                                    : Colors.green),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m['display_name']?.toString() ?? m['email']?.toString() ?? '—',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('${m['email'] ?? ''} · ${m['team_size'] ?? 0} commerciaux',
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      if (deleted) const Chip(label: Text('Supprimé'), visualDensity: VisualDensity.compact),
                      if (suspended && !deleted) const Chip(label: Text('Suspendu'), visualDensity: VisualDensity.compact),
                      if (blocked && !suspended && !deleted) const Chip(label: Text('Actions bloquées'), visualDensity: VisualDensity.compact),
                    ],
                  ),
                  if (!deleted)
                    OverflowBar(
                      alignment: MainAxisAlignment.end,
                      children: [
                        if (!suspended)
                          TextButton(
                            onPressed: () => _call('app_admin_suspend_user',
                                {'p_user_id': m['user_id'], 'p_reason': 'admin', 'p_duration_hours': null},
                                'Manager suspendu.'),
                            child: const Text('Suspendre'),
                          )
                        else
                          TextButton(
                            onPressed: () => _call('app_admin_unsuspend_user',
                                {'p_user_id': m['user_id']}, 'Manager réactivé.'),
                            child: const Text('Réactiver'),
                          ),
                        TextButton(
                          onPressed: () => _call('app_admin_set_manager_blocked',
                              {'p_manager': m['user_id'], 'p_blocked': active},
                              active ? 'Actions bloquées.' : 'Actions rétablies.'),
                          child: Text(active ? 'Bloquer actions' : 'Débloquer actions'),
                        ),
                        TextButton(
                          onPressed: () => _confirmDelete(m),
                          child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                        ),
                      ],
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
