import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import '../../theme/td_theme.dart';

/// Écran enseignant TD — Exercices TD : créer, voir soumissions, corriger (manuellement + IA).
class TeacherTdExercisesScreen extends StatefulWidget {
  const TeacherTdExercisesScreen({super.key});

  @override
  State<TeacherTdExercisesScreen> createState() => _TeacherTdExercisesScreenState();
}

class _TeacherTdExercisesScreenState extends State<TeacherTdExercisesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _exercises = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client.rpc('app_td_teacher_list_exercises');
      if (res is List) {
        _exercises = res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('[TeacherTdExercises] load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _exercises.isEmpty) {
      return Center(child: CircularProgressIndicator(color: TdTheme.instructorGradient[1]));
    }

    return RefreshIndicator(
      color: TdTheme.instructorGradient[1],
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(children: [
            const Expanded(child: Text('Exercices TD', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            ElevatedButton.icon(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nouveau'),
              style: ElevatedButton.styleFrom(
                backgroundColor: TdTheme.instructorGradient[1], foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          if (_exercises.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(children: [
                Icon(Icons.assignment_outlined, size: 48, color: TdTheme.instructorGradient[1].withAlpha(80)),
                const SizedBox(height: 12),
                const Text('Aucun exercice TD créé', style: TextStyle(color: Color(0xFF757575))),
              ]),
            ))
          else
            ..._exercises.map((ex) {
              final title = (ex['title'] ?? '').toString();
              final subject = ex['subject']?.toString();
              final isPublished = ex['is_published'] == true;
              final subCount = (ex['submission_count'] as int?) ?? 0;
              final gradedCount = (ex['graded_count'] as int?) ?? 0;

              return GestureDetector(
                onTap: () => _showSubmissions(ex),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isPublished ? TdTheme.instructorGradient[1].withAlpha(60) : const Color(0xFFE0E0E0)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(color: TdTheme.instructorGradient[1].withAlpha(20), borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.assignment, color: TdTheme.instructorGradient[1], size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      if (subject != null) Text(subject, style: const TextStyle(fontSize: 11, color: Color(0xFF757575))),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('$gradedCount/$subCount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: TdTheme.instructorGradient[1])),
                      Text(isPublished ? 'Publié' : 'Brouillon', style: TextStyle(fontSize: 10, color: isPublished ? TdTheme.instructorGradient[1] : const Color(0xFF9E9E9E))),
                    ]),
                  ]),
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showCreateDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? subject;
    int maxScore = 20;
    bool isPublished = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Nouvel exercice TD', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Titre *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'Consigne / Énoncé', border: OutlineInputBorder(), alignLabelWithHint: true)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: subject,
              decoration: const InputDecoration(labelText: 'Matière', border: OutlineInputBorder()),
              items: ['Mathématiques', 'Physique', 'Chimie', 'Droit Civil', 'Droit Constitutionnel', 'Économie', 'Comptabilité', 'Informatique', 'Français', 'Anglais', 'Philosophie']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setDialogState(() => subject = v),
            ),
            const SizedBox(height: 8),
            SwitchListTile(value: isPublished, onChanged: (v) => setDialogState(() => isPublished = v),
                title: const Text('Publier immédiatement', style: TextStyle(fontSize: 14)), contentPadding: EdgeInsets.zero),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: TdTheme.instructorGradient[1]),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop();
                await Supabase.instance.client.rpc('app_td_teacher_create_exercise', params: {
                  'p_title': titleCtrl.text.trim(),
                  'p_description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  'p_subject': subject,
                  'p_max_score': maxScore,
                  'p_is_published': isPublished,
                });
                _load();
              },
              child: const Text('Créer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubmissions(Map<String, dynamic> exercise) {
    final assignmentId = exercise['id']?.toString() ?? '';
    final title = (exercise['title'] ?? '').toString();
    final maxScore = (exercise['max_score'] as int?) ?? 20;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return _SubmissionsSheet(assignmentId: assignmentId, title: title, maxScore: maxScore);
      },
    );
  }
}

class _SubmissionsSheet extends StatefulWidget {
  final String assignmentId;
  final String title;
  final int maxScore;
  const _SubmissionsSheet({required this.assignmentId, required this.title, required this.maxScore});

  @override
  State<_SubmissionsSheet> createState() => _SubmissionsSheetState();
}

class _SubmissionsSheetState extends State<_SubmissionsSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _submissions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client.rpc('app_td_teacher_list_exercise_submissions', params: {'p_assignment_id': widget.assignmentId});
      if (res is Map && res['success'] == true && res['submissions'] is List) {
        _submissions = (res['submissions'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('[SubmissionsSheet] load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _triggerAiGrading(String submissionId) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;
      final uri = Uri.parse('${SupabaseConfig.url}/functions/v1/prep-grade-assignment');
      await http.post(uri, headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
        'apikey': SupabaseConfig.anonKey,
      }, body: jsonEncode({'submission_id': submissionId}));
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Correction IA lancée')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  void _showGradeDialog(Map<String, dynamic> sub) {
    final subId = sub['id']?.toString() ?? '';
    final aiScore = sub['ai_score'];
    final scoreCtrl = TextEditingController(text: aiScore?.toString() ?? '');
    final commentCtrl = TextEditingController(text: sub['teacher_comment']?.toString() ?? '');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Noter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (sub['ai_correction'] != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFEDE7F6), borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [Icon(Icons.auto_awesome, size: 14, color: Color(0xFF7C3AED)), SizedBox(width: 4),
                  Text('Suggestion IA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED)))]),
                const SizedBox(height: 4),
                Text('Score: $aiScore/${widget.maxScore}', style: const TextStyle(fontSize: 12)),
                Text((sub['ai_correction'] ?? '').toString(), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          TextField(controller: scoreCtrl, decoration: InputDecoration(labelText: 'Note / ${widget.maxScore}', border: const OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          TextField(controller: commentCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Commentaire', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TdTheme.instructorGradient[1]),
            onPressed: () async {
              final score = int.tryParse(scoreCtrl.text.trim());
              if (score == null) return;
              Navigator.of(ctx).pop();
              await Supabase.instance.client.rpc('app_td_teacher_grade_exercise', params: {
                'p_submission_id': subId, 'p_score': score,
                'p_comment': commentCtrl.text.trim().isEmpty ? null : commentCtrl.text.trim(),
              });
              _load();
            },
            child: const Text('Valider', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7, maxChildSize: 0.95, minChildSize: 0.4, expand: false,
      builder: (ctx, scrollCtrl) => Column(children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          Text('${_submissions.length} soumission(s)', style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
        ])),
        const Divider(height: 1),
        if (_loading) const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())
        else if (_submissions.isEmpty)
          const Padding(padding: EdgeInsets.all(32), child: Text('Aucune soumission.', style: TextStyle(color: Color(0xFF9E9E9E))))
        else Expanded(child: ListView.builder(
          controller: scrollCtrl, itemCount: _submissions.length, padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (ctx, i) {
            final sub = _submissions[i];
            final name = (sub['student_name'] ?? 'Étudiant').toString();
            final status = (sub['status'] ?? 'submitted').toString();
            final teacherScore = sub['teacher_score'];
            final aiScore = sub['ai_score'];
            final subId = sub['id']?.toString() ?? '';

            return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
              title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(
                status == 'graded' ? 'Noté: $teacherScore / ${widget.maxScore}'
                    : aiScore != null ? 'IA: $aiScore / ${widget.maxScore}' : 'En attente',
                style: TextStyle(fontSize: 12, color: status == 'graded' ? const Color(0xFF2E7D32) : const Color(0xFF757575)),
              ),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (status != 'graded')
                  IconButton(icon: const Icon(Icons.auto_awesome, color: Color(0xFF7C3AED), size: 20), tooltip: 'Correction IA',
                      onPressed: () => _triggerAiGrading(subId)),
                IconButton(
                  icon: Icon(status == 'graded' ? Icons.check_circle : Icons.grading,
                      color: status == 'graded' ? const Color(0xFF2E7D32) : TdTheme.instructorGradient[1], size: 20),
                  tooltip: 'Noter', onPressed: () => _showGradeDialog(sub)),
              ]),
            ));
          },
        )),
      ]),
    );
  }
}
