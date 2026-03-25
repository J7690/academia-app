/// Fichier de base pour les constantes gaming
/// Créé automatiquement - Phase 1 Infrastructure

/// Constantes des jeux Kellenge
class GameConstants {
  GameConstants._();

  /// Types de jeux disponibles
  static const List<String> gameTypes = [
    GameConstants.marketMaster,
    GameConstants.consumerChoice,
    GameConstants.firmTycoon,
    GameConstants.marketStructures,
  ];

  // Noms des jeux
  static const String marketMaster = 'Market Master';
  static const String consumerChoice = 'Consumer Choice';
  static const String firmTycoon = 'Firm Tycoon';
  static const String marketStructures = 'Market Structures';
  
  // Durées des jeux (en secondes)
  static const int defaultGameDuration = 120; // 2 minutes
  static const int quickGameDuration = 60; // 1 minute
  static const int longGameDuration = 300; // 5 minutes
  
  // Scores
  static const int correctAnswerPoints = 10;
  static const int wrongAnswerPenalty = 5;
  static const int timeBonusMultiplier = 2;
  
  // Multiplayer
  static const int maxPlayersPerGame = 4;
  static const int minPlayersPerGame = 2;
  static const int matchmakingTimeoutSeconds = 30;
  
  // Animation
  static const double defaultAnimationDuration = 0.3;
  static const double slowAnimationDuration = 0.5;
  static const double fastAnimationDuration = 0.1;
}
