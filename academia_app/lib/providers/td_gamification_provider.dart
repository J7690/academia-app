import 'package:flutter/foundation.dart';

import '../services/td_service.dart';

/// Central provider for the gamified TD module.
/// Manages home dashboard, catalog, enrollments, resources, stats, leaderboard.
class TdGamificationProvider extends ChangeNotifier {
  final TdService _service = TdService();

  // ─── Loading states ────────────────────────────────────────────
  bool _homeLoading = false;
  bool _catalogLoading = false;
  bool _enrollmentsLoading = false;
  bool _resourcesLoading = false;
  bool _statsLoading = false;
  bool _leaderboardLoading = false;
  bool _fieldsLoading = false;

  bool get homeLoading => _homeLoading;
  bool get catalogLoading => _catalogLoading;
  bool get enrollmentsLoading => _enrollmentsLoading;
  bool get resourcesLoading => _resourcesLoading;
  bool get statsLoading => _statsLoading;
  bool get leaderboardLoading => _leaderboardLoading;
  bool get fieldsLoading => _fieldsLoading;

  String? _error;
  String? get error => _error;

  // ─── Home dashboard data ───────────────────────────────────────
  Map<String, dynamic> _homeData = {};
  Map<String, dynamic> get homeData => _homeData;

  int get currentStreak => (_homeData['streak'] as Map?)?['current'] as int? ?? 0;
  int get longestStreak => (_homeData['streak'] as Map?)?['longest'] as int? ?? 0;
  int get totalActiveDays => (_homeData['streak'] as Map?)?['total_active_days'] as int? ?? 0;
  int get dailyGoalTarget => (_homeData['daily_goal'] as Map?)?['target_xp'] as int? ?? 50;
  int get dailyGoalEarned => (_homeData['daily_goal'] as Map?)?['earned_xp'] as int? ?? 0;
  bool get dailyGoalCompleted => (_homeData['daily_goal'] as Map?)?['completed'] as bool? ?? false;
  int get activeEnrollments => _homeData['active_enrollments'] as int? ?? 0;
  int get totalXp => _homeData['total_xp'] as int? ?? 0;
  int get level => _homeData['level'] as int? ?? 1;
  Map<String, dynamic>? get nextSession => _homeData['next_session'] as Map<String, dynamic>?;

  // ─── Catalog ───────────────────────────────────────────────────
  List<Map<String, dynamic>> _catalogPrograms = [];
  List<Map<String, dynamic>> get catalogPrograms => _catalogPrograms;

  String? _catalogFieldId;
  String? _catalogLevel;
  String? _catalogModality;
  String? _catalogSearch;
  String _catalogSort = 'popular';

  String? get catalogFieldId => _catalogFieldId;
  String? get catalogSearch => _catalogSearch;
  String get catalogSort => _catalogSort;

  // ─── Fields/Disciplines ────────────────────────────────────────
  List<Map<String, dynamic>> _fields = [];
  List<Map<String, dynamic>> get fields => _fields;

  // ─── Enrollments ───────────────────────────────────────────────
  List<Map<String, dynamic>> _enrollments = [];
  List<Map<String, dynamic>> get enrollments => _enrollments;

  // ─── Resources ─────────────────────────────────────────────────
  List<Map<String, dynamic>> _resources = [];
  List<Map<String, dynamic>> get resources => _resources;

  // ─── Stats ─────────────────────────────────────────────────────
  Map<String, dynamic> _statsData = {};
  Map<String, dynamic> get statsData => _statsData;

  Map<String, dynamic> get progressSummary => _statsData['progress'] as Map<String, dynamic>? ?? {};
  List<Map<String, dynamic>> get badges =>
      (_statsData['badges'] as List?)?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
  List<Map<String, dynamic>> get xpHistory =>
      (_statsData['xp_history'] as List?)?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
  int get totalStudyTimeSeconds => _statsData['total_study_time_seconds'] as int? ?? 0;

  // ─── Leaderboard ───────────────────────────────────────────────
  Map<String, dynamic> _leaderboardData = {};
  Map<String, dynamic> get leaderboardData => _leaderboardData;

  List<Map<String, dynamic>> get leaderboardEntries =>
      (_leaderboardData['entries'] as List?)?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
  int? get myRank => _leaderboardData['my_rank'] as int?;

  // ═══════════════════════════════════════════════════════════════
  // LOAD METHODS
  // ═══════════════════════════════════════════════════════════════

  /// Load home dashboard data
  Future<void> loadHome() async {
    _homeLoading = true;
    _error = null;
    notifyListeners();
    try {
      _homeData = await _service.tdStudentGetHome();
    } catch (e) {
      _error = e.toString();
      debugPrint('[TdGamification] loadHome error: $e');
    }
    _homeLoading = false;
    notifyListeners();
  }

  /// Load fields/disciplines
  Future<void> loadFields() async {
    _fieldsLoading = true;
    notifyListeners();
    try {
      final data = await _service.tdStudentListFields();
      final list = data['fields'];
      _fields = (list is List)
          ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
    } catch (e) {
      debugPrint('[TdGamification] loadFields error: $e');
    }
    _fieldsLoading = false;
    notifyListeners();
  }

  /// Load catalog with current filters
  Future<void> loadCatalog() async {
    _catalogLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _service.tdStudentListCatalog(
        fieldId: _catalogFieldId,
        level: _catalogLevel,
        modality: _catalogModality,
        search: _catalogSearch,
        sort: _catalogSort,
      );
      final list = data['programs'];
      _catalogPrograms = (list is List)
          ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
    } catch (e) {
      _error = e.toString();
      debugPrint('[TdGamification] loadCatalog error: $e');
    }
    _catalogLoading = false;
    notifyListeners();
  }

  /// Update catalog filters and reload
  void setCatalogFilters({
    String? fieldId,
    String? level,
    String? modality,
    String? search,
    String? sort,
  }) {
    _catalogFieldId = fieldId;
    _catalogLevel = level;
    _catalogModality = modality;
    _catalogSearch = search;
    if (sort != null) _catalogSort = sort;
    loadCatalog();
  }

  void setCatalogSearch(String? search) {
    _catalogSearch = search;
    loadCatalog();
  }

  /// Load my enrollments with progress
  Future<void> loadEnrollments() async {
    _enrollmentsLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _service.tdStudentGetMyEnrollments();
      final list = data['enrollments'];
      _enrollments = (list is List)
          ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
    } catch (e) {
      _error = e.toString();
      debugPrint('[TdGamification] loadEnrollments error: $e');
    }
    _enrollmentsLoading = false;
    notifyListeners();
  }

  /// Load resources for a program
  Future<void> loadResources({String? programId, String? enrollmentId}) async {
    _resourcesLoading = true;
    notifyListeners();
    try {
      final data = await _service.tdStudentListResources(
        programId: programId,
        enrollmentId: enrollmentId,
      );
      final list = data['resources'];
      _resources = (list is List)
          ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
    } catch (e) {
      debugPrint('[TdGamification] loadResources error: $e');
    }
    _resourcesLoading = false;
    notifyListeners();
  }

  /// Load stats & badges
  Future<void> loadStats() async {
    _statsLoading = true;
    notifyListeners();
    try {
      _statsData = await _service.tdStudentGetStats();
    } catch (e) {
      debugPrint('[TdGamification] loadStats error: $e');
    }
    _statsLoading = false;
    notifyListeners();
  }

  /// Load leaderboard
  Future<void> loadLeaderboard({String? programId}) async {
    _leaderboardLoading = true;
    notifyListeners();
    try {
      _leaderboardData = await _service.tdStudentGetLeaderboard(programId: programId);
    } catch (e) {
      debugPrint('[TdGamification] loadLeaderboard error: $e');
    }
    _leaderboardLoading = false;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════════

  /// Earn XP (called after completing actions)
  Future<Map<String, dynamic>> earnXp({
    required int amount,
    required String reason,
    String? refType,
    String? refId,
  }) async {
    try {
      final result = await _service.tdStudentEarnXp(
        amount: amount,
        reason: reason,
        refType: refType,
        refId: refId,
      );
      // Refresh home data to update streak/XP display
      loadHome();
      return result;
    } catch (e) {
      debugPrint('[TdGamification] earnXp error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Update resource progress
  Future<void> updateResourceProgress({
    required String resourceId,
    String? status,
    int? progressPct,
    String? lastPosition,
    int timeSpentSeconds = 0,
  }) async {
    try {
      await _service.tdStudentUpdateResourceProgress(
        resourceId: resourceId,
        status: status,
        progressPct: progressPct,
        lastPosition: lastPosition,
        timeSpentSeconds: timeSpentSeconds,
      );
    } catch (e) {
      debugPrint('[TdGamification] updateResourceProgress error: $e');
    }
  }

  /// Load all data for initial screen
  Future<void> loadAll() async {
    await Future.wait([
      loadHome(),
      loadFields(),
      loadCatalog(),
      loadEnrollments(),
    ]);
  }
}
