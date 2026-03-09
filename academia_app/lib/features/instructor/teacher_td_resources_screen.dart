import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';

import '../../providers/teacher_td_assignments_provider.dart';
import '../../services/td_service.dart';
import '../../theme/td_theme.dart';

/// Teacher: Manage resources for a TD program + view student progress
class TeacherTdResourcesScreen extends StatefulWidget {
  const TeacherTdResourcesScreen({super.key});

  @override
  State<TeacherTdResourcesScreen> createState() => _TeacherTdResourcesScreenState();
}

class _TeacherTdResourcesScreenState extends State<TeacherTdResourcesScreen>
    with SingleTickerProviderStateMixin {
  final TdService _service = TdService();
  late TabController _tabController;

  bool _studentsLoading = false;
  List<Map<String, dynamic>> _students = [];

  // Resources tab state
  String? _selectedProgramId;
  String? _selectedProgramTitle;
  bool _resourcesLoading = false;
  List<Map<String, dynamic>> _resources = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStudents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _studentsLoading = true);
    try {
      final data = await _service.tdTeacherListStudents();
      final list = data['students'];
      _students = (list is List)
          ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
    } catch (e) {
      debugPrint('[TeacherTdResources] loadStudents error: $e');
    }
    if (mounted) setState(() => _studentsLoading = false);
  }

  Future<void> _loadResources(String programId) async {
    setState(() => _resourcesLoading = true);
    try {
      final data = await _service.tdTeacherListResources(programId);
      final list = data['resources'];
      _resources = (list is List)
          ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
    } catch (e) {
      debugPrint('[TeacherTdResources] loadResources error: $e');
    }
    if (mounted) setState(() => _resourcesLoading = false);
  }

  Future<void> _deleteResource(String resourceId) async {
    try {
      await _service.tdTeacherDeleteResource(resourceId);
      if (_selectedProgramId != null) {
        _loadResources(_selectedProgramId!);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ressource supprimée.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _showAddResourceDialog() async {
    if (_selectedProgramId == null) return;
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    String kind = 'document';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Ajouter une ressource'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Titre *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: kind,
                  decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'document', child: Text('Document')),
                    DropdownMenuItem(value: 'video', child: Text('Vidéo')),
                    DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                    DropdownMenuItem(value: 'audio', child: Text('Audio')),
                    DropdownMenuItem(value: 'link', child: Text('Lien')),
                    DropdownMenuItem(value: 'exercise', child: Text('Exercice')),
                  ],
                  onChanged: (v) => setStateDialog(() => kind = v ?? 'document'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL *',
                    border: OutlineInputBorder(),
                    hintText: 'https://...',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: durationCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Durée (secondes, optionnel)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ajouter')),
          ],
        ),
      ),
    );

    if (result != true) return;
    final title = titleCtrl.text.trim();
    final url = urlCtrl.text.trim();
    if (title.isEmpty || url.isEmpty) return;

    try {
      await _service.tdTeacherAddResource(
        programId: _selectedProgramId!,
        title: title,
        kind: kind,
        url: url,
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        durationSeconds: int.tryParse(durationCtrl.text.trim()),
      );
      _loadResources(_selectedProgramId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ressource ajoutée.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TdTheme.scaffoldBg,
      body: Column(
        children: [
          Container(
            color: TdTheme.cardBg,
            child: TabBar(
              controller: _tabController,
              indicatorColor: TdTheme.instructorPrimary,
              labelColor: TdTheme.instructorPrimary,
              unselectedLabelColor: TdTheme.textTertiary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              tabs: const [
                Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Étudiants'),
                Tab(icon: Icon(Icons.folder_outlined, size: 18), text: 'Ressources'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStudentsTab(),
                _buildResourcesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsTab() {
    if (_studentsLoading && _students.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_students.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 56, color: TdTheme.textTertiary.withOpacity(0.4)),
            const SizedBox(height: 12),
            const Text('Aucun étudiant assigné',
                style: TextStyle(fontSize: 14, color: TdTheme.textSecondary)),
            const SizedBox(height: 4),
            const Text("L'admin doit t'assigner des étudiants.",
                style: TextStyle(fontSize: 12, color: TdTheme.textTertiary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStudents,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _students.length,
        itemBuilder: (context, index) {
          final s = _students[index];
          return FadeInUp(
            delay: Duration(milliseconds: 30 * index),
            duration: const Duration(milliseconds: 300),
            child: _StudentProgressCard(student: s),
          );
        },
      ),
    );
  }

  Widget _buildResourcesTab() {
    // Get unique programs from teacher assignments
    final assignmentsProvider = context.watch<TeacherTdAssignmentsProvider>();
    final assignments = assignmentsProvider.assignments;
    final programMap = <String, String>{};
    for (final a in assignments) {
      final pid = a['program_id']?.toString();
      final ptitle = a['program_title']?.toString() ?? 'Programme';
      if (pid != null && pid.isNotEmpty) {
        programMap[pid] = ptitle;
      }
    }

    return Column(
      children: [
        // Program selector
        if (programMap.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DropdownButtonFormField<String>(
              value: _selectedProgramId,
              decoration: const InputDecoration(
                labelText: 'Programme TD',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: programMap.entries.map((e) {
                return DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis));
              }).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedProgramId = v;
                  _selectedProgramTitle = v != null ? programMap[v] : null;
                });
                if (v != null) _loadResources(v);
              },
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TdTheme.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TdTheme.warning.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: TdTheme.warning, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Aucun programme TD assigné. L'admin doit d'abord t'assigner des missions.",
                      style: TextStyle(fontSize: 12, color: TdTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Resources list
        if (_selectedProgramId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_resources.length} ressource${_resources.length > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 12, color: TdTheme.textSecondary),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddResourceDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ajouter', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TdTheme.instructorPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: _selectedProgramId == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_open, size: 48, color: TdTheme.textTertiary.withOpacity(0.4)),
                      const SizedBox(height: 8),
                      const Text('Sélectionne un programme ci-dessus',
                          style: TextStyle(fontSize: 13, color: TdTheme.textTertiary)),
                    ],
                  ),
                )
              : _resourcesLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _resources.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.note_add, size: 48, color: TdTheme.textTertiary.withOpacity(0.4)),
                              const SizedBox(height: 8),
                              const Text('Aucune ressource pour ce programme',
                                  style: TextStyle(fontSize: 13, color: TdTheme.textTertiary)),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _showAddResourceDialog,
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Ajouter la première'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: TdTheme.instructorPrimary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _loadResources(_selectedProgramId!),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            itemCount: _resources.length,
                            itemBuilder: (context, index) {
                              final r = _resources[index];
                              return FadeInUp(
                                delay: Duration(milliseconds: 30 * index),
                                duration: const Duration(milliseconds: 300),
                                child: _TeacherResourceCard(
                                  resource: r,
                                  onDelete: () {
                                    final id = r['id']?.toString();
                                    if (id != null) _deleteResource(id);
                                  },
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

class _StudentProgressCard extends StatelessWidget {
  final Map<String, dynamic> student;

  const _StudentProgressCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final programTitle = student['program_title']?.toString() ?? '';
    final status = student['access_status']?.toString() ?? '';
    final pct = (student['progress_pct'] as int? ?? 0) / 100.0;
    final completedSessions = student['completed_sessions'] as int? ?? 0;
    final totalSessions = student['total_sessions'] as int? ?? 0;
    final xp = student['student_xp'] as int? ?? 0;
    final level = student['student_level'] as int? ?? 1;
    final streak = student['student_streak'] as int? ?? 0;
    final unread = student['unread_messages'] as int? ?? 0;

    final (statusLabel, statusColor) = TdTheme.accessStatusInfo(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: TdTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: TdTheme.instructorPrimary.withOpacity(0.1),
                child: const Icon(Icons.person, color: TdTheme.instructorPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(programTitle,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        TdTheme.statusBadge(statusLabel, statusColor),
                        const SizedBox(width: 6),
                        TdTheme.xpBadge(xp),
                        const SizedBox(width: 6),
                        TdTheme.levelBadge(level),
                      ],
                    ),
                  ],
                ),
              ),
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: TdTheme.error, shape: BoxShape.circle),
                  child: Text('$unread',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (streak > 0) ...[
                TdTheme.streakBadge(streak),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          totalSessions > 0
                              ? 'Séance $completedSessions/$totalSessions'
                              : 'Progression',
                          style: const TextStyle(fontSize: 11, color: TdTheme.textSecondary),
                        ),
                        Text('${(pct * 100).toInt()}%',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700, color: TdTheme.instructorPrimary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TdTheme.progressBar(value: pct, color: TdTheme.instructorPrimary),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeacherResourceCard extends StatelessWidget {
  final Map<String, dynamic> resource;
  final VoidCallback onDelete;

  const _TeacherResourceCard({required this.resource, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final title = resource['title']?.toString() ?? '';
    final description = resource['description']?.toString() ?? '';
    final kind = resource['kind']?.toString() ?? 'document';
    final url = resource['url']?.toString() ?? '';
    final durationSec = resource['duration_seconds'] as int?;
    final downloads = resource['download_count'] as int? ?? 0;

    final (icon, color) = _kindInfo(kind);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: TdTheme.cardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (description.isNotEmpty)
                    Text(description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: TdTheme.textSecondary)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      TdTheme.statusBadge(_kindLabel(kind), color),
                      if (durationSec != null) ...[
                        const SizedBox(width: 6),
                        Text('${(durationSec / 60).ceil()} min',
                            style: const TextStyle(fontSize: 10, color: TdTheme.textTertiary)),
                      ],
                      const SizedBox(width: 6),
                      Text('$downloads téléch.',
                          style: const TextStyle(fontSize: 10, color: TdTheme.textTertiary)),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: TdTheme.error),
              tooltip: 'Supprimer',
              onPressed: () {
                showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Supprimer cette ressource ?'),
                    content: Text('« $title » sera supprimée définitivement.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: TdTheme.error),
                        child: const Text('Supprimer'),
                      ),
                    ],
                  ),
                ).then((confirmed) {
                  if (confirmed == true) onDelete();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _kindInfo(String kind) {
    switch (kind) {
      case 'video':
        return (Icons.play_circle_filled, const Color(0xFFEF4444));
      case 'pdf':
        return (Icons.picture_as_pdf, const Color(0xFFEA580C));
      case 'document':
        return (Icons.description, const Color(0xFF0891B2));
      case 'audio':
        return (Icons.headphones, const Color(0xFF7C3AED));
      case 'link':
        return (Icons.link, const Color(0xFF0891B2));
      case 'exercise':
        return (Icons.edit_note, const Color(0xFF059669));
      default:
        return (Icons.insert_drive_file, TdTheme.instructorPrimary);
    }
  }

  String _kindLabel(String kind) {
    switch (kind) {
      case 'video':
        return 'Vidéo';
      case 'pdf':
        return 'PDF';
      case 'document':
        return 'Document';
      case 'audio':
        return 'Audio';
      case 'link':
        return 'Lien';
      case 'exercise':
        return 'Exercice';
      default:
        return kind;
    }
  }
}
