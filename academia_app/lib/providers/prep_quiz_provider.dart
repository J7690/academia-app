import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    // Try server first, fallback to local
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentSession != null) {
        final res = await client.rpc('app_prep_get_student_progress');
        if (res is Map) {
          final m = Map<String, dynamic>.from(res);
          _totalXp = (m['total_xp'] as int?) ?? 0;
          _currentStreak = (m['current_streak'] as int?) ?? 0;
          _longestStreak = (m['longest_streak'] as int?) ?? 0;
          _totalCorrect = (m['total_correct'] as int?) ?? 0;
          _totalAnswered = (m['total_answered'] as int?) ?? 0;
          _lastActivityDate = m['last_activity_date']?.toString();
          _checkStreak();
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('[PrepQuizProvider] Server load failed, using local: $e');
    }
    // Fallback to local SharedPreferences
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
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString('prep_last_activity', today);
    // Sync to server
    _syncProgressToServer(today);
  }

  Future<void> _syncProgressToServer(String lastActivityDate) async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) return;
      await client.rpc('app_prep_sync_student_progress', params: {
        'p_total_xp': _totalXp,
        'p_current_streak': _currentStreak,
        'p_longest_streak': _longestStreak,
        'p_total_correct': _totalCorrect,
        'p_total_answered': _totalAnswered,
        'p_last_activity_date': lastActivityDate,
      });
    } catch (e) {
      debugPrint('[PrepQuizProvider] Server sync failed: $e');
    }
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

  // ─── Stats par matière (depuis Supabase) ─────────────────────────
  List<Map<String, dynamic>> _subjectStats = [];
  List<Map<String, dynamic>> get subjectStats => _subjectStats;

  Future<void> loadSubjectStats() async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) return;
      final res = await client.rpc('app_prep_get_subject_stats');
      if (res is List) {
        _subjectStats = res
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[PrepQuizProvider] loadSubjectStats error: $e');
    }
  }

  // ─── Chargement des questions depuis Supabase ────────────────────
  bool _isLoadingQuestions = false;
  bool get isLoadingQuestions => _isLoadingQuestions;

  Future<List<PrepQuestion>> loadQuestionsFromServer({
    String? subject,
    String? concoursType,
    int? difficulty,
    int count = 10,
  }) async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) return [];
      final res = await client.rpc('app_prep_get_quiz_questions', params: {
        if (subject != null) 'p_subject': subject,
        if (concoursType != null) 'p_concours_type': concoursType,
        if (difficulty != null) 'p_difficulty': difficulty,
        'p_count': count,
      });
      if (res is List && res.isNotEmpty) {
        return res.whereType<Map>().map((m) {
          final map = Map<String, dynamic>.from(m);
          // Build options from choices or options field
          List<String> opts = [];
          int correctIdx = (map['correct_index'] as int?) ?? 0;
          final choices = map['choices'];
          if (choices is List && choices.isNotEmpty) {
            final sorted = List<Map<String, dynamic>>.from(
                choices.whereType<Map>().map((c) => Map<String, dynamic>.from(c)));
            sorted.sort((a, b) => ((a['sort_order'] ?? 0) as int).compareTo((b['sort_order'] ?? 0) as int));
            opts = sorted.map((c) => (c['text'] ?? '').toString()).toList();
            // Find correct index from choices
            for (int i = 0; i < sorted.length; i++) {
              if (sorted[i]['is_correct'] == true) {
                correctIdx = i;
                break;
              }
            }
          } else if (map['options'] is List) {
            opts = (map['options'] as List).map((e) => e.toString()).toList();
          }
          return PrepQuestion(
            id: (map['id'] ?? '').toString(),
            content: (map['content'] ?? map['question'] ?? '').toString(),
            options: opts,
            correctIndex: correctIdx,
            explanation: map['explanation']?.toString(),
            subject: (map['subject'] ?? '').toString(),
            difficulty: (map['difficulty'] as int?) ?? 1,
            imageUrl: map['image_url']?.toString(),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[PrepQuizProvider] loadQuestionsFromServer error: $e');
    }
    return [];
  }

  // ─── Chargement adaptatif des questions ──────────────────────────
  Future<List<PrepQuestion>> loadAdaptiveQuestionsFromServer({
    String? concoursType,
    int count = 10,
  }) async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) return [];
      
      final res = await client.rpc('app_prep_get_adaptive_quiz', params: {
        'p_count': count,
        if (concoursType != null) 'p_concours_type': concoursType,
      });
      
      if (res is Map && res['questions'] is List) {
        final questions = res['questions'] as List;
        return questions.whereType<Map>().map((m) {
          final map = Map<String, dynamic>.from(m);
          
          // Parse options
          List<String> opts = [];
          if (map['options'] is List) {
            opts = (map['options'] as List).map((e) => e.toString()).toList();
          }
          
          return PrepQuestion(
            id: (map['id'] ?? '').toString(),
            content: (map['question'] ?? '').toString(),
            options: opts,
            correctIndex: (map['correct_index'] as int?) ?? 0,
            explanation: map['explanation']?.toString(),
            subject: (map['subject'] ?? '').toString(),
            difficulty: (map['difficulty'] as int?) ?? 1,
            imageUrl: map['image_url']?.toString(),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[PrepQuizProvider] loadAdaptiveQuestionsFromServer error: $e');
    }
    return [];
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

  /// Start a quiz, loading from Supabase first; falls back to demo if DB is empty.
  Future<void> startQuizFromServer({
    String? subject,
    String? concoursType,
    int count = 10,
    int? timeLimitSeconds,
    bool examMode = false,
    bool adaptiveMode = false,
  }) async {
    _isLoadingQuestions = true;
    notifyListeners();
    try {
      List<PrepQuestion> questions;
      
      if (adaptiveMode) {
        // Use adaptive quiz RPC
        questions = await loadAdaptiveQuestionsFromServer(
          concoursType: concoursType,
          count: count,
        );
      } else {
        // Use regular quiz loading
        questions = await loadQuestionsFromServer(
          subject: subject,
          concoursType: concoursType,
          count: count,
        );
      }
      
      if (questions.isEmpty) {
        questions = generateDemoQuestions(subject: subject ?? 'Culture Générale', count: count);
      }
      startQuiz(questions: questions, timeLimitSeconds: timeLimitSeconds, examMode: examMode);
    } finally {
      _isLoadingQuestions = false;
      notifyListeners();
    }
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
        content: 'En quelle année le Burkina Faso a-t-il obtenu son indépendance ?',
        options: ['1958', '1960', '1962', '1956'],
        correctIndex: 1,
        explanation: 'La Haute-Volta (ancien nom du Burkina Faso) a obtenu son indépendance le 5 août 1960.',
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
        content: 'Quelle institution burkinabè forme les agents des régies financières ?',
        options: ['ENAM', 'ENAREF', 'ENS', 'Université Ki-Zerbo'],
        correctIndex: 1,
        explanation: 'L\'ENAREF (École Nationale des Régies Financières) forme les agents des douanes, des impôts et du trésor public au Burkina Faso.',
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
        content: 'Quelle est la capitale du Burkina Faso ?',
        options: ['Bobo-Dioulasso', 'Ouagadougou', 'Koudougou', 'Banfora'],
        correctIndex: 1,
        explanation: 'Ouagadougou est la capitale politique et administrative du Burkina Faso. Bobo-Dioulasso est la capitale économique.',
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
        content: 'Quelle est la monnaie utilisée au Burkina Faso ?',
        options: ['Le Naira', 'Le Franc CFA (XOF)', 'Le Cedi', 'Le Dalasi'],
        correctIndex: 1,
        explanation: 'Le Burkina Faso utilise le Franc CFA de l\'Afrique de l\'Ouest (XOF), émis par la BCEAO. Le pays est membre de l\'UEMOA.',
        subject: 'Économie',
        difficulty: 1,
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
        content: 'Que signifie "Burkina Faso" ?',
        options: ['Terre des hommes libres', 'Pays des hommes intègres', 'Nation des braves', 'Terre de paix'],
        correctIndex: 1,
        explanation: '"Burkina Faso" signifie "Pays des hommes intègres". "Burkina" vient du mooré (intégrité) et "Faso" du dioula (patrie).',
        subject: 'Culture Générale',
        difficulty: 1,
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
