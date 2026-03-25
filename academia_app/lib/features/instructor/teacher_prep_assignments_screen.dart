import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/teacher_prep_assignments_provider.dart';
import '../../theme/prep_theme.dart';

/// Écran enseignant — Exercices CONCOURS (distinct des TD assignments).
/// Permet de créer des exercices, voir les soumissions, corriger (manuellement ou IA).
class TeacherPrepAssignmentsScreen extends StatefulWidget {
  const TeacherPrepAssignmentsScreen({super.key});

  @override
  State<TeacherPrepAssignmentsScreen> createState() =>
      _TeacherPrepAssignmentsScreenState();
}

class _TeacherPrepAssignmentsScreenState
    extends State<TeacherPrepAssignmentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeacherPrepAssignmentsProvider>().loadMyAssignments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TeacherPrepAssignmentsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.assignments.isEmpty) {
          return const Center(
              child: CircularProgressIndicator(color: PrepTheme.success));
        }

        return RefreshIndicator(
          color: PrepTheme.success,
          onRefresh: provider.loadMyAssignments,
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Exercices Concours',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: PrepTheme.textPrimary,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateDialog(context, provider),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nouveau'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PrepTheme.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (provider.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(provider.error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),

              if (provider.assignments.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(Icons.assignment_outlined,
                            size: 48, color: PrepTheme.textTertiary),
                        const SizedBox(height: 12),
                        const Text('Aucun exercice concours créé',
                            style: TextStyle(color: PrepTheme.textTertiary)),
                        const SizedBox(height: 8),
                        const Text(
                          'Créez des exercices pour que vos étudiants\ns\'entraînent aux concours du BF.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: PrepTheme.textTertiary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...provider.assignments.map((a) => _AssignmentCard(
                      assignment: a,
                      onTap: () => _showSubmissionsDialog(context, provider, a),
                    )),
            ],
          ),
        );
      },
    );
  }

  void _showCreateDialog(
      BuildContext context, TeacherPrepAssignmentsProvider provider) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? concoursType;
    String? subjectName;
    String assignmentType = 'qcm';
    int maxScore = 20;
    bool isPublished = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Nouvel exercice concours',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Titre *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Consigne / Description',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: concoursType,
                  decoration: const InputDecoration(
                      labelText: 'Concours', border: OutlineInputBorder()),
                  items: [
                    'ENAREF',
                    'ADMIN_CIVIL',
                    'DOUANE',
                    'GREFFIERS',
                    'SANTE',
                    'EDUCATION',
                    'GRH',
                    'PARAMILITAIRE'
                  ]
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => concoursType = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: subjectName,
                  decoration: const InputDecoration(
                      labelText: 'Matière', border: OutlineInputBorder()),
                  items: [
                    'Culture Générale',
                    'Actualités BF',
                    'Droit Constitutionnel',
                    'Droit Administratif',
                    'Économie',
                    'Finances Publiques',
                    'Fiscalité',
                    'Français',
                    'Tests Psychotechniques',
                    'Mathématiques'
                  ]
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => subjectName = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: assignmentType,
                  decoration: const InputDecoration(
                      labelText: 'Type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'qcm', child: Text('QCM')),
                    DropdownMenuItem(
                        value: 'dissertation', child: Text('Dissertation')),
                    DropdownMenuItem(
                        value: 'cas_pratique', child: Text('Cas pratique')),
                  ],
                  onChanged: (v) => setDialogState(
                      () => assignmentType = v ?? 'qcm'),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                      labelText: 'Note maximale',
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: '$maxScore'),
                  onChanged: (v) =>
                      maxScore = int.tryParse(v) ?? 20,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: isPublished,
                  onChanged: (v) =>
                      setDialogState(() => isPublished = v),
                  title: const Text('Publier immédiatement',
                      style: TextStyle(fontSize: 14)),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: PrepTheme.success),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop();
                await provider.upsertAssignment(
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                  concoursType: concoursType,
                  subjectName: subjectName,
                  assignmentType: assignmentType,
                  maxScore: maxScore,
                  isPublished: isPublished,
                );
              },
              child: const Text('Créer',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubmissionsDialog(BuildContext context,
      TeacherPrepAssignmentsProvider provider, Map<String, dynamic> assignment) {
    final assignmentId = assignment['id']?.toString() ?? '';
    final title = assignment['title']?.toString() ?? '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        provider.loadSubmissions(assignmentId);
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          expand: false,
          builder: (ctx, scrollCtrl) {
            return Consumer<TeacherPrepAssignmentsProvider>(
              builder: (ctx, p, _) {
                final subs = p.submissions;
                return Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(title,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                          ),
                          Text('${subs.length} soumission(s)',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: PrepTheme.textTertiary)),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    if (p.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      )
                    else if (subs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Aucune soumission pour le moment.',
                            style:
                                TextStyle(color: PrepTheme.textTertiary)),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          controller: scrollCtrl,
                          itemCount: subs.length,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemBuilder: (ctx, i) {
                            final sub = subs[i];
                            final studentName =
                                (sub['student_name'] ?? 'Étudiant')
                                    .toString();
                            final status =
                                (sub['status'] ?? 'submitted').toString();
                            final teacherScore = sub['teacher_score'];
                            final aiScore = sub['ai_score'];
                            final subId = sub['id']?.toString() ?? '';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(studentName,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  status == 'graded'
                                      ? 'Noté: ${teacherScore ?? "?"} / ${assignment['max_score'] ?? 20}'
                                      : aiScore != null
                                          ? 'IA suggère: $aiScore / ${assignment['max_score'] ?? 20}'
                                          : 'En attente de correction',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: status == 'graded'
                                        ? PrepTheme.success
                                        : PrepTheme.textTertiary,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (status != 'graded')
                                      IconButton(
                                        icon: const Icon(
                                            Icons.auto_awesome,
                                            color: PrepTheme.xpPurple,
                                            size: 20),
                                        tooltip: 'Correction IA',
                                        onPressed: () async {
                                          final result = await provider
                                              .triggerAiGrading(subId);
                                          if (result != null && ctx.mounted) {
                                            ScaffoldMessenger.of(ctx)
                                                .showSnackBar(SnackBar(
                                              content: Text(
                                                  'IA suggère ${result['ai_score']}/${assignment['max_score'] ?? 20}'),
                                            ));
                                            provider
                                                .loadSubmissions(assignmentId);
                                          }
                                        },
                                      ),
                                    IconButton(
                                      icon: Icon(
                                        status == 'graded'
                                            ? Icons.check_circle
                                            : Icons.grading,
                                        color: status == 'graded'
                                            ? PrepTheme.success
                                            : PrepTheme.primary,
                                        size: 20,
                                      ),
                                      tooltip: 'Noter',
                                      onPressed: () => _showGradeDialog(
                                          ctx,
                                          provider,
                                          sub,
                                          assignment,
                                          assignmentId),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showGradeDialog(
      BuildContext context,
      TeacherPrepAssignmentsProvider provider,
      Map<String, dynamic> submission,
      Map<String, dynamic> assignment,
      String assignmentId) {
    final subId = submission['id']?.toString() ?? '';
    final maxScore = (assignment['max_score'] as int?) ?? 20;
    final aiScore = submission['ai_score'];
    final scoreCtrl = TextEditingController(
        text: aiScore?.toString() ?? '');
    final commentCtrl = TextEditingController(
        text: submission['teacher_comment']?.toString() ?? '');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Noter la soumission',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (submission['ai_correction'] != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: PrepTheme.xpPurpleSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome,
                            color: PrepTheme.xpPurple, size: 16),
                        SizedBox(width: 6),
                        Text('Suggestion IA',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: PrepTheme.xpPurple)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Score: $aiScore/$maxScore',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (submission['ai_correction'] ?? '').toString(),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: scoreCtrl,
              decoration: InputDecoration(
                labelText: 'Note / $maxScore',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Commentaire',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: PrepTheme.success),
            onPressed: () async {
              final score = int.tryParse(scoreCtrl.text.trim());
              if (score == null) return;
              Navigator.of(ctx).pop();
              final ok = await provider.gradeSubmission(
                submissionId: subId,
                score: score,
                comment: commentCtrl.text.trim().isEmpty
                    ? null
                    : commentCtrl.text.trim(),
              );
              if (ok) {
                provider.loadSubmissions(assignmentId);
              }
            },
            child:
                const Text('Valider', style: TextStyle(color: Colors.white)),
          ),
        ],
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
    final concoursType = assignment['concours_type']?.toString();
    final subjectName = assignment['subject_name']?.toString();
    final isPublished = assignment['is_published'] == true;
    final subCount = (assignment['submission_count'] as int?) ?? 0;
    final gradedCount = (assignment['graded_count'] as int?) ?? 0;
    final type = (assignment['assignment_type'] ?? 'qcm').toString();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: PrepTheme.cardBox(
          borderColor: isPublished ? PrepTheme.success.withAlpha(60) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: PrepTheme.success.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                type == 'qcm'
                    ? Icons.quiz
                    : type == 'dissertation'
                        ? Icons.edit_note
                        : Icons.cases_outlined,
                color: PrepTheme.success,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (concoursType != null) ...[
                        PrepTheme.chip(concoursType, PrepTheme.primary),
                        const SizedBox(width: 6),
                      ],
                      if (subjectName != null)
                        PrepTheme.chip(subjectName, PrepTheme.success),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$gradedCount/$subCount',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: PrepTheme.success)),
                Text(isPublished ? 'Publié' : 'Brouillon',
                    style: TextStyle(
                      fontSize: 10,
                      color: isPublished
                          ? PrepTheme.success
                          : PrepTheme.textTertiary,
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
