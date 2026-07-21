import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Onglet « Coordination » (M3) — le manager/admin publie des diffusions
/// vers les commerciaux, qui sont notifiés et voient l'info dans leur app.
class ManagerAnnouncementsTab extends StatefulWidget {
  /// true pour l'admin (autorise la portée globale « tous les commerciaux »).
  final bool isAdmin;
  const ManagerAnnouncementsTab({super.key, this.isAdmin = false});

  @override
  State<ManagerAnnouncementsTab> createState() =>
      _ManagerAnnouncementsTabState();
}

class _ManagerAnnouncementsTabState extends State<ManagerAnnouncementsTab> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _global = false;
  bool _sending = false;
  String? _feedback;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _feedback = 'Le titre est requis.');
      return;
    }
    setState(() {
      _sending = true;
      _feedback = null;
    });
    try {
      final r = await Supabase.instance.client
          .rpc('app_manager_publish_announcement', params: {
        'p_title': title,
        'p_body': _bodyCtrl.text.trim(),
        'p_scope': (widget.isAdmin && _global) ? 'global' : 'team',
      });
      if (r is Map && r['success'] == true) {
        _titleCtrl.clear();
        _bodyCtrl.clear();
        setState(() => _feedback =
            'Diffusé · ${r['notified'] ?? 0} commercial(aux) notifié(s).');
      } else {
        setState(() => _feedback =
            'Échec : ${(r is Map ? r['error'] : null) ?? 'inconnu'}');
      }
    } catch (e) {
      setState(() => _feedback = 'Erreur : $e');
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Diffuser une information à ${widget.isAdmin ? "vos commerciaux" : "votre équipe"}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(
          controller: _titleCtrl,
          decoration: const InputDecoration(
              labelText: 'Titre', border: OutlineInputBorder()),
          maxLength: 160,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _bodyCtrl,
          decoration: const InputDecoration(
              labelText: 'Message', border: OutlineInputBorder()),
          maxLines: 4,
        ),
        if (widget.isAdmin)
          SwitchListTile(
            title: const Text('Envoyer à TOUS les commerciaux (global)'),
            subtitle: const Text('Sinon : uniquement ceux qui vous sont rattachés'),
            value: _global,
            onChanged: (v) => setState(() => _global = v),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _sending ? null : _publish,
          icon: _sending
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.campaign),
          label: const Text('Diffuser + notifier'),
        ),
        if (_feedback != null) ...[
          const SizedBox(height: 12),
          Text(_feedback!,
              style: TextStyle(
                  color: _feedback!.startsWith('Diffusé') ? Colors.green : Colors.red)),
        ],
      ],
    );
  }
}
