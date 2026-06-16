import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PrepSubject {
  final String id;
  final String slug;
  final String title;
  final String? description;
  final int? sortOrder;

  const PrepSubject({
    required this.id,
    required this.slug,
    required this.title,
    this.description,
    this.sortOrder,
  });

  factory PrepSubject.fromJson(Map<String, dynamic> json) {
    return PrepSubject(
      id: (json['id'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString().trim().isEmpty
          ? null
          : (json['description'] ?? '').toString(),
      sortOrder: json['sort_order'] is int ? json['sort_order'] as int : null,
    );
  }

}

class PrepAttemptItem {
  final String id;
  final DateTime? createdAt;
  final String attemptType;
  final bool? isCorrect;
  final int? timeSpentSec;
  final String questionId;
  final String subjectId;
  final String question;
  final String? correctAnswer;

  const PrepAttemptItem({
    required this.id,
    required this.createdAt,
    required this.attemptType,
    required this.isCorrect,
    required this.timeSpentSec,
    required this.questionId,
    required this.subjectId,
    required this.question,
    required this.correctAnswer,
  });

  factory PrepAttemptItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    bool? parseBool(dynamic v) {
      if (v is bool) return v;
      if (v == null) return null;
      final s = v.toString().toLowerCase();
      if (s == 'true') return true;
      if (s == 'false') return false;
      return null;
    }

    int? parseInt(dynamic v) {
      if (v is int) return v;
      if (v == null) return null;
      return int.tryParse(v.toString());
    }

    return PrepAttemptItem(
      id: (json['id'] ?? '').toString(),
      createdAt: parseDt(json['created_at']),
      attemptType: (json['attempt_type'] ?? 'training').toString(),
      isCorrect: parseBool(json['is_correct']),
      timeSpentSec: parseInt(json['time_spent_sec']),
      questionId: (json['question_id'] ?? '').toString(),
      subjectId: (json['subject_id'] ?? '').toString(),
      question: (json['question'] ?? '').toString(),
      correctAnswer: (json['correct_answer'] ?? '').toString().trim().isEmpty
          ? null
          : (json['correct_answer'] ?? '').toString(),
    );
  }
}

class PrepSubjectStats {
  final String subjectId;
  final int days;
  final int total;
  final int correct;
  final double accuracy;
  final double avgTimeSec;

  const PrepSubjectStats({
    required this.subjectId,
    required this.days,
    required this.total,
    required this.correct,
    required this.accuracy,
    required this.avgTimeSec,
  });

  factory PrepSubjectStats.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    double parseDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }

    return PrepSubjectStats(
      subjectId: (json['subject_id'] ?? '').toString(),
      days: parseInt(json['days']),
      total: parseInt(json['total']),
      correct: parseInt(json['correct']),
      accuracy: parseDouble(json['accuracy']),
      avgTimeSec: parseDouble(json['avg_time_sec']),
    );
  }
}

class PrepChapter {
  final String id;
  final String subjectId;
  final String slug;
  final String title;
  final String? description;
  final int? sortOrder;

  const PrepChapter({
    required this.id,
    required this.subjectId,
    required this.slug,
    required this.title,
    this.description,
    this.sortOrder,
  });

  factory PrepChapter.fromJson(Map<String, dynamic> json) {
    return PrepChapter(
      id: (json['id'] ?? '').toString(),
      subjectId: (json['subject_id'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString().trim().isEmpty
          ? null
          : (json['description'] ?? '').toString(),
      sortOrder: json['sort_order'] is int ? json['sort_order'] as int : null,
    );
  }
}

class PrepQuestion {
  final String id;
  final String subjectId;
  final String? chapterId;
  final String questionType;
  final String level;
  final String? mechanism;
  final String question;
  final String? explanation;
  final String? correctAnswer;
  final int? estimatedTimeSec;

  const PrepQuestion({
    required this.id,
    required this.subjectId,
    required this.chapterId,
    required this.questionType,
    required this.level,
    required this.mechanism,
    required this.question,
    required this.explanation,
    required this.correctAnswer,
    required this.estimatedTimeSec,
  });

  factory PrepQuestion.fromJson(Map<String, dynamic> json) {
    return PrepQuestion(
      id: (json['id'] ?? '').toString(),
      subjectId: (json['subject_id'] ?? '').toString(),
      chapterId: (json['chapter_id'] ?? '').toString().trim().isEmpty
          ? null
          : (json['chapter_id'] ?? '').toString(),
      questionType: (json['question_type'] ?? 'mcq').toString(),
      level: (json['level'] ?? 'beginner').toString(),
      mechanism: (json['mechanism'] ?? '').toString().trim().isEmpty
          ? null
          : (json['mechanism'] ?? '').toString(),
      question: (json['question'] ?? '').toString(),
      explanation: (json['explanation'] ?? '').toString().trim().isEmpty
          ? null
          : (json['explanation'] ?? '').toString(),
      correctAnswer: (json['correct_answer'] ?? '').toString().trim().isEmpty
          ? null
          : (json['correct_answer'] ?? '').toString(),
      estimatedTimeSec:
          json['estimated_time_sec'] is int ? json['estimated_time_sec'] as int : null,
    );
  }
}

class PrepChoice {
  final String id;
  final String questionId;
  final String? choiceLabel;
  final String choiceText;
  final int? sortOrder;

  const PrepChoice({
    required this.id,
    required this.questionId,
    required this.choiceLabel,
    required this.choiceText,
    required this.sortOrder,
  });

  factory PrepChoice.fromJson(Map<String, dynamic> json) {
    return PrepChoice(
      id: (json['id'] ?? '').toString(),
      questionId: (json['question_id'] ?? '').toString(),
      choiceLabel: (json['choice_label'] ?? '').toString().trim().isEmpty
          ? null
          : (json['choice_label'] ?? '').toString(),
      choiceText: (json['choice_text'] ?? '').toString(),
      sortOrder: json['sort_order'] is int ? json['sort_order'] as int : null,
    );
  }
}

// ─── Exam Blanc (Sujet blanc) models ──────────────────────────────────

class ExamBlancChoice {
  final String label;
  final String text;
  final bool isCorrect;

  const ExamBlancChoice({
    required this.label,
    required this.text,
    required this.isCorrect,
  });

  factory ExamBlancChoice.fromJson(Map<String, dynamic> json) {
    return ExamBlancChoice(
      label: (json['label'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      isCorrect: json['is_correct'] == true,
    );
  }
}

class ExamBlancQuestion {
  final String questionType; // 'qcm' or 'open'
  final String question;
  final String? explanation;
  final String? expectedAnswer; // for open-ended questions
  final int points; // points for this question (default 1 for QCM, 2 for open)
  final List<ExamBlancChoice> choices;

  const ExamBlancQuestion({
    this.questionType = 'qcm',
    required this.question,
    this.explanation,
    this.expectedAnswer,
    this.points = 1,
    required this.choices,
  });

  bool get isOpen => questionType == 'open';
  bool get isQcm => questionType == 'qcm';

  factory ExamBlancQuestion.fromJson(Map<String, dynamic> json) {
    final rawChoices = json['choices'];
    final choices = (rawChoices is List)
        ? rawChoices
            .whereType<Map>()
            .map((c) => ExamBlancChoice.fromJson(Map<String, dynamic>.from(c)))
            .toList()
        : <ExamBlancChoice>[];
    final type = (json['question_type'] ?? 'qcm').toString();
    return ExamBlancQuestion(
      questionType: type,
      question: (json['question'] ?? '').toString(),
      explanation: (json['explanation'] ?? '').toString().trim().isEmpty
          ? null
          : json['explanation'].toString(),
      expectedAnswer:
          (json['expected_answer'] ?? '').toString().trim().isEmpty
              ? null
              : json['expected_answer'].toString(),
      points: json['points'] is int ? json['points'] as int : (type == 'open' ? 2 : 1),
      choices: choices,
    );
  }
}

class ExamBlancSection {
  final String subjectName;
  final int questionsCount;
  final List<ExamBlancQuestion> questions;

  const ExamBlancSection({
    required this.subjectName,
    required this.questionsCount,
    required this.questions,
  });

  factory ExamBlancSection.fromJson(Map<String, dynamic> json) {
    final rawQ = json['questions'];
    final questions = (rawQ is List)
        ? rawQ
            .whereType<Map>()
            .map((q) => ExamBlancQuestion.fromJson(Map<String, dynamic>.from(q)))
            .toList()
        : <ExamBlancQuestion>[];
    return ExamBlancSection(
      subjectName: (json['subject_name'] ?? '').toString(),
      questionsCount: json['questions_count'] is int
          ? json['questions_count'] as int
          : questions.length,
      questions: questions,
    );
  }
}

class ExamBlanc {
  final String id;
  final String title;
  final String? description;
  final String concoursType;
  final int totalQuestions;
  final int durationMinutes;
  final int timesTaken;
  final double? avgScore;
  final bool alreadyTaken;
  final double? userBestScore;
  final DateTime? createdAt;
  final List<ExamBlancSection> sections;

  const ExamBlanc({
    required this.id,
    required this.title,
    this.description,
    required this.concoursType,
    required this.totalQuestions,
    required this.durationMinutes,
    required this.timesTaken,
    this.avgScore,
    this.alreadyTaken = false,
    this.userBestScore,
    this.createdAt,
    this.sections = const [],
  });

  factory ExamBlanc.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'];
    final sections = (rawSections is List)
        ? rawSections
            .whereType<Map>()
            .map((s) => ExamBlancSection.fromJson(Map<String, dynamic>.from(s)))
            .toList()
        : <ExamBlancSection>[];

    return ExamBlanc(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString().trim().isEmpty
          ? null
          : json['description'].toString(),
      concoursType: (json['concours_type'] ?? 'TOUS').toString(),
      totalQuestions: json['total_questions'] is int
          ? json['total_questions'] as int
          : 0,
      durationMinutes: json['duration_minutes'] is int
          ? json['duration_minutes'] as int
          : 120,
      timesTaken:
          json['times_taken'] is int ? json['times_taken'] as int : 0,
      avgScore: json['avg_score'] is num
          ? (json['avg_score'] as num).toDouble()
          : null,
      alreadyTaken: json['already_taken'] == true,
      userBestScore: json['user_best_score'] is num
          ? (json['user_best_score'] as num).toDouble()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      sections: sections,
    );
  }
}

class PrepConcoursProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;

  List<PrepSubject> _subjects = const [];
  final Map<String, List<PrepChapter>> _chaptersBySubject = {};
  final Map<String, List<PrepChoice>> _choicesByQuestion = {};
  List<PrepAttemptItem> _myAttempts = const [];
  PrepSubjectStats? _mySubjectStats;

  List<ExamBlanc> _examBlancs = const [];
  bool _isGeneratingExam = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<PrepSubject> get subjects => _subjects;
  List<PrepAttemptItem> get myAttempts => _myAttempts;
  PrepSubjectStats? get mySubjectStats => _mySubjectStats;
  List<ExamBlanc> get examBlancs => _examBlancs;
  bool get isGeneratingExam => _isGeneratingExam;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadSubjects() async {
    _setLoading(true);
    _setError(null);
    try {
      final res = await _client.rpc('app_prep_list_subjects');
      final list = (res is List ? res : const [])
          .whereType<Map>()
          .map((e) => PrepSubject.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
      _subjects = list;
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> createSubject({
    required String title,
    String? slug,
    String? description,
    int? sortOrder,
    bool isActive = true,
    bool reloadAfter = true,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final res = await _client.rpc(
        'app_admin_prep_create_subject',
        params: {
          'p_title': title,
          'p_slug': slug,
          'p_description': description,
          'p_sort_order': sortOrder,
          'p_is_active': isActive,
        },
      );

      if (res is! Map) {
        _setError('Réponse invalide du serveur.');
        return null;
      }

      final map = Map<String, dynamic>.from(res);
      if (map['success'] != true) {
        _setError(map['error']?.toString() ?? 'Erreur lors de la création.');
        return null;
      }

      final subject = map['subject'];
      String? id;
      if (subject is Map) {
        id = (subject['id'] ?? '').toString().trim();
      }
      if (reloadAfter) {
        await loadSubjects();
      }
      return id;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  List<PrepChapter> getChaptersForSubject(String subjectId) {
    return _chaptersBySubject[subjectId] ?? const [];
  }

  Future<void> loadChapters(String subjectId) async {
    _setLoading(true);
    _setError(null);
    try {
      final res = await _client.rpc(
        'app_prep_list_chapters',
        params: {'p_subject_id': subjectId},
      );
      final list = (res is List ? res : const [])
          .whereType<Map>()
          .map((e) => PrepChapter.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
      _chaptersBySubject[subjectId] = list;
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<List<PrepQuestion>> loadPublishedQuestions({
    required String subjectId,
    String? level,
    String? chapterId,
    int limit = 10,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final res = await _client.rpc(
        'app_prep_list_published_questions',
        params: {
          'p_subject_id': subjectId,
          'p_level': level,
          'p_limit': limit,
          'p_chapter_id': chapterId,
        },
      );
      final list = (res is List ? res : const [])
          .whereType<Map>()
          .map((e) => PrepQuestion.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
      return list;
    } catch (e) {
      _setError(e.toString());
      return const [];
    } finally {
      _setLoading(false);
    }
  }

  List<PrepChoice> getChoicesForQuestion(String questionId) {
    return _choicesByQuestion[questionId] ?? const [];
  }

  Future<void> loadChoices(String questionId) async {
    if (_choicesByQuestion.containsKey(questionId)) return;

    _setLoading(true);
    _setError(null);
    try {
      final res = await _client.rpc(
        'app_prep_list_question_choices',
        params: {'p_question_id': questionId},
      );
      final list = (res is List ? res : const [])
          .whereType<Map>()
          .map((e) => PrepChoice.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
      _choicesByQuestion[questionId] = list;
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createAttempt({
    required String questionId,
    required String attemptType,
    String? selectedAnswer,
    bool? isCorrect,
    int? timeSpentSec,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final res = await _client.rpc(
        'app_prep_create_attempt',
        params: {
          'p_question_id': questionId,
          'p_attempt_type': attemptType,
          'p_selected_answer': selectedAnswer,
          'p_is_correct': isCorrect,
          'p_time_spent_sec': timeSpentSec,
        },
      );
      if (res is Map) {
        final map = Map<String, dynamic>.from(res);
        if (map['success'] == true) {
          return true;
        }
        _setError(map['error']?.toString() ?? 'Erreur lors de l\'enregistrement.');
        return false;
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMyAttempts({String? subjectId, String? attemptType, int limit = 50}) async {
    _setLoading(true);
    _setError(null);
    try {
      final res = await _client.rpc(
        'app_prep_list_my_attempts',
        params: {
          'p_subject_id': subjectId,
          'p_attempt_type': attemptType,
          'p_limit': limit,
        },
      );

      if (res is! Map) {
        _setError('Réponse invalide du serveur.');
        return;
      }
      final map = Map<String, dynamic>.from(res);
      if (map['success'] != true) {
        _setError(map['error']?.toString() ?? 'Erreur lors du chargement.');
        return;
      }

      final attempts = map['attempts'];
      if (attempts is List) {
        _myAttempts = attempts
            .whereType<Map>()
            .map((e) => PrepAttemptItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false);
      } else {
        _myAttempts = const [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMySubjectStats({required String subjectId, int days = 30}) async {
    _setLoading(true);
    _setError(null);
    try {
      final res = await _client.rpc(
        'app_prep_get_my_subject_stats',
        params: {
          'p_subject_id': subjectId,
          'p_days': days,
        },
      );

      if (res is! Map) {
        _setError('Réponse invalide du serveur.');
        return;
      }
      final map = Map<String, dynamic>.from(res);
      if (map['success'] != true) {
        _setError(map['error']?.toString() ?? 'Erreur lors du chargement.');
        return;
      }
      _mySubjectStats = PrepSubjectStats.fromJson(map);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ─── Exam Blanc methods ───────────────────────────────────────────────

  Future<void> loadExamBlancs({String? concoursType}) async {
    _setLoading(true);
    _setError(null);
    try {
      final userId = _client.auth.currentUser?.id;
      final res = await _client.rpc('app_prep_list_exam_blancs', params: {
        'p_concours_type': concoursType,
        'p_user_id': userId,
        'p_limit': 20,
      });
      if (res is! Map) {
        _setError('Réponse invalide.');
        return;
      }
      final map = Map<String, dynamic>.from(res);
      if (map['success'] != true) {
        _setError(map['error']?.toString() ?? 'Erreur.');
        return;
      }
      final rawExams = map['exams'];
      _examBlancs = (rawExams is List)
          ? rawExams
              .whereType<Map>()
              .map((e) => ExamBlanc.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [];
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<ExamBlanc?> getExamBlanc(String examId) async {
    try {
      final res = await _client.rpc('app_prep_get_exam_blanc', params: {
        'p_exam_id': examId,
      });
      if (res is! Map) return null;
      final map = Map<String, dynamic>.from(res);
      if (map['success'] != true) return null;
      final raw = map['exam'];
      if (raw is! Map) return null;
      return ExamBlanc.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> submitExamBlanc({
    required String examId,
    required int score,
    required int total,
    required List<Map<String, dynamic>> answers,
    int? durationSeconds,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;
      final res = await _client.rpc('app_prep_submit_exam_blanc', params: {
        'p_exam_id': examId,
        'p_user_id': userId,
        'p_score': score,
        'p_total': total,
        'p_answers': answers,
        'p_duration_seconds': durationSeconds,
      });
      if (res is! Map) return null;
      return Map<String, dynamic>.from(res);
    } catch (_) {
      return null;
    }
  }

  Future<bool> requestNewExamBlanc({String concoursType = 'TOUS'}) async {
    _isGeneratingExam = true;
    notifyListeners();
    try {
      final resp = await _client.functions.invoke(
        'prep-compose-exam-blanc',
        body: {'concours_type': concoursType},
      );
      final data = resp.data;
      if (data is Map && data['success'] == true) {
        await loadExamBlancs(concoursType: null);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      _isGeneratingExam = false;
      notifyListeners();
    }
  }
}
