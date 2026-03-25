import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/supabase_config.dart';
import 'psychotech_generator.dart';

/// Service IA pour les tests psychotechniques.
/// Utilise OpenRouter (via Edge Function prep-tutor-chat) pour :
/// 1. Générer des analogies verbales dynamiques
/// 2. Générer des intrus dynamiques
/// 3. Fournir des explications détaillées pas à pas
/// 4. Recommander des exercices adaptés au profil
class PsychotechAiService {
  PsychotechAiService._();

  /// Génère une analogie verbale via l'IA.
  /// Fallback sur le générateur statique si l'IA échoue.
  static Future<PsychotechQuestion> generateAiAnalogy({int difficulty = 1}) async {
    try {
      final prompt =
          'Génère UNE analogie verbale pour un test psychotechnique de concours au Burkina Faso '
          '(difficulté $difficulty/5). '
          'Réponds UNIQUEMENT en JSON valide, sans markdown :\n'
          '{"words":["MOT1","MOT2","MOT3"],"correct":"Réponse","distractors":["Dist1","Dist2","Dist3"],"explanation":"Explication de la relation logique."}';

      final response = await _callAi(prompt);
      if (response != null) {
        final jsonMatch = response.contains('{') ? response.substring(response.indexOf('{'), response.lastIndexOf('}') + 1) : null;
        if (jsonMatch != null) {
          final data = jsonDecode(jsonMatch);
          final words = (data['words'] as List?)?.cast<String>() ?? [];
          final correct = (data['correct'] ?? '').toString();
          final dists = (data['distractors'] as List?)?.cast<String>() ?? [];
          final expl = (data['explanation'] ?? '').toString();

          if (words.length >= 3 && correct.isNotEmpty && dists.length >= 3) {
            final allOptions = <String>[correct, ...dists.take(3)]..shuffle();
            return PsychotechQuestion(
              type: 'analogies',
              difficulty: difficulty,
              questionText: '${words[0]} est à ${words[1]} ce que ${words[2]} est à :',
              options: allOptions,
              correctIndex: allOptions.indexOf(correct),
              explanation: '$expl La réponse est $correct.',
              method: 'Identifiez la relation entre les 2 premiers mots, puis appliquez la même relation au 3ème.',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[PsychotechAI] generateAiAnalogy error: $e');
    }
    // Fallback statique
    return PsychotechGenerator.generateVerbalAnalogy(difficulty: difficulty);
  }

  /// Génère un intrus via l'IA.
  static Future<PsychotechQuestion> generateAiIntruder({int difficulty = 1}) async {
    try {
      final context = difficulty >= 3 ? 'contexte Burkina Faso (géographie, institutions, culture)' : 'culture générale';
      final prompt =
          'Génère UN exercice d\'intrus pour un test psychotechnique ($context, difficulté $difficulty/5). '
          'Réponds UNIQUEMENT en JSON valide, sans markdown :\n'
          '{"items":["Mot1","Mot2","Mot3","Mot4","Mot5"],"intruder_index":2,"explanation":"Pourquoi cet élément est l\'intrus."}';

      final response = await _callAi(prompt);
      if (response != null) {
        final jsonMatch = response.contains('{') ? response.substring(response.indexOf('{'), response.lastIndexOf('}') + 1) : null;
        if (jsonMatch != null) {
          final data = jsonDecode(jsonMatch);
          final items = (data['items'] as List?)?.cast<String>() ?? [];
          final intruderIdx = (data['intruder_index'] as int?) ?? 0;
          final expl = (data['explanation'] ?? '').toString();

          if (items.length >= 4 && intruderIdx < items.length) {
            return PsychotechQuestion(
              type: 'intrus',
              difficulty: difficulty,
              questionText: 'Trouvez l\'intrus :',
              questionData: {'items': items},
              options: items,
              correctIndex: intruderIdx,
              explanation: '$expl La réponse est ${items[intruderIdx]}.',
              method: 'Cherchez le point commun entre la majorité des éléments. L\'intrus est celui qui ne partage pas cette caractéristique.',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[PsychotechAI] generateAiIntruder error: $e');
    }
    return PsychotechGenerator.generateIntruder(difficulty: difficulty);
  }

  /// Demande une explication IA détaillée pour une erreur de l'étudiant.
  static Future<String?> explainError({
    required PsychotechQuestion question,
    required int studentAnswerIndex,
  }) async {
    try {
      final prompt =
          'L\'étudiant a répondu "${question.options[studentAnswerIndex]}" '
          'à la question suivante d\'un test psychotechnique :\n\n'
          'Question : ${question.questionText}\n'
          'Options : ${question.options.join(", ")}\n'
          'Bonne réponse : ${question.options[question.correctIndex]}\n\n'
          'Explique-lui pourquoi sa réponse est fausse et comment trouver la bonne réponse. '
          'Sois bienveillant, utilise un langage simple, et donne des astuces mémorables. '
          'Si c\'est un test de suite ou dominos, montre le raisonnement étape par étape.';

      return await _callAi(prompt);
    } catch (e) {
      debugPrint('[PsychotechAI] explainError: $e');
      return null;
    }
  }

  /// Appelle l'Edge Function prep-tutor-chat pour obtenir une réponse IA.
  static Future<String?> _callAi(String message) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return null;

    try {
      final uri = Uri.parse('${SupabaseConfig.url}/functions/v1/prep-tutor-chat');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'apikey': SupabaseConfig.anonKey,
        },
        body: jsonEncode({
          'message': message,
          'subject': 'Tests Psychotechniques',
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return (data['reply'] ?? '').toString().trim();
        }
      }
    } catch (e) {
      debugPrint('[PsychotechAI] _callAi error: $e');
    }
    return null;
  }
}
