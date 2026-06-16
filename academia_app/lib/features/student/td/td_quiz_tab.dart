import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/td_theme.dart';
import 'td_scan_subject_screen.dart';

/// Onglet Quiz TD — Questions universitaires depuis td_questions (séparé du concours).
class TdQuizTab extends StatefulWidget {
  const TdQuizTab({super.key});

  @override
  State<TdQuizTab> createState() => _TdQuizTabState();
}

class _TdQuizTabState extends State<TdQuizTab> {
  bool _loadingSubjects = true;
  bool _inQuiz = false;
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  int? _selectedAnswer;
  bool _showResult = false;
  int _score = 0;
  String? _selectedSubject;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    setState(() => _loadingSubjects = true);
    try {
      final res = await Supabase.instance.client.rpc('app_td_student_list_subjects');
      if (res is Map && res['success'] == true && res['subjects'] is List) {
        _subjects = (res['subjects'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('[TdQuizTab] loadSubjects error: $e');
    }
    if (mounted) setState(() => _loadingSubjects = false);
  }

  Future<void> _startQuiz({String? subject, int count = 10}) async {
    try {
      final res = await Supabase.instance.client.rpc('app_td_student_get_quiz_questions', params: {
        'p_subject': subject,
        'p_count': count,
      });
      if (res is Map && res['success'] == true && res['questions'] is List) {
        final qs = (res['questions'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        if (qs.isNotEmpty) {
          setState(() {
            _questions = qs;
            _currentIndex = 0;
            _selectedAnswer = null;
            _showResult = false;
            _score = 0;
            _inQuiz = true;
            _selectedSubject = subject;
          });
        }
      }
    } catch (e) {
      debugPrint('[TdQuizTab] startQuiz error: $e');
    }
  }

  void _selectAnswer(int index) {
    if (_showResult) return;
    final q = _questions[_currentIndex];
    final correct = (q['correct_index'] as int?) ?? 0;
    if (index == correct) _score++;
    setState(() { _selectedAnswer = index; _showResult = true; });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() { _currentIndex++; _selectedAnswer = null; _showResult = false; });
    } else {
      setState(() => _inQuiz = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_inQuiz && _questions.isNotEmpty) return _buildQuizView();
    return _buildMenuView();
  }

  Widget _buildMenuView() {
    if (_loadingSubjects) return Center(child: CircularProgressIndicator(color: TdTheme.studentTdGradient[1]));

    final totalQ = _subjects.fold<int>(0, (sum, s) => sum + ((s['cnt'] as int?) ?? 0));

    return RefreshIndicator(
      color: TdTheme.studentTdGradient[1],
      onRefresh: _loadSubjects,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: LinearGradient(colors: TdTheme.studentTdGradient), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.quiz, color: Colors.white, size: 24),
                SizedBox(width: 10),
                Text('Quiz Universitaire', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              Text('$totalQ questions · ${_subjects.length} matières · Adapté aux universités BF',
                  style: TextStyle(color: Colors.white.withAlpha(190), fontSize: 12)),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: () => _startQuiz(count: 10),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Quiz rapide (10 questions)'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: TdTheme.studentTdGradient[1], padding: const EdgeInsets.symmetric(vertical: 12)),
              )),
            ]),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TdScanSubjectScreen(),
                  ),
                );
              },
              icon: Icon(Icons.document_scanner, color: TdTheme.studentTdGradient[1], size: 18),
              label: Text(
                'Scanner un exercice (correction IA)',
                style: TextStyle(color: TdTheme.studentTdGradient[1], fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: TdTheme.studentTdGradient[1].withAlpha(120)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 18),

          const Text('Par matière', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),

          if (_subjects.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Aucune question disponible.', style: TextStyle(color: Color(0xFF9E9E9E)))))
          else
            ..._subjects.map((s) {
              final subject = (s['subject'] ?? '').toString();
              final cnt = (s['cnt'] as int?) ?? 0;
              return GestureDetector(
                onTap: () => _startQuiz(subject: subject, count: 10),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0E0E0))),
                  child: Row(children: [
                    Container(width: 40, height: 40,
                      decoration: BoxDecoration(color: TdTheme.studentTdGradient[1].withAlpha(20), borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.school, color: TdTheme.studentTdGradient[1], size: 20)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(subject, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                    Text('$cnt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: TdTheme.studentTdGradient[1])),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 14, color: TdTheme.studentTdGradient[1]),
                  ]),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildQuizView() {
    final q = _questions[_currentIndex];
    final content = (q['content'] ?? '').toString();
    final options = (q['options'] is List) ? (q['options'] as List).cast<String>() : <String>[];
    final correctIdx = (q['correct_index'] as int?) ?? 0;
    final explanation = (q['explanation'] ?? '').toString();
    final subject = (q['subject'] ?? '').toString();
    final progress = (_currentIndex + 1) / _questions.length;
    final isLast = _currentIndex >= _questions.length - 1;

    return Column(children: [
      // Top bar
      Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
        color: TdTheme.scaffoldBg,
        child: Row(children: [
          IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => setState(() => _inQuiz = false)),
          Expanded(child: Column(children: [
            Text('${_currentIndex + 1}/${_questions.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: const Color(0xFFE0E0E0), valueColor: AlwaysStoppedAnimation(TdTheme.studentTdGradient[1]))),
          ])),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: TdTheme.studentTdGradient[1].withAlpha(20), borderRadius: BorderRadius.circular(8)),
            child: Text('$_score pts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: TdTheme.studentTdGradient[1]))),
        ]),
      ),
      if (subject.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Align(alignment: Alignment.centerLeft, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: TdTheme.studentTdGradient[1].withAlpha(20), borderRadius: BorderRadius.circular(6)),
          child: Text(subject, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: TdTheme.studentTdGradient[1]))))),

      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(content, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5)),
        const SizedBox(height: 20),
        ...List.generate(options.length, (i) {
          final isSelected = _selectedAnswer == i;
          final isCorrect = i == correctIdx;
          final isWrong = _showResult && isSelected && !isCorrect;
          Color bg, border, textC;
          if (_showResult && isCorrect) { bg = const Color(0xFFC8E6C9); border = const Color(0xFF2E7D32); textC = const Color(0xFF1B5E20); }
          else if (isWrong) { bg = const Color(0xFFFFCDD2); border = const Color(0xFFD32F2F); textC = const Color(0xFFB71C1C); }
          else if (isSelected) { bg = const Color(0xFFE3F2FD); border = TdTheme.studentTdGradient[1]; textC = TdTheme.studentTdGradient[1]; }
          else { bg = Colors.white; border = const Color(0xFFBDBDBD); textC = const Color(0xFF424242); }

          return GestureDetector(
            onTap: _showResult ? null : () => _selectAnswer(i),
            child: Container(
              width: double.infinity, margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border, width: isSelected || (_showResult && isCorrect) ? 2 : 1)),
              child: Row(children: [
                if (_showResult && isCorrect) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 18)),
                if (isWrong) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.cancel, color: Color(0xFFD32F2F), size: 18)),
                Expanded(child: Text(options[i], style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textC))),
              ]),
            ),
          );
        }),

        if (_showResult) ...[
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _selectedAnswer == correctIdx ? const Color(0xFFC8E6C9) : const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(_selectedAnswer == correctIdx ? Icons.check_circle : Icons.lightbulb, size: 18, color: _selectedAnswer == correctIdx ? const Color(0xFF2E7D32) : const Color(0xFFF57C00)),
                const SizedBox(width: 8),
                Text(_selectedAnswer == correctIdx ? 'Correct !' : 'Explication', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _selectedAnswer == correctIdx ? const Color(0xFF2E7D32) : const Color(0xFFF57C00))),
              ]),
              const SizedBox(height: 8),
              Text(explanation, style: const TextStyle(fontSize: 13, height: 1.4)),
            ])),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _nextQuestion,
            style: ElevatedButton.styleFrom(backgroundColor: TdTheme.studentTdGradient[1], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(isLast ? 'Voir les résultats ($_score/${_questions.length})' : 'Question suivante →'),
          )),
        ],
      ]))),
    ]);
  }
}
