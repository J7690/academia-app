import 'package:supabase_flutter/supabase_flutter.dart';

/// Service de gestion des ligues pour les jeux Kellenge
/// Gère la création, participation, et suivi des ligues
class LeagueService {
  static LeagueService? _instance;
  static LeagueService get instance => _instance ??= LeagueService._();
  
  LeagueService._();
  
  final SupabaseClient _supabase = Supabase.instance.client;
  
  /// Créer une nouvelle ligue
  Future<LeagueResult> createLeague({
    required String name,
    String? description,
    required String gameType,
    String leagueType = 'seasonal',
    String division = 'main',
    int seasonNumber = 1,
    DateTime? seasonStart,
    DateTime? seasonEnd,
    int maxPlayers = 1000,
    int minElo = 0,
    int maxElo = 3000,
    String? promotionDivision,
    String? relegationDivision,
    int promotionCount = 2,
    int relegationCount = 2,
    Map<String, dynamic> settings = const {},
  }) async {
    try {
      final response = await _supabase.rpc('league_create', params: {
        'p_name': name,
        'p_description': description,
        'p_game_type': gameType,
        'p_league_type': leagueType,
        'p_division': division,
        'p_season_number': seasonNumber,
        'p_season_start': seasonStart?.toIso8601String(),
        'p_season_end': seasonEnd?.toIso8601String(),
        'p_max_players': maxPlayers,
        'p_min_elo': minElo,
        'p_max_elo': maxElo,
        'p_promotion_division': promotionDivision,
        'p_relegation_division': relegationDivision,
        'p_promotion_count': promotionCount,
        'p_relegation_count': relegationCount,
        'p_settings': settings,
      });
      
      if (response.isEmpty) {
        return LeagueResult(
          success: false,
          message: 'Failed to create league',
        );
      }
      
      final result = response.first;
      final success = result['success'] as bool;
      
      if (!success) {
        return LeagueResult(
          success: false,
          message: result['message'] as String,
        );
      }
      
      return LeagueResult(
        success: true,
        leagueId: result['league_id'] as String,
        message: result['message'] as String,
      );
      
    } catch (e) {
      return LeagueResult(
        success: false,
        message: 'Error creating league: $e',
      );
    }
  }
  
  /// Rejoindre une ligue
  Future<LeagueResult> joinLeague(String leagueId) async {
    try {
      final response = await _supabase.rpc('league_join', params: {
        'p_league_id': leagueId,
      });
      
      if (response.isEmpty) {
        return LeagueResult(
          success: false,
          message: 'Failed to join league',
        );
      }
      
      final result = response.first;
      final success = result['success'] as bool;
      
      return LeagueResult(
        success: success,
        message: result['message'] as String,
      );
      
    } catch (e) {
      return LeagueResult(
        success: false,
        message: 'Error joining league: $e',
      );
    }
  }
  
  /// Lister les ligues disponibles
  Future<List<League>> listAvailableLeagues({
    String? gameType,
    String? division,
    int limit = 20,
  }) async {
    try {
      final response = await _supabase.rpc('league_list_available', params: {
        'p_game_type': gameType,
        'p_division': division,
        'p_limit': limit,
      });
      
      if (response.isEmpty) {
        return [];
      }
      
      return response.map((league) => League.fromJson(league)).toList();
      
    } catch (e) {
      print('Error listing leagues: $e');
      return [];
    }
  }
  
  /// Obtenir les détails d'une ligue
  Future<League?> getLeagueDetails(String leagueId) async {
    try {
      final response = await _supabase
          .from('leagues')
          .select('''
            id,
            name,
            description,
            game_type,
            league_type,
            division,
            season_number,
            current_players,
            max_players,
            min_elo,
            max_elo,
            is_active,
            season_start,
            season_end,
            promotion_division,
            relegation_division,
            promotion_count,
            relegation_count,
            created_by,
            created_at,
            updated_at,
            settings
            ''')
          .eq('id', leagueId)
          .single();
      
      return League.fromJson(response);
      
    } catch (e) {
      print('Error getting league details: $e');
      return null;
    }
  }
  
  /// Obtenir les classements d'une ligue
  Future<List<LeagueStanding>> getLeagueStandings(String leagueId, {String? division}) async {
    try {
      final response = await _supabase.rpc('league_get_standings', params: {
        'p_league_id': leagueId,
        'p_division': division,
      });
      
      if (response.isEmpty) {
        return [];
      }
      
      return response.map((standing) => LeagueStanding.fromJson(standing)).toList();
      
    } catch (e) {
      print('Error getting league standings: $e');
      return [];
    }
  }
  
  /// Obtenir les participants d'une ligue
  Future<List<LeagueParticipant>> getLeagueParticipants(String leagueId) async {
    try {
      final response = await _supabase
          .from('league_participations')
          .select('''
            id,
            league_id,
            user_id,
            division,
            rank_position,
            points,
            matches_played,
            matches_won,
            matches_lost,
            matches_drawn,
            win_rate,
            elo_rating,
            elo_rating_start,
            elo_rating_end,
            elo_change,
            promotion_points,
            demotion_points,
            current_streak,
            best_streak,
            season_points,
            joined_at,
            last_match_at,
            status
            ''')
          .eq('league_id', leagueId)
          .order('rank_position');
      
      return response.map((participant) => LeagueParticipant.fromJson(participant)).toList();
      
    } catch (e) {
      print('Error getting league participants: $e');
      return [];
    }
  }
  
  /// Obtenir les matchs d'une ligue
  Future<List<LeagueMatch>> getLeagueMatches(String leagueId) async {
    try {
      final response = await _supabase
          .from('league_matches')
          .select('''
            id,
            league_id,
            participant1_id,
            participant2_id,
            scheduled_at,
            started_at,
            completed_at,
            status,
            winner_id,
            participant1_score,
            participant2_score,
            participant1_elo_change,
            participant2_elo_change,
            participant1_points,
            participant2_points,
            notes
            ''')
          .eq('league_id', leagueId)
          .order('scheduled_at DESC');
      
      return response.map((match) => LeagueMatch.fromJson(match)).toList();
      
    } catch (e) {
      print('Error getting league matches: $e');
      return [];
    }
  }
  
  /// Reporter le résultat d'un match de ligue
  Future<bool> reportLeagueMatchResult({
    required String matchId,
    required String winnerId,
    int participant1Score = 0,
    int participant2Score = 0,
    int participant1Points = 0,
    int participant2Points = 0,
    int participant1EloChange = 0,
    int participant2EloChange = 0,
    String? notes,
  }) async {
    try {
      final response = await _supabase.rpc('league_report_match_result', params: {
        'p_match_id': matchId,
        'p_winner_id': winnerId,
        'p_participant1_score': participant1Score,
        'p_participant2_score': participant2Score,
        'p_participant1_points': participant1Points,
        'p_participant2_points': participant2Points,
        'p_participant1_elo_change': participant1EloChange,
        'p_participant2_elo_change': participant2EloChange,
        'p_notes': notes,
      });
      
      if (response.isEmpty) {
        return false;
      }
      
      final result = response.first;
      return result['success'] as bool;
      
    } catch (e) {
      print('Error reporting match result: $e');
      return false;
    }
  }
  
  /// Vérifier si un joueur peut rejoindre une ligue
  Future<bool> canJoinLeague(String leagueId) async {
    try {
      final league = await getLeagueDetails(leagueId);
      if (league == null) return false;
      
      // Vérifier si la ligue est active
      if (!league.isActive) return false;
      
      // Vérifier si la ligue est pleine
      if (league.currentPlayers >= league.maxPlayers) return false;
      
      // Vérifier si déjà participant
      final participants = await getLeagueParticipants(leagueId);
      final isAlreadyParticipant = participants.any((p) => p.userId == _supabase.auth.currentUser?.id);
      if (isAlreadyParticipant) return false;
      
      // TODO: Vérifier les contraintes ELO
      // Nécessite l'accès au classement ELO
      return true;
      
    } catch (e) {
      print('Error checking league eligibility: $e');
      return false;
    }
  }
  
  /// Quitter une ligue
  Future<bool> leaveLeague(String leagueId) async {
    try {
      // Mettre à jour le statut du participant
      final response = await _supabase
          .from('league_participations')
          .update({
            'status': 'inactive'
          })
          .eq('league_id', leagueId)
          .eq('user_id', _supabase.auth.currentUser?.id)
          .eq('status', 'active');
      
      return response.error == null;
      
    } catch (e) {
      print('Error leaving league: $e');
      return false;
    }
  }
  
  /// Obtenir les saisons d'une ligue
  Future<List<LeagueSeason>> getLeagueSeasons(String leagueId) async {
    try {
      final response = await _supabase
          .from('leagues')
          .select('''
            season_number,
            season_start,
            season_end,
            current_players,
            max_players,
            is_active
            ''')
          .eq('id', leagueId)
          .order('season_number DESC');
      
      return response.map((season) => LeagueSeason.fromJson(season)).toList();
      
    } catch (e) {
      print('Error getting league seasons: $e');
      return [];
    }
  }
  
  /// Obtenir les récompenses d'une ligue
  Future<List<LeagueReward>> getLeagueRewards(String leagueId) async {
    try {
      final response = await _supabase
          .from('tournament_rewards')
          .select('''
            rank_from,
            rank_to,
            reward_type,
            reward_value,
            reward_name,
            reward_description,
            reward_icon,
            created_at
            ''')
          .eq('league_id', leagueId)
          .order('rank_from');
      
      return response.map((reward) => LeagueReward.fromJson(reward)).toList();
      
    } catch (e) {
      print('Error getting league rewards: $e');
      return [];
    }
  }
  
  /// Obtenir les événements d'une ligue
  Future<List<CompetitiveEvent>> getLeagueEvents(String leagueId, {int limit = 50}) async {
    try {
      final response = await _supabase
          .from('competitive_events')
          .select('''
            id,
            participant_id,
            event_type,
            event_data,
            created_at
            ''')
          .eq('league_id', leagueId)
          .order('created_at DESC')
          .limit(limit);
      
      return response.map((event) => CompetitiveEvent.fromJson(event)).toList();
      
    } catch (e) {
      print('Error getting competitive events: $e');
      return [];
    }
  }
  
  /// Obtenir les statistiques d'un joueur dans les ligues
  Future<List<PlayerLeagueStats>> getPlayerLeagueStats(String userId) async {
    try {
      final response = await _supabase
          .from('league_participations')
          .select('''
            league_id,
            division,
            rank_position,
            points,
            matches_played,
            matches_won,
            matches_lost,
            matches_drawn,
            win_rate,
            elo_rating,
            elo_change,
            current_streak,
            best_streak,
            season_points,
            status,
            joined_at,
            last_match_at,
            leagues!name,
            leagues!game_type
            ''')
          .eq('user_id', userId)
          .innerJoin('leagues', 'league_participations.league_id', 'leagues.id')
          .order('season_points DESC');
      
      return response.map((stat) => PlayerLeagueStats.fromJson(stat)).toList();
      
    } catch (e) {
      print('Error getting player league stats: $e');
      return [];
    }
  }
}

/// Résultat d'une opération de ligue
class LeagueResult {
  final bool success;
  final String? leagueId;
  final String message;
  
  LeagueResult({
    required this.success,
    required this.message,
    this.leagueId,
  });
}

/// Modèle de ligue
class League {
  final String id;
  final String name;
  final String? description;
  final String gameType;
  final String leagueType;
  final String division;
  final int seasonNumber;
  final int currentPlayers;
  final int maxPlayers;
  final int minElo;
  final int maxElo;
  final bool isActive;
  final DateTime seasonStart;
  final DateTime seasonEnd;
  final String? promotionDivision;
  final String? relegationDivision;
  final int promotionCount;
  final int relegationCount;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> settings;
  
  League({
    required this.id,
    required this.name,
    required this.gameType,
    required this.leagueType,
    required this.division,
    required this.seasonNumber,
    required this.currentPlayers,
    required this.maxPlayers,
    required this.minElo,
    required this.maxElo,
    required this.isActive,
    required this.seasonStart,
    required this.seasonEnd,
    required this.promotionCount,
    required this.relegationCount,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.settings,
    this.promotionDivision,
    this.relegationDivision,
  });
  
  factory League.fromJson(Map<String, dynamic> json) {
    return League(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      gameType: json['game_type'],
      leagueType: json['league_type'],
      division: json['division'],
      seasonNumber: json['season_number'],
      currentPlayers: json['current_players'],
      maxPlayers: json['max_players'],
      minElo: json['min_elo'],
      maxElo: json['max_elo'],
      isActive: json['is_active'],
      seasonStart: DateTime.parse(json['season_start']),
      seasonEnd: DateTime.parse(json['season_end']),
      promotionDivision: json['promotion_division'],
      relegationDivision: json['relegation_division'],
      promotionCount: json['promotion_count'],
      relegationCount: json['relegation_count'],
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      settings: json['settings'],
    );
  }
  
  bool get isFull => currentPlayers >= maxPlayers;
  bool get isSeasonal => leagueType == 'seasonal';
  bool get isRanked => leagueType == 'ranked';
  bool get isCasual => leagueType == 'casual';
  bool get hasPromotion => promotionDivision != null;
  bool get hasRelegation => relegationDivision != null;
  bool get isBronze => division == 'bronze';
  bool get isSilver => division == 'silver';
  bool get isGold => division == 'gold';
  bool get isPlatinum => division == 'platinum';
  bool get isDiamond => division == 'diamond';
  bool get isMain => division == 'main';
  
  String get statusDisplay {
    return isActive ? 'Active' : 'Inactive';
  }
  
  String get leagueTypeDisplay {
    switch (leagueType) {
      case 'seasonal':
        return 'Seasonal';
      case 'ranked':
        return 'Ranked';
      case 'casual':
        return 'Casual';
      default:
        return leagueType;
    }
  }
  
  String get divisionDisplay {
    switch (division) {
      case 'bronze':
        return 'Bronze';
      case 'silver':
        return 'Silver';
      case 'gold':
        return 'Gold';
      case 'platinum':
        return 'Platinum';
      case 'diamond':
        return 'Diamond';
      case 'main':
        return 'Main';
      default:
        return division;
    }
  }
  
  String get seasonDisplay {
    return 'Season $seasonNumber';
  }
  
  Duration get seasonDuration {
    return seasonEnd.difference(seasonStart);
  }
  
  double get fillPercentage {
    if (maxPlayers == 0) return 0.0;
    return (currentPlayers / maxPlayers) * 100;
  }
}

/// Saison de ligue
class LeagueSeason {
  final int seasonNumber;
  final DateTime seasonStart;
  final DateTime seasonEnd;
  final int currentPlayers;
  final int maxPlayers;
  final bool isActive;
  
  LeagueSeason({
    required this.seasonNumber,
    required this.seasonStart,
    required this.seasonEnd,
    required this.currentPlayers,
    required this.maxPlayers,
    required this.isActive,
  });
  
  factory LeagueSeason.fromJson(Map<String, dynamic> json) {
    return LeagueSeason(
      seasonNumber: json['season_number'],
      seasonStart: DateTime.parse(json['season_start']),
      seasonEnd: DateTime.parse(json['season_end']),
      currentPlayers: json['current_players'],
      maxPlayers: json['max_players'],
      isActive: json['is_active'],
    );
  }
  
  String get statusDisplay {
    return isActive ? 'Active' : 'Ended';
  }
  
  Duration get seasonDuration {
    return seasonEnd.difference(seasonStart);
  }
  
  bool get isCurrentSeason => DateTime.now().isAfter(seasonStart) && DateTime.now().isBefore(seasonEnd);
}

/// Participant à une ligue
class LeagueParticipant {
  final String id;
  final String leagueId;
  final String userId;
  final String division;
  final int rankPosition;
  final int points;
  final int matchesPlayed;
  final int matchesWon;
  final int matchesLost;
  int matchesDrawn;
  final double winRate;
  final int eloRating;
  final int eloRatingStart;
  final int? eloRatingEnd;
  final int eloChange;
  final int currentStreak;
  final int bestStreak;
  final int seasonPoints;
  final DateTime joinedAt;
  final DateTime? lastMatchAt;
  final String status;
  
  LeagueParticipant({
    required this.id,
    required this.leagueId,
    required this.userId,
    required this.division,
    required this.rankPosition,
    required this.points,
    required this.matchesPlayed,
    required this.matchesWon,
    required this.matchesLost,
    this.matchesDrawn = 0,
    required this.winRate,
    required this.eloRating,
    required this.eloRatingStart,
    this.eloRatingEnd,
    this.eloChange,
    this.currentStreak,
    this.bestStreak,
    required this.seasonPoints,
    required this.joinedAt,
    this.lastMatchAt,
    required this.status,
  });
  
  factory LeagueParticipant.fromJson(Map<String, dynamic> json) {
    return LeagueParticipant(
      id: json['id'],
      leagueId: json['league_id'],
      userId: json['user_id'],
      division: json['division'],
      rankPosition: json['rank_position'],
      points: json['points'],
      matchesPlayed: json['matches_played'],
      matchesWon: json['matches_won'],
      matchesLost: json['matches_lost'],
      matchesDrawn: json['matches_drawn'],
      winRate: json['win_rate'],
      eloRating: json['elo_rating'],
      eloRatingStart: json['elo_rating_start'],
      eloRatingEnd: json['elo_rating_end'],
      eloChange: json['elo_change'],
      currentStreak: json['current_streak'],
      bestStreak: json['best_streak'],
      seasonPoints: json['season_points'],
      joinedAt: DateTime.parse(json['joined_at']),
      lastMatchAt: json['last_match_at'] != null ? DateTime.parse(json['last_match_at']) : null,
      status: json['status'],
    );
  }
  
  bool get isActive => status == 'active';
  bool get isPromoted => status == 'promoted';
  bool get isRelegated => status == 'relegated';
  bool get isBanned => status == 'banned';
  bool get isInactive => status == 'inactive';
  
  bool get hasPositiveStreak => currentStreak > 0;
  bool get hasNegativeStreak => currentStreak < 0;
  
  String get statusDisplay {
    switch (status) {
      case 'active':
        return 'Active';
      case 'promoted':
        return 'Promoted';
      case 'relegated':
        return 'Relegated';
      case 'banned':
        return 'Banned';
      case 'inactive':
        return 'Inactive';
      default:
        return status;
    }
  }
  
  int get totalMatches => matchesWon + matchesLost + matchesDrawn;
  
  String get streakDisplay {
    final absStreak = currentStreak.abs();
    if (currentStreak == 0) return 'No streak';
    return '${hasPositiveStreak ? 'W' : 'L'}$absStreak';
  }
  
  String get eloChangeDisplay {
    if (eloChange == 0) return '0';
    return '${eloChange > 0 ? '+' : ''}$eloChange';
  }
}

/// Match de ligue
class LeagueMatch {
  final String id;
  final String leagueId;
  final String participant1Id;
  final String participant2Id;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String status;
  final String? winnerId;
  final int participant1Score;
  final int participant2Score;
  final int participant1EloChange;
  final int participant2EloChange;
  final int participant1Points;
  final int participant2Points;
  final String? notes;
  
  LeagueMatch({
    required this.id,
    required this.leagueId,
    required this.participant1Id,
    required this.participant2Id,
    this.scheduledAt,
    this.startedAt,
    this.completedAt,
    required this.status,
    this.winnerId,
    this.participant1Score = 0,
    this.participant2Score = 0,
    this.participant1EloChange = 0,
    this.participant2EloChange = 0,
    this.participant1Points = 0,
    this.participant2Points = 0,
    this.notes,
  });
  
  factory LeagueMatch.fromJson(Map<String, dynamic> json) {
    return LeagueMatch(
      id: json['id'],
      leagueId: json['league_id'],
      participant1Id: json['participant1_id'],
      participant2Id: json['participant2_id'],
      scheduledAt: json['scheduled_at'] != null ? DateTime.parse(json['scheduled_at']) : null,
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      status: json['status'],
      winnerId: json['winner_id'],
      participant1Score: json['participant1_score'] ?? 0,
      participant2Score: json['participant2_score'] ?? 0,
      participant1EloChange: json['participant1_elo_change'] ?? 0,
      participant2EloChange: json['participant2_elo_change'] ?? 0,
      participant1Points: json['participant1_points'] ?? 0,
      participant2Points: json['participant2_points'] ?? 0,
      notes: json['notes'],
    );
  }
  
  bool get isScheduled => status == 'scheduled';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  
  String get statusDisplay {
    switch (status) {
      case 'scheduled':
        return 'Scheduled';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
  
  bool get isParticipant1Winner => winnerId == participant1Id;
  bool get isParticipant2Winner => winnerId == participant2Id;
  
  String get resultDisplay {
    if (!isCompleted) return 'Pending';
    if (isParticipant1Winner) return 'Player 1 Won';
    if (isParticipant2Winner) return 'Player 2 Won';
    return 'Draw';
  }
  
  String get scoreDisplay {
    return '$participant1Score - $participant2Score';
  }
}

/// Classement de ligue
class LeagueStanding {
  final int rankPosition;
  final String participantId;
  final String participantName;
  final String division;
  final int points;
  final int matchesPlayed;
  final int matchesWon;
  final int matchesLost;
  final int matchesDrawn;
  final double winRate;
  final int eloRating;
  final int eloChange;
  final int currentStreak;
  final int bestStreak;
  final int seasonPoints;
  final String status;
  
  LeagueStanding({
    required this.rankPosition,
    required this.participantId,
    required this.participantName,
    required this.division,
    required this.points,
    required this.matchesPlayed,
    required this.matchesWon,
    required this.matchesLost,
    this.matchesDrawn = 0,
    required this.winRate,
    required this.eloRating,
    required this.eloChange,
    required this.currentStreak,
    required this.bestStreak,
    required this.seasonPoints,
    required this.status,
  });
  
  factory LeagueStanding.fromJson(Map<String, dynamic> json) {
    return LeagueStanding(
      rankPosition: json['rank_position'],
      participantId: json['participant_id'],
      participantName: json['participant_name'],
      division: json['division'],
      points: json['points'],
      matchesPlayed: json['matches_played'],
      matchesWon: json['matches_won'],
      matchesLost: json['matches_lost'],
      matchesDrawn: json['matches_drawn'],
      winRate: json['win_rate'],
      eloRating: json['elo_rating'],
      eloChange: json['elo_change'],
      currentStreak: json['current_streak'],
      bestStreak: json['best_streak'],
      seasonPoints: json['season_points'],
      status: json['status'],
    );
  }
  
  bool get isPromoted => status == 'promoted';
  bool get isRelegated => status == 'relegated';
  bool get isActive => status == 'active';
  
  String get statusDisplay {
    switch (status) {
      case 'active':
        return 'Active';
      case 'promoted':
        return 'Promoted';
      case 'relegated':
        return 'Relegated';
      default:
        return status;
    }
  }
  
  String get streakDisplay {
    final absStreak = currentStreak.abs();
    if (currentStreak == 0) return 'No streak';
    return '${currentStreak > 0 ? 'W' : 'L'}$absStreak';
  }
  
  String get eloChangeDisplay {
    if (eloChange == 0) return '0';
    return '${eloChange > 0 ? '+' : ''}$eloChange';
  }
  
  int get totalMatches => matchesWon + matchesLost + matchesDrawn;
}

/// Récompense de ligue
class LeagueReward {
  final int rankFrom;
  final int rankTo;
  final String rewardType;
  final int rewardValue;
  final String? rewardName;
  final String? rewardDescription;
  final String? rewardIcon;
  final DateTime createdAt;
  
  LeagueReward({
    required this.rankFrom,
    required this.rankTo,
    required this.rewardType,
    required this.rewardValue,
    this.rewardName,
    this.rewardDescription,
    this.rewardIcon,
    required this.createdAt,
  });
  
  factory LeagueReward.fromJson(Map<String, dynamic> json) {
    return LeagueReward(
      rankFrom: json['rank_from'],
      rankTo: json['rank_to'],
      rewardType: json['reward_type'],
      rewardValue: json['reward_value'],
      rewardName: json['reward_name'],
      rewardDescription: json['reward_description'],
      rewardIcon: json['reward_icon'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
  
  String get rewardTypeDisplay {
    switch (rewardType) {
      case 'promotion':
        return 'Promotion';
      case 'relegation':
        return 'Relegation';
      case 'badge':
        return 'Badge';
      case 'points':
        return 'Points';
      case 'item':
        return 'Item Reward';
      default:
        return rewardType;
    }
  }
  
  String get rankDisplay {
    if (rankFrom == rankTo) {
      return 'Rank $rankFrom';
    }
    return 'Ranks $rankFrom-$rankTo';
  }
}

/// Statistiques d'un joueur dans les ligues
class PlayerLeagueStats {
  final String leagueId;
  final String leagueName;
  final String gameType;
  final String division;
  final int rankPosition;
  final int points;
  final int matchesPlayed;
  final int matchesWon;
  final int matchesLost;
  final int matchesDrawn;
  final double winRate;
  final int eloRating;
  final int eloChange;
  final int currentStreak;
  final int bestStreak;
  final int seasonPoints;
  final String status;
  final DateTime joinedAt;
  final DateTime? lastMatchAt;
  
  PlayerLeagueStats({
    required this.leagueId,
    required this.leagueName,
    required this.gameType,
    required this.division,
    required this.rankPosition,
    required this.points,
    required this.matchesPlayed,
    required this.matchesWon,
    required this.matchesLost,
    required this.matchesDrawn,
    required this.winRate,
    required this.eloRating,
    required this.eloChange,
    required this.currentStreak,
    required this.bestStreak,
    required this.seasonPoints,
    required this.status,
    required this.joinedAt,
    this.lastMatchAt,
  });
  
  factory PlayerLeagueStats.fromJson(Map<String, dynamic> json) {
    return PlayerLeagueStats(
      leagueId: json['league_id'],
      leagueName: json['name'],
      gameType: json['game_type'],
      division: json['division'],
      rankPosition: json['rank_position'],
      points: json['points'],
      matchesPlayed: json['matches_played'],
      matchesWon: json['matches_won'],
      matchesLost: json['matches_lost'],
      matchesDrawn: json['matches_drawn'],
      winRate: json['win_rate'],
      eloRating: json['elo_rating'],
      eloChange: json['elo_change'],
      currentStreak: json['current_streak'],
      bestStreak: json['best_streak'],
      seasonPoints: json['season_points'],
      status: json['status'],
      joinedAt: DateTime.parse(json['joined_at']),
      lastMatchAt: json['last_match_at'] != null ? DateTime.parse(json['last_match_at']) : null,
    );
  }
  
  bool get isActive => status == 'active';
  bool get isPromoted => status == 'promoted';
  bool get isRelegated => status == 'relegated';
  bool get isBanned => status == 'banned';
  
  String get statusDisplay {
    switch (status) {
      case 'active':
        return 'Active';
      case 'promoted':
        return 'Promoted';
      case 'relegated':
        return 'Relegated';
      case 'banned':
        return 'Banned';
      default:
        return status;
    }
  }
  
  int get totalMatches => matchesWon + matchesLost + matchesDrawn;
  
  String get streakDisplay {
    final absStreak = currentStreak.abs();
    if (currentStreak == 0) return 'No streak';
    return '${currentStreak > 0 ? 'W' : 'L'}$absStreak';
  }
  
  String get eloChangeDisplay {
    if (eloChange == 0) return '0';
    return '${eloChange > 0 ? '+' : ''}$eloChange';
  }
}
