import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fiche de séance — génération, lecture, correction et publication.
///
/// Deux versions du même contenu :
///
/// * `student` — résumé, plan, concepts, questions et réponses, à retenir.
///   Rien sur les autres participants.
/// * `host` — tout ce qui précède, plus les statistiques de participation,
///   les questions restées sans réponse et les points à reprendre.
///
/// L'enseignant relit et publie. Tant qu'il ne l'a pas fait, l'étudiant ne
/// voit rien : un résumé automatique erroné diffusé sous l'autorité d'un
/// professeur est un problème pédagogique, pas un simple défaut technique.
class SessionSummaryService {
  SessionSummaryService._();
  static final instance = SessionSummaryService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Demande la génération de la fiche. Réservé à l'hôte côté serveur.
  ///
  /// Retourne `null` si tout s'est bien passé, sinon un message.
  Future<String?> generate(String sessionId) async {
    try {
      final response = await _client.functions.invoke(
        'learning-session-summary',
        body: {'session_id': sessionId},
      );
      final data = response.data;
      if (response.status == 200 && data is Map && data['success'] == true) {
        return null;
      }
      if (data is Map && data['error'] != null) {
        return data['error'].toString();
      }
      return 'La génération de la fiche a échoué.';
    } catch (e) {
      debugPrint('[SessionSummary] generate error: $e');
      return 'Service de synthèse indisponible pour le moment.';
    }
  }

  /// Charge la fiche. `audience` vaut `student` ou `host`.
  ///
  /// Retourne un état explicite plutôt qu'une simple absence :
  /// `none` (jamais générée), `unpublished` (générée, pas encore publiée),
  /// `ready`, `pending`, `failed`.
  Future<SummaryResult> load(String sessionId,
      {String audience = 'student'}) async {
    try {
      final res = await _client.rpc('app_learning_get_summary', params: {
        'p_session_id': sessionId,
        'p_audience': audience,
      });
      if (res is! Map<String, dynamic> || res['success'] != true) {
        return SummaryResult.error(
          res is Map ? res['error']?.toString() : null,
        );
      }
      final summary = res['summary'];
      return SummaryResult(
        status: (res['status'] ?? 'none').toString(),
        isHost: res['is_host'] == true,
        content: summary is Map<String, dynamic>
            ? (summary['content'] as Map<String, dynamic>? ?? const {})
            : const {},
        isPublished:
            summary is Map<String, dynamic> && summary['is_published'] == true,
        generatedAt: summary is Map<String, dynamic>
            ? DateTime.tryParse('${summary['generated_at']}')
            : null,
        modelUsed: summary is Map<String, dynamic>
            ? summary['model_used']?.toString()
            : null,
      );
    } catch (e) {
      debugPrint('[SessionSummary] load error: $e');
      return SummaryResult.error(e.toString());
    }
  }

  /// Publie la fiche étudiant, éventuellement après correction du contenu.
  Future<String?> publish(
    String sessionId, {
    Map<String, dynamic>? correctedContent,
    bool publish = true,
  }) async {
    try {
      final res = await _client.rpc('app_learning_publish_summary', params: {
        'p_session_id': sessionId,
        'p_content': correctedContent,
        'p_publish': publish,
      });
      if (res is Map<String, dynamic> && res['success'] == true) return null;
      return res is Map ? res['error']?.toString() : 'Publication impossible.';
    } catch (e) {
      debugPrint('[SessionSummary] publish error: $e');
      return e.toString();
    }
  }

  /// Journalise un moment de séance : il alimente la fiche et, plus tard,
  /// le chapitrage du replay.
  Future<void> logEvent(
    String sessionId,
    String kind, {
    Map<String, dynamic>? payload,
  }) async {
    try {
      await _client.rpc('app_learning_log_event', params: {
        'p_session_id': sessionId,
        'p_kind': kind,
        'p_payload': payload ?? <String, dynamic>{},
      });
    } catch (e) {
      // Un événement perdu ne doit jamais gêner la séance en cours.
      debugPrint('[SessionSummary] logEvent($kind) ignoré : $e');
    }
  }
}

/// État de chargement d'une fiche, avec sa raison quand elle est absente.
class SummaryResult {
  final String status;
  final bool isHost;
  final bool isPublished;
  final Map<String, dynamic> content;
  final DateTime? generatedAt;
  final String? modelUsed;
  final String? error;

  const SummaryResult({
    required this.status,
    this.isHost = false,
    this.isPublished = false,
    this.content = const {},
    this.generatedAt,
    this.modelUsed,
    this.error,
  });

  factory SummaryResult.error(String? message) =>
      SummaryResult(status: 'failed', error: message ?? 'Erreur inconnue.');

  bool get hasContent => content.isNotEmpty;
  bool get neverGenerated => status == 'none';
  bool get awaitingPublication => status == 'unpublished';
}
