import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'live_arena_service.dart';

/// Service pour gérer les quiz battles en temps réel
class QuizBattleService {
  static final Map<String, BattleSession> _activeBattles = {};
  static final Uuid _uuid = Uuid();
  
  /// Créer une nouvelle session de quiz battle
  static Future<String> createBattleSession({
    required String fighter1Id,
    required String fighter2Id,
    required String gameType,
    int maxQuestions = 10,
    Duration? timePerQuestion,
  }) async {
    final battleId = _uuid.v4();
    
    try {
      // Créer la session Live Arena
      final sessionId = await LiveArenaService.createLiveSession(
        fighter1Id: fighter1Id,
        fighter2Id: fighter2Id,
        gameType: gameType,
        settings: {
          'battle_type': 'quiz',
          'max_questions': maxQuestions,
          'time_per_question': timePerQuestion?.inSeconds ?? 30,
        },
      );
      
      // Créer la session de battle
      final battleSession = BattleSession(
        id: battleId,
        sessionId: sessionId,
        fighter1Id: fighter1Id,
        fighter2Id: fighter2Id,
        gameType: gameType,
        maxQuestions: maxQuestions,
        timePerQuestion: timePerQuestion ?? Duration(seconds: 30),
        currentRound: 0,
        fighter1Score: 0,
        fighter2Score: 0,
        questions: [],
        currentQuestion: null,
        status: BattleStatus.waiting,
        createdAt: DateTime.now(),
      );
      
      _activeBattles[battleId] = battleSession;
      
      // Générer les questions
      await _generateQuestions(battleSession);
      
      // Notifier le démarrage
      await _broadcastBattleEvent(battleId, 'battle_created', {
        'fighter1_id': fighter1Id,
        'fighter2_id': fighter2Id,
        'game_type': gameType,
        'max_questions': maxQuestions,
      });
      
      return battleId;
    } catch (e) {
      throw Exception('Erreur lors de la création du battle: $e');
    }
  }
  
  /// Démarrer le quiz battle
  static Future<void> startBattle(String battleId) async {
    final battle = _activeBattles[battleId];
    if (battle == null) throw Exception('Battle non trouvé');
    
    battle.status = BattleStatus.active;
    battle.currentRound = 1;
    
    // Démarrer la session Live Arena
    await LiveArenaService.startSession(battle.sessionId);
    
    // Envoyer la première question
    await _sendNextQuestion(battleId);
    
    await _broadcastBattleEvent(battleId, 'battle_started', {
      'round': battle.currentRound,
      'total_questions': battle.maxQuestions,
    });
  }
  
  /// Soumettre une réponse
  static Future<BattleResult> submitAnswer({
    required String battleId,
    required String userId,
    required String answer,
    required int questionIndex,
  }) async {
    final battle = _activeBattles[battleId];
    if (battle == null) throw Exception('Battle non trouvé');
    
    if (battle.status != BattleStatus.active) {
      throw Exception('Battle pas actif');
    }
    
    final question = battle.questions[questionIndex];
    if (question == null) throw Exception('Question non trouvée');
    
    final isCorrect = question.isCorrect(answer);
    final startTime = question.startTime ?? DateTime.now();
    final responseTime = DateTime.now().difference(startTime).inSeconds;
    
    // Calculer les points
    final basePoints = 100;
    final timeBonus = max(0, 50 - responseTime); // Bonus de temps
    final totalPoints = isCorrect ? basePoints + timeBonus : 0;
    
    // Mettre à jour le score
    if (userId == battle.fighter1Id) {
      battle.fighter1Score += totalPoints;
    } else if (userId == battle.fighter2Id) {
      battle.fighter2Score += totalPoints;
    }
    
    // Notifier la réponse
    await _broadcastBattleEvent(battleId, 'answer_submitted', {
      'user_id': userId,
      'question_index': questionIndex,
      'answer': answer,
      'is_correct': isCorrect,
      'points': totalPoints,
      'response_time': responseTime,
      'fighter1_score': battle.fighter1Score,
      'fighter2_score': battle.fighter2Score,
    });
    
    // Vérifier si la question est terminée
    final allAnswered = await _checkAllAnswered(battleId, questionIndex);
    if (allAnswered) {
      await _endQuestion(battleId);
    }
    
    // Vérifier si le battle est terminé
    if (battle.currentRound >= battle.maxQuestions) {
      await _endBattle(battleId);
    }
    
    return BattleResult(
      isCorrect: isCorrect,
      points: totalPoints,
      responseTime: responseTime,
      fighter1Score: battle.fighter1Score,
      fighter2Score: battle.fighter2Score,
    );
  }
  
  /// Obtenir la question actuelle
  static BattleQuestion? getCurrentQuestion(String battleId) {
    final battle = _activeBattles[battleId];
    return battle?.currentQuestion;
  }
  
  /// Obtenir l'état du battle
  static BattleSession? getBattleState(String battleId) {
    return _activeBattles[battleId];
  }
  
  /// Stream des événements de battle
  static Stream<Map<String, dynamic>> getBattleStream(String battleId) {
    final battle = _activeBattles[battleId];
    if (battle == null) return Stream.empty();
    
    return LiveArenaService.getEventStream(battle.sessionId)
        .where((event) => event['event_type']?.toString().startsWith('battle_') == true);
  }
  
  /// Stream du chat de battle
  static Stream<Map<String, dynamic>> getBattleChatStream(String battleId) {
    final battle = _activeBattles[battleId];
    if (battle == null) return Stream.empty();
    
    return LiveArenaService.getChatStream(battle.sessionId);
  }
  
  /// Envoyer un message dans le chat
  static Future<void> sendBattleMessage({
    required String battleId,
    required String userId,
    required String message,
    String? targetUserId,
  }) async {
    final battle = _activeBattles[battleId];
    if (battle == null) throw Exception('Battle non trouvé');
    
    await LiveArenaService.sendChatMessage(
      sessionId: battle.sessionId,
      userId: userId,
      message: message,
      targetUserId: targetUserId,
      messageType: 'battle_chat',
    );
  }
  
  /// Obtenir les questions disponibles pour un type de jeu
  static Future<List<BattleQuestion>> getQuestionsForGameType(String gameType) async {
    switch (gameType) {
      case 'market_master':
        return _getMarketMasterQuestions();
      case 'consumer_choice':
        return _getConsumerChoiceQuestions();
      case 'firm_tycoon':
        return _getFirmTycoonQuestions();
      case 'market_structures':
        return _getMarketStructuresQuestions();
      default:
        return [];
    }
  }
  
  /// Générer les questions pour le battle
  static Future<void> _generateQuestions(BattleSession battle) async {
    try {
      final allQuestions = await getQuestionsForGameType(battle.gameType);
      
      // Mélanger et sélectionner les questions
      allQuestions.shuffle();
      battle.questions = allQuestions.take(battle.maxQuestions).toList();
      
      // Initialiser les timestamps
      for (final question in battle.questions) {
        question.startTime = DateTime.now();
      }
      
    } catch (e) {
      print('Erreur lors de la génération des questions: $e');
      // Utiliser des questions par défaut
      battle.questions = _getDefaultQuestions(battle.gameType, battle.maxQuestions);
    }
  }
  
  /// Envoyer la prochaine question
  static Future<void> _sendNextQuestion(String battleId) async {
    final battle = _activeBattles[battleId];
    if (battle == null || battle.currentRound > battle.questions.length) return;
    
    battle.currentQuestion = battle.questions[battle.currentRound - 1];
    battle.currentQuestion!.startTime = DateTime.now();
    
    await _broadcastBattleEvent(battleId, 'question_sent', {
      'round': battle.currentRound,
      'question': battle.currentQuestion!.toJson(),
      'time_limit': battle.timePerQuestion.inSeconds,
    });
    
    // Démarrer le timer pour cette question
    Timer(battle.timePerQuestion, () {
      _handleQuestionTimeout(battleId);
    });
  }
  
  /// Gérer le timeout d'une question
  static Future<void> _handleQuestionTimeout(String battleId) async {
    final battle = _activeBattles[battleId];
    if (battle == null) return;
    
    await _broadcastBattleEvent(battleId, 'question_timeout', {
      'round': battle.currentRound,
      'question_index': battle.currentRound - 1,
      'correct_answer': battle.currentQuestion?.correctAnswer,
    });
    
    // Passer à la question suivante
    battle.currentRound++;
    if (battle.currentRound <= battle.maxQuestions) {
      await _sendNextQuestion(battleId);
    } else {
      await _endBattle(battleId);
    }
  }
  
  /// Terminer la question actuelle
  static Future<void> _endQuestion(String battleId) async {
    final battle = _activeBattles[battleId];
    if (battle == null) return;
    
    await _broadcastBattleEvent(battleId, 'question_ended', {
      'round': battle.currentRound,
      'correct_answer': battle.currentQuestion?.correctAnswer,
      'explanation': battle.currentQuestion?.explanation,
    });
    
    // Passer à la question suivante après une pause
    Timer(Duration(seconds: 3), () {
      battle.currentRound++;
      if (battle.currentRound <= battle.maxQuestions) {
        _sendNextQuestion(battleId);
      } else {
        _endBattle(battleId);
      }
    });
  }
  
  /// Vérifier si tous les joueurs ont répondu
  static Future<bool> _checkAllAnswered(String battleId, int questionIndex) async {
    // Pour simplifier, on suppose que les deux joueurs doivent répondre
    // En pratique, on pourrait suivre les réponses individuelles
    return false; // À implémenter avec le suivi des réponses
  }
  
  /// Terminer le battle
  static Future<void> _endBattle(String battleId) async {
    final battle = _activeBattles[battleId];
    if (battle == null) return;
    
    battle.status = BattleStatus.completed;
    
    // Déterminer le gagnant
    String? winnerId;
    if (battle.fighter1Score > battle.fighter2Score) {
      winnerId = battle.fighter1Id;
    } else if (battle.fighter2Score > battle.fighter1Score) {
      winnerId = battle.fighter2Id;
    }
    
    // Terminer la session Live Arena
    await LiveArenaService.endSession(
      sessionId: battle.sessionId,
      finalScore: {
        'fighter1_score': battle.fighter1Score,
        'fighter2_score': battle.fighter2Score,
        'total_rounds': battle.maxQuestions,
      },
      winnerId: winnerId,
    );
    
    await _broadcastBattleEvent(battleId, 'battle_ended', {
      'winner_id': winnerId,
      'final_scores': {
        'fighter1': battle.fighter1Score,
        'fighter2': battle.fighter2Score,
      },
      'total_rounds': battle.maxQuestions,
    });
    
    // Nettoyer après un délai
    Timer(Duration(minutes: 5), () {
      _activeBattles.remove(battleId);
    });
  }
  
  /// Diffuser un événement de battle
  static Future<void> _broadcastBattleEvent(String battleId, String eventType, Map<String, dynamic> data) async {
    final battle = _activeBattles[battleId];
    if (battle == null) return;
    
    try {
      await Supabase.instance.client
          .from('live_arena_events')
          .insert({
            'session_id': battle.sessionId,
            'event_type': 'battle_$eventType',
            'event_data': {
              'battle_id': battleId,
              ...data,
            },
            'timestamp': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      print('Erreur lors de la diffusion de l''événement: $e');
    }
  }
  
  /// Questions pour Market Master
  static List<BattleQuestion> _getMarketMasterQuestions() {
    return [
      BattleQuestion(
        id: 'mm_1',
        question: 'Quelle est la conséquence d\'une augmentation de l\'offre de café sur le marché ?',
        options: [
          'Le prix du café augmente',
          'Le prix du café diminue',
          'La demande augmente',
          'L\'équilibre reste inchangé',
        ],
        correctAnswer: 'Le prix du café diminue',
        explanation: 'Selon la loi de l\'offre et de la demande, une augmentation de l\'offre entraîne une baisse des prix toutes choses égales.',
        difficulty: 2,
        category: 'supply_demand',
      ),
      BattleQuestion(
        id: 'mm_2',
        question: 'Que signifie un équilibre de marché ?',
        options: [
          'Offre = Demande',
          'Prix d\'équilibre = 0',
          'Quantité offerte = Quantité demandée',
          'Le marché est stable',
        ],
        correctAnswer: 'Quantité offerte = Quantité demandée',
        explanation: 'L\'équilibre de marché est atteint lorsque la quantité offerte est égale à la quantité demandée au prix d\'équilibre.',
        difficulty: 1,
        category: 'equilibrium',
      ),
      BattleQuestion(
        id: 'mm_3',
        question: 'Quel facteur influence le plus le prix du pétrole brut ?',
        options: [
          'La demande mondiale',
          'Les décisions de l\'OPEP',
          'Les stocks américains',
          'Tous les facteurs ci-dessus',
        ],
        correctAnswer: 'Tous les facteurs ci-dessus',
        explanation: 'Le prix du pétrole est influencé par l\'offre, la demande, les décisions de l\'OPEP et les stocks de consommation.',
        difficulty: 3,
        category: 'market_factors',
      ),
    ];
  }
  
  /// Questions pour Consumer Choice
  static List<BattleQuestion> _getConsumerChoiceQuestions() {
    return [
      BattleQuestion(
        id: 'cc_1',
        question: 'Qu\'est-ce que l\'utilité marginale ?',
        options: [
          'L\'utilité totale d\'un bien',
          'L\'utilité d\'une unité supplémentaire',
          'Le prix d\'un bien',
          'La satisfaction totale',
        ],
        correctAnswer: 'L\'utilité d\'une unité supplémentaire',
        explanation: 'L\'utilité marginale mesure l\'augmentation de satisfaction provenant de la consommation d\'une unité supplémentaire d\'un bien.',
        difficulty: 2,
        category: 'utility',
      ),
      BattleQuestion(
        id: 'cc_2',
        question: 'Que signifie la contrainte budgétaire ?',
        options: [
          'Le revenu total disponible',
          'La dépense minimale requise',
          'Le revenu disponible après dépenses fixes',
          'Le budget maximal autorisé',
        ],
        correctAnswer: 'Le budget maximal autorisé',
        explanation: 'La contrainte budgétaire représente la limite des dépenses possibles compte tenu du revenu disponible.',
        difficulty: 1,
        category: 'budget_constraint',
      ),
    ];
  }
  
  /// Questions pour Firm Tycoon
  static List<BattleQuestion> _getFirmTycoonQuestions() {
    return [
      BattleQuestion(
        id: 'ft_1',
        question: 'Quel est le point de profit maximisation ?',
        options: [
          'Coût marginal = Revenu marginal',
          'Coût total = Revenu total',
          'Coût fixe = Revenu fixe',
          'Coût variable = Revenu variable',
        ],
        correctAnswer: 'Coût marginal = Revenu marginal',
        explanation: 'Une entreprise maximise son profit lorsque le coût marginal de production est égal au revenu marginal.',
        difficulty: 3,
        category: 'profit_maximization',
      ),
      BattleQuestion(
        id: 'ft_2',
        question: 'Que sont les coûts fixes ?',
        options: [
          'Coûts qui varient avec la production',
          'Coûts indépendants du volume de production',
          'Coûts de matières premières',
          'Coûts salariaux variables',
        ],
        correctAnswer: 'Coûts indépendants du volume de production',
        explanation: 'Les coûts fixes sont des dépenses qui ne varient pas avec le niveau de production de l\'entreprise.',
        difficulty: 1,
        category: 'cost_structure',
      ),
    ];
  }
  
  /// Questions pour Market Structures
  static List<BattleQuestion> _getMarketStructuresQuestions() {
    return [
      BattleQuestion(
        id: 'ms_1',
        question: 'Quelle caractéristique définit un monopole ?',
        options: [
          'Un seul vendeur et de nombreux acheteurs',
          'Quelques vendeurs et de nombreux acheteurs',
          'Beaucoup de vendeurs et d\'acheteurs',
          'Produits différenciés',
        ],
        correctAnswer: 'Un seul vendeur et de nombreux acheteurs',
        explanation: 'Un monopole est une structure de marché où il n\'y a qu\'un seul vendeur pour un produit ou service donné.',
        difficulty: 1,
        category: 'monopoly',
      ),
      BattleQuestion(
        id: 'ms_2',
        question: 'Quelle est la principale différence entre concurrence parfaite et monopolistique ?',
        options: [
          'Le nombre de vendeurs',
          'La qualité des produits',
          'Les prix pratiqués',
          'La localisation géographique',
        ],
        correctAnswer: 'Le nombre de vendeurs',
        explanation: 'La principale différence réside dans le nombre de vendeurs sur le marché : un seul en monopole contre plusieurs en concurrence parfaite.',
        difficulty: 2,
        category: 'market_comparison',
      ),
    ];
  }
  
  /// Questions par défaut
  static List<BattleQuestion> _getDefaultQuestions(String gameType, int count) {
    switch (gameType) {
      case 'market_master':
        return _getMarketMasterQuestions().take(count).toList();
      case 'consumer_choice':
        return _getConsumerChoiceQuestions().take(count).toList();
      case 'firm_tycoon':
        return _getFirmTycoonQuestions().take(count).toList();
      case 'market_structures':
        return _getMarketStructuresQuestions().take(count).toList();
      default:
        return [
          BattleQuestion(
            id: 'default_1',
            question: 'Question par défaut',
            options: ['Option 1', 'Option 2', 'Option 3', 'Option 4'],
            correctAnswer: 'Option 1',
            explanation: 'Explication par défaut',
            difficulty: 1,
            category: 'default',
          ),
        ];
    }
  }
}

/// Session de quiz battle
class BattleSession {
  final String id;
  final String sessionId;
  final String fighter1Id;
  final String fighter2Id;
  final String gameType;
  final int maxQuestions;
  final Duration timePerQuestion;
  
  int currentRound;
  int fighter1Score;
  int fighter2Score;
  List<BattleQuestion> questions;
  BattleQuestion? currentQuestion;
  BattleStatus status;
  final DateTime createdAt;
  
  BattleSession({
    required this.id,
    required this.sessionId,
    required this.fighter1Id,
    required this.fighter2Id,
    required this.gameType,
    required this.maxQuestions,
    required this.timePerQuestion,
    required this.currentRound,
    required this.fighter1Score,
    required this.fighter2Score,
    required this.questions,
    this.currentQuestion,
    required this.status,
    required this.createdAt,
  });
}

/// Question de quiz battle
class BattleQuestion {
  final String id;
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String explanation;
  final int difficulty;
  final String category;
  DateTime? startTime;
  
  BattleQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    required this.difficulty,
    required this.category,
    this.startTime,
  });
  
  bool isCorrect(String answer) {
    return answer == correctAnswer;
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correct_answer': correctAnswer,
      'explanation': explanation,
      'difficulty': difficulty,
      'category': category,
    };
  }
}

/// Résultat d'une réponse
class BattleResult {
  final bool isCorrect;
  final int points;
  final int responseTime;
  final int fighter1Score;
  final int fighter2Score;
  
  BattleResult({
    required this.isCorrect,
    required this.points,
    required this.responseTime,
    required this.fighter1Score,
    required this.fighter2Score,
  });
}

/// Statut du battle
enum BattleStatus {
  waiting,
  active,
  completed,
  cancelled,
}
