import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

/// Service de communication temps réel simplifié pour les jeux Kellenge
/// Gère les messages de chat et notifications via polling
class RealtimeService {
  static RealtimeService? _instance;
  static RealtimeService get instance => _instance ??= RealtimeService._();
  
  RealtimeService._();
  
  final SupabaseClient _supabase = Supabase.instance.client;
  final Map<String, Timer> _pollingTimers = {};
  final Map<String, Function> _callbacks = {};
  
  /// S'abonner aux messages de chat d'une session (polling)
  void subscribeToChat(
    String sessionId, 
    Function(List<ChatMessage>) onMessages,
  ) {
    final callbackKey = 'chat_$sessionId';
    
    // Annuler l'abonnement précédent si existant
    _pollingTimers[callbackKey]?.cancel();
    _callbacks.remove(callbackKey);
    
    // Stocker le callback
    _callbacks[callbackKey] = onMessages;
    
    // Démarrer le polling
    _startChatPolling(sessionId);
  }
  
  /// S'abonner aux changements de participants d'une session (polling)
  void subscribeToParticipants(
    String sessionId, 
    Function(List<SessionParticipant>) onParticipants,
  ) {
    final callbackKey = 'participants_$sessionId';
    
    // Annuler l'abonnement précédent si existant
    _pollingTimers[callbackKey]?.cancel();
    _callbacks.remove(callbackKey);
    
    // Stocker le callback
    _callbacks[callbackKey] = onParticipants;
    
    // Démarrer le polling
    _startParticipantsPolling(sessionId);
  }
  
  /// S'abonner aux changements de statut d'une session (polling)
  void subscribeToSessionStatus(
    String sessionId, 
    Function(GameSession) onSessionChange,
  ) {
    final callbackKey = 'session_status_$sessionId';
    
    // Annuler l'abonnement précédent si existant
    _pollingTimers[callbackKey]?.cancel();
    _callbacks.remove(callbackKey);
    
    // Stocker le callback
    _callbacks[callbackKey] = onSessionChange;
    
    // Démarrer le polling
    _startSessionStatusPolling(sessionId);
  }
  
  void _startChatPolling(String sessionId) {
    final callbackKey = 'chat_$sessionId';
    final callback = _callbacks[callbackKey];
    
    if (callback == null) return;
    
    _pollingTimers[callbackKey] = Timer.periodic(
      const Duration(seconds: 2),
      (_) async {
        final messages = await getChatHistory(sessionId);
        if (messages.isNotEmpty) {
          callback(messages);
        }
      },
    );
  }
  
  void _startParticipantsPolling(String sessionId) {
    final callbackKey = 'participants_$sessionId';
    final callback = _callbacks[callbackKey];
    
    if (callback == null) return;
    
    _pollingTimers[callbackKey] = Timer.periodic(
      const Duration(seconds: 3),
      (_) async {
        final participants = await getSessionParticipants(sessionId);
        if (participants.isNotEmpty) {
          callback(participants);
        }
      },
    );
  }
  
  void _startSessionStatusPolling(String sessionId) {
    final callbackKey = 'session_status_$sessionId';
    final callback = _callbacks[callbackKey];
    
    if (callback == null) return;
    
    _pollingTimers[callbackKey] = Timer.periodic(
      const Duration(seconds: 5),
      (_) async {
        final session = await getSessionDetails(sessionId);
        if (session != null) {
          callback(session);
        }
      },
    );
  }
  
  /// Envoyer un message de chat
  Future<bool> sendChatMessage({
    required String sessionId,
    required String message,
    String messageType = 'text',
  }) async {
    try {
      final response = await _supabase.rpc('game_send_chat_message', params: {
        'p_session_id': sessionId,
        'p_message': message,
        'p_message_type': messageType,
      });
      
      if (response.isEmpty) {
        return false;
      }
      
      final result = response.first;
      return result['success'] as bool;
      
    } catch (e) {
      print('Error sending chat message: $e');
      return false;
    }
  }
  
  /// Obtenir l'historique des messages de chat
  Future<List<ChatMessage>> getChatHistory(String sessionId, {int limit = 50}) async {
    try {
      final response = await _supabase.rpc('game_get_chat_messages', params: {
        'p_session_id': sessionId,
        'p_limit': limit,
      });
      
      if (response.isEmpty) {
        return [];
      }
      
      return response.map((msg) => ChatMessage.fromJson(msg)).toList();
      
    } catch (e) {
      print('Error getting chat history: $e');
      return [];
    }
  }
  
  /// Envoyer un message système (notification de jeu)
  Future<bool> sendSystemMessage({
    required String sessionId,
    required String message,
  }) async {
    return await sendChatMessage(
      sessionId: sessionId,
      message: message,
      messageType: 'system',
    );
  }
  
  /// Envoyer un message d'émoji
  Future<bool> sendEmojiMessage({
    required String sessionId,
    required String emoji,
  }) async {
    return await sendChatMessage(
      sessionId: sessionId,
      message: emoji,
      messageType: 'emoji',
    );
  }
  
  /// Envoyer un événement de jeu
  Future<bool> sendGameEvent({
    required String sessionId,
    required String eventDescription,
  }) async {
    return await sendChatMessage(
      sessionId: sessionId,
      message: eventDescription,
      messageType: 'game_event',
    );
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
  
  /// Annuler tous les abonnements
  void cancelAllSubscriptions() {
    for (final timer in _pollingTimers.values) {
      timer.cancel();
    }
    _pollingTimers.clear();
    _callbacks.clear();
  }
  
  /// Annuler un abonnement spécifique
  void cancelSubscription(String subscriptionKey) {
    final timer = _pollingTimers.remove(subscriptionKey);
    timer?.cancel();
    _callbacks.remove(subscriptionKey);
  }
  
  /// Nettoyer les ressources
  void dispose() {
    cancelAllSubscriptions();
  }
}

/// Message de chat
class ChatMessage {
  final String messageId;
  final String senderId;
  final String senderName;
  final String message;
  final String messageType;
  final DateTime createdAt;
  final bool isEdited;
  
  ChatMessage({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.messageType,
    required this.createdAt,
    this.isEdited = false,
  });
  
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: json['message_id'],
      senderId: json['sender_id'],
      senderName: json['sender_name'],
      message: json['message'],
      messageType: json['message_type'],
      createdAt: DateTime.parse(json['created_at']),
      isEdited: json['edited_at'] != null,
    );
  }
  
  bool get isSystem => messageType == 'system';
  bool get isEmoji => messageType == 'emoji';
  bool get isGameEvent => messageType == 'game_event';
  bool get isText => messageType == 'text';
  bool get isFromCurrentUser => senderId == Supabase.instance.client.auth.currentUser?.id;
  
  String get displayName => isSystem ? 'System' : senderName;
  
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
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
  bool get isDisconnected => status == 'disconnected';
  bool get isCurrentUser => userId == Supabase.instance.client.auth.currentUser?.id;
  
  String get statusDisplay {
    switch (status) {
      case 'host':
        return 'Host';
      case 'joined':
        return 'Joined';
      case 'ready':
        return 'Ready';
      case 'playing':
        return 'Playing';
      case 'disconnected':
        return 'Disconnected';
      default:
        return status;
    }
  }
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
  bool get isHost => hostId == Supabase.instance.client.auth.currentUser?.id;
  
  String get statusDisplay {
    switch (status) {
      case 'waiting':
        return 'Waiting for players';
      case 'active':
        return 'Game in progress';
      case 'completed':
        return 'Game completed';
      case 'cancelled':
        return 'Game cancelled';
      default:
        return status;
    }
  }
}
