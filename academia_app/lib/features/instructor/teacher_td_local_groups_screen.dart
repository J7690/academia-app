import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/td_theme.dart';

/// Écran enseignant TD — Groupes locaux assignés, membres, sessions physiques.
class TeacherTdLocalGroupsScreen extends StatefulWidget {
  const TeacherTdLocalGroupsScreen({super.key});

  @override
  State<TeacherTdLocalGroupsScreen> createState() => _TeacherTdLocalGroupsScreenState();
}

class _TeacherTdLocalGroupsScreenState extends State<TeacherTdLocalGroupsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _groups = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client.rpc('app_td_teacher_list_local_groups');
      if (res is List) {
        _groups = res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('[TeacherTdLocalGroups] load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _groups.isEmpty) {
      return Center(child: CircularProgressIndicator(color: TdTheme.instructorGradient[1]));
    }

    return RefreshIndicator(
      color: TdTheme.instructorGradient[1],
      onRefresh: _load,
      child: _groups.isEmpty
          ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
              const SizedBox(height: 80),
              Center(child: Column(children: [
                Icon(Icons.groups_outlined, size: 48, color: TdTheme.instructorGradient[1].withAlpha(80)),
                const SizedBox(height: 12),
                const Text('Aucun groupe local assigné', style: TextStyle(color: Color(0xFF757575))),
                const SizedBox(height: 6),
                const Text('L\'admin vous affectera des groupes d\'étudiants\ndans votre zone géographique.',
                    textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 12)),
              ])),
            ])
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _groups.length,
              itemBuilder: (context, index) {
                final g = _groups[index];
                final subject = (g['subject'] ?? '').toString();
                final neighborhood = g['neighborhood']?.toString();
                final memberCount = (g['member_count'] as int?) ?? 0;
                final sessionDate = g['session_date']?.toString();
                final members = g['members'] is List ? (g['members'] as List) : [];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(color: TdTheme.instructorGradient[1].withAlpha(20), borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.groups, color: TdTheme.instructorGradient[1], size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(subject, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        if (neighborhood != null) Text('📍 $neighborhood', style: const TextStyle(fontSize: 11, color: Color(0xFF757575))),
                      ])),
                      Text('$memberCount', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: TdTheme.instructorGradient[1])),
                      const Icon(Icons.people, size: 14, color: Color(0xFF9E9E9E)),
                    ]),
                    if (sessionDate != null) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.event, size: 14, color: Color(0xFF757575)),
                        const SizedBox(width: 4),
                        Text('Session : $sessionDate', style: const TextStyle(fontSize: 12, color: Color(0xFF757575))),
                      ]),
                    ],
                    if (members.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text('Membres :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      ...members.take(8).map((m) {
                        final name = m is Map ? (m['name'] ?? '').toString() : '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(children: [
                            const Icon(Icons.person, size: 14, color: Color(0xFF9E9E9E)),
                            const SizedBox(width: 6),
                            Text(name, style: const TextStyle(fontSize: 12)),
                          ]),
                        );
                      }),
                    ],
                  ]),
                );
              },
            ),
    );
  }
}
