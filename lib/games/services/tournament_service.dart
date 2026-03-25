import 'package:supabase_flutter/supabase_flutter.dart';

/// Service de gestion des tournois pour les jeux Kellenge
/// Gère la création, participation, et suivi des tournois
class TournamentService {
  static TournamentService? _instance;
  static TournamentService get instance => _instance ??= TournamentService._();
  
  TournamentService._();
  
  final SupabaseClient _supabase = Supabase.instance.client;
  
  /// Créer un nouveau tournoi
  Future<TournamentResult> createTournament({
    required String name,
    String? description,
    required String gameType,
    String tournamentType = 'elimination',
    String format = 'single_elimination',
    int maxParticipants = 16,
    int minParticipants = 4,
    DateTime? registrationStart,
    DateTime? registrationEnd,
    DateTime? startDate,
    DateTime? endDate,
    int prizePool = 0,
    int entryFee = 0,
    bool isFeatured = false,
    bool isPrivate = false,
    int eloMin = 0,
    int eloMax = 3000,
    bool autoStart = true,
    Map<String, dynamic> settings = const {},
  }) async {
    try {
      final response = await _supabase.rpc('tournament_create', params: {
        'p_name': name,
        'p_description': description,
        'p_game_type': gameType,
        'p_tournament_type': tournamentType,
        'p_format': format,
        'p_max_participants': maxParticipants,
        'p_min_participants': minParticipants,
        'p_registration_start': registrationStart?.toIso8601String(),
        'p_registration_end': registrationEnd?.toIso8601String(),
        'p_start_date': startDate?.toIso8601String(),
        'p_end_date': endDate?.toIso8601String(),
        'p_prize_pool': prizePool,
        'p_entry_fee': entryFee,
        'p_is_featured': isFeatured,
        'p_is_private': isPrivate,
        'p_elo_min': eloMin,
        'p_elo_max': eloMax,
        'p_auto_start': autoStart,
        'p_settings': settings,
      });
      
      if (response.isEmpty) {
        return TournamentResult(
          success: false,
          message: 'Failed to create tournament',
        );
      }
      
      final result = response.first;
      final success = result['success'] as bool;
      
      if (!success) {
        return TournamentResult(
          success: false,
          message: result['message'] as String,
        );
      }
      
      return TournamentResult(
        success: true,
        tournamentId: result['tournament_id'] as String,
        message: result['message'] as String,
      );
      
    } catch (e) {
      return TournamentResult(
        success: false,
        message: 'Error creating tournament: $e',
      );
    }
  }
  
  /// S'inscrire à un tournoi
  Future<TournamentResult> registerForTournament(String tournamentId) async {
    try {
      final response = await _supabase.rpc('tournament_register', params: {
        'p_tournament_id': tournamentId,
      });
      
      if (response.isEmpty) {
        return TournamentResult(
          success: false,
          message: 'Failed to register for tournament',
        );
      }
      
      final result = response.first;
      final success = result['success'] as bool;
      
      return TournamentResult(
        success: success,
        message: result['message'] as String,
      );
      
    } catch (e) {
      return TournamentResult(
        success: false,
        message: 'Error registering for tournament: $e',
      );
    }
  }
  
  /// Lister les tournois disponibles
  Future<List<Tournament>> listAvailableTournaments({
    String? gameType,
    int limit = 20,
  }) async {
    try {
      final response = await _supabase.rpc('tournament_list_available', params: {
        'p_game_type': gameType,
        'p_limit': limit,
      });
      
      if (response.isEmpty) {
        return [];
      }
      
      return response.map((tournament) => Tournament.fromJson(tournament)).toList();
      
    } catch (e) {
      print('Error listing tournaments: $e');
      return [];
    }
  }
  
  /// Obtenir les détails d'un tournoi
  Future<Tournament?> getTournamentDetails(String tournamentId) async {
    try {
      final response = await _supabase.rpc('tournament_get_details', params: {
        'p_tournament_id': tournamentId,
      });
      
      if (response.isEmpty) {
        return null;
      }
      
      final result = response.first;
      return Tournament.fromJson(result);
      
    } catch (e) {
      print('Error getting tournament details: $e');
      return null;
    }
  }
  
  /// Obtenir les classements d'un tournoi
  Future<List<TournamentStanding>> getTournamentStandings(String tournamentId) async {
    try {
      final response = await _supabase.rpc('tournament_get_standings', params: {
        'p_tournament_id': tournamentId,
      });
      
      if (response.isEmpty) {
        return [];
      }
      
      return response.map((standing) => TournamentStanding.fromJson(standing)).toList();
      
    } catch (e) {
      print('Error getting tournament standings: $e');
      return [];
    }
  }
}

/// Résultat d'une opération de tournoi
class TournamentResult {
  final bool success;
  final String? tournamentId;
  final String message;
  
  TournamentResult({
    required this.success,
    required this.message,
    this.tournamentId,
  });
}

/// Modèle de tournoi
class Tournament {
  final String id;
  final String name;
  final String? description;
  final String gameType;
  final String tournamentType;
  final String format;
  final int maxParticipants;
  final int currentParticipants;
  final String status;
  final DateTime registrationStart;
  final DateTime registrationEnd;
  final DateTime startDate;
  final DateTime endDate;
  final int prizePool;
  final int entryFee;
  final bool isFeatured;
  final bool isPrivate;
  final int eloMin;
  final int eloMax;
  final String createdBy;
  final DateTime createdAt;
  final Map<String, dynamic> settings;
  final int participantCount;
  final int currentRound;
  final int totalMatches;
  final int completedMatches;
  
  Tournament({
    required this.id,
    required this.name,
    required this.gameType,
    required this.tournamentType,
    required this.format,
    required this.maxParticipants,
    required this.currentParticipants,
    required this.status,
    required this.registrationStart,
    required this.registrationEnd,
    required this.startDate,
    required this.endDate,
    required this.prizePool,
    required this.entryFee,
    required this.isFeatured,
    required this.isPrivate,
    required this.eloMin,
    required this.eloMax,
    required this.createdBy,
    required this.createdAt,
    required this.settings,
    required this.participantCount,
    required this.currentRound,
    required this.totalMatches,
    required this.completedMatches,
  });
  
  factory Tournament.fromJson(Map<String, dynamic> json) {
    return Tournament(
      id: json['tournament_id'],
      name: json['name'],
      description: json['description'],
      gameType: json['game_type'],
      tournamentType: json['tournament_type'],
      format: json['format'],
      maxParticipants: json['max_participants'],
      currentParticipants: json['current_participants'],
      status: json['status'],
      registrationStart: DateTime.parse(json['registration_start']),
      registrationEnd: DateTime.parse(json['registration_end']),
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      prizePool: json['prize_pool'],
      entryFee: json['entry_fee'],
      isFeatured: json['is_featured'],
      isPrivate: json['is_private'],
      eloMin: json['elo_min'],
      eloMax: json['elo_max'],
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      settings: json['settings'],
      participantCount: json['participant_count'],
      currentRound: json['current_round'],
      totalMatches: json['total_matches'],
      completedMatches: json['completed_matches'],
    );
  }
  
  bool get isRegistrationOpen => status == 'registration' && registrationEnd.isAfter(DateTime.now());
  bool get isFull => currentParticipants >= maxParticipants;
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get canStart => isRegistrationOpen && currentParticipants >= 4;
  
  String get statusDisplay {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'registration':
        return 'Registration Open';
      case 'active':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
  
  String get formatDisplay {
    switch (format) {
      case 'single_elimination':
        return 'Single Elimination';
      case 'double_elimination':
        return 'Double Elimination';
      case 'best_of_3':
        return 'Best of 3';
      case 'best_of_5':
        return 'Best of 5';
      default:
        return format;
    }
  }
  
  String get tournamentTypeDisplay {
    switch (tournamentType) {
      case 'elimination':
        return 'Elimination';
      case 'round_robin':
        return 'Round Robin';
      case 'swiss':
        return 'Swiss System';
      case 'group_stage':
        return 'Group Stage';
      default:
        return tournamentType;
    }
  }
}

/// Classementement d'un tournoi
class TournamentStanding {
  final int rankPosition;
  final String participantId;
  final String participantName;
  final String status;
  final int currentRound;
  final int matchesPlayed;
  final int matchesWon;
  final int matchesLost;
  int matchesDrawn;
  final int points;
  final int eloRatingBefore;
  final int? eloRatingAfter;
  final int prizeWon;
  final String eliminatedBy;
  final DateTime? eliminatedAt;
  
  TournamentStanding({
    required this.rankPosition,
    required this.participantId,
    required this.participantName,
    required this.status,
    required this.currentRound,
    required this.matchesPlayed,
    required this.matchesWon,
    required this.matchesLost,
    this.matchesDrawn = 0,
    required this.points,
    required this.eloRatingBefore,
    this.eloRatingAfter,
    this.prizeWon = 0,
    this.eliminatedBy,
    this.eliminatedAt,
  });
  
  factory TournamentStanding.fromJson(Map<String, dynamic> json) {
    return TournamentStanding(
      rankPosition: json['rank_position'],
      participantId: json['participant_id'],
      participantName: json['participant_name'],
      status: json['status'],
      currentRound: json['current_round'],
      matchesPlayed: json['matches_played'],
      matchesWon: json['matches_won'],
      matchesLost: json['matches_lost'],
      matchesDrawn: json['matches_drawn'],
      points: json['points'],
      eloRatingBefore: json['elo_rating_before'],
      eloRatingAfter: json['elo_rating_after'],
      prizeWon: json['prize_won'],
      eliminatedBy: json['eliminated_by'],
      eliminatedAt: json['eliminated_at'] != null ? DateTime.parse(json['eliminated_at']) : null,
    );
  }
  
  bool get isEliminated => status == 'eliminated';
  bool get isWinner => status == 'winner';
  bool get isActive => status == 'active';
  bool get isWithdrawn => status == 'withdrawn';
  
  double get winRate {
    if (matchesPlayed == 0) return 0.0;
    return (matchesWon / matchesPlayed) * 100;
  }
  
  String get statusDisplay {
    switch (status) {
      case 'active':
        return 'Active';
      case 'eliminated':
        return 'Eliminated';
      case 'winner':
        return 'Winner';
      case 'withdrawn':
        return 'Withdrawn';
      default:
        return status;
    }
  }
}
