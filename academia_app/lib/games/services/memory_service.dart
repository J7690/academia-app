import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Mémoire éclair : mémoriser une suite de chiffres, la restituer dans l'ordre.
///
/// Modèle des championnats de mémoire. Ce jeu a trois qualités rares réunies :
/// aucun contenu à produire (tout est généré), aucune filière requise, et la
/// triche largement sans objet — la suite n'existait nulle part dix secondes
/// plus tôt.
///
/// La suite est générée ET corrigée par le serveur : le score ne peut pas être
/// falsifié depuis l'application.
class MemoryService {
  MemoryService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Démarre une manche. [digits] entre 5 et 80, [memoSeconds] entre 10 et 120.
  static Future<MemoryRound?> start({
    int digits = 20,
    int memoSeconds = 60,
  }) async {
    try {
      final r = await _client.rpc('memory_start', params: {
        'p_digits': digits,
        'p_memo_seconds': memoSeconds,
      });
      if (r is Map && r['success'] == true) {
        return MemoryRound.fromJson(Map<String, dynamic>.from(r));
      }
      debugPrint('[Mémoire] manche refusée: ${r is Map ? r['error'] : r}');
    } catch (e) {
      debugPrint('[Mémoire] démarrage impossible: $e');
    }
    return null;
  }

  /// Rend sa réponse. Le serveur corrige, chiffre par chiffre.
  static Future<MemoryResult?> submit({
    required String roundId,
    required String answer,
    int? elapsedMs,
  }) async {
    try {
      final r = await _client.rpc('memory_submit', params: {
        'p_round_id': roundId,
        'p_answer': answer,
        'p_elapsed_ms': elapsedMs,
      });
      if (r is Map && r['success'] == true) {
        return MemoryResult.fromJson(Map<String, dynamic>.from(r));
      }
      debugPrint('[Mémoire] envoi refusé: ${r is Map ? r['error'] : r}');
    } catch (e) {
      debugPrint('[Mémoire] envoi impossible: $e');
    }
    return null;
  }

  /// Mon meilleur résultat, pour proposer la bonne difficulté au lancement.
  static Future<MemoryBest> myBest() async {
    try {
      final r = await _client.rpc('memory_my_best');
      if (r is Map) return MemoryBest.fromJson(Map<String, dynamic>.from(r));
    } catch (e) {
      debugPrint('[Mémoire] record indisponible: $e');
    }
    return const MemoryBest(bestScore: 0, roundsPlayed: 0);
  }
}

class MemoryRound {
  const MemoryRound({
    required this.roundId,
    required this.sequence,
    required this.digits,
    required this.memoSeconds,
    required this.recallSeconds,
  });

  final String roundId;
  final String sequence;
  final int digits;
  final int memoSeconds;
  final int recallSeconds;

  factory MemoryRound.fromJson(Map<String, dynamic> j) => MemoryRound(
        roundId: j['round_id']?.toString() ?? '',
        sequence: j['sequence']?.toString() ?? '',
        digits: j['digits'] is int ? j['digits'] as int : 0,
        memoSeconds: j['memo_seconds'] is int ? j['memo_seconds'] as int : 60,
        recallSeconds:
            j['recall_seconds'] is int ? j['recall_seconds'] as int : 300,
      );
}

class MemoryResult {
  const MemoryResult({
    required this.score,
    required this.digits,
    required this.streak,
    required this.sequence,
    required this.answer,
    required this.outOfTime,
  });

  final int score;
  final int digits;

  /// Plus longue série juste depuis le début — ce que les joueurs regardent.
  final int streak;
  final String sequence;
  final String answer;

  /// Manche rendue trop tard : elle ne compte pas au classement.
  final bool outOfTime;

  factory MemoryResult.fromJson(Map<String, dynamic> j) => MemoryResult(
        score: j['score'] is int ? j['score'] as int : 0,
        digits: j['digits'] is int ? j['digits'] as int : 0,
        streak: j['streak'] is int ? j['streak'] as int : 0,
        sequence: j['sequence']?.toString() ?? '',
        answer: j['answer']?.toString() ?? '',
        outOfTime: j['out_of_time'] == true,
      );
}

class MemoryBest {
  const MemoryBest({required this.bestScore, required this.roundsPlayed});

  final int bestScore;
  final int roundsPlayed;

  factory MemoryBest.fromJson(Map<String, dynamic> j) => MemoryBest(
        bestScore: j['best_score'] is int ? j['best_score'] as int : 0,
        roundsPlayed: j['rounds_played'] is int ? j['rounds_played'] as int : 0,
      );
}
