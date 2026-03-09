import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'td_service.dart';

/// Service IA pour le tuteur de préparation aux concours.
///
/// Architecture (Option A — Edge Function OpenRouter):
/// 1. Flutter envoie {message, conversation_id, subject} à l'Edge Function
/// 2. L'Edge Function `prep-tutor-chat` utilise la clé OpenRouter (env var)
/// 3. L'Edge Function sauvegarde les messages dans td_ai_messages (RPC)
/// 4. Fallback: mode démo si l'Edge Function n'est pas encore déployée
///
/// La clé API OpenRouter est côté serveur (env var Supabase), jamais exposée
/// côté client. Même clé que Bobodo — zéro config admin nécessaire.
class PrepAiService {
  PrepAiService._();

  static final TdService _tdService = TdService();

  /// Envoie un message au tuteur IA via l'Edge Function `prep-tutor-chat`.
  ///
  /// [conversationId] — ID de la conversation Supabase (pour persistence)
  /// [messages] — Historique local (non utilisé par l'Edge Function qui charge
  ///              l'historique depuis Supabase, mais gardé pour compatibilité)
  /// [userMessage] — Nouveau message de l'utilisateur
  /// [subject] — Matière en cours (optionnel, pour contextualiser la réponse)
  static Future<String> chat({
    String? conversationId,
    required List<Map<String, String>> messages,
    required String userMessage,
    String? subject,
  }) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;

    if (session == null || session.accessToken.isEmpty) {
      debugPrint('[PrepAiService] Utilisateur non authentifié, mode démo');
      return _demoResponse(userMessage);
    }

    try {
      final uri = Uri.parse('${SupabaseConfig.url}/functions/v1/prep-tutor-chat');
      final body = jsonEncode({
        'message': userMessage,
        if (conversationId != null) 'conversation_id': conversationId,
        if (subject != null && subject.isNotEmpty) 'subject': subject,
      });

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'apikey': SupabaseConfig.anonKey,
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final reply = (data['reply'] ?? '').toString().trim();
          if (reply.isNotEmpty) return reply;
        }
        return _demoResponse(userMessage);
      }

      // Edge Function not deployed yet or error — fallback to demo
      debugPrint(
        '[PrepAiService] Edge Function error ${response.statusCode}: '
        '${response.body.length > 300 ? response.body.substring(0, 300) : response.body}',
      );
      return _demoResponse(userMessage);
    } catch (e) {
      debugPrint('[PrepAiService] Exception: $e');
      return _demoResponse(userMessage);
    }
  }

  /// Crée une nouvelle conversation dans Supabase.
  static Future<String?> createConversation({String? title, String? subject}) async {
    try {
      final result = await _tdService.prepCreateAiConversation(
        title: title,
        subject: subject,
      );
      return result['conversation_id']?.toString();
    } catch (e) {
      debugPrint('[PrepAiService] Erreur création conversation: $e');
      return null;
    }
  }

  /// Réponses démo quand l'Edge Function n'est pas encore déployée.
  static String _demoResponse(String query) {
    final q = query.toLowerCase();
    if (q.contains('math') || q.contains('calcul') || q.contains('équation')) {
      return '📐 **Mathématiques**\n\n'
          'Voici une approche méthodique :\n\n'
          '1. **Identifie le type de problème** — équation, fonction, géométrie, probabilités\n'
          '2. **Écris les données** — ce que tu connais et ce que tu cherches\n'
          '3. **Choisis la méthode** — formule directe, substitution, raisonnement par l\'absurde\n'
          '4. **Vérifie ton résultat** — remplace dans l\'équation d\'origine\n\n'
          'Donne-moi un exercice précis et je te guide pas à pas ! 💡\n\n'
          '_⚠️ Mode démo — L\'Edge Function prep-tutor-chat doit être déployée via Supabase CLI._';
    }
    if (q.contains('droit') || q.contains('constitution') || q.contains('loi')) {
      return '⚖️ **Droit**\n\n'
          'Pour bien préparer les questions de droit aux concours :\n\n'
          '• **Maîtrise les grands principes** — séparation des pouvoirs, hiérarchie des normes, État de droit\n'
          '• **Connais la Constitution camerounaise** — préambule, organisation des pouvoirs\n'
          '• **Entraîne-toi aux cas pratiques** — applique la règle au cas d\'espèce\n\n'
          'Quelle notion veux-tu approfondir ? 📚\n\n'
          '_⚠️ Mode démo — L\'Edge Function prep-tutor-chat doit être déployée via Supabase CLI._';
    }
    if (q.contains('dissertation') || q.contains('rédaction') || q.contains('méthode')) {
      return '✍️ **Méthodologie de dissertation**\n\n'
          '**Structure en 3 parties :**\n\n'
          '**Introduction** (accroche → définition → problématique → annonce du plan)\n\n'
          '**Développement**\n'
          '- I. Thèse (arguments + exemples)\n'
          '- II. Antithèse (nuances + contre-exemples)\n'
          '- III. Synthèse (dépassement)\n\n'
          '**Conclusion** (bilan → ouverture)\n\n'
          '💡 Astuce : Commence toujours par un brouillon du plan avant de rédiger !\n\n'
          '_⚠️ Mode démo — L\'Edge Function prep-tutor-chat doit être déployée via Supabase CLI._';
    }
    if (q.contains('enam') || q.contains('concours')) {
      return '🏛️ **Préparation ENAM**\n\n'
          'Le concours de l\'ENAM comporte généralement :\n\n'
          '• **Culture générale** — actualité, histoire, géographie\n'
          '• **Droit** — constitutionnel, administratif, civil\n'
          '• **Économie** — macroéconomie, finances publiques\n'
          '• **Français** — dissertation, résumé de texte\n\n'
          'Je te recommande de :\n'
          '1. Faire un quiz quotidien sur chaque matière\n'
          '2. Réviser les annales des 5 dernières années\n'
          '3. T\'entraîner à la dissertation chronométrée\n\n'
          'Par quelle matière veux-tu commencer ? 🎯\n\n'
          '_⚠️ Mode démo — L\'Edge Function prep-tutor-chat doit être déployée via Supabase CLI._';
    }
    return '🤔 Bonne question !\n\n'
        'Je vais t\'aider avec ça. Pour te donner la meilleure réponse possible, '
        'peux-tu me préciser :\n\n'
        '• **La matière** concernée (maths, droit, histoire…)\n'
        '• **Le concours** que tu prépares (ENAM, ENS, BAC…)\n'
        '• **Ton niveau** actuel sur ce sujet\n\n'
        'Plus tu es précis, mieux je peux t\'accompagner ! 💪\n\n'
        '_⚠️ Mode démo — L\'Edge Function prep-tutor-chat doit être déployée via Supabase CLI._';
  }
}
