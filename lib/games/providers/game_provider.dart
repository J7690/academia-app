import 'package:flutter/material.dart';
import '../services/game_scoring_system.dart';
import '../models/game_session.dart';
import '../utils/game_constants.dart';

/// Provider pour la gestion des jeux Kellenge
/// Gère l'état global des jeux et sessions
class GameProvider extends ChangeNotifier {
  // État des jeux
  GameSession? _currentSession;
  GameScoringSystem? _scoringSystem;
  bool _isGameActive = false;
  String? _currentGameType;
  
  // Statistiques globales
  int _totalGamesPlayed = 0;
  int _totalHighScore = 0;
  Map<String, int> _gameHighScores = {};
  
  // Getters
  GameSession? get currentSession => _currentSession;
  GameScoringSystem? get scoringSystem => _scoringSystem;
  bool get isGameActive => _isGameActive;
  String? get currentGameType => _currentGameType;
  int get totalGamesPlayed => _totalGamesPlayed;
  int get totalHighScore => _totalHighScore;
  Map<String, int> get gameHighScores => Map.unmodifiable(_gameHighScores);
  
  /// Démarre une nouvelle session de jeu
  void startGameSession({
    required String gameType,
    required String playerId,
    int duration = GameConstants.defaultGameDuration,
    Map<String, dynamic>? gameConfig,
  }) {
    // Créer la session
    _currentSession = GameSession.create(
      playerId: playerId,
      gameType: gameType,
      duration: duration,
      gameConfig: gameConfig,
    );
    
    // Initialiser le système de scoring
    _scoringSystem = GameScoringSystem();
    _scoringSystem!.startNewGame();
    
    // Mettre à jour l'état
    _isGameActive = true;
    _currentGameType = gameType;
    
    notifyListeners();
  }
  
  /// Termine la session de jeu actuelle
  void endGameSession() {
    if (_scoringSystem != null && _currentSession != null) {
      // Finaliser le scoring
      _scoringSystem!.endGame();
      
      // Mettre à jour les statistiques
      _updateGlobalStats();
      
      // Nettoyer l'état
      _isGameActive = false;
      _currentSession = null;
      _currentGameType = null;
      
      notifyListeners();
    }
  }
  
  void _updateGlobalStats() {
    if (_scoringSystem == null) return;
    
    _totalGamesPlayed++;
    
    final currentScore = _scoringSystem!.currentScore;
    final currentHighScore = _scoringSystem!.highScore;
    
    // Mettre à jour le high score global
    if (currentHighScore > _totalHighScore) {
      _totalHighScore = currentHighScore;
    }
    
    // Mettre à jour le high score par type de jeu
    if (_currentGameType != null) {
      final existingHighScore = _gameHighScores[_currentGameType!] ?? 0;
      if (currentScore > existingHighScore) {
        _gameHighScores[_currentGameType!] = currentScore;
      }
    }
  }
  
  /// Met à jour le score du jeu actuel
  void updateScore(int score) {
    if (_scoringSystem != null) {
      // Le système de scoring gère déjà les notifications
      notifyListeners();
    }
  }
  
  /// Ajoute une bonne réponse
  void addCorrectAnswer({int bonusPoints = 0}) {
    _scoringSystem?.addCorrectAnswer(bonusPoints: bonusPoints);
    notifyListeners();
  }
  
  /// Ajoute une mauvaise réponse
  void addWrongAnswer() {
    _scoringSystem?.addWrongAnswer();
    notifyListeners();
  }
  
  /// Pause/Resume le jeu
  void togglePauseGame() {
    _isGameActive = !_isGameActive;
    notifyListeners();
  }
  
  /// Réinitialise toutes les statistiques
  void resetAllStats() {
    _totalGamesPlayed = 0;
    _totalHighScore = 0;
    _gameHighScores.clear();
    _scoringSystem?.resetAllStats();
    notifyListeners();
  }
  
  /// Exporte les données pour Supabase
  Map<String, dynamic> toDatabaseJson() {
    return {
      'total_games_played': _totalGamesPlayed,
      'total_high_score': _totalHighScore,
      'game_high_scores': _gameHighScores,
      'scoring_stats': _scoringSystem?.toDatabaseJson(),
      'last_updated': DateTime.now().toIso8601String(),
    };
  }
  
  @override
  void dispose() {
    _scoringSystem?.dispose();
    super.dispose();
  }
}
