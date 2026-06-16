import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service pour gérer les sessions live de jeux dans le feed Challenge.
///
/// Utilise Supabase Realtime Presence pour signaler qu'un joueur est
/// en train de jouer, et les RPCs pour créer/terminer les sessions.
/// Séparé des autres types de live (prep, cours, TD).
class GameLiveService {
  GameLiveService._();

  static final SupabaseClient _client = Supabase.instance.client;
  static RealtimeChannel? _presenceChannel;
  static String? _currentSessionId;
  static String? _currentRoomName;
  static bool _isLive = false;

  static bool get isLive => _isLive;
  static String? get currentSessionId => _currentSessionId;
  static String? get currentRoomName => _currentRoomName;

  /// Démarre une session live : insère en base + rejoint le canal Presence.
  /// Appelé automatiquement quand le joueur lance un jeu.
  static Future<String?> startLive({
    required String gameType,
    String mode = 'solo',
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('[GameLive] Utilisateur non authentifié');
        return null;
      }

      // 1. Créer la session en base via RPC
      final response = await _client.rpc('challenge_game_start_live', params: {
        'p_game_type': gameType,
        'p_mode': mode,
      });

      final sessionId = response?['session_id']?.toString();
      final roomName = response?['room_name']?.toString();
      if (sessionId == null || sessionId.isEmpty) {
        debugPrint('[GameLive] Échec création session');
        return null;
      }

      _currentSessionId = sessionId;
      _currentRoomName = roomName;
      _isLive = true;

      // Fetch player display name and avatar for Presence
      String playerName = '';
      String playerAvatar = '';
      try {
        final profile = await _client.schema('app').from('students')
            .select('full_name, avatar_url')
            .eq('id', userId)
            .maybeSingle();
        if (profile != null) {
          playerName = (profile['full_name'] ?? '').toString();
          playerAvatar = (profile['avatar_url'] ?? '').toString();
        }
      } catch (_) {}

      // 2. Rejoindre le canal Presence pour que les autres voient le live
      _presenceChannel = _client.channel('game_live_feed');
      _presenceChannel!.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          _presenceChannel!.track({
            'user_id': userId,
            'session_id': sessionId,
            'room_name': roomName ?? 'game_$sessionId',
            'game_type': gameType,
            'mode': mode,
            'player_name': playerName,
            'player_avatar': playerAvatar,
            'started_at': DateTime.now().toIso8601String(),
          });
          debugPrint('[GameLive] Presence tracked: $gameType ($sessionId) room=$roomName name=$playerName');
        }
      });

      debugPrint('[GameLive] Session live démarrée: $sessionId');
      return sessionId;
    } catch (e) {
      debugPrint('[GameLive] Erreur startLive: $e');
      _isLive = false;
      _currentSessionId = null;
      return null;
    }
  }

  /// Termine la session live : met à jour la base + quitte le canal Presence.
  /// Appelé automatiquement quand le jeu se termine.
  static Future<void> endLive({
    int scoreFinal = 0,
    String? replayVideoAssetId,
  }) async {
    if (!_isLive || _currentSessionId == null) return;

    try {
      // 1. Mettre à jour la session en base
      await _client.rpc('challenge_game_end_live', params: {
        'p_session_id': _currentSessionId,
        'p_score_final': scoreFinal,
        'p_replay_video_asset_id': replayVideoAssetId,
      });

      // 2. Quitter le canal Presence
      if (_presenceChannel != null) {
        await _presenceChannel!.untrack();
        await _client.removeChannel(_presenceChannel!);
        _presenceChannel = null;
      }

      debugPrint('[GameLive] Session terminée: $_currentSessionId (score=$scoreFinal)');
    } catch (e) {
      debugPrint('[GameLive] Erreur endLive: $e');
    } finally {
      _isLive = false;
      _currentSessionId = null;
      _currentRoomName = null;
    }
  }

  /// Annule la session live (joueur quitte avant la fin).
  static Future<void> cancelLive() async {
    if (!_isLive || _currentSessionId == null) return;

    try {
      // Mettre le status à 'cancelled' directement
      await _client.schema('app').from('challenge_game_live_sessions')
          .update({'status': 'cancelled', 'ended_at': DateTime.now().toIso8601String()})
          .eq('id', _currentSessionId!);

      if (_presenceChannel != null) {
        await _presenceChannel!.untrack();
        await _client.removeChannel(_presenceChannel!);
        _presenceChannel = null;
      }

      debugPrint('[GameLive] Session annulée: $_currentSessionId');
    } catch (e) {
      debugPrint('[GameLive] Erreur cancelLive: $e');
    } finally {
      _isLive = false;
      _currentSessionId = null;
      _currentRoomName = null;
    }
  }

  /// Récupère la liste des sessions live en cours (pour afficher dans le feed).
  static Future<List<Map<String, dynamic>>> getLiveSessions() async {
    try {
      final response = await _client.rpc('challenge_game_list_live');
      if (response is Map<String, dynamic>) {
        final sessions = response['sessions'];
        if (sessions is List) {
          return sessions
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
      if (response is List) {
        return response
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[GameLive] Erreur getLiveSessions: $e');
      return [];
    }
  }

  /// Souscrit au canal Presence pour être notifié des joueurs en live.
  /// Retourne un Stream de la liste des joueurs actuellement en live.
  static Stream<List<Map<String, dynamic>>> watchLivePlayers() {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();

    final channel = _client.channel('game_live_feed');
    channel.onPresenceSync((payload) {
      final presences = channel.presenceState();
      final players = <Map<String, dynamic>>[];
      for (final state in presences) {
        for (final presence in state.presences) {
          final data = presence.payload;
          if (data.containsKey('user_id')) {
            players.add(Map<String, dynamic>.from(data));
          }
        }
      }
      controller.add(players);
    }).subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
    };

    return controller.stream;
  }
}
