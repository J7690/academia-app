import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Service pour gérer les sessions Live Arena
class LiveArenaService {
  static final Map<String, LiveSession> _activeSessions = {};
  static final Map<String, List<Spectator>> _spectators = {};
  static final Uuid _uuid = Uuid();
  
  /// Créer une nouvelle session Live Arena
  static Future<String> createLiveSession({
    required String fighter1Id,
    required String fighter2Id,
    required String gameType,
    bool isPrivate = false,
    int maxSpectators = 1000,
    Map<String, dynamic>? settings,
  }) async {
    final sessionId = _uuid.v4();
    
    try {
      final result = await Supabase.instance.client
          .from('live_arena_sessions')
          .insert({
            'id': sessionId,
            'fighter1_id': fighter1Id,
            'fighter2_id': fighter2Id,
            'game_type': gameType,
            'status': 'waiting',
            'is_private': isPrivate,
            'max_spectators': maxSpectators,
            'room_code': isPrivate ? _generateRoomCode() : null,
            'settings': settings ?? {},
          }).select();
      
      final session = LiveSession.fromJson(result.first);
      _activeSessions[sessionId] = session;
      _spectators[sessionId] = [];
      
      // Notifier les joueurs
      await _notifyFighters(sessionId);
      
      return sessionId;
    } catch (e) {
      throw Exception('Erreur lors de la création de la session: $e');
    }
  }
  
  /// Démarrer une session Live Arena
  static Future<void> startSession(String sessionId) async {
    try {
      await Supabase.instance.client
          .from('live_arena_sessions')
          .update({
            'status': 'active',
            'start_time': DateTime.now().toIso8601String(),
          })
          .eq('id', sessionId);
      
      // Mettre à jour le cache local
      if (_activeSessions.containsKey(sessionId)) {
        _activeSessions[sessionId]!.status = LiveStatus.active;
        _activeSessions[sessionId]!.startTime = DateTime.now();
      }
      
      // Notifier le démarrage
      await _broadcastEvent(sessionId, 'session_started', {
        'session_id': sessionId,
        'start_time': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Erreur lors du démarrage de la session: $e');
    }
  }
  
  /// Ajouter un spectateur à la session
  static Future<void> addSpectator(String sessionId, String userId) async {
    try {
      // Vérifier si la session existe et est active
      final session = await getSession(sessionId);
      if (session.status != LiveStatus.active) {
        throw Exception('Session non disponible');
      }
      
      // Vérifier si le spectateur n'est pas déjà présent
      if (_spectators[sessionId]?.any((s) => s.userId == userId) == true) {
        return; // Déjà présent
      }
      
      // Vérifier la limite de spectateurs
      if (session.spectatorCount >= session.maxSpectators) {
        throw Exception('Session pleine');
      }
      
      // Ajouter le spectateur
      final spectator = Spectator(
        userId: userId,
        joinedAt: DateTime.now(),
        supportPoints: 0,
        chatMessages: 0,
        reactions: 0,
        isActive: true,
      );
      
      await Supabase.instance.client
          .from('live_spectators')
          .insert({
            'session_id': sessionId,
            'user_id': userId,
            'joined_at': spectator.joinedAt.toIso8601String(),
            'support_points': spectator.supportPoints,
            'chat_messages': spectator.chatMessages,
            'reactions': spectator.reactions,
            'is_active': spectator.isActive,
          });
      
      _spectators[sessionId]?.add(spectator);
      
      // Notifier tous les participants
      await _broadcastEvent(sessionId, 'spectator_joined', {
        'user_id': userId,
        'total_spectators': _spectators[sessionId]?.length ?? 0,
      });
    } catch (e) {
      throw Exception('Erreur lors de l''ajout du spectateur: $e');
    }
  }
  
  /// Envoyer un message dans le chat
  static Future<void> sendChatMessage({
    required String sessionId,
    required String userId,
    required String message,
    String? targetUserId,
    String messageType = 'text',
  }) async {
    try {
      await Supabase.instance.client
          .from('live_chat_messages')
          .insert({
            'session_id': sessionId,
            'user_id': userId,
            'message': message,
            'message_type': messageType,
            'target_user_id': targetUserId,
            'created_at': DateTime.now().toIso8601String(),
          });
      
      // Mettre à jour le compteur de messages du spectateur
      final spectatorIndex = _spectators[sessionId]?.indexWhere((s) => s.userId == userId);
      if (spectatorIndex != null && spectatorIndex != -1) {
        _spectators[sessionId]![spectatorIndex].chatMessages++;
      }
      
      // Notifier le message
      await _broadcastEvent(sessionId, 'chat_message', {
        'user_id': userId,
        'message': message,
        'message_type': messageType,
        'target_user_id': targetUserId,
      });
    } catch (e) {
      throw Exception('Erreur lors de l''envoi du message: $e');
    }
  }
  
  /// Supporter un joueur
  static Future<void> supportFighter({
    required String sessionId,
    required String spectatorId,
    required String fighterId,
  }) async {
    try {
      // Mettre à jour le support du spectateur
      await Supabase.instance.client
          .from('live_spectators')
          .update({
            'supported_fighter': fighterId,
            'support_points': Supabase.instance.client.raw('support_points + 1'),
          })
          .eq('session_id', sessionId)
          .eq('user_id', spectatorId);
      
      // Mettre à jour le cache local
      final spectatorIndex = _spectators[sessionId]?.indexWhere((s) => s.userId == spectatorId);
      if (spectatorIndex != null && spectatorIndex != -1) {
        _spectators[sessionId]![spectatorIndex].supportedFighter = fighterId;
        _spectators[sessionId]![spectatorIndex].supportPoints++;
      }
      
      // Notifier le support
      await _broadcastEvent(sessionId, 'fighter_supported', {
        'spectator_id': spectatorId,
        'fighter_id': fighterId,
      });
    } catch (e) {
      throw Exception('Erreur lors du support: $e');
    }
  }
  
  /// Terminer une session
  static Future<void> endSession({
    required String sessionId,
    required Map<String, dynamic> finalScore,
    String? winnerId,
  }) async {
    try {
      await Supabase.instance.client
          .from('live_arena_sessions')
          .update({
            'status': 'completed',
            'end_time': DateTime.now().toIso8601String(),
            'final_score': finalScore,
            'winner_id': winnerId,
          })
          .eq('id', sessionId);
      
      // Mettre à jour le cache local
      if (_activeSessions.containsKey(sessionId)) {
        _activeSessions[sessionId]!.status = LiveStatus.completed;
        _activeSessions[sessionId]!.endTime = DateTime.now();
        _activeSessions[sessionId]!.finalScore = finalScore;
        _activeSessions[sessionId]!.winnerId = winnerId;
      }
      
      // Notifier la fin de session
      await _broadcastEvent(sessionId, 'session_ended', {
        'final_score': finalScore,
        'winner_id': winnerId,
        'end_time': DateTime.now().toIso8601String(),
      });
      
      // Nettoyer le cache après un délai
      Timer(Duration(minutes: 5), () {
        _activeSessions.remove(sessionId);
        _spectators.remove(sessionId);
      });
    } catch (e) {
      throw Exception('Erreur lors de la fin de session: $e');
    }
  }
  
  /// Obtenir une session
  static Future<LiveSession> getSession(String sessionId) async {
    // D'abord vérifier le cache
    if (_activeSessions.containsKey(sessionId)) {
      return _activeSessions[sessionId]!;
    }
    
    // Sinon charger depuis la base
    try {
      final result = await Supabase.instance.client
          .from('live_arena_sessions')
          .select()
          .eq('id', sessionId)
          .single();
      
      final session = LiveSession.fromJson(result);
      _activeSessions[sessionId] = session;
      return session;
    } catch (e) {
      throw Exception('Session non trouvée: $e');
    }
  }
  
  /// Obtenir les spectateurs d'une session
  static Future<List<Spectator>> getSpectators(String sessionId) async {
    // D'abord vérifier le cache
    if (_spectators.containsKey(sessionId)) {
      return _spectators[sessionId]!;
    }
    
    // Sinon charger depuis la base
    try {
      final result = await Supabase.instance.client
          .from('live_spectators')
          .select()
          .eq('session_id', sessionId)
          .eq('is_active', true)
          .order('joined_at');
      
      final spectators = result.map((json) => Spectator.fromJson(json)).toList();
      _spectators[sessionId] = spectators;
      return spectators;
    } catch (e) {
      throw Exception('Erreur lors du chargement des spectateurs: $e');
    }
  }
  
  /// Stream des événements en temps réel
  static Stream<Map<String, dynamic>> getEventStream(String sessionId) {
    return Supabase.instance.client
        .channel('live_arena_$sessionId')
        .onPostgresChanges(
          event: EventType.insert,
          schema: 'app',
          table: 'live_arena_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
        )
        .map((event) => event.newRecord ?? {});
  }
  
  /// Stream des messages de chat
  static Stream<Map<String, dynamic>> getChatStream(String sessionId) {
    return Supabase.instance.client
        .channel('live_chat_$sessionId')
        .onPostgresChanges(
          event: EventType.insert,
          schema: 'app',
          table: 'live_chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
        )
        .map((event) => event.newRecord ?? {});
  }
  
  /// Obtenir les sessions actives
  static Future<List<LiveSession>> getActiveSessions() async {
    try {
      final result = await Supabase.instance.client
          .from('live_arena_sessions')
          .select()
          .in_('status', ['waiting', 'active'])
          .order('created_at', ascending: false);
      
      return result.map((json) => LiveSession.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Erreur lors du chargement des sessions actives: $e');
    }
  }
  
  /// Notifier les joueurs
  static Future<void> _notifyFighters(String sessionId) async {
    final session = _activeSessions[sessionId];
    if (session == null) return;
    
    // Implémenter la notification via push notifications
    // TODO: Intégrer avec le service de notifications existant
  }
  
  /// Diffuser un événement
  static Future<void> _broadcastEvent(String sessionId, String eventType, Map<String, dynamic> data) async {
    try {
      await Supabase.instance.client
          .from('live_arena_events')
          .insert({
            'session_id': sessionId,
            'event_type': eventType,
            'event_data': data,
            'timestamp': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      print('Erreur lors de la diffusion de l''événement: $e');
    }
  }
  
  /// Générer un code de room
  static String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String code = '';
    for (int i = 0; i < 6; i++) {
      code += chars[(random + i) % chars.length];
    }
    return code;
  }
  
  /// Nettoyer les anciennes sessions
  static Future<void> cleanupOldSessions() async {
    try {
      await Supabase.instance.client
          .from('live_arena_sessions')
          .update({'status': 'cancelled'})
          .lt('created_at', DateTime.now().subtract(Duration(hours: 24)))
          .in_('status', ['waiting', 'active']);
    } catch (e) {
      print('Erreur lors du nettoyage: $e');
    }
  }
}

/// Modèles de données
enum LiveStatus { waiting, active, completed, cancelled }

class LiveSession {
  final String id;
  final String fighter1Id;
  final String fighter2Id;
  final String gameType;
  final LiveStatus status;
  final DateTime? startTime;
  final DateTime? endTime;
  final Map<String, dynamic> finalScore;
  final String? winnerId;
  final int spectatorCount;
  final int maxSpectators;
  final bool isPrivate;
  final String? roomCode;
  final Map<String, dynamic> settings;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  LiveSession({
    required this.id,
    required this.fighter1Id,
    required this.fighter2Id,
    required this.gameType,
    required this.status,
    this.startTime,
    this.endTime,
    required this.finalScore,
    this.winnerId,
    required this.spectatorCount,
    required this.maxSpectators,
    required this.isPrivate,
    this.roomCode,
    required this.settings,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory LiveSession.fromJson(Map<String, dynamic> json) {
    return LiveSession(
      id: json['id'],
      fighter1Id: json['fighter1_id'],
      fighter2Id: json['fighter2_id'],
      gameType: json['game_type'],
      status: _parseStatus(json['status']),
      startTime: json['start_time'] != null ? DateTime.parse(json['start_time']) : null,
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      finalScore: json['final_score'] ?? {},
      winnerId: json['winner_id'],
      spectatorCount: json['spectator_count'] ?? 0,
      maxSpectators: json['max_spectators'] ?? 1000,
      isPrivate: json['is_private'] ?? false,
      roomCode: json['room_code'],
      settings: json['settings'] ?? {},
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
  
  static LiveStatus _parseStatus(String status) {
    switch (status) {
      case 'waiting':
        return LiveStatus.waiting;
      case 'active':
        return LiveStatus.active;
      case 'completed':
        return LiveStatus.completed;
      case 'cancelled':
        return LiveStatus.cancelled;
      default:
        return LiveStatus.waiting;
    }
  }
}

class Spectator {
  final String userId;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final int supportPoints;
  final int chatMessages;
  final int reactions;
  final String? supportedFighter;
  final bool isActive;
  final Map<String, dynamic> metadata;
  
  Spectator({
    required this.userId,
    required this.joinedAt,
    this.leftAt,
    required this.supportPoints,
    required this.chatMessages,
    required this.reactions,
    this.supportedFighter,
    required this.isActive,
    required this.metadata,
  });
  
  factory Spectator.fromJson(Map<String, dynamic> json) {
    return Spectator(
      userId: json['user_id'],
      joinedAt: DateTime.parse(json['joined_at']),
      leftAt: json['left_at'] != null ? DateTime.parse(json['left_at']) : null,
      supportPoints: json['support_points'] ?? 0,
      chatMessages: json['chat_messages'] ?? 0,
      reactions: json['reactions'] ?? 0,
      supportedFighter: json['supported_fighter'],
      isActive: json['is_active'] ?? true,
      metadata: json['metadata'] ?? {},
    );
  }
}

class LiveEvent {
  final String id;
  final String sessionId;
  final String eventType;
  final Map<String, dynamic> eventData;
  final String? userId;
  final DateTime timestamp;
  final bool processed;
  
  LiveEvent({
    required this.id,
    required this.sessionId,
    required this.eventType,
    required this.eventData,
    this.userId,
    required this.timestamp,
    required this.processed,
  });
  
  factory LiveEvent.fromJson(Map<String, dynamic> json) {
    return LiveEvent(
      id: json['id'],
      sessionId: json['session_id'],
      eventType: json['event_type'],
      eventData: json['event_data'] ?? {},
      userId: json['user_id'],
      timestamp: DateTime.parse(json['timestamp']),
      processed: json['processed'] ?? false,
    );
  }
}
