import 'package:supabase_flutter/supabase_flutter.dart';

/// Service de matchmaking pour les jeux Kellenge
/// Gère la recherche d'adversaires et la création de sessions
class MatchmakingService {
  static MatchmakingService? _instance;
  static MatchmakingService get instance => _instance ??= MatchmakingService._();
  
  MatchmakingService._();
  
  final SupabaseClient _supabase = Supabase.instance.client;
  
  /// Démarrer le matchmaking
  Future<MatchmakingResult> startMatchmaking({
    required String gameType,
    int eloRange = 200,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    try {
      // Mettre à jour les statistiques de recherche
      await _updateMatchmakingStats(gameType, searchInitiated: true);
      
      // Démarrer la recherche
      final response = await _supabase.rpc('game_start_matchmaking', params: {
        'p_game_type': gameType,
        'p_elo_range': eloRange,
      });
      
      if (response.isEmpty) {
        throw Exception('Failed to start matchmaking');
      }
      
      final result = response.first;
      final success = result['success'] as bool;
      
      if (!success) {
        return MatchmakingResult(
          success: false,
          message: result['message'] as String,
        );
      }
      
      final sessionId = result['session_id'] as String;
      
      // Si match trouvé immédiatement
      if (result['message'] == 'Match found!') {
        await _updateMatchmakingStats(gameType, matchFound: true);
        return MatchmakingResult(
          success: true,
          sessionId: sessionId,
          message: 'Match found!',
          isMatchFound: true,
        );
      }
      
      // Sinon, attendre un match (polling)
      return await _waitForMatch(sessionId, gameType, timeout);
      
    } catch (e) {
      return MatchmakingResult(
        success: false,
        message: 'Error starting matchmaking: $e',
      );
    }
  }
  
  /// Attendre qu'un match soit trouvé
  Future<MatchmakingResult> _waitForMatch(
    String sessionId, 
    String gameType,
    Duration timeout,
  ) async {
    final startTime = DateTime.now();
    int waitTime = 0;
    
    while (DateTime.now().difference(startTime) < timeout) {
      await Future.delayed(const Duration(seconds: 2));
      waitTime += 2;
      
      // Vérifier si la session a des participants supplémentaires
      final participants = await getSessionParticipants(sessionId);
      
      if (participants.length >= 2) {
        await _updateMatchmakingStats(gameType, matchFound: true, waitTimeSeconds: waitTime);
        return MatchmakingResult(
          success: true,
          sessionId: sessionId,
          message: 'Match found!',
          isMatchFound: true,
        );
      }
    }
    
    // Timeout
    await _updateMatchmakingStats(gameType, waitTimeSeconds: waitTime);
    return MatchmakingResult(
      success: false,
      message: 'Matchmaking timeout - no opponent found',
    );
  }
  
  /// Créer une session privée
  Future<MatchmakingResult> createPrivateSession({
    required String gameType,
    String gameMode = 'battle',
    int maxPlayers = 2,
    int eloMin = 0,
    int eloMax = 3000,
    Map<String, dynamic> gameConfig = const {},
  }) async {
    try {
      final response = await _supabase.rpc('game_create_multiplayer_session', params: {
        'p_game_type': gameType,
        'p_game_mode': gameMode,
        'p_max_players': maxPlayers,
        'p_is_private': true,
        'p_elo_min': eloMin,
        'p_elo_max': eloMax,
        'p_game_config': gameConfig,
      });
      
      if (response.isEmpty) {
        throw Exception('Failed to create private session');
      }
      
      final result = response.first;
      final success = result['success'] as bool;
      
      if (!success) {
        return MatchmakingResult(
          success: false,
          message: result['message'] as String,
        );
      }
      
      return MatchmakingResult(
        success: true,
        sessionId: result['session_id'] as String,
        roomCode: result['room_code'] as String,
        message: result['message'] as String,
      );
      
    } catch (e) {
      return MatchmakingResult(
        success: false,
        message: 'Error creating private session: $e',
      );
    }
  }
  
  /// Rejoindre une session par code
  Future<MatchmakingResult> joinSessionByCode(String roomCode) async {
    try {
      final response = await _supabase.rpc('game_join_session_by_code', params: {
        'p_room_code': roomCode,
      });
      
      if (response.isEmpty) {
        throw Exception('Failed to join session');
      }
      
      final result = response.first;
      final success = result['success'] as bool;
      
      if (!success) {
        return MatchmakingResult(
          success: false,
          message: result['message'] as String,
        );
      }
      
      return MatchmakingResult(
        success: true,
        sessionId: result['session_id'] as String,
        message: result['message'] as String,
      );
      
    } catch (e) {
      return MatchmakingResult(
        success: false,
        message: 'Error joining session: $e',
      );
    }
  }
  
  /// Lister les sessions publiques disponibles
  Future<List<PublicSession>> listPublicSessions({
    String? gameType,
    int limit = 20,
  }) async {
    try {
      final response = await _supabase.rpc('game_list_public_sessions', params: {
        'p_game_type': gameType,
        'p_limit': limit,
      });
      
      if (response.isEmpty) {
        return [];
      }
      
      return response.map((session) => PublicSession.fromJson(session)).toList();
      
    } catch (e) {
      print('Error listing public sessions: $e');
      return [];
    }
  }
  
  /// Démarrer une session
  Future<bool> startSession(String sessionId) async {
    try {
      final response = await _supabase.rpc('game_start_session', params: {
        'p_session_id': sessionId,
      });
      
      if (response.isEmpty) {
        return false;
      }
      
      final result = response.first;
      return result['success'] as bool;
      
    } catch (e) {
      print('Error starting session: $e');
      return false;
    }
  }
  
  /// Terminer une session et mettre à jour les ELO
  Future<bool> endSession({
    required String sessionId,
    required Map<String, int> finalScores,
  }) async {
    try {
      final response = await _supabase.rpc('game_end_session', params: {
        'p_session_id': sessionId,
        'p_final_scores': finalScores,
      });
      
      if (response.isEmpty) {
        return false;
      }
      
      final result = response.first;
      return result['success'] as bool;
      
    } catch (e) {
      print('Error ending session: $e');
      return false;
    }
  }
  
  /// Envoyer une invitation
  Future<bool> sendInvitation(String recipientId, String sessionId) async {
    try {
      final response = await _supabase.rpc('game_send_invitation', params: {
        'p_recipient_id': recipientId,
        'p_session_id': sessionId,
      });
      
      if (response.isEmpty) {
        return false;
      }
      
      final result = response.first;
      return result['success'] as bool;
      
    } catch (e) {
      print('Error sending invitation: $e');
      return false;
    }
  }
  
  /// Accepter une invitation
  Future<MatchmakingResult> acceptInvitation(String invitationId) async {
    try {
      final response = await _supabase.rpc('game_accept_invitation', params: {
        'p_invitation_id': invitationId,
      });
      
      if (response.isEmpty) {
        throw Exception('Failed to accept invitation');
      }
      
      final result = response.first;
      final success = result['success'] as bool;
      
      if (!success) {
        return MatchmakingResult(
          success: false,
          message: result['message'] as String,
        );
      }
      
      return MatchmakingResult(
        success: true,
        sessionId: result['session_id'] as String,
        message: result['message'] as String,
      );
      
    } catch (e) {
      return MatchmakingResult(
        success: false,
        message: 'Error accepting invitation: $e',
      );
    }
  }
  
  /// Obtenir les participants d'une session
  Future<List<SessionParticipant>> getSessionParticipants(String sessionId) async {
    try {
      final response = await _supabase
          .from('game_multiplayer_participants')
          .select('''
            user_id,
            status,
            score,
            elo_rating_before,
            joined_at
          ''')
          .eq('session_id', sessionId);
      
      return response.map((p) => SessionParticipant.fromJson(p)).toList();
      
    } catch (e) {
      print('Error getting session participants: $e');
      return [];
    }
  }
  
  /// Obtenir les détails d'une session
  Future<GameSession?> getSessionDetails(String sessionId) async {
    try {
      final response = await _supabase
          .from('game_multiplayer_sessions')
          .select('''
            id,
            game_type,
            game_mode,
            max_players,
            current_players,
            status,
            room_code,
            host_id,
            is_private,
            elo_min,
            elo_max,
            created_at,
            started_at,
            completed_at,
            game_config
          ''')
          .eq('id', sessionId)
          .single();
      
      return GameSession.fromJson(response);
      
    } catch (e) {
      print('Error getting session details: $e');
      return null;
    }
  }
  
  /// Mettre à jour les statistiques de matchmaking
  Future<void> _updateMatchmakingStats(
    String gameType, {
    bool searchInitiated = false,
    bool matchFound = false,
    int? waitTimeSeconds,
  }) async {
    try {
      await _supabase.rpc('game_update_matchmaking_stats', params: {
        'p_game_type': gameType,
        'p_search_initiated': searchInitiated,
        'p_match_found': matchFound,
        'p_wait_time_seconds': waitTimeSeconds,
      });
    } catch (e) {
      print('Error updating matchmaking stats: $e');
    }
  }
  
  /// Annuler le matchmaking (quitter la file d'attente)
  Future<bool> cancelMatchmaking(String sessionId) async {
    try {
      await _supabase
          .from('game_multiplayer_participants')
          .delete()
          .eq('session_id', sessionId)
          .eq('user_id', Supabase.instance.client.auth.currentUser?.id);
      
      return true;
    } catch (e) {
      print('Error cancelling matchmaking: $e');
      return false;
    }
  }
}

/// Résultat du matchmaking
class MatchmakingResult {
  final bool success;
  final String? sessionId;
  final String? roomCode;
  final String message;
  final bool isMatchFound;
  
  MatchmakingResult({
    required this.success,
    required this.message,
    this.sessionId,
    this.roomCode,
    this.isMatchFound = false,
  });
}

/// Session publique disponible
class PublicSession {
  final String sessionId;
  final String gameType;
  final String gameMode;
  final int maxPlayers;
  final int currentPlayers;
  final String status;
  final String roomCode;
  final String hostName;
  final int eloMin;
  final int eloMax;
  final DateTime createdAt;
  
  PublicSession({
    required this.sessionId,
    required this.gameType,
    required this.gameMode,
    required this.maxPlayers,
    required this.currentPlayers,
    required this.status,
    required this.roomCode,
    required this.hostName,
    required this.eloMin,
    required this.eloMax,
    required this.createdAt,
  });
  
  factory PublicSession.fromJson(Map<String, dynamic> json) {
    return PublicSession(
      sessionId: json['session_id'],
      gameType: json['game_type'],
      gameMode: json['game_mode'],
      maxPlayers: json['max_players'],
      currentPlayers: json['current_players'],
      status: json['status'],
      roomCode: json['room_code'],
      hostName: json['host_name'],
      eloMin: json['elo_min'],
      eloMax: json['elo_max'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
  
  bool get isAvailable => status == 'waiting' && currentPlayers < maxPlayers;
  bool get canJoin => isAvailable && createdAt.isAfter(DateTime.now().subtract(const Duration(hours: 1)));
}

/// Participant à une session
class SessionParticipant {
  final String userId;
  final String status;
  final int score;
  final int eloRatingBefore;
  final DateTime joinedAt;
  
  SessionParticipant({
    required this.userId,
    required this.status,
    required this.score,
    required this.eloRatingBefore,
    required this.joinedAt,
  });
  
  factory SessionParticipant.fromJson(Map<String, dynamic> json) {
    return SessionParticipant(
      userId: json['user_id'],
      status: json['status'],
      score: json['score'] ?? 0,
      eloRatingBefore: json['elo_rating_before'] ?? 1000,
      joinedAt: DateTime.parse(json['joined_at']),
    );
  }
  
  bool get isHost => status == 'host';
  bool get isPlaying => status == 'playing';
  bool get isReady => status == 'ready';
}

/// Session de jeu
class GameSession {
  final String id;
  final String gameType;
  final String gameMode;
  final int maxPlayers;
  final int currentPlayers;
  final String status;
  final String? roomCode;
  final String hostId;
  final bool isPrivate;
  final int eloMin;
  final int eloMax;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final Map<String, dynamic> gameConfig;
  
  GameSession({
    required this.id,
    required this.gameType,
    required this.gameMode,
    required this.maxPlayers,
    required this.currentPlayers,
    required this.status,
    this.roomCode,
    required this.hostId,
    required this.isPrivate,
    required this.eloMin,
    required this.eloMax,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    required this.gameConfig,
  });
  
  factory GameSession.fromJson(Map<String, dynamic> json) {
    return GameSession(
      id: json['id'],
      gameType: json['game_type'],
      gameMode: json['game_mode'],
      maxPlayers: json['max_players'],
      currentPlayers: json['current_players'],
      status: json['status'],
      roomCode: json['room_code'],
      hostId: json['host_id'],
      isPrivate: json['is_private'],
      eloMin: json['elo_min'],
      eloMax: json['elo_max'],
      createdAt: DateTime.parse(json['created_at']),
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      gameConfig: json['game_config'] ?? {},
    );
  }
  
  bool get isWaiting => status == 'waiting';
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isFull => currentPlayers >= maxPlayers;
  bool get canStart => isWaiting && currentPlayers >= 2;
}
