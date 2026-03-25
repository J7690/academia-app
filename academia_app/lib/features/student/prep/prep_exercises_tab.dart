import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/prep_theme.dart';

/// Onglet Exercices — Exercices envoyés par l'enseignant concours, soumission, corrections.
class PrepExercisesTab extends StatefulWidget {
  const PrepExercisesTab({super.key});

  @override
  State<PrepExercisesTab> createState() => _PrepExercisesTabState();
}

class _PrepExercisesTabState extends State<PrepExercisesTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _assignments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client.rpc('app_prep_student_list_assignments');
      if (res is List) {
        _assignments = res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('[PrepExercisesTab] load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: PrepTheme.success));
    }

    return RefreshIndicator(
      color: PrepTheme.success,
      onRefresh: _load,
      child: _assignments.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.assignment_outlined, size: 48, color: PrepTheme.textTertiary),
                      const SizedBox(height: 12),
                      const Text('Aucun exercice disponible',
                          style: TextStyle(color: PrepTheme.textTertiary, fontSize: 14)),
                      const SizedBox(height: 6),
                      const Text('Les enseignants publieront bientôt des exercices.',
                          style: TextStyle(color: PrepTheme.textTertiary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              itemCount: _assignments.length,
              itemBuilder: (context, index) {
                final a = _assignments[index];
                return FadeInUp(
                  delay: Duration(milliseconds: 40 * index),
                  duration: const Duration(milliseconds: 350),
                  child: _AssignmentCard(
                    assignment: a,
                    onTap: () => _showSubmitDialog(a),
                  ),
                );
              },
            ),
    );
  }

  void _showSubmitDialog(Map<String, dynamic> assignment) {
    final title = (assignment['title'] ?? '').toString();
    final desc = (assignment['description'] ?? '').toString();
    final maxScore = (assignment['max_score'] as int?) ?? 20;
    final mySubmission = assignment['my_submission'];
    final hasSubmitted = mySubmission != null;
    final teacherScore = mySubmission is Map ? mySubmission['teacher_score'] : null;
    final status = mySubmission is Map ? mySubmission['status']?.toString() : null;

    final answerCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(desc, style: const TextStyle(fontSize: 13, color: PrepTheme.textSecondary)),
            ],
            const SizedBox(height: 16),

            if (hasSubmitted && status == 'graded') ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: PrepTheme.successSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PrepTheme.success.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: PrepTheme.success, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Corrigé', style: TextStyle(fontWeight: FontWeight.w600, color: PrepTheme.success)),
                          Text('Note : $teacherScore / $maxScore',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (hasSubmitted) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: PrepTheme.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.hourglass_top, color: PrepTheme.primary, size: 20),
                    SizedBox(width: 12),
                    Text('Soumis — En attente de correction',
                        style: TextStyle(fontSize: 13, color: PrepTheme.primary)),
                  ],
                ),
              ),
            ] else ...[
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
                      await Supabase.instance.client.rpc('app_prep_student_submit_assignment', params: {
                        'p_assignment_id': assignment['id'],
                        'p_answer_content': {'text': answerCtrl.text.trim()},
                      });
                      _load();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Réponse soumise ✓')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur : $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Soumettre'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PrepTheme.success,
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

class _AssignmentCard extends StatelessWidget {
  final Map<String, dynamic> assignment;
  final VoidCallback onTap;

  const _AssignmentCard({required this.assignment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = (assignment['title'] ?? '').toString();
    final concours = assignment['concours_type']?.toString();
    final subject = assignment['subject_name']?.toString();
    final type = (assignment['assignment_type'] ?? 'qcm').toString();
    final mySubmission = assignment['my_submission'];
    final hasSubmitted = mySubmission != null;
    final status = mySubmission is Map ? mySubmission['status']?.toString() : null;
    final deadline = assignment['deadline']?.toString();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: PrepTheme.cardBox(
          borderColor: status == 'graded'
              ? PrepTheme.success.withAlpha(60)
              : hasSubmitted
                  ? PrepTheme.primary.withAlpha(60)
                  : null,
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: (status == 'graded' ? PrepTheme.success : PrepTheme.primary).withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                type == 'qcm' ? Icons.quiz
                    : type == 'dissertation' ? Icons.edit_note
                    : Icons.cases_outlined,
                color: status == 'graded' ? PrepTheme.success : PrepTheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (concours != null) ...[PrepTheme.chip(concours, PrepTheme.primary), const SizedBox(width: 6)],
                    if (subject != null) PrepTheme.chip(subject, PrepTheme.success),
                  ]),
                  if (deadline != null) ...[
                    const SizedBox(height: 4),
                    Text('Deadline : ${deadline.substring(0, 10)}',
                        style: const TextStyle(fontSize: 10, color: PrepTheme.textTertiary)),
                  ],
                ],
              ),
            ),
            Icon(
              status == 'graded' ? Icons.check_circle
                  : hasSubmitted ? Icons.hourglass_top
                  : Icons.arrow_forward_ios,
              color: status == 'graded' ? PrepTheme.success
                  : hasSubmitted ? PrepTheme.primary
                  : PrepTheme.textTertiary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
