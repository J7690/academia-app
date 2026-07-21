import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Onglet « Mon équipe » + statistiques (M1/M2).
/// Piloté par la RPC `app_manager_team_stats` qui renvoie la portée
/// équipe (manager) ou globale (admin) selon le rôle de l'appelant.
class ManagerTeamTab extends StatefulWidget {
  const ManagerTeamTab({super.key});

  @override
  State<ManagerTeamTab> createState() => _ManagerTeamTabState();
}

class _ManagerTeamTabState extends State<ManagerTeamTab> {
  bool _loading = true;
  String? _error;
  bool _isAdmin = false;
  List<Map<String, dynamic>> _commercials = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Supabase.instance.client.rpc('app_manager_team_stats');
      if (r is Map && r['success'] == true) {
        setState(() {
          _isAdmin = r['is_admin'] == true;
          _commercials = (r['commercials'] as List? ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _loading = false;
        });
      } else {
        setState(() {
          _error = (r is Map ? r['error'] : null)?.toString() ?? 'Erreur';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Erreur : $_error')));
    }
    if (_commercials.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: const [
          SizedBox(height: 120),
          Icon(Icons.groups_outlined, size: 56, color: Colors.grey),
          SizedBox(height: 12),
          Center(child: Text('Aucun commercial dans votre équipe pour le moment')),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_isAdmin)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Vue globale (admin) — tous les commerciaux',
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
            ),
          ..._commercials.map(_tile),
        ],
      ),
    );
  }

  Widget _tile(Map<String, dynamic> c) {
    final active = c['is_active'] == true;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: active ? Colors.green.shade100 : Colors.grey.shade300,
          child: Icon(Icons.person, color: active ? Colors.green : Colors.grey),
        ),
        title: Text(c['email']?.toString() ?? '—',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Code ${c['ref_code'] ?? '—'} · Taux ${c['commission_rate'] ?? '—'}% · '
          '${c['referrals'] ?? 0} filleuls',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${c['commissions'] ?? 0}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const Text('commissions', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
