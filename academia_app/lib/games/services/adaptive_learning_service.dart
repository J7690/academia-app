import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'economic_data_service.dart';

/// Service pour l'apprentissage adaptatif basé sur l'IA
class AdaptiveLearningService {
  static final Map<String, AdaptiveProfile> _profiles = {};
  static final Random _random = Random();
  
  /// Obtenir ou créer le profil adaptatif d'un utilisateur
  static Future<AdaptiveProfile> getProfile(String userId, String gameType) async {
    final profileKey = '${userId}_${gameType}';
    
    if (_profiles.containsKey(profileKey)) {
      return _profiles[profileKey]!;
    }
    
    try {
      // Charger depuis la base
      final result = await Supabase.instance.client
          .from('adaptive_learning_profiles')
          .select()
          .eq('user_id', userId)
          .eq('game_type', gameType)
          .single();
      
      final profile = AdaptiveProfile.fromJson(result);
      _profiles[profileKey] = profile;
      return profile;
    } catch (e) {
      // Créer un nouveau profil
      final newProfile = AdaptiveProfile.create(userId, gameType);
      await _saveProfile(newProfile);
      _profiles[profileKey] = newProfile;
      return newProfile;
    }
  }
  
  /// Générer un scénario adapté pour l'utilisateur
  static Future<AdaptiveScenario> generateAdaptiveScenario({
    required String userId,
    required String gameType,
    List<EconomicIndicator>? realData,
  }) async {
    final profile = await getProfile(userId, gameType);
    final scenarios = await EconomicDataService.getAfricanMarketScenarios()
        .then((s) => s.where((sc) => sc.gameType == gameType).toList());
    
    // Sélectionner un scénario basé sur le profil
    final selectedScenario = _selectScenario(scenarios, profile);
    
    // Ajuster la difficulté
    final adjustedDifficulty = _adjustDifficulty(profile);
    
    // Générer les objectifs adaptés
    final objectives = _generateAdaptiveObjectives(profile, selectedScenario);
    
    // Créer les indices adaptés
    final hints = _generateAdaptiveHints(profile, selectedScenario);
    
    return AdaptiveScenario(
      scenario: selectedScenario,
      difficultyLevel: adjustedDifficulty,
      objectives: objectives,
      hints: hints,
      timeLimit: _calculateTimeLimit(profile, adjustedDifficulty),
      successProbability: _calculateSuccessProbability(profile),
    );
  }
  
  /// Mettre à jour le profil après une session de jeu
  static Future<void> updateProfile({
    required String userId,
    required String gameType,
    required int score,
    required int maxScore,
    required Duration timeSpent,
    required List<String> conceptsMastered,
    required List<String> conceptsStruggled,
  }) async {
    final profile = await getProfile(userId, gameType);
    
    // Mettre à jour les statistiques
    profile.totalAttempts++;
    if (score >= maxScore * 0.7) {
      profile.successfulAttempts++;
    }
    
    // Mettre à jour le score moyen
    final newScore = (score / maxScore) * 100;
    profile.averageScore = ((profile.averageScore * (profile.totalAttempts - 1)) + newScore) / profile.totalAttempts;
    
    // Mettre à jour le temps moyen
    final newTime = timeSpent.inSeconds;
    profile.averageTimeSeconds = ((profile.averageTimeSeconds * (profile.totalAttempts - 1)) + newTime).toInt();
    
    // Mettre à jour la maîtrise des concepts
    for (final concept in conceptsMastered) {
      profile.conceptMastery[concept] = min(1.0, (profile.conceptMastery[concept] ?? 0.0) + 0.2);
    }
    
    for (final concept in conceptsStruggled) {
      profile.conceptMastery[concept] = max(0.0, (profile.conceptMastery[concept] ?? 0.5) - 0.1);
    }
    
    // Ajuster la préférence de difficulté
    _adjustDifficultyPreference(profile, score, maxScore);
    
    // Mettre à jour la date de dernière session
    profile.lastSessionDate = DateTime.now();
    
    // Sauvegarder
    await _saveProfile(profile);
    _profiles['${userId}_${gameType}'] = profile;
  }
  
  /// Obtenir des recommandations d'apprentissage
  static Future<List<LearningRecommendation>> getRecommendations(
    String userId,
    String gameType,
  ) async {
    final profile = await getProfile(userId, gameType);
    final recommendations = <LearningRecommendation>[];
    
    // Recommander des concepts à améliorer
    final weakConcepts = profile.conceptMastery.entries
        .where((entry) => entry.value < 0.5)
        .map((entry) => entry.key)
        .toList();
    
    for (final concept in weakConcepts) {
      recommendations.add(LearningRecommendation(
        type: 'concept_review',
        title: 'Réviser: $concept',
        description: 'Vous avez besoin de pratiquer ce concept',
        priority: 'high',
        estimatedTime: Duration(minutes: 15),
      ));
    }
    
    // Recommander des scénarios adaptés
    if (profile.averageScore < 70) {
      recommendations.add(LearningRecommendation(
        type: 'practice_easier',
        title: 'Pratiquer avec difficulté réduite',
        description: 'Commencez avec des scénarios plus simples',
        priority: 'medium',
        estimatedTime: Duration(minutes: 20),
      ));
    }
    
    // Recommander des défis si l'utilisateur performe bien
    if (profile.averageScore > 85) {
      recommendations.add(LearningRecommendation(
        type: 'challenge_harder',
        title: 'Défi avancé',
        description: 'Essayez des scénarios plus complexes',
        priority: 'low',
        estimatedTime: Duration(minutes: 25),
      ));
    }
    
    return recommendations;
  }
  
  /// Analyser les performances et générer des insights
  static Future<PerformanceInsight> analyzePerformance(
    String userId,
    String gameType,
  ) async {
    final profile = await getProfile(userId, gameType);
    
    // Calculer les tendances
    final trend = _calculatePerformanceTrend(profile);
    
    // Identifier les points forts et faibles
    final strengths = profile.conceptMastery.entries
        .where((entry) => entry.value >= 0.8)
        .map((entry) => entry.key)
        .toList();
    
    final weaknesses = profile.conceptMastery.entries
        .where((entry) => entry.value < 0.5)
        .map((entry) => entry.key)
        .toList();
    
    // Générer des recommandations personnalisées
    final recommendation = _generatePersonalizedRecommendation(profile, strengths, weaknesses);
    
    return PerformanceInsight(
      overallScore: profile.averageScore,
      trend: trend,
      strengths: strengths,
      weaknesses: weaknesses,
      recommendation: recommendation,
      nextLevel: _calculateNextLevel(profile),
    );
  }
  
  /// Sélectionner un scénario adapté
  static AfricanMarketScenario _selectScenario(
    List<AfricanMarketScenario> scenarios,
    AdaptiveProfile profile,
  ) {
    // Filtrer par difficulté appropriée
    final appropriateScenarios = scenarios.where((scenario) {
      final difficultyDiff = (scenario.difficultyLevel - profile.difficultyPreference).abs();
      return difficultyDiff <= 1; // Difficulté dans la plage acceptable
    }).toList();
    
    if (appropriateScenarios.isEmpty) {
      // Si aucun scénario approprié, prendre le plus proche
      return scenarios.reduce((a, b) {
        final diffA = (a.difficultyLevel - profile.difficultyPreference).abs();
        final diffB = (b.difficultyLevel - profile.difficultyPreference).abs();
        return diffA < diffB ? a : b;
      });
    }
    
    // Pondérer par taux de succès et utiliser
    return appropriateScenarios[_random.nextInt(appropriateScenarios.length)];
  }
  
  /// Ajuster la difficulté
  static int _adjustDifficulty(AdaptiveProfile profile) {
    if (profile.averageScore > 85) {
      return min(5, profile.difficultyPreference + 1);
    } else if (profile.averageScore < 60) {
      return max(1, profile.difficultyPreference - 1);
    }
    return profile.difficultyPreference;
  }
  
  /// Générer des objectifs adaptés
  static List<String> _generateAdaptiveObjectives(
    AdaptiveProfile profile,
    AfricanMarketScenario scenario,
  ) {
    final baseObjectives = <String>[
      'Atteindre l''équilibre du marché',
      'Maximiser le profit',
      'Optimiser l''allocation des ressources',
    ];
    
    // Adapter selon les concepts maîtrisés
    final adaptedObjectives = baseObjectives.map((objective) {
      if (profile.conceptMastery.containsKey('equilibrium') && 
          profile.conceptMastery['equilibrium']! < 0.5) {
        return '$objective (avec aide visuelle)';
      }
      return objective;
    }).toList();
    
    return adaptedObjectives;
  }
  
  /// Générer des indices adaptés
  static List<String> _generateAdaptiveHints(
    AdaptiveProfile profile,
    AfricanMarketScenario scenario,
  ) {
    final hints = <String>[];
    
    // Ajouter des indices basés sur les difficultés
    if (profile.averageScore < 70) {
      hints.add('Conseil: Commencez par analyser les données réelles');
      hints.add('Astuce: Utilisez les graphiques pour visualiser les tendances');
    }
    
    // Ajouter des indices spécifiques au scénario
    if (scenario.events.isNotEmpty) {
      hints.add('Attention: Les événements peuvent affecter le marché');
    }
    
    return hints;
  }
  
  /// Calculer la limite de temps
  static Duration _calculateTimeLimit(AdaptiveProfile profile, int difficulty) {
    final baseTime = Duration(minutes: 10);
    final difficultyMultiplier = 1.0 + (difficulty - 3) * 0.2; // +/- 20% par niveau
    final performanceMultiplier = profile.averageScore > 80 ? 0.8 : 1.2; // Plus rapide si bon
    
    final totalSeconds = (baseTime.inSeconds * difficultyMultiplier * performanceMultiplier).round();
    return Duration(seconds: totalSeconds);
  }
  
  /// Calculer la probabilité de succès
  static double _calculateSuccessProbability(AdaptiveProfile profile) {
    final baseProbability = profile.averageScore / 100;
    final recentPerformance = profile.successfulAttempts / max(1, profile.totalAttempts);
    
    return (baseProbability * 0.7 + recentPerformance * 0.3).clamp(0.1, 0.9);
  }
  
  /// Ajuster la préférence de difficulté
  static void _adjustDifficultyPreference(AdaptiveProfile profile, int score, int maxScore) {
    final successRate = score / maxScore;
    
    if (successRate > 0.9 && profile.difficultyPreference < 5) {
      profile.difficultyPreference++;
    } else if (successRate < 0.4 && profile.difficultyPreference > 1) {
      profile.difficultyPreference--;
    }
  }
  
  /// Calculer la tendance de performance
  static PerformanceTrend _calculatePerformanceTrend(AdaptiveProfile profile) {
    if (profile.totalAttempts < 3) {
      return PerformanceTrend.insufficient;
    }
    
    // Simuler une tendance basée sur le score moyen
    if (profile.averageScore > 80) {
      return PerformanceTrend.improving;
    } else if (profile.averageScore < 60) {
      return PerformanceTrend.declining;
    }
    
    return PerformanceTrend.stable;
  }
  
  /// Générer une recommandation personnalisée
  static String _generatePersonalizedRecommendation(
    AdaptiveProfile profile,
    List<String> strengths,
    List<String> weaknesses,
  ) {
    if (weaknesses.isNotEmpty) {
      return 'Concentrez-vous sur l''amélioration des concepts: ${weaknesses.join(', ')}';
    }
    
    if (strengths.isNotEmpty && profile.averageScore > 85) {
      return 'Excellent travail ! Essayez des scénarios plus difficiles pour continuer à progresser';
    }
    
    return 'Continuez à pratiquer régulièrement pour maintenir votre niveau';
  }
  
  /// Calculer le prochain niveau
  static String _calculateNextLevel(AdaptiveProfile profile) {
    if (profile.averageScore >= 90) {
      return 'Expert';
    } else if (profile.averageScore >= 75) {
      return 'Avancé';
    } else if (profile.averageScore >= 60) {
      return 'Intermédiaire';
    }
    
    return 'Débutant';
  }
  
  /// Sauvegarder le profil
  static Future<void> _saveProfile(AdaptiveProfile profile) async {
    try {
      // Schema `app` explicite : sans lui, l'appel vise `public` — ou la table
      // n'existe pas — et l'echec passait inapercu dans le catch ci-dessous.
      await Supabase.instance.client
          .schema('app')
          .from('adaptive_learning_profiles')
          .upsert(profile.toJson(), onConflict: 'user_id,game_type');
    } catch (e) {
      print('Erreur lors de la sauvegarde du profil: $e');
    }
  }
}

/// Profil adaptatif utilisateur
class AdaptiveProfile {
  final String userId;
  final String gameType;
  final Map<String, double> conceptMastery;
  int difficultyPreference;
  double averageScore;
  int averageTimeSeconds;
  int totalAttempts;
  int successfulAttempts;
  DateTime? lastSessionDate;
  List<String> learningPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  AdaptiveProfile({
    required this.userId,
    required this.gameType,
    required this.conceptMastery,
    required this.difficultyPreference,
    required this.averageScore,
    required this.averageTimeSeconds,
    required this.totalAttempts,
    required this.successfulAttempts,
    this.lastSessionDate,
    required this.learningPath,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory AdaptiveProfile.create(String userId, String gameType) {
    final now = DateTime.now();
    return AdaptiveProfile(
      userId: userId,
      gameType: gameType,
      conceptMastery: {
        'equilibrium': 0.5,
        'supply_demand': 0.5,
        'utility': 0.5,
        'cost_analysis': 0.5,
        'market_structure': 0.5,
      },
      difficultyPreference: 3,
      averageScore: 0.0,
      averageTimeSeconds: 600, // 10 minutes
      totalAttempts: 0,
      successfulAttempts: 0,
      lastSessionDate: null,
      learningPath: [],
      createdAt: now,
      updatedAt: now,
    );
  }
  
  factory AdaptiveProfile.fromJson(Map<String, dynamic> json) {
    return AdaptiveProfile(
      userId: json['user_id'],
      gameType: json['game_type'],
      conceptMastery: Map<String, double>.from(json['concept_mastery'] ?? {}),
      difficultyPreference: json['difficulty_preference'] ?? 3,
      averageScore: (json['average_score'] as num?)?.toDouble() ?? 0.0,
      averageTimeSeconds: json['average_time_seconds'] ?? 600,
      totalAttempts: json['total_attempts'] ?? 0,
      successfulAttempts: json['successful_attempts'] ?? 0,
      lastSessionDate: json['last_session_date'] != null 
          ? DateTime.parse(json['last_session_date']) 
          : null,
      learningPath: List<String>.from(json['learning_path'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'game_type': gameType,
      'concept_mastery': conceptMastery,
      'difficulty_preference': difficultyPreference,
      'average_score': averageScore,
      'average_time_seconds': averageTimeSeconds,
      'total_attempts': totalAttempts,
      'successful_attempts': successfulAttempts,
      'last_session_date': lastSessionDate?.toIso8601String(),
      'learning_path': learningPath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Scénario adaptatif
class AdaptiveScenario {
  final AfricanMarketScenario scenario;
  final int difficultyLevel;
  final List<String> objectives;
  final List<String> hints;
  final Duration timeLimit;
  final double successProbability;
  
  AdaptiveScenario({
    required this.scenario,
    required this.difficultyLevel,
    required this.objectives,
    required this.hints,
    required this.timeLimit,
    required this.successProbability,
  });
}

/// Recommandation d'apprentissage
class LearningRecommendation {
  final String type;
  final String title;
  final String description;
  final String priority;
  final Duration estimatedTime;
  
  LearningRecommendation({
    required this.type,
    required this.title,
    required this.description,
    required this.priority,
    required this.estimatedTime,
  });
}

/// Insight de performance
class PerformanceInsight {
  final double overallScore;
  final PerformanceTrend trend;
  final List<String> strengths;
  final List<String> weaknesses;
  final String recommendation;
  final String nextLevel;
  
  PerformanceInsight({
    required this.overallScore,
    required this.trend,
    required this.strengths,
    required this.weaknesses,
    required this.recommendation,
    required this.nextLevel,
  });
}

/// Tendance de performance
enum PerformanceTrend {
  improving,
  stable,
  declining,
  insufficient,
}
