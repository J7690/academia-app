import 'package:flutter/foundation.dart';
import '../utils/game_constants.dart';

/// Système de scoring pour les jeux Kellenge
/// Gère les points, bonus, pénalités et classements
class GameScoringSystem extends ChangeNotifier {
  // État du scoring
  int _currentScore = 0;
  int _highScore = 0;
  int _comboMultiplier = 1;
  int _streakCount = 0;
  final List<ScoreEvent> _scoreHistory = [];
  
  // Statistiques
  int _totalCorrectAnswers = 0;
  int _totalWrongAnswers = 0;
  int _totalGamesPlayed = 0;
  double _averageScore = 0.0;
  
  // Getters
  int get currentScore => _currentScore;
  int get highScore => _highScore;
  int get comboMultiplier => _comboMultiplier;
  int get streakCount => _streakCount;
  List<ScoreEvent> get scoreHistory => List.unmodifiable(_scoreHistory);
  
  int get totalCorrectAnswers => _totalCorrectAnswers;
  int get totalWrongAnswers => _totalWrongAnswers;
  int get totalGamesPlayed => _totalGamesPlayed;
  double get averageScore => _averageScore;
  
  /// Ajoute des points pour une bonne réponse
  void addCorrectAnswer({int bonusPoints = 0}) {
    _totalCorrectAnswers++;
    _streakCount++;
    
    // Calcul du combo multiplier
    _updateComboMultiplier();
    
    // Calcul des points
    int basePoints = GameConstants.correctAnswerPoints;
    int comboPoints = basePoints * _comboMultiplier;
    int totalPoints = comboPoints + bonusPoints;
    
    _addScore(totalPoints, ScoreEventType.correct);
    _addScoreEvent(ScoreEvent.correct(totalPoints, _comboMultiplier));
    
    notifyListeners();
  }
  
  /// Ajoute une pénalité pour une mauvaise réponse
  void addWrongAnswer() {
    _totalWrongAnswers++;
    _streakCount = 0; // Reset streak
    _comboMultiplier = 1; // Reset combo
    
    int penalty = GameConstants.wrongAnswerPenalty;
    _subtractScore(penalty, ScoreEventType.wrong);
    _addScoreEvent(ScoreEvent.wrong(penalty));
    
    notifyListeners();
  }
  
  /// Ajoute un bonus de temps
  void addTimeBonus(int timeRemaining) {
    int bonus = timeRemaining * GameConstants.timeBonusMultiplier;
    _addScore(bonus, ScoreEventType.timeBonus);
    _addScoreEvent(ScoreEvent.timeBonus(bonus));
    
    notifyListeners();
  }
  
  /// Ajoute un bonus personnalisé
  void addCustomBonus(int points, String reason) {
    _addScore(points, ScoreEventType.bonus);
    _addScoreEvent(ScoreEvent.bonus(points, reason));
    
    notifyListeners();
  }
  
  void _addScore(int points, ScoreEventType type) {
    _currentScore += points;
    
    // Mise à jour du high score
    if (_currentScore > _highScore) {
      _highScore = _currentScore;
    }
  }
  
  void _subtractScore(int points, ScoreEventType type) {
    _currentScore = (_currentScore - points).clamp(0, double.infinity).toInt();
  }
  
  void _updateComboMultiplier() {
    if (_streakCount >= 10) {
      _comboMultiplier = 3;
    } else if (_streakCount >= 5) {
      _comboMultiplier = 2;
    } else {
      _comboMultiplier = 1;
    }
  }
  
  void _addScoreEvent(ScoreEvent event) {
    _scoreHistory.add(event);
    
    // Limiter l'historique à 100 événements
    if (_scoreHistory.length > 100) {
      _scoreHistory.removeAt(0);
    }
  }
  
  /// Démarre une nouvelle partie
  void startNewGame() {
    _currentScore = 0;
    _comboMultiplier = 1;
    _streakCount = 0;
    _totalGamesPlayed++;
    
    _addScoreEvent(ScoreEvent.gameStart());
    notifyListeners();
  }
  
  /// Termine la partie et met à jour les statistiques
  void endGame() {
    _updateAverageScore();
    _addScoreEvent(ScoreEvent.gameEnd(_currentScore));
    notifyListeners();
  }
  
  void _updateAverageScore() {
    if (_totalGamesPlayed > 0) {
      _averageScore = (_averageScore * (_totalGamesPlayed - 1) + _currentScore) / _totalGamesPlayed;
    }
  }
  
  /// Réinitialise toutes les statistiques
  void resetAllStats() {
    _currentScore = 0;
    _highScore = 0;
    _comboMultiplier = 1;
    _streakCount = 0;
    _scoreHistory.clear();
    _totalCorrectAnswers = 0;
    _totalWrongAnswers = 0;
    _totalGamesPlayed = 0;
    _averageScore = 0.0;
    
    notifyListeners();
  }
  
  /// Exporte les statistiques pour Supabase
  Map<String, dynamic> toDatabaseJson() {
    return {
      'high_score': _highScore,
      'total_games_played': _totalGamesPlayed,
      'total_correct_answers': _totalCorrectAnswers,
      'total_wrong_answers': _totalWrongAnswers,
      'average_score': _averageScore,
      'last_updated': DateTime.now().toIso8601String(),
    };
  }
}

/// Événement de scoring pour l'historique
class ScoreEvent {
  final DateTime timestamp;
  final ScoreEventType type;
  final int points;
  final int comboMultiplier;
  final String? description;
  
  ScoreEvent({
    required this.timestamp,
    required this.type,
    required this.points,
    this.comboMultiplier = 1,
    this.description,
  });
  
  factory ScoreEvent.correct(int points, int comboMultiplier) {
    return ScoreEvent(
      timestamp: DateTime.now(),
      type: ScoreEventType.correct,
      points: points,
      comboMultiplier: comboMultiplier,
      description: 'Correct answer (x$comboMultiplier)',
    );
  }
  
  factory ScoreEvent.wrong(int penalty) {
    return ScoreEvent(
      timestamp: DateTime.now(),
      type: ScoreEventType.wrong,
      points: -penalty,
      description: 'Wrong answer (-$penalty)',
    );
  }
  
  factory ScoreEvent.timeBonus(int bonus) {
    return ScoreEvent(
      timestamp: DateTime.now(),
      type: ScoreEventType.timeBonus,
      points: bonus,
      description: 'Time bonus (+$bonus)',
    );
  }
  
  factory ScoreEvent.bonus(int points, String reason) {
    return ScoreEvent(
      timestamp: DateTime.now(),
      type: ScoreEventType.bonus,
      points: points,
      description: reason,
    );
  }
  
  factory ScoreEvent.gameStart() {
    return ScoreEvent(
      timestamp: DateTime.now(),
      type: ScoreEventType.gameStart,
      points: 0,
      description: 'Game started',
    );
  }
  
  factory ScoreEvent.gameEnd(int finalScore) {
    return ScoreEvent(
      timestamp: DateTime.now(),
      type: ScoreEventType.gameEnd,
      points: finalScore,
      description: 'Game ended with score: $finalScore',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'points': points,
      'combo_multiplier': comboMultiplier,
      'description': description,
    };
  }
}

enum ScoreEventType {
  correct,
  wrong,
  timeBonus,
  bonus,
  gameStart,
  gameEnd,
}
