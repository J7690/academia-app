import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Système de feedback visuel et sonore simplifié pour les jeux Kellenge
/// Gère les animations et effets visuels de base pour les actions de jeu
class GameFeedbackSystem {
  static GameFeedbackSystem? _instance;
  static GameFeedbackSystem get instance => _instance ??= GameFeedbackSystem._();
  
  GameFeedbackSystem._();
  
  /// Affiche un feedback de succès
  void showSuccess(Vector2 position, {int points = 0, String? message}) {
    final text = message ?? (points > 0 ? '+$points points!' : 'Success!');
    debugPrint('Feedback: $text at ${position.x},${position.y}');
  }
  
  /// Affiche un feedback d'erreur
  void showError(Vector2 position, {int points = 0, String? message}) {
    final text = message ?? (points < 0 ? '${points} points!' : 'Try again!');
    debugPrint('Feedback: $text at ${position.x},${position.y}');
  }
  
  /// Affiche un feedback de combo
  void showCombo(Vector2 position, int multiplier) {
    final text = 'Combo x$multiplier!';
    debugPrint('Feedback: $text at ${position.x},${position.y}');
  }
  
  /// Affiche un feedback de niveau atteint
  void showLevelUp(Vector2 position, String level) {
    final text = 'Level Up: $level!';
    debugPrint('Feedback: $text at ${position.x},${position.y}');
  }
  
  /// Affiche un feedback de streak
  void showStreak(Vector2 position, int streak) {
    final text = '${streak} Streak!';
    debugPrint('Feedback: $text at ${position.x},${position.y}');
  }
  
  /// Affiche un feedback de bonus
  void showBonus(Vector2 position, int bonus, String reason) {
    final text = 'Bonus: +$bonus $reason';
    debugPrint('Feedback: $text at ${position.x},${position.y}');
  }
  
  /// Affiche un feedback d'événement de jeu
  void showGameEvent(Vector2 position, String event) {
    debugPrint('Game Event: $event at ${position.x},${position.y}');
  }
  
  /// Nettoie les ressources
  void dispose() {
    debugPrint('GameFeedbackSystem disposed');
  }
}
