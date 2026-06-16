import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_config.dart';
import '../../../theme/td_theme.dart';

/// Onglet Exercices TD — Exercices enseignant + devoirs/exercices IA générés.
class TdExercisesTab extends StatefulWidget {
  const TdExercisesTab({super.key});

  @override
  State<TdExercisesTab> createState() => _TdExercisesTabState();
}

class _TdExercisesTabState extends State<TdExercisesTab> {
  bool _loading = true;
  bool _generating = false;
  List<Map<String, dynamic>> _teacherExercises = [];
  List<Map<String, dynamic>> _generatedAssignments = [];
  List<Map<String, dynamic>> _lastGeneratedExercises = [];

  static const _subjects = [
    'Mathématiques', 'Physique', 'Chimie', 'Biologie', 'Informatique',
    'Économie', 'Droit', 'Comptabilité', 'Gestion', 'Français', 'Anglais',
    'Philosophie', 'Histoire-Géo', 'Médecine', 'Agronomie',
  ];
  static const _levels = ['L1', 'L2', 'L3', 'M1', 'M2'];
  static const _semesters = ['S1', 'S2'];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([_loadTeacherExercises(), _loadGeneratedAssignments()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadTeacherExercises() async {
    try {
      final res = await Supabase.instance.client.rpc('app_td_student_list_exercises');
      if (res is List) {
        _teacherExercises = res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('[TdExercisesTab] loadTeacher error: $e');
    }
  }

  Future<void> _loadGeneratedAssignments() async {
    try {
      final res = await Supabase.instance.client.rpc('app_td_student_list_generated_assignments');
      if (res is Map && res['success'] == true && res['assignments'] is List) {
        _generatedAssignments = (res['assignments'] as List)
            .whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('[TdExercisesTab] loadGenerated error: $e');
    }
  }

  Future<void> _generateExercises({
    required String subject,
    required String mode,
    String? studyYear,
    String? semester,
    String? field,
    int count = 10,
    int totalPoints = 20,
    int durationMinutes = 60,
  }) async {
    setState(() => _generating = true);
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) throw Exception('Non authentifié');

      final uri = Uri.parse('${SupabaseConfig.url}/functions/v1/td-generate-exercises');
      final response = await http.post(uri, headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'apikey': SupabaseConfig.anonKey,
      }, body: jsonEncode({
        'subject': subject,
        'mode': mode,
        'count': count,
        if (studyYear != null) 'study_year': studyYear,
        if (semester != null) 'semester': semester,
        if (field != null) 'field': field,
        'total_points': totalPoints,
        'duration_minutes': durationMinutes,
      }));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final exercises = (data['exercises'] as List?)?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
          await _loadAll();
          if (mounted) {
            setState(() => _lastGeneratedExercises = exercises);
            if (exercises.isNotEmpty) {
              _showGeneratedExercisesSheet(
                exercises: exercises,
                subject: subject,
                mode: mode,
                totalPoints: data['total_points'] as int? ?? totalPoints,
                durationMinutes: data['duration_minutes'] as int? ?? durationMinutes,
                assignmentId: data['assignment_id']?.toString(),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('${data['generated_count']} questions générées !'),
                backgroundColor: const Color(0xFF059669),
              ));
            }
          }
        } else {
          throw Exception(data['error']?.toString() ?? 'Erreur inconnue');
        }
      } else {
        throw Exception('Erreur serveur (${response.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _showGenerateSheet({required String mode}) {
    String? subject;
    String? level;
    String? semester;
    int count = mode == 'exam' ? 15 : 10;
    int points = 20;
    int duration = mode == 'exam' ? 90 : 60;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
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
              Text(
                mode == 'exam' ? 'Générer un devoir type' : 'Générer des exercices',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                mode == 'exam'
                    ? 'Un sujet complet avec barème et durée'
                    : 'Des exercices QCM avec correction immédiate',
                style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: subject,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Matière *',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setS(() => subject = v),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: level,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Année',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: _levels.map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) => setS(() => level = v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: semester,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Semestre',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: _semesters.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) => setS(() => semester = v),
                  ),
                ),
              ]),
              if (mode == 'exam') ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: '$points',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Points',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (v) => points = int.tryParse(v) ?? 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: '$duration',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Durée (min)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (v) => duration = int.tryParse(v) ?? 60,
                    ),
                  ),
                ]),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: subject == null
                      ? null
                      : () {
                          Navigator.of(ctx).pop();
                          _generateExercises(
                            subject: subject!,
                            mode: mode,
                            studyYear: level,
                            semester: semester,
                            count: count,
                            totalPoints: points,
                            durationMinutes: duration,
                          );
                        },
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(mode == 'exam' ? 'Générer le devoir' : 'Générer les exercices'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TdTheme.studentTdGradient[1],
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGeneratedExercisesSheet({
    required List<Map<String, dynamic>> exercises,
    required String subject,
    required String mode,
    int totalPoints = 20,
    int durationMinutes = 60,
    String? assignmentId,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 12),
                  Row(children: [
                    Icon(mode == 'exam' ? Icons.description : Icons.auto_awesome,
                      color: mode == 'exam' ? const Color(0xFFDB2777) : TdTheme.studentTdGradient[1], size: 22),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      mode == 'exam' ? 'Devoir type — $subject' : 'Exercices générés — $subject',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    )),
                  ]),
                  if (mode == 'exam') ...[const SizedBox(height: 4), Text('$totalPoints pts • $durationMinutes min • ${exercises.length} questions', style: const TextStyle(fontSize: 12, color: Color(0xFF757575)))],
                  const Divider(height: 20),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: exercises.length,
                itemBuilder: (ctx, i) {
                  final ex = exercises[i];
                  final q = (ex['question'] ?? '').toString();
                  final options = (ex['options'] as List?)?.map((o) => o.toString()).toList() ?? [];
                  final correctIdx = (ex['correct_index'] as int?) ?? 0;
                  final explanation = (ex['explanation'] ?? '').toString();
                  final diff = (ex['difficulty'] as int?) ?? 2;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(color: TdTheme.studentTdGradient[1].withAlpha(20), borderRadius: BorderRadius.circular(8)),
                            child: Center(child: Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: TdTheme.studentTdGradient[1]))),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(4)),
                            child: Text('Difficulté $diff/5', style: const TextStyle(fontSize: 9, color: Color(0xFF7C3AED), fontWeight: FontWeight.w600)),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Text(q, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.4)),
                        if (options.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...List.generate(options.length, (j) {
                            final isCorrect = j == correctIdx;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(children: [
                                Icon(
                                  isCorrect ? Icons.check_circle : Icons.radio_button_unchecked,
                                  size: 16,
                                  color: isCorrect ? const Color(0xFF059669) : const Color(0xFFBDBDBD),
                                ),
                                const SizedBox(width: 6),
                                Expanded(child: Text(options[j], style: TextStyle(
                                  fontSize: 12,
                                  color: isCorrect ? const Color(0xFF059669) : const Color(0xFF424242),
                                  fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal,
                                ))),
                              ]),
                            );
                          }),
                        ],
                        if (explanation.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Icon(Icons.lightbulb_outline, size: 14, color: Color(0xFF059669)),
                              const SizedBox(width: 6),
                              Expanded(child: Text(explanation, style: const TextStyle(fontSize: 11, color: Color(0xFF374151), height: 1.4))),
                            ]),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTeacherExerciseSheet(Map<String, dynamic> exercise) {
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
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (subject != null || teacherName != null) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                if (subject != null) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: TdTheme.studentTdGradient[1].withAlpha(20), borderRadius: BorderRadius.circular(6)),
                  child: Text(subject, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: TdTheme.studentTdGradient[1])),
                ),
                if (teacherName != null) Text('Par $teacherName', style: const TextStyle(fontSize: 11, color: Color(0xFF757575))),
              ]),
            ],
            if (desc.isNotEmpty) ...[const SizedBox(height: 10), Text(desc, style: const TextStyle(fontSize: 13, color: Color(0xFF424242), height: 1.5))],
            const SizedBox(height: 16),
            if (hasSubmitted && status == 'graded')
              _statusBox(const Color(0xFFC8E6C9), const Color(0xFF2E7D32), Icons.check_circle, 'Corrigé', 'Note : $teacherScore / $maxScore')
            else if (hasSubmitted && aiScore != null)
              _statusBox(const Color(0xFFEDE7F6), const Color(0xFF7C3AED), Icons.auto_awesome, 'Correction IA', '$aiScore / $maxScore')
            else if (hasSubmitted)
              _statusBox(TdTheme.studentTdGradient[1].withAlpha(15), TdTheme.studentTdGradient[1], Icons.hourglass_top, 'Soumis', 'En attente de correction')
            else ...[
              TextField(controller: answerCtrl, maxLines: 6, decoration: const InputDecoration(labelText: 'Votre réponse', hintText: 'Rédigez votre réponse ici...', border: OutlineInputBorder(), alignLabelWithHint: true)),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: () async {
                  if (answerCtrl.text.trim().isEmpty) return;
                  Navigator.of(ctx).pop();
                  try {
                    await Supabase.instance.client.rpc('app_td_student_submit_exercise', params: {
                      'p_assignment_id': exercise['id'],
                      'p_answer_content': {'text': answerCtrl.text.trim()},
                    });
                    _loadAll();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Réponse soumise')));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
                  }
                },
                icon: const Icon(Icons.send, size: 18),
                label: const Text('Soumettre'),
                style: ElevatedButton.styleFrom(backgroundColor: TdTheme.studentTdGradient[1], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBox(Color bg, Color fg, IconData icon, String title, String subtitle) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: fg.withAlpha(60))),
    child: Row(children: [
      Icon(icon, color: fg, size: 22),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: fg, fontSize: 13)),
        Text(subtitle, style: const TextStyle(fontSize: 12)),
      ])),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final accent = TdTheme.studentTdGradient[1];

    if (_loading) return Center(child: CircularProgressIndicator(color: accent));

    return RefreshIndicator(
      color: accent,
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        children: [
          // ─── Generate buttons ─────────────────────────────────────
          Row(children: [
            Expanded(child: _GenerateButton(
              icon: Icons.auto_awesome,
              label: 'Générer exercices',
              color: accent,
              loading: _generating,
              onTap: () => _showGenerateSheet(mode: 'exercise'),
            )),
            const SizedBox(width: 10),
            Expanded(child: _GenerateButton(
              icon: Icons.description,
              label: 'Générer devoir type',
              color: const Color(0xFFDB2777),
              loading: _generating,
              onTap: () => _showGenerateSheet(mode: 'exam'),
            )),
          ]),
          if (_generating) ...[
            const SizedBox(height: 12),
            Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: accent)),
              const SizedBox(width: 10),
              const Text('Génération en cours...', style: TextStyle(fontSize: 13, color: Color(0xFF757575))),
            ])),
          ],
          const SizedBox(height: 20),

          // ─── Last generated exercises (if any) ─────────────────
          if (_lastGeneratedExercises.isNotEmpty) ...[            const Text('Derniers exercices générés', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('${_lastGeneratedExercises.length} exercices \u2022 Appuyez pour revoir', style: const TextStyle(fontSize: 11, color: Color(0xFF757575))),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showGeneratedExercisesSheet(
                exercises: _lastGeneratedExercises,
                subject: _lastGeneratedExercises.first['subject']?.toString() ?? 'Exercices',
                mode: 'exercise',
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: TdTheme.studentTdGradient[1].withAlpha(50)),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: TdTheme.studentTdGradient[1].withAlpha(20), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.auto_awesome, color: TdTheme.studentTdGradient[1], size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${_lastGeneratedExercises.length} exercices QCM générés', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('Appuyez pour voir les questions et corrections', style: const TextStyle(fontSize: 11, color: Color(0xFF757575))),
                  ])),
                  Icon(Icons.chevron_right, size: 18, color: TdTheme.studentTdGradient[1]),
                ]),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ─── Generated assignments (devoirs type) ─────────────────
          if (_generatedAssignments.isNotEmpty) ...[
            const Text('Devoirs type générés', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ..._generatedAssignments.map((a) => GestureDetector(
              onTap: () {
                final questionsJson = a['questions_json'];
                List<Map<String, dynamic>> questions = [];
                if (questionsJson is List) {
                  questions = questionsJson.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
                } else if (questionsJson is String) {
                  try {
                    final parsed = jsonDecode(questionsJson);
                    if (parsed is List) questions = parsed.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
                  } catch (_) {}
                }
                if (questions.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucune question trouvée dans ce devoir.')));
                  return;
                }
                _showGeneratedExercisesSheet(
                  exercises: questions,
                  subject: a['subject']?.toString() ?? 'Devoir',
                  mode: a['mode']?.toString() ?? 'exam',
                  totalPoints: a['total_points'] as int? ?? 20,
                  durationMinutes: a['duration_minutes'] as int? ?? 60,
                  assignmentId: a['id']?.toString(),
                );
              },
              child: _GeneratedAssignmentCard(assignment: a),
            )),
            const SizedBox(height: 20),
          ],

          // ─── Teacher exercises ─────────────────────────────────────
          const Text('Exercices enseignant', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (_teacherExercises.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE0E0E0))),
              child: Column(children: [
                Icon(Icons.assignment_outlined, size: 40, color: accent.withAlpha(80)),
                const SizedBox(height: 8),
                const Text('Aucun exercice enseignant', style: TextStyle(color: Color(0xFF757575), fontSize: 13)),
                const SizedBox(height: 4),
                const Text('Les exercices de vos enseignants apparaîtront ici.', style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 11)),
              ]),
            )
          else
            ..._teacherExercises.map((ex) => _TeacherExerciseCard(exercise: ex, onTap: () => _showTeacherExerciseSheet(ex))),
        ],
      ),
    );
  }
}

class _GenerateButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  const _GenerateButton({required this.icon, required this.label, required this.color, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: loading ? null : onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withAlpha(200)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: color.withAlpha(40), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        Icon(icon, color: Colors.white, size: 26),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _GeneratedAssignmentCard extends StatelessWidget {
  final Map<String, dynamic> assignment;
  const _GeneratedAssignmentCard({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final title = (assignment['title'] ?? '').toString();
    final subject = assignment['subject']?.toString() ?? '';
    final mode = assignment['mode']?.toString() ?? 'exam';
    final qCount = assignment['question_count'] as int? ?? 0;
    final pts = assignment['total_points'] as int? ?? 20;
    final dur = assignment['duration_minutes'] as int? ?? 60;
    final year = assignment['study_year']?.toString();
    final sem = assignment['semester']?.toString();
    final isExam = mode == 'exam';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isExam ? const Color(0xFFDB2777).withAlpha(50) : TdTheme.studentTdGradient[1].withAlpha(50)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: (isExam ? const Color(0xFFDB2777) : TdTheme.studentTdGradient[1]).withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(isExam ? Icons.description : Icons.auto_awesome,
            color: isExam ? const Color(0xFFDB2777) : TdTheme.studentTdGradient[1], size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 4, children: [
            _chip(subject, TdTheme.studentTdGradient[1]),
            if (year != null) _chip(year, const Color(0xFF059669)),
            if (sem != null) _chip(sem, const Color(0xFFF59E0B)),
            _chip('$qCount Q', const Color(0xFF6366F1)),
            if (isExam) ...[
              _chip('$pts pts', const Color(0xFFDB2777)),
              _chip('$dur min', const Color(0xFF0891B2)),
            ],
          ]),
        ])),
        const Icon(Icons.chevron_right, size: 18, color: Color(0xFFBDBDBD)),
      ]),
    );
  }

  Widget _chip(String text, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: c.withAlpha(20), borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: c)),
  );
}

class _TeacherExerciseCard extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final VoidCallback onTap;
  const _TeacherExerciseCard({required this.exercise, required this.onTap});

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
            Wrap(spacing: 6, children: [
              if (subject != null) Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: TdTheme.studentTdGradient[1].withAlpha(20), borderRadius: BorderRadius.circular(4)),
                child: Text(subject, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: TdTheme.studentTdGradient[1])),
              ),
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
