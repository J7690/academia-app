import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modèle d'une question QCM.
class PrepQuestion {
  final String id;
  final String content;
  final List<String> options;
  final int correctIndex;
  final String? explanation;
  final String subject;
  final int difficulty; // 1-5
  final String? imageUrl;

  const PrepQuestion({
    required this.id,
    required this.content,
    required this.options,
    required this.correctIndex,
    this.explanation,
    this.subject = '',
    this.difficulty = 1,
    this.imageUrl,
  });

  factory PrepQuestion.fromMap(Map<String, dynamic> m) {
    final opts = m['options'];
    List<String> optionsList;
    if (opts is List) {
      optionsList = opts.map((e) => e.toString()).toList();
    } else {
      optionsList = [];
    }
    return PrepQuestion(
      id: m['id']?.toString() ?? '',
      content: m['content']?.toString() ?? '',
      options: optionsList,
      correctIndex: (m['correct_index'] as int?) ?? 0,
      explanation: m['explanation']?.toString(),
      subject: m['subject']?.toString() ?? '',
      difficulty: (m['difficulty'] as int?) ?? 1,
      imageUrl: m['image_url']?.toString(),
    );
  }
}

/// Résultat d'une réponse.
class PrepAnswer {
  final String questionId;
  final int selectedIndex;
  final bool isCorrect;
  final Duration timeSpent;

  const PrepAnswer({
    required this.questionId,
    required this.selectedIndex,
    required this.isCorrect,
    required this.timeSpent,
  });
}

/// État d'un quiz en cours.
enum QuizStatus { idle, inProgress, reviewing, completed }

class PrepQuizProvider extends ChangeNotifier {
  // ─── État quiz ─────────────────────────────────────────────────
  QuizStatus _status = QuizStatus.idle;
  List<PrepQuestion> _questions = [];
  List<PrepAnswer> _answers = [];
  int _currentIndex = 0;
  DateTime? _questionStartTime;
  int? _timeLimitSeconds;
  int _remainingSeconds = 0;
  bool _isExamMode = false;

  // ─── Progression / Gamification ────────────────────────────────
  int _totalXp = 0;
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalCorrect = 0;
  int _totalAnswered = 0;
  String? _lastActivityDate;

  // ─── Getters ───────────────────────────────────────────────────
  QuizStatus get status => _status;
  List<PrepQuestion> get questions => List.unmodifiable(_questions);
  List<PrepAnswer> get answers => List.unmodifiable(_answers);
  int get currentIndex => _currentIndex;
  int get remainingSeconds => _remainingSeconds;
  bool get isExamMode => _isExamMode;
  int get totalXp => _totalXp;
  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;
  int get totalCorrect => _totalCorrect;
  int get totalAnswered => _totalAnswered;

  PrepQuestion? get currentQuestion =>
      _currentIndex < _questions.length ? _questions[_currentIndex] : null;

  double get scorePercent =>
      _answers.isEmpty ? 0 : _answers.where((a) => a.isCorrect).length / _answers.length;

  int get correctCount => _answers.where((a) => a.isCorrect).length;

  bool get hasNext => _currentIndex < _questions.length - 1;

  // ─── Initialisation ────────────────────────────────────────────
  Future<void> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    _totalXp = prefs.getInt('prep_total_xp') ?? 0;
    _currentStreak = prefs.getInt('prep_current_streak') ?? 0;
    _longestStreak = prefs.getInt('prep_longest_streak') ?? 0;
    _totalCorrect = prefs.getInt('prep_total_correct') ?? 0;
    _totalAnswered = prefs.getInt('prep_total_answered') ?? 0;
    _lastActivityDate = prefs.getString('prep_last_activity');
    _checkStreak();
    notifyListeners();
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('prep_total_xp', _totalXp);
    await prefs.setInt('prep_current_streak', _currentStreak);
    await prefs.setInt('prep_longest_streak', _longestStreak);
    await prefs.setInt('prep_total_correct', _totalCorrect);
    await prefs.setInt('prep_total_answered', _totalAnswered);
    await prefs.setString('prep_last_activity', DateTime.now().toIso8601String().substring(0, 10));
  }

  void _checkStreak() {
    if (_lastActivityDate == null) return;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final yesterday = DateTime.now().subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
    if (_lastActivityDate != today && _lastActivityDate != yesterday) {
      _currentStreak = 0;
    }
  }

  void _updateStreak() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (_lastActivityDate != today) {
      _currentStreak++;
      if (_currentStreak > _longestStreak) {
        _longestStreak = _currentStreak;
      }
      _lastActivityDate = today;
    }
  }

  // ─── Démarrer un quiz ──────────────────────────────────────────
  void startQuiz({
    required List<PrepQuestion> questions,
    int? timeLimitSeconds,
    bool examMode = false,
  }) {
    _questions = List.of(questions);
    _answers = [];
    _currentIndex = 0;
    _timeLimitSeconds = timeLimitSeconds;
    _remainingSeconds = timeLimitSeconds ?? 0;
    _isExamMode = examMode;
    _status = QuizStatus.inProgress;
    _questionStartTime = DateTime.now();
    notifyListeners();
  }

  // ─── Répondre à une question ───────────────────────────────────
  void answerQuestion(int selectedIndex) {
    if (_status != QuizStatus.inProgress) return;
    if (_currentIndex >= _questions.length) return;

    final question = _questions[_currentIndex];
    final timeSpent = _questionStartTime != null
        ? DateTime.now().difference(_questionStartTime!)
        : Duration.zero;

    final isCorrect = selectedIndex == question.correctIndex;

    _answers.add(PrepAnswer(
      questionId: question.id,
      selectedIndex: selectedIndex,
      isCorrect: isCorrect,
      timeSpent: timeSpent,
    ));

    _totalAnswered++;
    if (isCorrect) {
      _totalCorrect++;
      _totalXp += 20;
    }

    if (!_isExamMode) {
      _status = QuizStatus.reviewing;
    }

    notifyListeners();
  }

  // ─── Passer à la question suivante ─────────────────────────────
  void nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      _currentIndex++;
      _status = QuizStatus.inProgress;
      _questionStartTime = DateTime.now();
    } else {
      _finishQuiz();
    }
    notifyListeners();
  }

  // ─── Terminer le quiz ──────────────────────────────────────────
  void _finishQuiz() {
    _status = QuizStatus.completed;

    // Bonus XP
    final pct = scorePercent;
    if (pct >= 1.0) {
      _totalXp += 25; // Perfect score
    } else if (pct >= 0.8) {
      _totalXp += 10; // Good score
    }

    if (_isExamMode) {
      _totalXp += 50; // Exam mode bonus
    }

    _updateStreak();
    _saveProgress();
    notifyListeners();
  }

  void finishExam() {
    // For exam mode: submit all at once
    _finishQuiz();
    notifyListeners();
  }

  // ─── Timer ─────────────────────────────────────────────────────
  void tickTimer() {
    if (_remainingSeconds > 0) {
      _remainingSeconds--;
      notifyListeners();
      if (_remainingSeconds <= 0) {
        _finishQuiz();
      }
    }
  }

  // ─── Reset ─────────────────────────────────────────────────────
  void resetQuiz() {
    _status = QuizStatus.idle;
    _questions = [];
    _answers = [];
    _currentIndex = 0;
    _questionStartTime = null;
    _timeLimitSeconds = null;
    _remainingSeconds = 0;
    _isExamMode = false;
    notifyListeners();
  }

  // ─── Données de démo ──────────────────────────────────────────
  static List<PrepQuestion> generateDemoQuestions({
    String subject = 'Culture Générale',
    int count = 10,
  }) {
    final allQuestions = <PrepQuestion>[
      PrepQuestion(
        id: 'q1',
        content: 'Quel est le plus long fleuve d\'Afrique ?',
        options: ['Le Congo', 'Le Nil', 'Le Niger', 'Le Zambèze'],
        correctIndex: 1,
        explanation: 'Le Nil mesure environ 6 650 km, ce qui en fait le plus long fleuve d\'Afrique et l\'un des plus longs au monde.',
        subject: 'Géographie',
        difficulty: 1,
      ),
      PrepQuestion(
        id: 'q2',
        content: 'En quelle année le Cameroun a-t-il obtenu son indépendance ?',
        options: ['1958', '1960', '1962', '1956'],
        correctIndex: 1,
        explanation: 'Le Cameroun français a obtenu son indépendance le 1er janvier 1960.',
        subject: 'Histoire',
        difficulty: 1,
      ),
      PrepQuestion(
        id: 'q3',
        content: 'Quelle est la formule chimique de l\'eau ?',
        options: ['CO₂', 'H₂O', 'NaCl', 'O₂'],
        correctIndex: 1,
        explanation: 'L\'eau est composée de deux atomes d\'hydrogène et un atome d\'oxygène : H₂O.',
        subject: 'Chimie',
        difficulty: 1,
      ),
      PrepQuestion(
        id: 'q4',
        content: 'Quel est le résultat de : 15² - 10² ?',
        options: ['125', '100', '225', '150'],
        correctIndex: 0,
        explanation: '15² = 225, 10² = 100. 225 - 100 = 125. On peut aussi utiliser l\'identité remarquable : (15-10)(15+10) = 5 × 25 = 125.',
        subject: 'Mathématiques',
        difficulty: 2,
      ),
      PrepQuestion(
        id: 'q5',
        content: 'Quelle institution camerounaise forme les administrateurs civils ?',
        options: ['IRIC', 'ENAM', 'ENS', 'ENSET'],
        correctIndex: 1,
        explanation: 'L\'ENAM (École Nationale d\'Administration et de Magistrature) forme les administrateurs civils et les magistrats.',
        subject: 'Culture Générale',
        difficulty: 2,
      ),
      PrepQuestion(
        id: 'q6',
        content: 'Quel est le principe fondamental de la séparation des pouvoirs ?',
        options: [
          'Législatif, exécutif, judiciaire',
          'Présidentiel, parlementaire, mixte',
          'Fédéral, unitaire, confédéral',
          'Monarchique, républicain, démocratique',
        ],
        correctIndex: 0,
        explanation: 'Montesquieu a théorisé la séparation des pouvoirs en trois branches : législatif, exécutif et judiciaire.',
        subject: 'Droit',
        difficulty: 2,
      ),
      PrepQuestion(
        id: 'q7',
        content: 'Quelle est la capitale politique du Cameroun ?',
        options: ['Douala', 'Yaoundé', 'Bafoussam', 'Garoua'],
        correctIndex: 1,
        explanation: 'Yaoundé est la capitale politique du Cameroun, tandis que Douala est la capitale économique.',
        subject: 'Géographie',
        difficulty: 1,
      ),
      PrepQuestion(
        id: 'q8',
        content: 'Si f(x) = 3x² + 2x - 1, quelle est la valeur de f\'(x) ?',
        options: ['6x + 2', '3x + 2', '6x² + 2', '6x - 1'],
        correctIndex: 0,
        explanation: 'La dérivée de 3x² est 6x, la dérivée de 2x est 2, et la dérivée de -1 est 0. Donc f\'(x) = 6x + 2.',
        subject: 'Mathématiques',
        difficulty: 3,
      ),
      PrepQuestion(
        id: 'q9',
        content: 'Quel organe est responsable de la production de la bile ?',
        options: ['L\'estomac', 'Le pancréas', 'Le foie', 'La rate'],
        correctIndex: 2,
        explanation: 'Le foie produit la bile, qui est stockée dans la vésicule biliaire et aide à la digestion des graisses.',
        subject: 'Biologie',
        difficulty: 2,
      ),
      PrepQuestion(
        id: 'q10',
        content: 'Quel traité a créé l\'Union Africaine (UA) ?',
        options: [
          'Traité d\'Abuja',
          'Acte constitutif de Lomé',
          'Charte de l\'OUA',
          'Acte constitutif de Durban',
        ],
        correctIndex: 1,
        explanation: 'L\'Acte constitutif de l\'Union Africaine a été adopté à Lomé (Togo) en 2000 et est entré en vigueur en 2001.',
        subject: 'Relations Internationales',
        difficulty: 3,
      ),
      PrepQuestion(
        id: 'q11',
        content: 'Quel est le PIB par habitant approximatif du Cameroun (2024) ?',
        options: ['500 USD', '1 600 USD', '3 200 USD', '5 000 USD'],
        correctIndex: 1,
        explanation: 'Le PIB par habitant du Cameroun est d\'environ 1 600 USD (Banque Mondiale, 2024).',
        subject: 'Économie',
        difficulty: 3,
      ),
      PrepQuestion(
        id: 'q12',
        content: 'En physique, quelle est l\'unité de mesure de la force ?',
        options: ['Joule', 'Watt', 'Newton', 'Pascal'],
        correctIndex: 2,
        explanation: 'Le Newton (N) est l\'unité de mesure de la force dans le Système International (SI). 1 N = 1 kg·m/s².',
        subject: 'Physique',
        difficulty: 1,
      ),
      PrepQuestion(
        id: 'q13',
        content: 'Quel philosophe a écrit "Le Contrat Social" ?',
        options: ['Voltaire', 'Montesquieu', 'Jean-Jacques Rousseau', 'John Locke'],
        correctIndex: 2,
        explanation: 'Jean-Jacques Rousseau a publié "Du Contrat Social" en 1762, ouvrage fondamental de la philosophie politique.',
        subject: 'Philosophie',
        difficulty: 2,
      ),
      PrepQuestion(
        id: 'q14',
        content: 'Quelle est la langue officielle de l\'Union Africaine qui n\'est PAS une langue officielle du Cameroun ?',
        options: ['Français', 'Anglais', 'Arabe', 'Espagnol'],
        correctIndex: 2,
        explanation: 'Le Cameroun a deux langues officielles : le français et l\'anglais. L\'arabe est une langue officielle de l\'UA mais pas du Cameroun.',
        subject: 'Culture Générale',
        difficulty: 2,
      ),
      PrepQuestion(
        id: 'q15',
        content: 'Résoudre : 2x + 5 = 17. Quelle est la valeur de x ?',
        options: ['4', '6', '7', '11'],
        correctIndex: 1,
        explanation: '2x + 5 = 17 → 2x = 12 → x = 6.',
        subject: 'Mathématiques',
        difficulty: 1,
      ),
    ];

    final rng = Random();
    final shuffled = List<PrepQuestion>.from(allQuestions)..shuffle(rng);
    return shuffled.take(min(count, shuffled.length)).toList();
  }
}
