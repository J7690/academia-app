import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// « Le comptoir » : servir des clients en officine.
///
/// S'adresse à deux formations du catalogue — auxiliaire de pharmacie et
/// délégué médical.
///
/// Les réponses attendues ne quittent jamais le serveur : `start()` ne renvoie
/// que la demande du client, l'ordonnance et le rayon. C'est `submit()` qui
/// corrige et rend le débrief.
class PharmacyService {
  PharmacyService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<PharmacyShift?> start() async {
    try {
      final r = await _client.rpc('pharmacy_start');
      if (r is Map && r['success'] == true) {
        return PharmacyShift.fromJson(Map<String, dynamic>.from(r));
      }
      debugPrint('[Comptoir] service refusé: ${r is Map ? r['error'] : r}');
    } catch (e) {
      debugPrint('[Comptoir] démarrage impossible: $e');
    }
    return null;
  }

  static Future<PharmacyReport?> submit({
    required String roundId,
    required Map<String, List<String>> delivered,
    int? elapsedMs,
  }) async {
    try {
      final answers = delivered.entries
          .map((e) => {'case_id': e.key, 'delivered': e.value})
          .toList();
      final r = await _client.rpc('pharmacy_submit', params: {
        'p_round_id': roundId,
        'p_answers': answers,
        'p_time_ms': elapsedMs,
      });
      if (r is Map && r['success'] == true) {
        return PharmacyReport.fromJson(Map<String, dynamic>.from(r));
      }
      debugPrint('[Comptoir] envoi refusé: ${r is Map ? r['error'] : r}');
    } catch (e) {
      debugPrint('[Comptoir] envoi impossible: $e');
    }
    return null;
  }
}

class PharmacyShift {
  const PharmacyShift({required this.roundId, required this.cases});

  final String roundId;
  final List<PharmacyCase> cases;

  factory PharmacyShift.fromJson(Map<String, dynamic> j) {
    final raw = j['cases'];
    return PharmacyShift(
      roundId: j['round_id']?.toString() ?? '',
      cases: raw is List
          ? raw.whereType<Map<String, dynamic>>().map(PharmacyCase.fromJson).toList()
          : const [],
    );
  }
}

class PharmacyCase {
  const PharmacyCase({
    required this.id,
    required this.title,
    required this.customerLine,
    required this.caseType,
    required this.prescription,
    required this.shelf,
  });

  final String id;
  final String title;
  final String customerLine;

  /// `prescription` : le client présente une ordonnance.
  /// `request` : il demande de lui-même un produit — c'est là que se jouent les refus.
  final String caseType;
  final List<String> prescription;
  final List<ShelfItem> shelf;

  bool get hasPrescription => caseType == 'prescription';

  factory PharmacyCase.fromJson(Map<String, dynamic> j) {
    final pres = j['prescription'];
    final shelf = j['shelf'];
    return PharmacyCase(
      id: j['id']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      customerLine: j['customer_line']?.toString() ?? '',
      caseType: j['case_type']?.toString() ?? 'prescription',
      prescription:
          pres is List ? pres.map((e) => e.toString()).toList() : const [],
      shelf: shelf is List
          ? shelf.whereType<Map<String, dynamic>>().map(ShelfItem.fromJson).toList()
          : const [],
    );
  }
}

class ShelfItem {
  const ShelfItem({required this.code, required this.label, required this.detail});

  final String code;
  final String label;
  final String detail;

  factory ShelfItem.fromJson(Map<String, dynamic> j) => ShelfItem(
        code: j['code']?.toString() ?? '',
        label: j['label']?.toString() ?? '',
        detail: j['detail']?.toString() ?? '',
      );
}

class PharmacyReport {
  const PharmacyReport({
    required this.score,
    required this.total,
    required this.cases,
  });

  final int score;
  final int total;
  final List<PharmacyCaseResult> cases;

  factory PharmacyReport.fromJson(Map<String, dynamic> j) {
    final raw = j['cases'];
    return PharmacyReport(
      score: j['score'] is int ? j['score'] as int : 0,
      total: j['total'] is int ? j['total'] as int : 0,
      cases: raw is List
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(PharmacyCaseResult.fromJson)
              .toList()
          : const [],
    );
  }
}

class PharmacyCaseResult {
  const PharmacyCaseResult({
    required this.title,
    required this.isCorrect,
    required this.delivered,
    required this.shouldDeliver,
    required this.shouldRefuse,
    required this.explanation,
    required this.isValidated,
  });

  final String title;
  final bool isCorrect;
  final List<String> delivered;
  final List<String> shouldDeliver;
  final List<String> shouldRefuse;
  final String explanation;

  /// Faux tant qu'un pharmacien n'a pas relu le cas. Affiché au joueur : mieux
  /// vaut annoncer qu'un contenu est en cours de validation que de le présenter
  /// comme une vérité établie.
  final bool isValidated;

  static List<String> _liste(dynamic v) =>
      v is List ? v.map((e) => e.toString()).toList() : const [];

  factory PharmacyCaseResult.fromJson(Map<String, dynamic> j) =>
      PharmacyCaseResult(
        title: j['title']?.toString() ?? '',
        isCorrect: j['is_correct'] == true,
        delivered: _liste(j['delivered']),
        shouldDeliver: _liste(j['should_deliver']),
        shouldRefuse: _liste(j['should_refuse']),
        explanation: j['explanation']?.toString() ?? '',
        isValidated: j['is_validated'] == true,
      );
}
