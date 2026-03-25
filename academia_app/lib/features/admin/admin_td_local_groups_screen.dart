import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/td_theme.dart';

/// Admin — Dashboard groupes locaux : voir, filtrer, assigner enseignant.
class AdminTdLocalGroupsScreen extends StatefulWidget {
  const AdminTdLocalGroupsScreen({super.key});

  @override
  State<AdminTdLocalGroupsScreen> createState() => _AdminTdLocalGroupsScreenState();
}

class _AdminTdLocalGroupsScreenState extends State<AdminTdLocalGroupsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _groups = [];
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client.rpc('app_td_admin_list_local_groups', params: {
        'p_status': _filterStatus,
        'p_city': null,
      });
      if (res is List) {
        _groups = res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('[AdminTdLocalGroups] load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TdTheme.scaffoldBg,
      appBar: AppBar(
        elevation: 0, centerTitle: false,
        title: const Text('Groupes Locaux — Admin'),
        foregroundColor: Colors.white,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: TdTheme.adminTdGradient))),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Actualiser'),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              const Text('Statut : ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Expanded(child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _FilterChip(label: 'Tous', selected: _filterStatus == null, onTap: () { setState(() => _filterStatus = null); _load(); }),
                  _FilterChip(label: 'En formation', selected: _filterStatus == 'forming', onTap: () { setState(() => _filterStatus = 'forming'); _load(); }),
                  _FilterChip(label: 'Confirmé', selected: _filterStatus == 'confirmed', onTap: () { setState(() => _filterStatus = 'confirmed'); _load(); }),
                  _FilterChip(label: 'Actif', selected: _filterStatus == 'active', onTap: () { setState(() => _filterStatus = 'active'); _load(); }),
                  _FilterChip(label: 'Terminé', selected: _filterStatus == 'completed', onTap: () { setState(() => _filterStatus = 'completed'); _load(); }),
                ]),
              )),
            ]),
          ),

          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              _StatCard('Total', '${_groups.length}', TdTheme.adminTdPrimary),
              const SizedBox(width: 8),
              _StatCard('En formation', '${_groups.where((g) => g['status'] == 'forming').length}', TdTheme.warning),
              const SizedBox(width: 8),
              _StatCard('Sans enseignant', '${_groups.where((g) => g['assigned_teacher_id'] == null).length}', TdTheme.error),
            ]),
          ),
          const SizedBox(height: 8),

          // Groups list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _groups.isEmpty
                    ? const Center(child: Text('Aucun groupe', style: TextStyle(color: Color(0xFF9E9E9E))))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _groups.length,
                          itemBuilder: (context, index) {
                            final g = _groups[index];
                            return _AdminGroupCard(
                              group: g,
                              onAssignTeacher: () => _showAssignTeacherDialog(g),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showAssignTeacherDialog(Map<String, dynamic> group) {
    final groupId = group['id']?.toString() ?? '';
    final teacherIdCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Affecter un enseignant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Groupe : ${group['subject']} — ${group['neighborhood'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 13)),
          Text('${group['member_count'] ?? group['current_members'] ?? 0} membres',
              style: const TextStyle(fontSize: 12, color: Color(0xFF757575))),
          const SizedBox(height: 16),
          TextField(
            controller: teacherIdCtrl,
            decoration: const InputDecoration(
              labelText: 'ID de l\'enseignant (UUID)',
              hintText: 'Collez l\'UUID de l\'enseignant',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Copiez l\'UUID depuis l\'onglet Enseignants.', style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TdTheme.adminTdPrimary),
            onPressed: () async {
              final teacherId = teacherIdCtrl.text.trim();
              if (teacherId.isEmpty) return;
              Navigator.of(ctx).pop();
              try {
                await Supabase.instance.client.rpc('app_td_admin_assign_teacher_to_group', params: {
                  'p_group_id': groupId,
                  'p_teacher_id': teacherId,
                });
                _load();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enseignant affecté ✓')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
              }
            },
            child: const Text('Affecter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? TdTheme.adminTdPrimary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? TdTheme.adminTdPrimary : const Color(0xFFBDBDBD)),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? Colors.white : const Color(0xFF616161))),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF757575))),
      ]),
    ));
  }
}

class _AdminGroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final VoidCallback onAssignTeacher;
  const _AdminGroupCard({required this.group, required this.onAssignTeacher});

  @override
  Widget build(BuildContext context) {
    final subject = (group['subject'] ?? '').toString();
    final neighborhood = group['neighborhood']?.toString();
    final status = (group['status'] ?? 'forming').toString();
    final memberCount = (group['member_count'] as int?) ?? (group['current_members'] as int?) ?? 0;
    final maxMembers = (group['max_members'] as int?) ?? 8;
    final teacherName = group['teacher_name']?.toString();
    final hasTeacher = group['assigned_teacher_id'] != null;

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'forming': statusColor = TdTheme.warning; statusLabel = 'En formation'; break;
      case 'confirmed': statusColor = TdTheme.info; statusLabel = 'Confirmé'; break;
      case 'active': statusColor = TdTheme.success; statusLabel = 'Actif'; break;
      case 'completed': statusColor = const Color(0xFF9E9E9E); statusLabel = 'Terminé'; break;
      default: statusColor = const Color(0xFF9E9E9E); statusLabel = status;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: !hasTeacher ? TdTheme.error.withAlpha(80) : const Color(0xFFE0E0E0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(subject, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            if (neighborhood != null) Text('📍 $neighborhood', style: const TextStyle(fontSize: 11, color: Color(0xFF757575))),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withAlpha(20), borderRadius: BorderRadius.circular(8)),
            child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text('$memberCount/$maxMembers membres', style: const TextStyle(fontSize: 12, color: Color(0xFF757575))),
          const Spacer(),
          if (hasTeacher && teacherName != null)
            Row(children: [
              const Icon(Icons.person, size: 14, color: Color(0xFF2E7D32)),
              const SizedBox(width: 4),
              Text(teacherName, style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32))),
            ])
          else
            ElevatedButton.icon(
              onPressed: onAssignTeacher,
              icon: const Icon(Icons.person_add, size: 16),
              label: const Text('Affecter', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: TdTheme.adminTdPrimary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
        ]),
      ]),
    );
  }
}
