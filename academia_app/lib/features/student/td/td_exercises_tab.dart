import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/td_theme.dart';

/// Onglet Exercices TD — Exercices envoyés par l'enseignant TD, soumission, corrections.
class TdExercisesTab extends StatefulWidget {
  const TdExercisesTab({super.key});

  @override
  State<TdExercisesTab> createState() => _TdExercisesTabState();
}

class _TdExercisesTabState extends State<TdExercisesTab> {
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
      final res = await Supabase.instance.client.rpc('app_td_student_list_exercises');
      if (res is List) {
        _exercises = res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('[TdExercisesTab] load error: $e');
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
      onRefresh: _load,
      child: _exercises.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                Center(child: Column(children: [
                  Icon(Icons.assignment_outlined, size: 48, color: TdTheme.studentTdGradient[1].withAlpha(80)),
                  const SizedBox(height: 12),
                  const Text('Aucun exercice disponible', style: TextStyle(color: Color(0xFF757575), fontSize: 14)),
                  const SizedBox(height: 6),
                  const Text('Vos enseignants publieront des exercices bientôt.',
                      style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 12)),
                ])),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              itemCount: _exercises.length,
              itemBuilder: (context, index) {
                final ex = _exercises[index];
                return _ExerciseCard(exercise: ex, onTap: () => _showSubmitSheet(ex));
              },
            ),
    );
  }

  void _showSubmitSheet(Map<String, dynamic> exercise) {
    final title = (exercise['title'] ?? '').toString();
    final desc = (exercise['description'] ?? '').toString();
    final maxScore = (exercise['max_score'] as int?) ?? 20;
    final subject = exercise['subject']?.toString();
    final teacherName = exercise['teacher_name']?.toString();
    final mySubmission = exercise['my_submission'];
    final hasSubmitted = mySubmission != null;
    final teacherScore = mySubmission is Map ? mySubmission['teacher_score'] : null;
    final aiScore = mySubmission is Map ? mySubmission['ai_score'] : null;
    final status = mySubmission is Map ? mySubmission['status']?.toString() : null;

    final answerCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (subject != null || teacherName != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                if (subject != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: TdTheme.studentTdGradient[1].withAlpha(20), borderRadius: BorderRadius.circular(6)),
                    child: Text(subject, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: TdTheme.studentTdGradient[1])),
                  ),
                  const SizedBox(width: 8),
                ],
                if (teacherName != null) Text('Par $teacherName', style: const TextStyle(fontSize: 11, color: Color(0xFF757575))),
              ]),
            ],
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(desc, style: const TextStyle(fontSize: 13, color: Color(0xFF424242), height: 1.5)),
            ],
            const SizedBox(height: 16),

            // Status display
            if (hasSubmitted && status == 'graded') ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFC8E6C9), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2E7D32).withAlpha(60)),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 24),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Corrigé', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
                    Text('Note : $teacherScore / $maxScore', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ])),
                ]),
              ),
            ] else if (hasSubmitted && aiScore != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE7F6), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF7C3AED).withAlpha(40)),
                ),
                child: Row(children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF7C3AED), size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Correction IA disponible', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF7C3AED), fontSize: 13)),
                    Text('L\'IA suggère $aiScore / $maxScore', style: const TextStyle(fontSize: 12)),
                    const Text('En attente de validation par l\'enseignant.', style: TextStyle(fontSize: 11, color: Color(0xFF757575))),
                  ])),
                ]),
              ),
            ] else if (hasSubmitted) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: TdTheme.studentTdGradient[1].withAlpha(15), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(Icons.hourglass_top, color: TdTheme.studentTdGradient[1], size: 20),
                  const SizedBox(width: 12),
                  const Text('Soumis — En attente de correction', style: TextStyle(fontSize: 13)),
                ]),
              ),
            ] else ...[
              // Submit form
              TextField(
                controller: answerCtrl,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Votre réponse',
                  hintText: 'Rédigez votre réponse ici...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (answerCtrl.text.trim().isEmpty) return;
                    Navigator.of(ctx).pop();
                    try {
                      await Supabase.instance.client.rpc('app_td_student_submit_exercise', params: {
                        'p_assignment_id': exercise['id'],
                        'p_answer_content': {'text': answerCtrl.text.trim()},
                      });
                      _load();
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Réponse soumise ✓')));
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
                    }
                  },
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Soumettre'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TdTheme.studentTdGradient[1],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final VoidCallback onTap;
  const _ExerciseCard({required this.exercise, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = (exercise['title'] ?? '').toString();
    final subject = exercise['subject']?.toString();
    final type = (exercise['assignment_type'] ?? 'exercise').toString();
    final teacherName = exercise['teacher_name']?.toString();
    final mySubmission = exercise['my_submission'];
    final hasSubmitted = mySubmission != null;
    final status = mySubmission is Map ? mySubmission['status']?.toString() : null;
    final deadline = exercise['deadline']?.toString();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: status == 'graded'
              ? const Color(0xFF2E7D32).withAlpha(60)
              : hasSubmitted ? TdTheme.studentTdGradient[1].withAlpha(60) : const Color(0xFFE0E0E0)),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: (status == 'graded' ? const Color(0xFF2E7D32) : TdTheme.studentTdGradient[1]).withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              type == 'qcm' ? Icons.quiz : type == 'dissertation' ? Icons.edit_note : Icons.assignment,
              color: status == 'graded' ? const Color(0xFF2E7D32) : TdTheme.studentTdGradient[1], size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(children: [
              if (subject != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: TdTheme.studentTdGradient[1].withAlpha(20), borderRadius: BorderRadius.circular(4)),
                  child: Text(subject, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: TdTheme.studentTdGradient[1])),
                ),
                const SizedBox(width: 6),
              ],
              if (teacherName != null) Text(teacherName, style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
            ]),
            if (deadline != null) ...[
              const SizedBox(height: 2),
              Text('Deadline : ${deadline.length >= 10 ? deadline.substring(0, 10) : deadline}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
            ],
          ])),
          Icon(
            status == 'graded' ? Icons.check_circle : hasSubmitted ? Icons.hourglass_top : Icons.arrow_forward_ios,
            color: status == 'graded' ? const Color(0xFF2E7D32) : hasSubmitted ? TdTheme.studentTdGradient[1] : const Color(0xFFBDBDBD),
            size: 18,
          ),
        ]),
      ),
    );
  }
}
