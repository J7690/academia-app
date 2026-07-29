import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Conserve le resultat des parties jouees.
///
/// Avant ce service (29/07/2026), une partie terminee n'etait enregistree nulle
/// part : le score s'affichait, puis disparaissait. Sans cette trace, ni
/// classement, ni progression, ni tournoi ne pouvaient exister.
///
/// Regle de conduite : enregistrer une partie ne doit JAMAIS empecher l'ecran de
/// fin de s'afficher. Toutes les methodes rendent la main sans lever d'exception,
/// meme hors ligne.
class GameResultsService {
  GameResultsService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Enregistre une partie terminee.
  ///
  /// Renvoie le meilleur score personnel et si cette partie l'a battu, de quoi
  /// feliciter le joueur sur l'ecran de fin. Renvoie `null` si l'enregistrement
  /// n'a pas pu se faire (hors ligne, non connecte) — l'appelant continue.
  static Future<GameResultOutcome?> record({
    required String gameType,
    required int score,
    int? correctAnswers,
    int? wrongAnswers,
    int? bestStreak,
    int? durationSec,
    Map<String, dynamic>? details,
  }) async {
    try {
      final response = await _client.rpc(
        'game_record_result',
        params: {
          'p_game_type': gameType,
          'p_score': score,
          'p_correct_answers': correctAnswers,
          'p_wrong_answers': wrongAnswers,
          'p_best_streak': bestStreak,
          'p_duration_sec': durationSec,
          'p_details': details ?? const <String, dynamic>{},
        },
      );

      if (response is! Map || response['success'] != true) {
        debugPrint('[GameResults] partie non enregistree: $response');
        return null;
      }

      final best = response['personal_best'];
      return GameResultOutcome(
        personalBest: best is int ? best : score,
        isPersonalBest: response['is_personal_best'] == true,
      );
    } catch (e) {
      // Hors ligne ou serveur indisponible : la partie reste jouee et affichee.
      debugPrint('[GameResults] enregistrement impossible: $e');
      return null;
    }
  }

  /// Classement d'un jeu (ou tous jeux confondus si [gameType] est nul).
  ///
  /// [period] : `day`, `week`, `month` ou `all`. Le classement retient le
  /// MEILLEUR score de chaque joueur, pas le cumul.
  static Future<List<Map<String, dynamic>>> leaderboard({
    String? gameType,
    String period = 'all',
    int limit = 50,
  }) async {
    try {
      final response = await _client.rpc(
        'game_leaderboard',
        params: {
          'p_game_type': gameType,
          'p_period': period,
          'p_limit': limit,
        },
      );
      if (response is List) {
        return response.whereType<Map<String, dynamic>>().toList();
      }
      return const [];
    } catch (e) {
      debugPrint('[GameResults] classement indisponible: $e');
      return const [];
    }
  }

  /// Mes statistiques par jeu (meilleur score, parties jouees, moyenne).
  static Future<List<Map<String, dynamic>>> myStats({String? gameType}) async {
    try {
      final response = await _client.rpc(
        'game_my_stats',
        params: {'p_game_type': gameType},
      );
      if (response is List) {
        return response.whereType<Map<String, dynamic>>().toList();
      }
      return const [];
    } catch (e) {
      debugPrint('[GameResults] statistiques indisponibles: $e');
      return const [];
    }
  }
}

/// Ce que l'ecran de fin peut annoncer au joueur.
class GameResultOutcome {
  const GameResultOutcome({
    required this.personalBest,
    required this.isPersonalBest,
  });

  final int personalBest;
  final bool isPersonalBest;
}
