import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/td_theme.dart';
import '../../../widgets/app_snack.dart';
import '../../../widgets/adaptive_dialog.dart';

/// Onglet Groupes Locaux — Matching par matière/quartier, inscription, création de groupes.
class TdLocalGroupsTab extends StatefulWidget {
  const TdLocalGroupsTab({super.key});

  @override
  State<TdLocalGroupsTab> createState() => _TdLocalGroupsTabState();
}

class _TdLocalGroupsTabState extends State<TdLocalGroupsTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _suggestions = [];
  Map<String, dynamic> _profile = {};
  bool _hasProfile = false;
  String? _filterSubject;
  String? _filterNeighborhood;

  static const _neighborhoods = [
    'Dassasgho', 'Patte-d\'oie', 'Pissy', '1200 Logements', 'Tampouy',
    'Karpala', 'Zogona', 'Gounghin', 'Kossodo', 'Ouaga 2000',
    'Somgandé', 'Tanghin', 'Wemtenga', 'Saaba', 'Baskuy',
  ];

  static const _subjects = [
    'Analyse Mathématique', 'Algèbre', 'Probabilités/Statistiques', 'Physique',
    'Chimie', 'Biologie', 'Droit Civil', 'Droit Constitutionnel',
    'Droit Administratif', 'Droit Pénal', 'Économie Générale', 'Microéconomie',
    'Comptabilité', 'Gestion', 'Informatique', 'Anglais', 'Français',
    'Philosophie', 'Sociologie', 'Histoire', 'Géographie',
  ];

  static const _universities = [
    'Université Joseph Ki-Zerbo', 'Université Nazi Boni', 'Université Norbert Zongo',
    'Université Thomas Sankara', 'Université Aube Nouvelle', 'Université Saint Thomas d\'Aquin',
    'Université Catholique de l\'Afrique de l\'Ouest', 'Autre',
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;
      // Load profile
      final profileRes = await client.rpc('app_td_student_get_profile');
      if (profileRes is Map && profileRes.isNotEmpty && profileRes['student_id'] != null) {
        _profile = Map<String, dynamic>.from(profileRes);
        _hasProfile = true;
      }
      // Load groups
      final groupsRes = await client.rpc('app_td_student_list_local_groups', params: {
        'p_subject': _filterSubject,
        'p_neighborhood': _filterNeighborhood,
        'p_city': null,
      });
      if (groupsRes is List) {
        _groups = groupsRes.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('[TdLocalGroupsTab] loadAll error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: TdTheme.studentTdGradient[1]));
    }

    return RefreshIndicator(
      color: TdTheme.studentTdGradient[1],
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Profile card (if not filled)
          if (!_hasProfile) _buildProfilePrompt(),
          if (_hasProfile) _buildProfileSummary(),
          const SizedBox(height: 16),

          // Filters
          _buildFilters(),
          const SizedBox(height: 16),

          // Create group button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showCreateGroupDialog(),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Créer un groupe d\'étude'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: TdTheme.studentTdGradient[1]),
                foregroundColor: TdTheme.studentTdGradient[1],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Suggested groups (matching)
          if (_hasProfile) ...[
            Row(children: [
              Icon(Icons.auto_awesome, size: 18, color: TdTheme.studentTdGradient[1]),
              const SizedBox(width: 6),
              const Expanded(child: Text('Groupes suggérés pour vous', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
              TextButton.icon(
                onPressed: _loadSuggestions,
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Trouver', style: TextStyle(fontSize: 12)),
              ),
            ]),
            if (_suggestions.isNotEmpty)
              ..._suggestions.map((g) => _GroupCard(
                group: g,
                onJoin: () => _joinGroup(g['id']?.toString() ?? ''),
                isSuggested: true,
              ))
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Appuyez sur "Trouver" pour voir les groupes qui vous correspondent.',
                    style: TextStyle(fontSize: 12, color: TdTheme.studentTdGradient[1].withAlpha(150))),
              ),
            const SizedBox(height: 12),
          ],

          // Groups list
          Text('Tous les groupes (${_groups.length})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),

          if (_groups.isEmpty)
            _buildEmptyGroups()
          else
            ..._groups.map((g) => _GroupCard(
              group: g,
              onJoin: () => _joinGroup(g['id']?.toString() ?? ''),
            )),
        ],
      ),
    );
  }

  Widget _buildProfilePrompt() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: TdTheme.studentTdGradient),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.person_pin_circle, color: Colors.white, size: 24),
            SizedBox(width: 10),
            Text('Complétez votre profil TD', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Text('Pour trouver des groupes d\'étude près de chez vous.',
              style: TextStyle(color: Colors.white.withAlpha(190), fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showProfileDialog(),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: TdTheme.studentTdGradient[1]),
              child: const Text('Remplir mon profil'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSummary() {
    final uni = (_profile['university'] ?? '').toString();
    final neighborhood = (_profile['neighborhood'] ?? '').toString();
    final subjects = (_profile['subjects_needed'] is List)
        ? (_profile['subjects_needed'] as List).cast<String>()
        : <String>[];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Icon(Icons.person_pin_circle, color: TdTheme.studentTdGradient[1], size: 24),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(uni.isNotEmpty ? uni : 'Université non renseignée',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              if (neighborhood.isNotEmpty)
                Text('📍 $neighborhood', style: const TextStyle(fontSize: 11, color: Color(0xFF757575))),
              if (subjects.isNotEmpty)
                Text(subjects.take(3).join(', '), style: const TextStyle(fontSize: 11, color: Color(0xFF757575))),
            ],
          )),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: () => _showProfileDialog(),
            tooltip: 'Modifier',
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: 'Toutes matières',
            isSelected: _filterSubject == null,
            onTap: () { setState(() => _filterSubject = null); _loadAll(); },
          ),
          ..._subjects.take(8).map((s) => _FilterChip(
            label: s,
            isSelected: _filterSubject == s,
            onTap: () { setState(() => _filterSubject = s); _loadAll(); },
          )),
        ],
      ),
    );
  }

  Widget _buildEmptyGroups() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.groups_outlined, size: 48, color: TdTheme.studentTdGradient[1].withAlpha(80)),
            const SizedBox(height: 12),
            const Text('Aucun groupe dans votre zone', style: TextStyle(color: Color(0xFF757575))),
            const SizedBox(height: 6),
            const Text('Créez le premier groupe et d\'autres étudiants vous rejoindront !',
                textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _loadSuggestions() async {
    try {
      final res = await Supabase.instance.client.rpc('app_td_suggest_groups_for_student');
      if (res is Map && res['success'] == true && res['suggestions'] is List) {
        setState(() => _suggestions = (res['suggestions'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList());
      }
    } catch (e) {
      debugPrint('[TdLocalGroups] suggestions error: $e');
    }
  }

  Future<void> _joinGroup(String groupId) async {
    if (groupId.isEmpty) return;
    try {
      final res = await Supabase.instance.client.rpc('app_td_student_join_group', params: {'p_group_id': groupId});
      if (res is Map && res['success'] == true) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inscrit au groupe ✓')));
        _loadAll();
      } else {
        final err = res is Map ? res['error']?.toString() : '';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err == 'group_full' ? 'Groupe complet' : 'Erreur: $err')));
      }
    } catch (e) {
      if (mounted) AppSnack.error(context, e);
    }
  }

  void _showProfileDialog() {
    String? university = _profile['university']?.toString();
    String? faculty = _profile['faculty']?.toString();
    String? studyYear = _profile['study_year']?.toString();
    String? neighborhood = _profile['neighborhood']?.toString();
    List<String> selectedSubjects = (_profile['subjects_needed'] is List)
        ? (_profile['subjects_needed'] as List).cast<String>()
        : <String>[];

    showDialog<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AdaptiveDialog(
          maxWidth: 480,
          title: const Text('Mon profil TD', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: _universities.contains(university) ? university : null,
                    decoration: const InputDecoration(labelText: 'Université *', border: OutlineInputBorder()),
                    items: _universities.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) => setDialogState(() => university = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Filière (ex: Droit, Maths, Médecine)', border: OutlineInputBorder()),
                    controller: TextEditingController(text: faculty),
                    onChanged: (v) => faculty = v,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: studyYear,
                    decoration: const InputDecoration(labelText: 'Niveau', border: OutlineInputBorder()),
                    items: ['L1', 'L2', 'L3', 'Master 1', 'Master 2', 'Doctorat']
                        .map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                    onChanged: (v) => setDialogState(() => studyYear = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _neighborhoods.contains(neighborhood) ? neighborhood : null,
                    decoration: const InputDecoration(labelText: 'Quartier *', border: OutlineInputBorder()),
                    items: _neighborhoods.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                    onChanged: (v) => setDialogState(() => neighborhood = v),
                  ),
                  const SizedBox(height: 12),
                  const Text('Matières à renforcer :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: _subjects.map((s) {
                      final selected = selectedSubjects.contains(s);
                      return GestureDetector(
                        onTap: () => setDialogState(() {
                          if (selected) { selectedSubjects.remove(s); } else { selectedSubjects.add(s); }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: selected ? TdTheme.studentTdGradient[1] : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: selected ? TdTheme.studentTdGradient[1] : const Color(0xFFBDBDBD)),
                          ),
                          child: Text(s, style: TextStyle(fontSize: 10, color: selected ? Colors.white : const Color(0xFF616161))),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: TdTheme.studentTdGradient[1]),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await Supabase.instance.client.rpc('app_td_student_upsert_profile', params: {
                  'p_university': university,
                  'p_faculty': faculty,
                  'p_study_year': studyYear,
                  'p_subjects_needed': selectedSubjects,
                  'p_neighborhood': neighborhood,
                  'p_is_seeking_group': true,
                });
                _loadAll();
              },
              child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateGroupDialog() {
    String? subject;
    String? level;
    String? neighborhood = _profile['neighborhood']?.toString();
    int maxMembers = 6;

    showDialog<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AdaptiveDialog(
          maxWidth: 460,
          title: const Text('Créer un groupe d\'étude', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: subject,
                  decoration: const InputDecoration(labelText: 'Matière *', border: OutlineInputBorder()),
                  items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setDialogState(() => subject = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: level,
                  decoration: const InputDecoration(labelText: 'Niveau', border: OutlineInputBorder()),
                  items: ['L1', 'L2', 'L3', 'Master 1', 'Master 2', 'Tous niveaux']
                      .map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                  onChanged: (v) => setDialogState(() => level = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _neighborhoods.contains(neighborhood) ? neighborhood : null,
                  decoration: const InputDecoration(labelText: 'Quartier *', border: OutlineInputBorder()),
                  items: _neighborhoods.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                  onChanged: (v) => setDialogState(() => neighborhood = v),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  const Text('Taille max : ', style: TextStyle(fontSize: 13)),
                  Expanded(child: Slider(
                    value: maxMembers.toDouble(), min: 3, max: 10, divisions: 7,
                    activeColor: TdTheme.studentTdGradient[1],
                    label: '$maxMembers',
                    onChanged: (v) => setDialogState(() => maxMembers = v.round()),
                  )),
                  Text('$maxMembers', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
              ],
            ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: TdTheme.studentTdGradient[1]),
              onPressed: () async {
                if (subject == null) return;
                Navigator.of(ctx).pop();
                await Supabase.instance.client.rpc('app_td_student_create_group', params: {
                  'p_subject': subject,
                  'p_level': level,
                  'p_city': 'Ouagadougou',
                  'p_neighborhood': neighborhood,
                  'p_max_members': maxMembers,
                });
                _loadAll();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Groupe créé ✓')));
              },
              child: const Text('Créer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? TdTheme.studentTdGradient[1] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? TdTheme.studentTdGradient[1] : const Color(0xFFBDBDBD)),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF616161))),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final VoidCallback onJoin;
  final bool isSuggested;
  const _GroupCard({required this.group, required this.onJoin, this.isSuggested = false});

  @override
  Widget build(BuildContext context) {
    final subject = (group['subject'] ?? '').toString();
    final level = group['level']?.toString();
    final neighborhood = group['neighborhood']?.toString();
    final city = (group['city'] ?? 'Ouagadougou').toString();
    final memberCount = (group['member_count'] as int?) ?? (group['current_members'] as int?) ?? 0;
    final maxMembers = (group['max_members'] as int?) ?? 8;
    final status = (group['status'] ?? 'forming').toString();
    final teacherName = group['teacher_name']?.toString();
    final myMembership = group['my_membership'];
    final hasJoined = myMembership != null;
    final sessionDate = group['session_date']?.toString();
    final pricePerStudent = group['price_per_student'] as int?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hasJoined ? TdTheme.studentTdGradient[1].withAlpha(80) : const Color(0xFFE0E0E0)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: TdTheme.studentTdGradient[1].withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.groups, color: TdTheme.studentTdGradient[1], size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subject, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(children: [
                    if (level != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: TdTheme.studentTdGradient[1].withAlpha(20), borderRadius: BorderRadius.circular(4)),
                        child: Text(level, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: TdTheme.studentTdGradient[1])),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (neighborhood != null)
                      Text('📍 $neighborhood', style: const TextStyle(fontSize: 11, color: Color(0xFF757575))),
                  ]),
                ],
              )),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$memberCount/$maxMembers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: TdTheme.studentTdGradient[1])),
                  const Text('membres', style: TextStyle(fontSize: 9, color: Color(0xFF9E9E9E))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (teacherName != null) ...[
                const Icon(Icons.person, size: 14, color: Color(0xFF757575)),
                const SizedBox(width: 4),
                Text(teacherName, style: const TextStyle(fontSize: 11, color: Color(0xFF757575))),
                const SizedBox(width: 12),
              ],
              if (sessionDate != null) ...[
                const Icon(Icons.event, size: 14, color: Color(0xFF757575)),
                const SizedBox(width: 4),
                Text(sessionDate, style: const TextStyle(fontSize: 11, color: Color(0xFF757575))),
                const SizedBox(width: 12),
              ],
              if (pricePerStudent != null) ...[
                const Icon(Icons.payments, size: 14, color: Color(0xFF757575)),
                const SizedBox(width: 4),
                Text('$pricePerStudent FCFA', style: const TextStyle(fontSize: 11, color: Color(0xFF757575))),
              ],
              const Spacer(),
              if (!hasJoined && memberCount < maxMembers)
                ElevatedButton(
                  onPressed: onJoin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TdTheme.studentTdGradient[1],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Rejoindre'),
                )
              else if (hasJoined)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC8E6C9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Inscrit ✓', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFFFCDD2), borderRadius: BorderRadius.circular(10)),
                  child: const Text('Complet', style: TextStyle(fontSize: 12, color: Color(0xFFD32F2F))),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
