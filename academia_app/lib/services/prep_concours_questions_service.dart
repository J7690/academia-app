import 'dart:convert';
import 'package:flutter/services.dart';

/// Service pour gérer les questions de préparation au concours
class PrepConcoursQuestionsService {
  static const String _questionsAssetPath = 
      'assets/data/prep_concours_questions_burkina.json';
  
  Map<String, dynamic>? _questionsData;
  List<Map<String, dynamic>> _allQuestions = [];
  Map<String, List<Map<String, dynamic>>> _questionsBySubject = {};
  
  /// Instance singleton
  static final PrepConcoursQuestionsService _instance = 
      PrepConcoursQuestionsService._internal();
  
  factory PrepConcoursQuestionsService() => _instance;
  
  PrepConcoursQuestionsService._internal();
  
  /// Charge les questions depuis le fichier JSON
  Future<void> loadQuestions() async {
    try {
      final String jsonString = await rootBundle.loadString(_questionsAssetPath);
      _questionsData = json.decode(jsonString);
      
      if (_questionsData != null && _questionsData!['questions'] != null) {
        _allQuestions = List<Map<String, dynamic>>.from(_questionsData!['questions']);
        _organizeQuestionsBySubject();
      }
    } catch (e) {
      print('Erreur lors du chargement des questions: $e');
    }
  }
  
  /// Organise les questions par matière
  void _organizeQuestionsBySubject() {
    _questionsBySubject.clear();
    
    for (final question in _allQuestions) {
      final subject = question['subject'] as String;
      if (!_questionsBySubject.containsKey(subject)) {
        _questionsBySubject[subject] = [];
      }
      _questionsBySubject[subject]!.add(question);
    }
  }
  
  /// Récupère toutes les questions
  List<Map<String, dynamic>> getAllQuestions() => List.from(_allQuestions);
  
  /// Récupère les questions d'une matière spécifique
  List<Map<String, dynamic>> getQuestionsBySubject(String subject) {
    return List.from(_questionsBySubject[subject] ?? []);
  }
  
  /// Récupère une question aléatoire
  Map<String, dynamic>? getRandomQuestion() {
    if (_allQuestions.isEmpty) return null;
    final random = DateTime.now().millisecondsSinceEpoch % _allQuestions.length;
    return _allQuestions[random];
  }
  
  /// Récupère une question aléatoire d'une matière
  Map<String, dynamic>? getRandomQuestionBySubject(String subject) {
    final subjectQuestions = _questionsBySubject[subject];
    if (subjectQuestions == null || subjectQuestions.isEmpty) return null;
    
    final random = DateTime.now().millisecondsSinceEpoch % subjectQuestions.length;
    return subjectQuestions[random];
  }
  
  /// Récupère les questions par niveau de difficulté
  List<Map<String, dynamic>> getQuestionsByDifficulty(String difficulty) {
    return _allQuestions
        .where((q) => q['difficulty'] == difficulty)
        .toList();
  }
  
  /// Récupère les questions par topic
  List<Map<String, dynamic>> getQuestionsByTopic(String topic) {
    return _allQuestions
        .where((q) => q['topic'] == topic)
        .toList();
  }
  
  /// Récupère une question par ID
  Map<String, dynamic>? getQuestionById(String id) {
    try {
      return _allQuestions.firstWhere((q) => q['id'] == id);
    } catch (e) {
      return null;
    }
  }
  
  /// Récupère toutes les matières disponibles
  List<String> getAvailableSubjects() {
    return _questionsBySubject.keys.toList();
  }
  
  /// Récupère les métadonnées
  Map<String, dynamic>? getMetadata() {
    return _questionsData?['metadata'];
  }
  
  /// Génère un quiz avec un nombre spécifique de questions
  List<Map<String, dynamic>> generateQuiz({
    int questionCount = 10,
    String? subject,
    String? difficulty,
  }) {
    List<Map<String, dynamic>> availableQuestions = _allQuestions;
    
    // Filtrer par matière si spécifiée
    if (subject != null) {
      availableQuestions = availableQuestions
          .where((q) => q['subject'] == subject)
          .toList();
    }
    
    // Filtrer par difficulté si spécifiée
    if (difficulty != null) {
      availableQuestions = availableQuestions
          .where((q) => q['difficulty'] == difficulty)
          .toList();
    }
    
    // Mélanger et prendre le nombre demandé
    availableQuestions.shuffle();
    return availableQuestions.take(questionCount).toList();
  }
  
  /// Vérifie si une réponse est correcte
  bool checkAnswer(String questionId, int selectedAnswer) {
    final question = getQuestionById(questionId);
    if (question == null) return false;
    
    return question['correct_answer'] == selectedAnswer;
  }
  
  /// Formate une question pour l'affichage
  Map<String, dynamic> formatQuestionForDisplay(Map<String, dynamic> question) {
    return {
      'id': question['id'],
      'subject': question['subject'],
      'topic': question['topic'],
      'question': question['question'],
      'options': List<String>.from(question['options']),
      'correctAnswer': question['correct_answer'],
      'explanation': question['explanation'],
      'difficulty': question['difficulty'],
    };
  }
  
  /// Obtient les statistiques des questions
  Map<String, dynamic> getQuestionsStatistics() {
    final stats = {
      'total': _allQuestions.length,
      'bySubject': <String, int>{},
      'byDifficulty': <String, int>{},
      'byTopic': <String, int>{},
    };
    
    for (final question in _allQuestions) {
      // Par matière
      final subject = question['subject'] as String;
      final bySubjectMap = stats['bySubject'] as Map<String, int>;
      bySubjectMap[subject] = (bySubjectMap[subject] ?? 0) + 1;
      
      // Par difficulté
      final difficulty = question['difficulty'] as String;
      final byDifficultyMap = stats['byDifficulty'] as Map<String, int>;
      byDifficultyMap[difficulty] = (byDifficultyMap[difficulty] ?? 0) + 1;
      
      // Par topic
      final topic = question['topic'] as String;
      final byTopicMap = stats['byTopic'] as Map<String, int>;
      byTopicMap[topic] = (byTopicMap[topic] ?? 0) + 1;
    }
    
    return stats;
  }
}
