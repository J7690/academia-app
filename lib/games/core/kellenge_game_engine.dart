import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/game_session.dart';
import '../utils/game_constants.dart';

/// Moteur de jeu principal pour Kellenge
/// Base pour tous les jeux économiques
class KellengeGameEngine extends FlameGame {
  
  // État du jeu
  late GameSession _gameSession;
  final Function(int) onScoreUpdated;
  final Function(String) onGameEvent;
  final VoidCallback? onGameEnded;
  
  // Composants principaux
  late TextComponent _scoreText;
  late TextComponent _timerText;
  late PositionComponent _gameContainer;
  
  // État interne
  bool _isGameActive = false;
  int _currentScore = 0;
  int _timeRemaining = GameConstants.defaultGameDuration;
  
  KellengeGameEngine({
    required this.onScoreUpdated,
    required this.onGameEvent,
    this.onGameEnded,
  });

  @override
  Future<void> onLoad() async {
    // Configuration de base du monde
    camera = CameraComponent.withFixedResolution(
      width: 800,
      height: 600,
    );
    
    // Création du conteneur de jeu
    _gameContainer = PositionComponent(
      size: Vector2(800, 600),
      position: Vector2(0, 0),
    );
    add(_gameContainer);
    
    // Initialisation UI
    _initializeGameUI();
    
    // Configuration de l'audio
    await _initializeAudio();
  }
  
  void _initializeGameUI() {
    // Panneau de score
    _scoreText = TextComponent(
      text: 'Score: 0',
      position: Vector2(20, 20),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    _gameContainer.add(_scoreText);
    
    // Panneau de timer
    _timerText = TextComponent(
      text: 'Time: ${GameConstants.defaultGameDuration}',
      position: Vector2(680, 20),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    _gameContainer.add(_timerText);
  }
  
  Future<void> _initializeAudio() async {
    // Préchargement des sons
    // Sera implémenté avec flame_audio
  }
  
  void startGame(GameSession session) {
    _gameSession = session;
    _isGameActive = true;
    _currentScore = 0;
    _timeRemaining = session.duration;
    
    _updateUI();
    _startGameTimer();
    
    onGameEvent('Game started: ${session.gameType}');
  }
  
  void _startGameTimer() {
    // Timer de jeu
    Stream.periodic(const Duration(seconds: 1), (count) => count)
        .listen((count) {
      if (!_isGameActive) return;
      
      _timeRemaining--;
      _updateUI();
      
      if (_timeRemaining <= 0) {
        _endGame();
      }
    });
  }
  
  void addScore(int points) {
    if (!_isGameActive) return;
    
    _currentScore += points;
    onScoreUpdated(_currentScore);
    _updateUI();
    
    onGameEvent('Score updated: +$points');
  }
  
  void subtractScore(int points) {
    if (!_isGameActive) return;
    
    _currentScore = (_currentScore - points).clamp(0, double.infinity).toInt();
    onScoreUpdated(_currentScore);
    _updateUI();
    
    onGameEvent('Score updated: -$points');
  }
  
  void _updateUI() {
    _scoreText.text = 'Score: $_currentScore';
    _timerText.text = 'Time: $_timeRemaining';
  }
  
  void _endGame() {
    _isGameActive = false;
    
    // Calcul du bonus de temps
    int timeBonus = (_timeRemaining * GameConstants.timeBonusMultiplier);
    _currentScore += timeBonus;
    
    onGameEvent('Game ended. Final score: $_currentScore (time bonus: +$timeBonus)');
    onGameEnded?.call();
  }
  
  void pauseGame() {
    _isGameActive = false;
    onGameEvent('Game paused');
  }
  
  void resumeGame() {
    _isGameActive = true;
    onGameEvent('Game resumed');
  }
  
  // Getters pour l'état du jeu
  bool get isGameActive => _isGameActive;
  int get currentScore => _currentScore;
  int get timeRemaining => _timeRemaining;
  GameSession get gameSession => _gameSession;
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // Logique de mise à jour du jeu
    if (_isGameActive) {
      _updateGameLogic(dt);
    }
  }
  
  void _updateGameLogic(double dt) {
    // Sera implémenté par les jeux spécifiques
  }
  
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    // Rendu personnalisé si nécessaire
  }
}
