import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Duel de Concours : deux étudiants, les mêmes questions, le meilleur gagne.
///
/// Le duel est ASYNCHRONE — chacun joue quand il veut. Ce n'est pas une
/// facilité : un duel en temps réel exclurait les étudiants dont la connexion
/// est instable, ce que déconseille la recherche sur l'edtech africaine.
///
/// Les bonnes réponses ne quittent jamais le serveur avant qu'on ait répondu :
/// `questions()` ne renvoie que les intitulés et les options, et c'est
/// `submit()` qui corrige côté base.
class DuelService {
  DuelService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Matières ayant assez de questions pour un duel.
  static Future<List<DuelSubject>> subjects() async {
    try {
      final r = await _client.rpc('duel_subjects');
      if (r is List) {
        return r
            .whereType<Map<String, dynamic>>()
            .map(DuelSubject.fromJson)
            .toList();
      }
    } catch (e) {
      debugPrint('[Duel] matières indisponibles: $e');
    }
    return const [];
  }

  /// Lance un duel. [subject] nul = toutes matières mélangées.
  static Future<DuelRound?> start({String? subject}) =>
      _round('duel_start', {'p_subject': subject});

  /// Rejoint un duel ouvert.
  static Future<DuelRound?> join(String duelId) =>
      _round('duel_join', {'p_duel_id': duelId});

  static Future<DuelRound?> _round(String fn, Map<String, dynamic> params) async {
    try {
      final r = await _client.rpc(fn, params: params);
      if (r is Map && r['success'] == true) {
        return DuelRound.fromJson(Map<String, dynamic>.from(r));
      }
      debugPrint('[Duel] $fn refusé: ${r is Map ? r['error'] : r}');
      return null;
    } catch (e) {
      debugPrint('[Duel] $fn impossible: $e');
      return null;
    }
  }

  /// Envoie ses réponses. Le serveur corrige et renvoie le détail.
  static Future<DuelResult?> submit({
    required String duelId,
    required List<DuelAnswer> answers,
    int? elapsedMs,
  }) async {
    try {
      final r = await _client.rpc('duel_submit', params: {
        'p_duel_id': duelId,
        'p_answers': answers.map((a) => a.toJson()).toList(),
        'p_time_ms': elapsedMs,
      });
      if (r is Map && r['success'] == true) {
        return DuelResult.fromJson(Map<String, dynamic>.from(r));
      }
      debugPrint('[Duel] envoi refusé: ${r is Map ? r['error'] : r}');
      return null;
    } catch (e) {
      debugPrint('[Duel] envoi impossible: $e');
      return null;
    }
  }

  /// Duels lancés par d'autres et en attente d'un adversaire.
  static Future<List<Map<String, dynamic>>> openDuels() async {
    try {
      final r = await _client.rpc('duel_list_open');
      if (r is List) return r.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('[Duel] liste indisponible: $e');
    }
    return const [];
  }

  /// Mes duels, terminés ou en attente.
  static Future<List<Map<String, dynamic>>> myHistory() async {
    try {
      final r = await _client.rpc('duel_my_history');
      if (r is List) return r.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('[Duel] historique indisponible: $e');
    }
    return const [];
  }
}

class DuelSubject {
  const DuelSubject({required this.name, required this.questionCount});
  final String name;
  final int questionCount;

  factory DuelSubject.fromJson(Map<String, dynamic> j) => DuelSubject(
        name: j['subject']?.toString() ?? '',
        questionCount: j['questions'] is int ? j['questions'] as int : 0,
      );
}

/// Une manche prête à jouer : les questions, sans les réponses.
class DuelRound {
  const DuelRound({
    required this.duelId,
    required this.subject,
    required this.questions,
  });

  final String duelId;
  final String subject;
  final List<DuelQuestion> questions;

  factory DuelRound.fromJson(Map<String, dynamic> j) {
    final raw = j['questions'];
    return DuelRound(
      duelId: j['duel_id']?.toString() ?? '',
      subject: j['subject']?.toString() ?? 'Toutes matières',
      questions: raw is List
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(DuelQuestion.fromJson)
              .toList()
          : const [],
    );
  }
}

class DuelQuestion {
  const DuelQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.seconds,
  });

  final String id;
  final String question;
  final List<String> options;
  final int seconds;

  factory DuelQuestion.fromJson(Map<String, dynamic> j) {
    final opts = j['options'];
    return DuelQuestion(
      id: j['id']?.toString() ?? '',
      question: j['question']?.toString() ?? '',
      options: opts is List ? opts.map((o) => o.toString()).toList() : const [],
      seconds: j['seconds'] is int ? j['seconds'] as int : 30,
    );
  }
}

class DuelAnswer {
  const DuelAnswer({required this.questionId, required this.choice});
  final String questionId;

  /// Index choisi, ou -1 si le temps est écoulé sans réponse.
  final int choice;

  Map<String, dynamic> toJson() =>
      {'question_id': questionId, 'choice': choice};
}

/// Ce que le serveur renvoie une fois la manche corrigée.
class DuelResult {
  const DuelResult({
    required this.score,
    required this.total,
    required this.status,
    required this.creatorScore,
    required this.opponentScore,
    required this.isWinner,
    required this.corrections,
  });

  final int score;
  final int total;

  /// `waiting` : l'adversaire n'a pas encore joué. `completed` : duel tranché.
  final String status;
  final int? creatorScore;
  final int? opponentScore;

  /// Nul tant que le duel n'est pas terminé, ou en cas d'égalité parfaite.
  final bool? isWinner;
  final List<DuelCorrection> corrections;

  bool get isFinished => status == 'completed';

  factory DuelResult.fromJson(Map<String, dynamic> j) {
    final raw = j['answers'];
    return DuelResult(
      score: j['score'] is int ? j['score'] as int : 0,
      total: j['total'] is int ? j['total'] as int : 0,
      status: j['status']?.toString() ?? 'waiting',
      creatorScore: j['creator_score'] is int ? j['creator_score'] as int : null,
      opponentScore:
          j['opponent_score'] is int ? j['opponent_score'] as int : null,
      isWinner: j['is_winner'] is bool ? j['is_winner'] as bool : null,
      corrections: raw is List
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(DuelCorrection.fromJson)
              .toList()
          : const [],
    );
  }
}

/// La correction d'une question : ce qui a été choisi, ce qu'il fallait, et
/// pourquoi. C'est ce qui distingue un jeu d'une révision.
class DuelCorrection {
  const DuelCorrection({
    required this.question,
    required this.options,
    required this.chosen,
    required this.correctIndex,
    required this.isCorrect,
    required this.explanation,
  });

  final String question;
  final List<String> options;
  final int chosen;
  final int correctIndex;
  final bool isCorrect;
  final String explanation;

  factory DuelCorrection.fromJson(Map<String, dynamic> j) {
    final opts = j['options'];
    return DuelCorrection(
      question: j['question']?.toString() ?? '',
      options: opts is List ? opts.map((o) => o.toString()).toList() : const [],
      chosen: j['chosen'] is int ? j['chosen'] as int : -1,
      correctIndex: j['correct_index'] is int ? j['correct_index'] as int : -1,
      isCorrect: j['is_correct'] == true,
      explanation: j['explanation']?.toString() ?? '',
    );
  }
}
