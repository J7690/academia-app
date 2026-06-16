import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Moteur de TD interactifs pour AcademiaClassroom.
///
/// Permet à l'hôte de lancer un exercice TD en session live
/// et aux étudiants de soumettre leurs réponses en temps réel.
/// S'appuie sur les tables `td_questions` et `td_student_answers` existantes.
class AcademiaPracticeEngine {
  AcademiaPracticeEngine._();
  static final instance = AcademiaPracticeEngine._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Charge une question TD par son ID.
  Future<Map<String, dynamic>?> getQuestion(String questionId) async {
    try {
      final res = await _client
          .from('td_questions')
          .select()
          .eq('id', questionId)
          .maybeSingle();
      return res;
    } catch (e) {
      debugPrint('[AcademiaPractice] getQuestion error: $e');
      return null;
    }
  }

  /// Charge des questions TD par matière pour une bank.
  Future<List<Map<String, dynamic>>> getQuestionsByBank({
    required String bankId,
    int limit = 10,
  }) async {
    try {
      final res = await _client
          .from('td_questions')
          .select()
          .eq('bank_id', bankId)
          .eq('is_active', true)
          .limit(limit);
      return (res as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[AcademiaPractice] getQuestionsByBank error: $e');
      return [];
    }
  }

  /// Soumet la réponse d'un étudiant pour un exercice en live.
  Future<bool> submitAnswer({
    required String questionId,
    required String sessionId,
    required int selectedIndex,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      await _client.from('td_student_answers').upsert({
        'question_id': questionId,
        'student_id': userId,
        'session_id': sessionId,
        'selected_index': selectedIndex,
        'answered_at': DateTime.now().toIso8601String(),
      }, onConflict: 'question_id,student_id');

      return true;
    } catch (e) {
      debugPrint('[AcademiaPractice] submitAnswer error: $e');
      return false;
    }
  }

  /// Résultats d'un exercice en live (pour le host).
  Future<Map<String, dynamic>> getExerciseResults({
    required String questionId,
    required String sessionId,
  }) async {
    try {
      final res = await _client
          .from('td_student_answers')
          .select('student_id, selected_index')
          .eq('question_id', questionId)
          .eq('session_id', sessionId);

      final answers = (res as List?) ?? [];
      final total = answers.length;
      final distribution = <int, int>{};
      for (final a in answers) {
        final idx = a['selected_index'] as int? ?? -1;
        distribution[idx] = (distribution[idx] ?? 0) + 1;
      }

      return {
        'total': total,
        'distribution': distribution,
      };
    } catch (e) {
      debugPrint('[AcademiaPractice] getExerciseResults error: $e');
      return {'total': 0, 'distribution': {}};
    }
  }

  /// Encode une question TD pour envoi via Data Channel.
  Map<String, dynamic> encodeForDataChannel(Map<String, dynamic> question) {
    return {
      'type': 'td_exercise',
      'question_id': question['id'],
      'content': question['content'],
      'options': question['options'],
      'question_type': question['question_type'],
      'time_limit_seconds': question['time_limit_seconds'] ?? 60,
      'points': question['points'] ?? 1,
      'subject': question['subject'],
    };
  }

  /// Décode un message Data Channel en exercice TD.
  static Map<String, dynamic>? decodeFromDataChannel(
      Map<String, dynamic> msg) {
    if (msg['type'] != 'td_exercise') return null;
    return msg;
  }
}
