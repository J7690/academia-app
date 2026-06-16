import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service d'IA pédagogique pour AcademiaClassroom.
///
/// Utilise une Edge Function pour générer des réponses contextuelles
/// (résumé de session, réponses aux questions, exercices à la volée).
class AcademiaAiService {
  AcademiaAiService._();
  static final instance = AcademiaAiService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Génère une réponse IA dans le contexte d'une session.
  ///
  /// [prompt] : question de l'utilisateur
  /// [context] : contexte supplémentaire (messages récents, sujet du cours)
  /// [mode] : 'answer' | 'summary' | 'exercise'
  Future<String?> generate({
    required String prompt,
    String? sessionId,
    String? context,
    String mode = 'answer',
  }) async {
    try {
      final res = await _client.functions.invoke(
        'academia-ai-assistant',
        body: {
          'prompt': prompt,
          'session_id': sessionId,
          'context': context,
          'mode': mode,
        },
      );

      if (res.status != 200) {
        debugPrint('[AcademiaAI] Error status: ${res.status}');
        return null;
      }

      final data = res.data;
      if (data is Map<String, dynamic>) {
        return data['response']?.toString();
      }
      return data?.toString();
    } catch (e) {
      debugPrint('[AcademiaAI] generate error: $e');
      return null;
    }
  }

  /// Résume la session en cours à partir des messages.
  Future<String?> summarizeSession({
    required String sessionId,
    required List<String> recentMessages,
  }) async {
    return generate(
      prompt: 'Résume cette session de cours en 3-5 points clés.',
      sessionId: sessionId,
      context: recentMessages.take(20).join('\n'),
      mode: 'summary',
    );
  }

  /// Répond à une question d'étudiant.
  Future<String?> answerQuestion({
    required String question,
    String? sessionId,
    String? courseSubject,
  }) async {
    return generate(
      prompt: question,
      sessionId: sessionId,
      context: courseSubject != null
          ? 'Cours : $courseSubject'
          : null,
      mode: 'answer',
    );
  }

  /// Génère un exercice à la volée.
  Future<String?> generateExercise({
    required String subject,
    String? difficulty,
    String? sessionId,
  }) async {
    final prompt = 'Génère un exercice QCM de niveau ${difficulty ?? "intermédiaire"} '
        'sur le sujet: $subject. Format: question + 4 options (A-D) + réponse correcte + explication.';
    return generate(
      prompt: prompt,
      sessionId: sessionId,
      mode: 'exercise',
    );
  }
}
