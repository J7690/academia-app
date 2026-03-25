import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TournamentProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Tournament> _availableTournaments = [];
  List<Tournament> _myTournaments = [];
  List<TournamentMatch> _myMatches = [];
  List<League> _availableLeagues = [];
  List<League> _myLeagues = [];
  
  List<Tournament> get availableTournaments => _availableTournaments;
  List<Tournament> get myTournaments => _myTournaments;
  List<TournamentMatch> get myMatches => _myMatches;
  List<League> get availableLeagues => _availableLeagues;
  List<League> get myLeagues => _myLeagues;
  
  Future<void> loadAvailableTournaments() async {
    try {
      final response = await _supabase
          .rpc('tournament_list_available');
      
      if (response != null) {
        _availableTournaments = (response as List)
            .map((json) => Tournament.fromJson(json))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      print('Error loading tournaments: $e');
    }
  }
  
  Future<bool> registerTournament(String tournamentId) async {
    try {
      final response = await _supabase
          .rpc('tournament_register', params: {'p_tournament_id': tournamentId});
      
      if (response['success'] == true) {
        await loadAvailableTournaments();
        await loadMyTournaments();
        return true;
      }
    } catch (e) {
      print('Error registering tournament: $e');
    }
    return false;
  }
  
  Future<void> loadMyTournaments() async {
    try {
      final response = await _supabase
          .rpc('tournament_get_details', params: {'p_user_id': _supabase.auth.currentUser?.id});
      
      if (response != null) {
        _myTournaments = (response as List)
            .map((json) => Tournament.fromJson(json))
            .toList();
        
        await loadMyMatches();
        notifyListeners();
      }
    } catch (e) {
      print('Error loading my tournaments: $e');
    }
  }
  
  Future<void> loadMyMatches() async {
    try {
      final response = await _supabase
          .rpc('tournament_get_standings', params: {'p_tournament_id': _myTournaments.firstOrNull?.id});
      
      if (response != null) {
        _myMatches = (response as List)
            .map((json) => TournamentMatch.fromJson(json))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      print('Error loading my matches: $e');
    }
  }
  
  Future<bool> createTournament({
    required String name,
    required String description,
    required String gameType,
    required int maxParticipants,
    String tournamentType = 'elimination',
    String format = 'single_elimination',
  }) async {
    try {
      final response = await _supabase
          .rpc('tournament_create', params: {
            'p_name': name,
            'p_description': description,
            'p_game_type': gameType,
            'p_tournament_type': tournamentType,
            'p_format': format,
            'p_max_participants': maxParticipants,
          });
      
      if (response['success'] == true) {
        await loadMyTournaments();
        return true;
      }
    } catch (e) {
      print('Error creating tournament: $e');
    }
    return false;
  }
  
  Future<bool> startTournament(String tournamentId) async {
    try {
      final response = await _supabase
          .rpc('tournament_start', params: {'p_tournament_id': tournamentId});
      
      if (response['success'] == true) {
        await loadMyTournaments();
        return true;
      }
    } catch (e) {
      print('Error starting tournament: $e');
    }
    return false;
  }
  
  Future<bool> reportMatchResult({
    required String matchId,
    required String winnerId,
    required int player1Score,
    required int player2Score,
  }) async {
    try {
      final response = await _supabase
          .rpc('tournament_report_match_result', params: {
            'p_match_id': matchId,
            'p_winner_id': winnerId,
            'p_player1_score': player1Score,
            'p_player2_score': player2Score,
          });
      
      if (response['success'] == true) {
        await loadMyTournaments();
        await loadMyMatches();
        return true;
      }
    } catch (e) {
      print('Error reporting match result: $e');
    }
    return false;
  }
  
  // Leagues methods
  Future<void> loadAvailableLeagues() async {
    try {
      final response = await _supabase
          .rpc('league_list_available');
      
      if (response != null) {
        _availableLeagues = (response as List)
            .map((json) => League.fromJson(json))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      print('Error loading leagues: $e');
    }
  }
  
  Future<bool> joinLeague(String leagueId) async {
    try {
      final response = await _supabase
          .rpc('league_join', params: {'p_league_id': leagueId});
      
      if (response['success'] == true) {
        await loadAvailableLeagues();
        await loadMyLeagues();
        return true;
      }
    } catch (e) {
      print('Error joining league: $e');
    }
    return false;
  }
  
  Future<void> loadMyLeagues() async {
    try {
      final response = await _supabase
          .rpc('league_get_standings', params: {'p_league_id': _availableLeagues.firstOrNull?.id});
      
      if (response != null) {
        _myLeagues = (response as List)
            .map((json) => League.fromJson(json))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      print('Error loading my leagues: $e');
    }
  }
  
  Future<bool> createLeague({
    required String name,
    required String description,
    required String gameType,
    String division = 'main',
    int seasonNumber = 1,
  }) async {
    try {
      final response = await _supabase
          .rpc('league_create', params: {
            'p_name': name,
            'p_description': description,
            'p_game_type': gameType,
            'p_division': division,
            'p_season_number': seasonNumber,
          });
      
      if (response['success'] == true) {
        await loadMyLeagues();
        return true;
      }
    } catch (e) {
      print('Error creating league: $e');
    }
    return false;
  }
  
  Future<bool> reportLeagueMatchResult({
    required String matchId,
    required String winnerId,
    required int player1Score,
    required int player2Score,
  }) async {
    try {
      final response = await _supabase
          .rpc('league_report_match_result', params: {
            'p_match_id': matchId,
            'p_winner_id': winnerId,
            'p_player1_score': player1Score,
            'p_player2_score': player2Score,
          });
      
      if (response['success'] == true) {
        await loadMyLeagues();
        return true;
      }
    } catch (e) {
      print('Error reporting league match result: $e');
    }
    return false;
  }
}

// Models
class Tournament {
  final String id;
  final String name;
  final String description;
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
  final DateTime updatedAt;
  
  Tournament({
    required this.id,
    required this.name,
    required this.description,
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
    required this.updatedAt,
  });
  
  factory Tournament.fromJson(Map<String, dynamic> json) {
    return Tournament(
      id: json['id'],
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
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class TournamentMatch {
  final String id;
  final String tournamentId;
  final int round;
  final int matchNumber;
  final String? player1Id;
  final String? player2Id;
  final String? winnerId;
  final String status;
  final DateTime scheduledAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int player1Score;
  final int player2Score;
  final String bracketPosition;
  
  TournamentMatch({
    required this.id,
    required this.tournamentId,
    required this.round,
    required this.matchNumber,
    this.player1Id,
    this.player2Id,
    this.winnerId,
    required this.status,
    required this.scheduledAt,
    this.startedAt,
    this.completedAt,
    required this.player1Score,
    required this.player2Score,
    required this.bracketPosition,
  });
  
  factory TournamentMatch.fromJson(Map<String, dynamic> json) {
    return TournamentMatch(
      id: json['id'],
      tournamentId: json['tournament_id'],
      round: json['round'],
      matchNumber: json['match_number'],
      player1Id: json['player1_id'],
      player2Id: json['player2_id'],
      winnerId: json['winner_id'],
      status: json['status'],
      scheduledAt: DateTime.parse(json['scheduled_at']),
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      player1Score: json['player1_score'],
      player2Score: json['player2_score'],
      bracketPosition: json['bracket_position'],
    );
  }
}

class League {
  final String id;
  final String name;
  final String description;
  final String gameType;
  final String division;
  final int seasonNumber;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  League({
    required this.id,
    required this.name,
    required this.description,
    required this.gameType,
    required this.division,
    required this.seasonNumber,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory League.fromJson(Map<String, dynamic> json) {
    return League(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      gameType: json['game_type'],
      division: json['division'],
      seasonNumber: json['season_number'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      status: json['status'],
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
