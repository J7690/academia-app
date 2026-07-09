import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../theme/prep_theme.dart';
import 'psychotech_generator.dart';
import 'psychotech_ai_service.dart';
import 'psychotech_profile_widget.dart';
import 'widgets/domino_widget.dart';
import 'widgets/playing_card_widget.dart';
import 'widgets/sequence_display_widget.dart';

/// Onglet Psychotech — Machine de tests psychotechniques avec modes d'entraînement.
class PrepPsychotechTab extends StatefulWidget {
  const PrepPsychotechTab({super.key});

  @override
  State<PrepPsychotechTab> createState() => _PrepPsychotechTabState();
}

class _PrepPsychotechTabState extends State<PrepPsychotechTab> {
  // Mode selection
  bool _inSession = false;
  int _difficulty = 1;
  String _mode = 'libre'; // libre, exam_blanc, chrono, type

  // Session state
  List<PsychotechQuestion> _questions = [];
  int _currentIndex = 0;
  int? _selectedAnswer;
  bool _showResult = false;
  int _score = 0;
  int _totalTime = 0;
  DateTime? _questionStart;
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _sessionComplete = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startSession(String mode, {String? type, int count = 10, int? timeLimitSeconds}) {
    List<PsychotechQuestion> questions;

    if (mode == 'exam_blanc') {
      questions = PsychotechGenerator.generateExamBlanc();
    } else if (type != null) {
      questions = PsychotechGenerator.generateSession(count: count, type: type, difficulty: _difficulty);
    } else {
      questions = PsychotechGenerator.generateSession(count: count, difficulty: _difficulty, mixed: true);
    }

    setState(() {
      _inSession = true;
      _mode = mode;
      _questions = questions;
      _currentIndex = 0;
      _selectedAnswer = null;
      _showResult = false;
      _score = 0;
      _totalTime = 0;
      _sessionComplete = false;
      _questionStart = DateTime.now();
      _remainingSeconds = timeLimitSeconds ?? 0;
    });

    if (timeLimitSeconds != null && timeLimitSeconds > 0) {
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_remainingSeconds > 0) {
          setState(() => _remainingSeconds--);
        } else {
          _finishSession();
        }
      });
    }
  }

  void _selectAnswer(int index) {
    if (_showResult) return;
    final timeSpent = _questionStart != null ? DateTime.now().difference(_questionStart!).inMilliseconds : 0;
    _totalTime += timeSpent;

    final q = _questions[_currentIndex];
    final isCorrect = index == q.correctIndex;
    if (isCorrect) _score++;

    setState(() {
      _selectedAnswer = index;
      _showResult = true;
    });

    // Save to Supabase (fire-and-forget)
    _saveResult(q, index, isCorrect, timeSpent);

    // Request AI explanation if wrong (fire-and-forget, updates UI when ready)
    if (!isCorrect) {
      _loadAiExplanation(q, index);
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _showResult = false;
        _questionStart = DateTime.now();
      });
    } else {
      _finishSession();
    }
  }

  void _finishSession() {
    _timer?.cancel();
    setState(() => _sessionComplete = true);
  }

  void _exitSession() {
    _timer?.cancel();
    setState(() {
      _inSession = false;
      _sessionComplete = false;
      _questions = [];
    });
  }

  String? _aiExplanation;
  bool _loadingAiExplanation = false;

  Future<void> _saveResult(PsychotechQuestion q, int answer, bool isCorrect, int timeMs) async {
    try {
      await Supabase.instance.client.rpc('app_prep_save_psychotech_result', params: {
        'p_test_type': q.type,
        'p_difficulty': q.difficulty,
        'p_is_correct': isCorrect,
        'p_time_spent_ms': timeMs,
        'p_question_data': q.toJson(),
        'p_student_answer': {'index': answer, 'text': q.options[answer]},
        'p_correct_answer': {'index': q.correctIndex, 'text': q.options[q.correctIndex]},
        'p_explanation': q.explanation,
      });
    } catch (_) {}
  }

  Future<void> _loadAiExplanation(PsychotechQuestion q, int studentAnswer) async {
    setState(() { _loadingAiExplanation = true; _aiExplanation = null; });
    final explanation = await PsychotechAiService.explainError(
      question: q,
      studentAnswerIndex: studentAnswer,
    );
    if (mounted) {
      setState(() { _aiExplanation = explanation; _loadingAiExplanation = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionComplete) return _buildResultsView();
    if (_inSession) return _buildQuestionView();
    return _buildMenuView();
  }

  // ═══════════════════════════════════════════════════════════════
  // MENU — Choix du mode
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMenuView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF9333EA)]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.psychology, color: Colors.white, size: 28),
                SizedBox(width: 10),
                Text('Machine Psychotechnique', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              Text('Entraînement illimité · 7 types de tests · Adapté aux concours BF',
                  style: TextStyle(color: Colors.white.withAlpha(190), fontSize: 12)),
              const SizedBox(height: 14),
              // Difficulty selector
              Row(children: [
                const Text('Difficulté : ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ...List.generate(5, (i) => GestureDetector(
                  onTap: () => setState(() => _difficulty = i + 1),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: i < _difficulty ? Colors.white : Colors.white.withAlpha(40),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(child: Text('${i + 1}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                            color: i < _difficulty ? const Color(0xFF7C3AED) : Colors.white70))),
                  ),
                )),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Quick modes
        const Text('Modes d\'entraînement', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),

        _ModeCard(
          icon: Icons.bolt, title: 'Entraînement libre', subtitle: '10 questions · Tous types mélangés',
          gradient: const [Color(0xFF6366F1), Color(0xFF818CF8)],
          onTap: () => _startSession('libre', count: 10),
        ),
        const SizedBox(height: 10),
        _ModeCard(
          icon: Icons.timer, title: 'Exam blanc paramilitaire', subtitle: '35 questions · Format concours BF · 45 min',
          gradient: const [Color(0xFFEA580C), Color(0xFFF97316)],
          onTap: () => _startSession('exam_blanc', timeLimitSeconds: 45 * 60),
        ),
        const SizedBox(height: 10),
        _ModeCard(
          icon: Icons.speed, title: 'Mode chronométré', subtitle: '20 questions · 10 minutes',
          gradient: const [Color(0xFFDC2626), Color(0xFFEF4444)],
          onTap: () => _startSession('chrono', count: 20, timeLimitSeconds: 10 * 60),
        ),
        const SizedBox(height: 20),

        // By type
        const Text('Par type de test', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.6,
          ),
          itemCount: PsychotechGenerator.allTypes.length,
          itemBuilder: (context, i) {
            final t = PsychotechGenerator.allTypes[i];
            return _TypeCard(
              emoji: PsychotechGenerator.typeIcon(t),
              label: PsychotechGenerator.typeLabel(t),
              onTap: () => _startSession('type', type: t, count: 10),
            );
          },
        ),
        const SizedBox(height: 20),

        // Profile & Analytics
        const Text('Mon profil', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        const PsychotechProfileWidget(),
        const SizedBox(height: 24),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // QUESTION VIEW
  // ═══════════════════════════════════════════════════════════════
  Widget _buildQuestionView() {
    final q = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;

    return Column(
      children: [
        // Top bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          color: PrepTheme.scaffoldBg,
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: _exitSession, tooltip: 'Quitter'),
                Expanded(
                  child: Column(
                    children: [
                      Text('${_currentIndex + 1}/${_questions.length}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: progress, minHeight: 4,
                            backgroundColor: const Color(0xFFE0E0E0), valueColor: const AlwaysStoppedAnimation(Color(0xFF7C3AED))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFF7C3AED).withAlpha(20), borderRadius: BorderRadius.circular(8)),
                  child: Text('$_score pts', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED))),
                ),
                if (_remainingSeconds > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _remainingSeconds < 60 ? const Color(0xFFFFCDD2) : const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                            color: _remainingSeconds < 60 ? const Color(0xFFD32F2F) : const Color(0xFF1565C0))),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Type badge
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text(PsychotechGenerator.typeIcon(q.type), style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(PsychotechGenerator.typeLabel(q.type),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED))),
              const Spacer(),
              ...List.generate(5, (i) => Icon(
                i < q.difficulty ? Icons.star : Icons.star_border,
                size: 14, color: const Color(0xFFF59E0B),
              )),
            ],
          ),
        ),

        // Question content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question text
                Text(q.questionText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5)),
                const SizedBox(height: 20),

                // Visual rendering for dominos/cards
                if (q.type == 'dominos') _buildDominoVisual(q),
                if (q.type == 'cartes') _buildCardVisual(q),

                // Options
                OptionsGridWidget(
                  options: q.options,
                  selectedIndex: _selectedAnswer,
                  correctIndex: q.correctIndex,
                  showResult: _showResult,
                  onSelect: _selectAnswer,
                ),

                // Explanation (after answer)
                if (_showResult) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _selectedAnswer == q.correctIndex ? const Color(0xFFC8E6C9) : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _selectedAnswer == q.correctIndex
                          ? const Color(0xFF2E7D32).withAlpha(60) : const Color(0xFFF57C00).withAlpha(60)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(_selectedAnswer == q.correctIndex ? Icons.check_circle : Icons.lightbulb,
                              size: 18, color: _selectedAnswer == q.correctIndex ? const Color(0xFF2E7D32) : const Color(0xFFF57C00)),
                          const SizedBox(width: 8),
                          Text(_selectedAnswer == q.correctIndex ? 'Correct !' : 'Explication',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                                  color: _selectedAnswer == q.correctIndex ? const Color(0xFF2E7D32) : const Color(0xFFF57C00))),
                        ]),
                        const SizedBox(height: 8),
                        Text(q.explanation, style: const TextStyle(fontSize: 13, height: 1.4)),
                        const SizedBox(height: 6),
                        Text('💡 ${q.method}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF616161))),
                      ],
                    ),
                  ),
                  // AI-powered detailed explanation (when wrong)
                  if (_selectedAnswer != q.correctIndex) ...[
                    const SizedBox(height: 10),
                    if (_loadingAiExplanation)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE7F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED))),
                          SizedBox(width: 10),
                          Expanded(child: Text('L\'IA prépare une explication détaillée...', style: TextStyle(fontSize: 12, color: Color(0xFF7C3AED)))),
                        ]),
                      )
                    else if (_aiExplanation != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE7F6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF7C3AED).withAlpha(40)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [
                              Icon(Icons.auto_awesome, size: 16, color: Color(0xFF7C3AED)),
                              SizedBox(width: 6),
                              Text('Tuteur IA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED))),
                            ]),
                            const SizedBox(height: 8),
                            Text(_aiExplanation!, style: const TextStyle(fontSize: 13, height: 1.5)),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextQuestion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_currentIndex < _questions.length - 1 ? 'Question suivante →' : 'Voir les résultats'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDominoVisual(PsychotechQuestion q) {
    final data = q.questionData;
    if (data is! Map || data['dominos'] is! List) return const SizedBox.shrink();
    final dominos = (data['dominos'] as List).cast<List>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...dominos.sublist(0, dominos.length - 1).map((d) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DominoWidget(topValue: (d as List)[0] as int, bottomValue: d[1] as int, size: 50),
            )),
            DominoWidget(topValue: 0, bottomValue: 0, isHidden: true, size: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildCardVisual(PsychotechQuestion q) {
    final data = q.questionData;
    if (data is! Map || data['cards'] is! List) return const SizedBox.shrink();
    final cards = (data['cards'] as List).cast<String>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...cards.sublist(0, cards.length - 1).map((c) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: PlayingCardWidget.fromString(c, width: 44),
            )),
            const PlayingCardWidget(value: 0, suit: '', isHidden: true, width: 44),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // RESULTS VIEW
  // ═══════════════════════════════════════════════════════════════
  Widget _buildResultsView() {
    final total = _questions.length;
    final pct = total > 0 ? (_score / total * 100).round() : 0;
    final avgTime = total > 0 ? (_totalTime / total / 1000).toStringAsFixed(1) : '0';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 20),
        // Score circle
        Center(
          child: SizedBox(
            width: 120, height: 120,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(width: 120, height: 120,
                child: CircularProgressIndicator(
                  value: pct / 100, strokeWidth: 8, strokeCap: StrokeCap.round,
                  backgroundColor: const Color(0xFFE0E0E0),
                  valueColor: AlwaysStoppedAnimation(pct >= 70 ? const Color(0xFF2E7D32) : pct >= 50 ? const Color(0xFFF57C00) : const Color(0xFFD32F2F)),
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('$pct%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                const Text('Score', style: TextStyle(fontSize: 12, color: Color(0xFF757575))),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        Text(pct >= 80 ? '🎉 Excellent !' : pct >= 60 ? '👍 Bien joué !' : pct >= 40 ? '💪 Continue !' : '📚 Entraîne-toi encore !',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),

        // Stats row
        Row(children: [
          _StatChip(Icons.check_circle, '$_score/$total', 'Correct', const Color(0xFF2E7D32)),
          const SizedBox(width: 10),
          _StatChip(Icons.timer, '${avgTime}s', 'Moy/question', const Color(0xFF1565C0)),
          const SizedBox(width: 10),
          _StatChip(Icons.star, '$_difficulty/5', 'Difficulté', const Color(0xFFF59E0B)),
        ]),
        const SizedBox(height: 24),

        // Actions
        ElevatedButton.icon(
          onPressed: () => _startSession(_mode, count: _questions.length),
          icon: const Icon(Icons.replay, size: 18),
          label: const Text('Recommencer'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _exitSession,
          icon: const Icon(Icons.home, size: 18),
          label: const Text('Retour au menu'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Sub-widgets
// ═══════════════════════════════════════════════════════════════

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ModeCard({required this.icon, required this.title, required this.subtitle, required this.gradient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: gradient[0].withAlpha(40), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withAlpha(50), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 24)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: Colors.white.withAlpha(190), fontSize: 11)),
          ])),
          Icon(Icons.arrow_forward_ios, color: Colors.white.withAlpha(150), size: 16),
        ]),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const _TypeCard({required this.emoji, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatChip(this.icon, this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF757575))),
        ]),
      ),
    );
  }
}
