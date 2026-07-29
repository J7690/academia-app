import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'auto_record_game_wrapper.dart';
import '../services/game_results_service.dart';

/// Jeu "Défi 10 Secondes" — 10 questions flash, 10s par question.
/// Score = exactitude × rapidité. Résultat partageable.
class SpeedChallengeGameScreen extends StatefulWidget {
  const SpeedChallengeGameScreen({super.key});

  @override
  State<SpeedChallengeGameScreen> createState() => _SpeedChallengeGameScreenState();
}

// ---------------------------------------------------------------------------
// Modèles
// ---------------------------------------------------------------------------

enum _Subject { maths, economy, culture, french }

class _QuizQ {
  final String question;
  final List<String> choices;
  final int correctIndex;
  final _Subject subject;
  const _QuizQ(this.question, this.choices, this.correctIndex, this.subject);
}

// ---------------------------------------------------------------------------
// Banque de questions (40 — 10 par matière)
// ---------------------------------------------------------------------------

const _bank = <_QuizQ>[
  // Maths
  _QuizQ('12 × 13 = ?', ['146', '156', '166', '136'], 1, _Subject.maths),
  _QuizQ('√144 = ?', ['11', '12', '13', '14'], 1, _Subject.maths),
  _QuizQ('25% de 200 = ?', ['40', '50', '60', '45'], 1, _Subject.maths),
  _QuizQ('7³ = ?', ['243', '343', '443', '143'], 1, _Subject.maths),
  _QuizQ('15 + 27 × 2 = ?', ['84', '69', '54', '42'], 1, _Subject.maths),
  _QuizQ('3/4 + 1/2 = ?', ['5/4', '4/6', '1/1', '5/6'], 0, _Subject.maths),
  _QuizQ('Combien de faces a un cube ?', ['4', '6', '8', '12'], 1, _Subject.maths),
  _QuizQ('2⁵ = ?', ['16', '32', '64', '25'], 1, _Subject.maths),
  _QuizQ('Aire d\'un cercle r=7 ?', ['154', '44', '88', '22'], 0, _Subject.maths),
  _QuizQ('1000 ÷ 8 = ?', ['120', '125', '130', '115'], 1, _Subject.maths),

  // Économie
  _QuizQ('PIB signifie ?', ['Produit Intérieur Brut', 'Prix Indicatif de Base', 'Plan d\'Investissement Bancaire', 'Produit Initial Budgétaire'], 0, _Subject.economy),
  _QuizQ('Quand l\'offre augmente, le prix...', ['augmente', 'baisse', 'reste stable', 'double'], 1, _Subject.economy),
  _QuizQ('La monnaie du Burkina Faso ?', ['CFA', 'Euro', 'Dollar', 'Naira'], 0, _Subject.economy),
  _QuizQ('L\'inflation c\'est...', ['hausse des prix', 'baisse des prix', 'hausse du PIB', 'baisse du chômage'], 0, _Subject.economy),
  _QuizQ('UEMOA signifie ?', ['Union Éco. et Monétaire Ouest-Africaine', 'Union Européenne Monétaire', 'Union des États du Monde', 'Unité Éco. du Maroc'], 0, _Subject.economy),
  _QuizQ('Le taux de change mesure...', ['valeur d\'une monnaie vs une autre', 'taux d\'intérêt', 'taux de chômage', 'taux de croissance'], 0, _Subject.economy),
  _QuizQ('Un monopole c\'est...', ['un seul vendeur', 'deux vendeurs', 'beaucoup de vendeurs', 'aucun vendeur'], 0, _Subject.economy),
  _QuizQ('La BCEAO est...', ['Banque Centrale', 'Banque Commerciale', 'Bureau de Change', 'Bourse des valeurs'], 0, _Subject.economy),
  _QuizQ('Le chômage structurel est dû à...', ['inadéquation compétences/emplois', 'saisons', 'crise temporaire', 'vacances'], 0, _Subject.economy),
  _QuizQ('Adam Smith est le père de...', ['l\'économie classique', 'le marxisme', 'le keynésianisme', 'le mercantilisme'], 0, _Subject.economy),

  // Culture Burkina
  _QuizQ('Capitale du Burkina Faso ?', ['Ouagadougou', 'Bobo-Dioulasso', 'Koudougou', 'Banfora'], 0, _Subject.culture),
  _QuizQ('Le FESPACO est un festival de...', ['cinéma', 'musique', 'danse', 'littérature'], 0, _Subject.culture),
  _QuizQ('Thomas Sankara était...', ['président', 'roi', 'général', 'diplomate'], 0, _Subject.culture),
  _QuizQ('Ancien nom du Burkina Faso ?', ['Haute-Volta', 'Gold Coast', 'Dahomey', 'Soudan français'], 0, _Subject.culture),
  _QuizQ('Le Burkina a combien de régions ?', ['13', '10', '15', '8'], 0, _Subject.culture),
  _QuizQ('Langue la plus parlée ?', ['Mooré', 'Français', 'Dioula', 'Fulfuldé'], 0, _Subject.culture),
  _QuizQ('Le Burkina est indépendant depuis...', ['1960', '1958', '1962', '1975'], 0, _Subject.culture),
  _QuizQ('Le Nahouri est une...', ['province', 'ville', 'rivière', 'montagne'], 0, _Subject.culture),
  _QuizQ('Quel fleuve traverse Ouaga ?', ['Massili', 'Niger', 'Volta', 'Sénégal'], 0, _Subject.culture),
  _QuizQ('La devise du Burkina ?', ['Unité – Progrès – Justice', 'Liberté – Égalité – Fraternité', 'Un Peuple – Un But – Une Foi', 'Paix – Travail – Patrie'], 0, _Subject.culture),

  // Français
  _QuizQ('"Éphémère" signifie...', ['de courte durée', 'éternel', 'mystérieux', 'brillant'], 0, _Subject.french),
  _QuizQ('Quel est le pluriel de "œil" ?', ['yeux', 'œils', 'oeils', 'yeuxs'], 0, _Subject.french),
  _QuizQ('"Il ... venu hier" ?', ['est', 'a', 'ai', 'es'], 0, _Subject.french),
  _QuizQ('Un synonyme de "rapide" ?', ['véloce', 'lent', 'lourd', 'calme'], 0, _Subject.french),
  _QuizQ('Le contraire de "bénéfice" ?', ['déficit', 'profit', 'gain', 'revenu'], 0, _Subject.french),
  _QuizQ('"Parmi" s\'écrit avec...', ['un i final', 'un s final', 'deux i', 'un t'], 0, _Subject.french),
  _QuizQ('Victor Hugo a écrit...', ['Les Misérables', 'Candide', 'L\'Étranger', 'Germinal'], 0, _Subject.french),
  _QuizQ('"Nous ... partis" ?', ['sommes', 'avons', 'étions', 'serons'], 0, _Subject.french),
  _QuizQ('Un adverbe modifie...', ['un verbe', 'un nom', 'un article', 'un pronom'], 0, _Subject.french),
  _QuizQ('"Perspicace" signifie...', ['qui comprend vite', 'qui court vite', 'qui parle bien', 'qui mange beaucoup'], 0, _Subject.french),
];

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _SpeedChallengeGameScreenState extends State<SpeedChallengeGameScreen> {
  _Subject _selectedSubject = _Subject.maths;
  bool _gameStarted = false;
  bool _gameOver = false;

  late List<_QuizQ> _questions;
  int _currentQ = 0;
  int _score = 0;
  int _correctCount = 0;
  int _timeLeft = 10;
  Timer? _timer;
  int? _selectedAnswer;
  bool _answered = false;
  final GlobalKey _resultKey = GlobalKey();

  String _subjectLabel(_Subject s) {
    switch (s) {
      case _Subject.maths: return 'Maths';
      case _Subject.economy: return 'Économie';
      case _Subject.culture: return 'Culture Burkina';
      case _Subject.french: return 'Français';
    }
  }

  Color _subjectColor(_Subject s) {
    switch (s) {
      case _Subject.maths: return Colors.blue;
      case _Subject.economy: return const Color(0xFF1EA75C);
      case _Subject.culture: return Colors.orange;
      case _Subject.french: return Colors.red;
    }
  }

  IconData _subjectIcon(_Subject s) {
    switch (s) {
      case _Subject.maths: return Icons.calculate;
      case _Subject.economy: return Icons.trending_up;
      case _Subject.culture: return Icons.public;
      case _Subject.french: return Icons.menu_book;
    }
  }

  void _startGame() {
    final subjectQs = _bank.where((q) => q.subject == _selectedSubject).toList()..shuffle(Random());
    _questions = subjectQs.take(10).toList();
    setState(() {
      _gameStarted = true;
      _gameOver = false;
      _currentQ = 0;
      _score = 0;
      _correctCount = 0;
      _selectedAnswer = null;
      _answered = false;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = 10;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) {
        _timer?.cancel();
        _onTimeout();
      }
    });
  }

  void _onTimeout() {
    if (_answered) return;
    setState(() => _answered = true);
    Future.delayed(const Duration(milliseconds: 800), _nextQuestion);
  }

  void _answerQuestion(int index) {
    if (_answered) return;
    _timer?.cancel();
    final correct = index == _questions[_currentQ].correctIndex;
    final timeBonus = _timeLeft;
    setState(() {
      _selectedAnswer = index;
      _answered = true;
      if (correct) {
        _correctCount++;
        _score += 10 + timeBonus;
      }
    });
    Future.delayed(const Duration(milliseconds: 800), _nextQuestion);
  }

  void _nextQuestion() {
    if (!mounted) return;
    if (_currentQ + 1 >= _questions.length) {
      setState(() => _gameOver = true);
      GameRecordController.of(context)?.onGameFinished();
      // Conserver la partie : sans cela le score disparaissait avec l'écran.
      GameResultsService.record(
        gameType: 'Défi 10 Secondes',
        score: _score,
        correctAnswers: _correctCount,
        wrongAnswers: _questions.length - _correctCount,
      );
      return;
    }
    setState(() {
      _currentQ++;
      _selectedAnswer = null;
      _answered = false;
    });
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final color = _subjectColor(_selectedSubject);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Défi 10 Secondes'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _gameOver
            ? _buildResult()
            : _gameStarted
                ? _buildQuestion()
                : _buildSubjectPicker(),
      ),
    );
  }

  // --- Sélection matière ---
  Widget _buildSubjectPicker() {
    return LayoutBuilder(builder: (context, constraints) {
      final isSmall = constraints.maxWidth < 380;
      return SingleChildScrollView(
        padding: EdgeInsets.all(isSmall ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.bolt, size: isSmall ? 48 : 64, color: const Color(0xFF6C63FF)),
            SizedBox(height: isSmall ? 8 : 16),
            Text(
              'Choisis ta matière',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: isSmall ? 18 : 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: isSmall ? 4 : 8),
            Text(
              '10 questions • 10 secondes chacune\nScore = bonne réponse + rapidité',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: isSmall ? 12 : 14, color: Colors.grey[600]),
            ),
            SizedBox(height: isSmall ? 16 : 28),
            ..._Subject.values.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: _selectedSubject == s
                    ? _subjectColor(s).withValues(alpha: 0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                elevation: _selectedSubject == s ? 2 : 0,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _selectedSubject = s),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmall ? 12 : 16,
                      vertical: isSmall ? 12 : 16,
                    ),
                    child: Row(
                      children: [
                        Icon(_subjectIcon(s), color: _subjectColor(s), size: 28),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            _subjectLabel(s),
                            style: TextStyle(
                              fontSize: isSmall ? 15 : 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_selectedSubject == s)
                          Icon(Icons.check_circle, color: _subjectColor(s), size: 24),
                      ],
                    ),
                  ),
                ),
              ),
            )),
            SizedBox(height: isSmall ? 12 : 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startGame,
                icon: const Icon(Icons.play_arrow, size: 22),
                label: const Text('Lancer le défi !'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _subjectColor(_selectedSubject),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: TextStyle(fontSize: isSmall ? 15 : 17, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // --- Question ---
  Widget _buildQuestion() {
    final q = _questions[_currentQ];
    final color = _subjectColor(_selectedSubject);
    final progress = (_currentQ + 1) / _questions.length;
    final isUrgent = _timeLeft <= 3;

    return LayoutBuilder(builder: (context, constraints) {
      final isSmall = constraints.maxWidth < 380 || constraints.maxHeight < 650;
      final pad = isSmall ? 12.0 : 20.0;

      return SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top bar : score + timer
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Score : $_score',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
                // Timer cercle
                SizedBox(
                  width: 48, height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _timeLeft / 10,
                        strokeWidth: 4,
                        backgroundColor: Colors.grey[200],
                        color: isUrgent ? Colors.red : color,
                      ),
                      Text(
                        '$_timeLeft',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isUrgent ? Colors.red : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Text(
                    '${_currentQ + 1}/10',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress, minHeight: 4,
                backgroundColor: Colors.grey[200], color: color,
              ),
            ),
            SizedBox(height: isSmall ? 16 : 28),
            // Question
            Text(
              q.question,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isSmall ? 17 : 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: isSmall ? 16 : 24),
            // Choix
            ...List.generate(q.choices.length, (i) {
              final isCorrect = i == q.correctIndex;
              final isSelected = i == _selectedAnswer;
              Color? bg;
              Color? border;
              if (_answered) {
                if (isCorrect) {
                  bg = Colors.green.withValues(alpha: 0.15);
                  border = Colors.green;
                } else if (isSelected) {
                  bg = Colors.red.withValues(alpha: 0.15);
                  border = Colors.red;
                }
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: bg ?? Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _answered ? null : () => _answerQuestion(i),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmall ? 12 : 16,
                        vertical: isSmall ? 12 : 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: border ?? Colors.grey.withValues(alpha: 0.3),
                          width: border != null ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (border ?? color).withValues(alpha: 0.15),
                            ),
                            child: Center(
                              child: Text(
                                String.fromCharCode(65 + i),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: border ?? color,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              q.choices[i],
                              style: TextStyle(fontSize: isSmall ? 13 : 15),
                            ),
                          ),
                          if (_answered && isCorrect)
                            const Icon(Icons.check_circle, color: Colors.green, size: 22),
                          if (_answered && isSelected && !isCorrect)
                            const Icon(Icons.cancel, color: Colors.red, size: 22),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      );
    });
  }

  // --- Résultat ---
  Widget _buildResult() {
    final color = _subjectColor(_selectedSubject);
    final pct = (_correctCount / _questions.length * 100).round();
    final label = pct >= 80 ? 'Excellent !' : (pct >= 50 ? 'Bien joué !' : 'Continue !');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          RepaintBoundary(
            key: _resultKey,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [color, color.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(
                    pct >= 80 ? Icons.emoji_events : (pct >= 50 ? Icons.thumb_up : Icons.school),
                    size: 52, color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Text(label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _statCol('Score', '$_score', Colors.white),
                      _statCol('Bonnes', '$_correctCount/10', Colors.white),
                      _statCol('Taux', '$pct%', Colors.white),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _subjectLabel(_selectedSubject),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Academia', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _shareResult,
              icon: const Icon(Icons.share, size: 20),
              label: const Text('Partager mon score'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _startGame,
                  icon: const Icon(Icons.replay, size: 20),
                  label: const Text('Rejouer'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _gameStarted = false;
                    _gameOver = false;
                  }),
                  icon: const Icon(Icons.swap_horiz, size: 20),
                  label: const Text('Matière'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
      ],
    );
  }

  Future<void> _shareResult() async {
    try {
      final boundary = _resultKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final xFile = XFile.fromData(bytes, mimeType: 'image/png', name: 'defi_10s_academia.png');
      await Share.shareXFiles(
        [xFile],
        text: 'J\'ai eu $_score pts au Défi 10 Secondes en ${_subjectLabel(_selectedSubject)} ! '
            'Tu peux faire mieux ? 🔥⚡ Essaie sur Academia !',
        subject: 'Défi 10 Secondes - Academia',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }
}
