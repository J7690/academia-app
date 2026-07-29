import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// « La consultation » : raisonnement diagnostique.
///
/// Un patient, une plainte, et un TEMPS CLINIQUE limité. Chaque question posée
/// et chaque examen demandé le consomme. C'est la mécanique relevée chez
/// Prognosis : on ne demande pas « quelle est la bonne réponse » mais
/// « qu'est-ce que je peux me permettre de chercher avant de décider ».
///
/// Le serveur envoie les actions et ce qu'elles révèlent — le joueur peut donc
/// explorer sans aller-retour réseau. Mais il ne dit ni le bon diagnostic, ni
/// quelles pistes étaient utiles : ces deux secrets ne sortent qu'au débrief.
class ClinicalService {
  ClinicalService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<ClinicalCase?> start() async {
    try {
      final r = await _client.rpc('clinical_start');
      if (r is Map && r['success'] == true) {
        return ClinicalCase.fromJson(Map<String, dynamic>.from(r));
      }
      debugPrint('[Consultation] refusée: ${r is Map ? r['error'] : r}');
    } catch (e) {
      debugPrint('[Consultation] démarrage impossible: $e');
    }
    return null;
  }

  static Future<ClinicalVerdict?> submit({
    required String roundId,
    required String choice,
    required int spent,
  }) async {
    try {
      final r = await _client.rpc('clinical_submit', params: {
        'p_round_id': roundId,
        'p_choice': choice,
        'p_spent': spent,
      });
      if (r is Map && r['success'] == true) {
        return ClinicalVerdict.fromJson(Map<String, dynamic>.from(r));
      }
      debugPrint('[Consultation] envoi refusé: ${r is Map ? r['error'] : r}');
    } catch (e) {
      debugPrint('[Consultation] envoi impossible: $e');
    }
    return null;
  }
}

class ClinicalCase {
  const ClinicalCase({
    required this.roundId,
    required this.title,
    required this.patient,
    required this.complaint,
    required this.budget,
    required this.actions,
    required this.options,
  });

  final String roundId;
  final String title;
  final String patient;
  final String complaint;
  final int budget;
  final List<ClinicalAction> actions;
  final List<ClinicalOption> options;

  factory ClinicalCase.fromJson(Map<String, dynamic> j) {
    final a = j['actions'];
    final o = j['options'];
    return ClinicalCase(
      roundId: j['round_id']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      patient: j['patient']?.toString() ?? '',
      complaint: j['complaint']?.toString() ?? '',
      budget: j['budget'] is int ? j['budget'] as int : 10,
      actions: a is List
          ? a.whereType<Map<String, dynamic>>().map(ClinicalAction.fromJson).toList()
          : const [],
      options: o is List
          ? o.whereType<Map<String, dynamic>>().map(ClinicalOption.fromJson).toList()
          : const [],
    );
  }
}

class ClinicalAction {
  const ClinicalAction({
    required this.code,
    required this.label,
    required this.kind,
    required this.cost,
    required this.reveals,
  });

  final String code;
  final String label;

  /// `question`, `exam` ou `test` — chacun a son icône et son coût typique.
  final String kind;
  final int cost;

  /// Ce que l'action apprend. Peut être une impasse : « radiographie normale ».
  final String reveals;

  factory ClinicalAction.fromJson(Map<String, dynamic> j) => ClinicalAction(
        code: j['code']?.toString() ?? '',
        label: j['label']?.toString() ?? '',
        kind: j['kind']?.toString() ?? 'question',
        cost: j['cost'] is int ? j['cost'] as int : 1,
        reveals: j['reveals']?.toString() ?? '',
      );
}

class ClinicalOption {
  const ClinicalOption({required this.code, required this.label});

  final String code;
  final String label;

  factory ClinicalOption.fromJson(Map<String, dynamic> j) => ClinicalOption(
        code: j['code']?.toString() ?? '',
        label: j['label']?.toString() ?? '',
      );
}

class ClinicalVerdict {
  const ClinicalVerdict({
    required this.isCorrect,
    required this.score,
    required this.budget,
    required this.spent,
    required this.correctLabel,
    required this.explanation,
    required this.isValidated,
    required this.review,
  });

  final bool isCorrect;
  final int score;
  final int budget;
  final int spent;
  final String correctLabel;
  final String explanation;

  /// Faux tant qu'un médecin n'a pas relu le cas — affiché au joueur.
  final bool isValidated;

  /// Quelles pistes étaient utiles, révélé seulement maintenant.
  final List<ClinicalReviewItem> review;

  factory ClinicalVerdict.fromJson(Map<String, dynamic> j) {
    final r = j['review'];
    return ClinicalVerdict(
      isCorrect: j['is_correct'] == true,
      score: j['score'] is int ? j['score'] as int : 0,
      budget: j['budget'] is int ? j['budget'] as int : 0,
      spent: j['spent'] is int ? j['spent'] as int : 0,
      correctLabel: j['correct_label']?.toString() ?? '',
      explanation: j['explanation']?.toString() ?? '',
      isValidated: j['is_validated'] == true,
      review: r is List
          ? r
              .whereType<Map<String, dynamic>>()
              .map(ClinicalReviewItem.fromJson)
              .toList()
          : const [],
    );
  }
}

class ClinicalReviewItem {
  const ClinicalReviewItem({
    required this.code,
    required this.label,
    required this.cost,
    required this.isUseful,
  });

  final String code;
  final String label;
  final int cost;
  final bool isUseful;

  factory ClinicalReviewItem.fromJson(Map<String, dynamic> j) =>
      ClinicalReviewItem(
        code: j['code']?.toString() ?? '',
        label: j['label']?.toString() ?? '',
        cost: j['cost'] is int ? j['cost'] as int : 0,
        isUseful: j['is_useful'] == true,
      );
}
