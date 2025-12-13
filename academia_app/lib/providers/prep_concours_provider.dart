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

class PrepConcoursProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;

  List<PrepSubject> _subjects = const [];
  final Map<String, List<PrepChapter>> _chaptersBySubject = {};
  final Map<String, List<PrepChoice>> _choicesByQuestion = {};
  List<PrepAttemptItem> _myAttempts = const [];
  PrepSubjectStats? _mySubjectStats;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<PrepSubject> get subjects => _subjects;
  List<PrepAttemptItem> get myAttempts => _myAttempts;
  PrepSubjectStats? get mySubjectStats => _mySubjectStats;

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
}
