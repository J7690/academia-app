import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Modèle pour une faiblesse par matière
class SubjectWeakness {
  final String subjectId;
  final String subjectName;
  final double successRate;
  final int totalQuestions;
  final int correctAnswers;
  final int incorrectAnswers;
  final double weaknessScore;
  final bool needsPractice;
  final int recommendedDifficulty;
  final String priority;

  const SubjectWeakness({
    required this.subjectId,
    required this.subjectName,
    required this.successRate,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.incorrectAnswers,
    required this.weaknessScore,
    required this.needsPractice,
    required this.recommendedDifficulty,
    required this.priority,
  });

  factory SubjectWeakness.fromMap(Map<String, dynamic> map) {
    return SubjectWeakness(
      subjectId: map['subject_id']?.toString() ?? '',
      subjectName: map['subject_name']?.toString() ?? '',
      successRate: (map['success_rate'] as num?)?.toDouble() ?? 0.0,
      totalQuestions: (map['total_questions'] as int?) ?? 0,
      correctAnswers: (map['correct_answers'] as int?) ?? 0,
      incorrectAnswers: (map['incorrect_answers'] as int?) ?? 0,
      weaknessScore: (map['weakness_score'] as num?)?.toDouble() ?? 0.0,
      needsPractice: map['needs_practice'] ?? false,
      recommendedDifficulty: (map['recommended_difficulty'] as int?) ?? 3,
      priority: map['priority']?.toString() ?? 'low',
    );
  }
}

/// Modèle pour une recommandation
class StudyRecommendation {
  final String subject;
  final String subjectId;
  final String message;
  final int suggestedDifficulty;
  final int suggestedPracticeCount;
  final String practicePriority;

  const StudyRecommendation({
    required this.subject,
    required this.subjectId,
    required this.message,
    required this.suggestedDifficulty,
    required this.suggestedPracticeCount,
    required this.practicePriority,
  });

  factory StudyRecommendation.fromMap(Map<String, dynamic> map) {
    return StudyRecommendation(
      subject: map['subject']?.toString() ?? '',
      subjectId: map['subject_id']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      suggestedDifficulty: (map['suggested_difficulty'] as int?) ?? 3,
      suggestedPracticeCount: (map['suggested_practice_count'] as int?) ?? 10,
      practicePriority: map['practice_priority']?.toString() ?? 'Faible',
    );
  }
}

/// Modèle pour la performance récente
class RecentPerformance {
  final DateTime date;
  final int score;
  final int totalQuestions;

  const RecentPerformance({
    required this.date,
    required this.score,
    required this.totalQuestions,
  });

  factory RecentPerformance.fromMap(Map<String, dynamic> map) {
    return RecentPerformance(
      date: DateTime.parse(map['date']?.toString() ?? DateTime.now().toIso8601String()),
      score: (map['score'] as int?) ?? 0,
      totalQuestions: (map['total_questions'] as int?) ?? 0,
    );
  }
}

/// Provider pour gérer l'analyse des faiblesses et le suivi de progression
class PrepWeaknessProvider extends ChangeNotifier {
  // ─── État ─────────────────────────────────────────────────────
  List<SubjectWeakness> _weakestSubjects = [];
  List<StudyRecommendation> _recommendations = [];
  List<RecentPerformance> _recentPerformances = [];
  Map<String, dynamic> _progressSummary = {};
  bool _isLoading = false;
  String? _error;
  double? _averageScoreTrend;

  // ─── Getters ───────────────────────────────────────────────────
  List<SubjectWeakness> get weakestSubjects => List.unmodifiable(_weakestSubjects);
  List<StudyRecommendation> get recommendations => List.unmodifiable(_recommendations);
  List<RecentPerformance> get recentPerformances => List.unmodifiable(_recentPerformances);
  Map<String, dynamic> get progressSummary => Map.unmodifiable(_progressSummary);
  bool get isLoading => _isLoading;
  String? get error => _error;
  double? get averageScoreTrend => _averageScoreTrend;

  // Stats calculées
  int get totalSubjectsPracticed => 
      (_progressSummary['total_subjects_practiced'] as int?) ?? 0;
  
  int get subjectsNeedingPractice => 
      (_progressSummary['subjects_needing_practice'] as int?) ?? 0;
  
  double get overallSuccessRate => 
      (_progressSummary['overall_success_rate'] as num?)?.toDouble() ?? 0.0;
  
  int get totalQuestionsAnswered => 
      (_progressSummary['total_questions_answered'] as int?) ?? 0;
  
  int get totalCorrectAnswers => 
      (_progressSummary['total_correct_answers'] as int?) ?? 0;

  // ─── Chargement de l'analyse des faiblesses ───────────────────
  Future<void> loadWeaknessAnalysis() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final client = Supabase.instance.client;
      
      if (client.auth.currentSession == null) {
        throw Exception('Non authentifié');
      }

      final response = await client.rpc('app_prep_get_weakness_analysis');
      
      if (response is Map) {
        // Parse weakest subjects
        if (response['weakest_subjects'] is List) {
          _weakestSubjects = (response['weakest_subjects'] as List)
              .whereType<Map>()
              .map((m) => SubjectWeakness.fromMap(Map<String, dynamic>.from(m)))
              .toList();
        }

        // Parse progress summary
        if (response['progress_summary'] is Map) {
          _progressSummary = Map<String, dynamic>.from(response['progress_summary']);
        }

        // Parse recommendations
        if (response['recommendations'] is List) {
          _recommendations = (response['recommendations'] as List)
              .whereType<Map>()
              .map((m) => StudyRecommendation.fromMap(Map<String, dynamic>.from(m)))
              .toList();
        }

        // Parse recent performance
        if (response['recent_performance'] is Map) {
          final recentPerf = response['recent_performance'] as Map;
          
          if (recentPerf['last_7_days'] is List) {
            _recentPerformances = (recentPerf['last_7_days'] as List)
                .whereType<Map>()
                .map((m) => RecentPerformance.fromMap(Map<String, dynamic>.from(m)))
                .toList();
          }

          _averageScoreTrend = (recentPerf['average_score_trend'] as num?)?.toDouble();
        }
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('[PrepWeaknessProvider] Error loading weakness analysis: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Obtenir la faiblesse principale ──────────────────────────
  SubjectWeakness? get primaryWeakness {
    if (_weakestSubjects.isEmpty) return null;
    return _weakestSubjects.first;
  }

  // ─── Obtenir la recommandation principale ─────────────────────
  StudyRecommendation? get primaryRecommendation {
    if (_recommendations.isEmpty) return null;
    return _recommendations.first;
  }

  // ─── Calculer l'évolution sur 7 jours ─────────────────────────
  double calculateWeeklyProgress() {
    if (_recentPerformances.length < 2) return 0.0;
    
    // Comparer la moyenne des 3 premiers jours vs 3 derniers jours
    final recentScores = _recentPerformances.take(3)
        .map((p) => p.score.toDouble())
        .toList();
    final olderScores = _recentPerformances.skip(_recentPerformances.length - 3)
        .map((p) => p.score.toDouble())
        .toList();
    
    if (recentScores.isEmpty || olderScores.isEmpty) return 0.0;
    
    final recentAvg = recentScores.reduce((a, b) => a + b) / recentScores.length;
    final olderAvg = olderScores.reduce((a, b) => a + b) / olderScores.length;
    
    return recentAvg - olderAvg;
  }

  // ─── Obtenir le niveau de maîtrise global ────────────────────
  String getGlobalMasteryLevel() {
    if (overallSuccessRate >= 80) return 'Excellent';
    if (overallSuccessRate >= 60) return 'Bon';
    if (overallSuccessRate >= 40) return 'En progression';
    return 'Débutant';
  }

  // ─── Obtenir la couleur associée à un taux de réussite ───────
  static int getColorForSuccessRate(double rate) {
    if (rate >= 80) return 0xFF4CAF50; // Green
    if (rate >= 60) return 0xFFFF9800; // Orange
    if (rate >= 40) return 0xFFFF5722; // Deep Orange
    return 0xFFF44336; // Red
  }

  // ─── Rafraîchir les données ───────────────────────────────────
  Future<void> refresh() async {
    await loadWeaknessAnalysis();
  }

  // ─── Réinitialiser ────────────────────────────────────────────
  void reset() {
    _weakestSubjects = [];
    _recommendations = [];
    _recentPerformances = [];
    _progressSummary = {};
    _isLoading = false;
    _error = null;
    _averageScoreTrend = null;
    notifyListeners();
  }
}
