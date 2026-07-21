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
    return Scaffold(
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        icon: const Icon(Icons.person_add),
        label: const Text('Créer un commercial'),
      ),
    );
  }

  Widget _buildBody() {
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
          SizedBox(height: 8),
          Center(child: Text('Utilisez le bouton ci-dessous pour en créer un',
              style: TextStyle(color: Colors.grey))),
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
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _openCreateSheet() async {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final pwdCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: '5');
    bool busy = false;
    String? feedback;

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Créer un commercial',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('Le commercial recevra un e-mail pour définir son mot de passe.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom complet')),
              TextField(controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail')),
              TextField(controller: pwdCtrl,
                  decoration: const InputDecoration(labelText: 'Mot de passe temporaire')),
              TextField(controller: rateCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Taux de commission (%)')),
              const SizedBox(height: 12),
              if (feedback != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(feedback!,
                      style: TextStyle(
                          color: feedback!.startsWith('OK') ? Colors.green : Colors.red)),
                ),
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final email = emailCtrl.text.trim();
                        final pwd = pwdCtrl.text.trim();
                        if (email.isEmpty || pwd.length < 6) {
                          setSheet(() => feedback = 'E-mail requis et mot de passe ≥ 6 caractères.');
                          return;
                        }
                        setSheet(() { busy = true; feedback = null; });
                        try {
                          final res = await Supabase.instance.client.functions.invoke(
                            'manager-create-commercial-account',
                            body: {
                              'email': email,
                              'password': pwd,
                              'full_name': nameCtrl.text.trim(),
                              'commission_rate': double.tryParse(rateCtrl.text.trim()) ?? 5.0,
                            },
                          );
                          final data = res.data;
                          if (data is Map && data['success'] == true) {
                            if (ctx.mounted) Navigator.pop(ctx);
                          } else {
                            setSheet(() {
                              busy = false;
                              feedback = 'Échec : ${(data is Map ? data['error'] : null) ?? 'inconnu'}';
                            });
                          }
                        } catch (e) {
                          setSheet(() { busy = false; feedback = 'Erreur : $e'; });
                        }
                      },
                icon: busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: const Text('Créer le commercial'),
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
