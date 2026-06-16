import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service de quiz live pour AcademiaClassroom.
///
/// Gère la création de questions, la soumission des réponses,
/// et la récupération des résultats via RPCs Supabase.
class AcademiaQuizService {
  AcademiaQuizService._();
  static final instance = AcademiaQuizService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Crée une question (host) et retourne son UUID.
  Future<String?> createQuestion({
    required String sessionId,
    required String question,
    required List<String> options,
    required int correctIndex,
    int durationSeconds = 30,
  }) async {
    try {
      final res = await _client.rpc('app_learning_quiz_create_question', params: {
        'p_session_id': sessionId,
        'p_question': question,
        'p_options': jsonEncode(options),
        'p_correct_index': correctIndex,
        'p_duration_seconds': durationSeconds,
      });
      return res?.toString();
    } catch (e) {
      debugPrint('[AcademiaQuizService] createQuestion error: $e');
      return null;
    }
  }

  /// Soumet une réponse étudiant. Retourne true si correct.
  Future<bool?> submitAnswer({
    required String questionId,
    required int selectedIndex,
  }) async {
    try {
      final res = await _client.rpc('app_learning_quiz_submit_answer', params: {
        'p_question_id': questionId,
        'p_selected_index': selectedIndex,
      });
      return res == true;
    } catch (e) {
      debugPrint('[AcademiaQuizService] submitAnswer error: $e');
      return null;
    }
  }

  /// Récupère les résultats d'une question.
  Future<Map<String, dynamic>?> getResults(String questionId) async {
    try {
      final res = await _client.rpc('app_learning_quiz_results', params: {
        'p_question_id': questionId,
      });
      if (res is List && res.isNotEmpty) {
        return (res.first as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('[AcademiaQuizService] getResults error: $e');
      return null;
    }
  }

  /// Liste toutes les questions d'une session.
  Future<List<Map<String, dynamic>>> listQuestions(String sessionId) async {
    try {
      final res = await _client.rpc('app_learning_quiz_list_questions', params: {
        'p_session_id': sessionId,
      });
      if (res is List) return res.cast<Map<String, dynamic>>();
      return [];
    } catch (e) {
      debugPrint('[AcademiaQuizService] listQuestions error: $e');
      return [];
    }
  }
}
