/// Modèle de session de jeu pour Kellenge
/// Représente une partie de jeu individuelle
class GameSession {
  final String id;
  final String playerId;
  final String gameType;
  final int duration;
  final DateTime createdAt;
  final Map<String, dynamic> gameConfig;
  
  GameSession({
    required this.id,
    required this.playerId,
    required this.gameType,
    required this.duration,
    required this.createdAt,
    required this.gameConfig,
  });
  
  factory GameSession.create({
    required String playerId,
    required String gameType,
    int duration = 120,
    Map<String, dynamic>? gameConfig,
  }) {
    return GameSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      playerId: playerId,
      gameType: gameType,
      duration: duration,
      createdAt: DateTime.now(),
      gameConfig: gameConfig ?? {},
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'player_id': playerId,
      'game_type': gameType,
      'duration': duration,
      'created_at': createdAt.toIso8601String(),
      'game_config': gameConfig,
    };
  }
  
  factory GameSession.fromJson(Map<String, dynamic> json) {
    return GameSession(
      id: json['id'],
      playerId: json['player_id'],
      gameType: json['game_type'],
      duration: json['duration'],
      createdAt: DateTime.parse(json['created_at']),
      gameConfig: json['game_config'] ?? {},
    );
  }
}
