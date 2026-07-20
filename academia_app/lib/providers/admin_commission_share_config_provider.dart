import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommissionShareConfig {
  final String id;
  final String scenarioName;
  final double ownerPercentage;
  final double promoterPercentage;
  final double platformPercentage;
  final double creatorPercentage;
  final int promoterWindowDays;
  final String? description;
  final bool isActive;
  final DateTime? effectiveFrom;
  final DateTime? effectiveUntil;
  final DateTime createdAt;
  final DateTime updatedAt;

  CommissionShareConfig({
    required this.id,
    required this.scenarioName,
    required this.ownerPercentage,
    required this.promoterPercentage,
    required this.platformPercentage,
    this.creatorPercentage = 0,
    this.promoterWindowDays = 30,
    this.description,
    required this.isActive,
    this.effectiveFrom,
    this.effectiveUntil,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CommissionShareConfig.fromJson(Map<String, dynamic> json) {
    return CommissionShareConfig(
      id: json['id'] as String,
      scenarioName: json['scenario_name'] as String,
      ownerPercentage: (json['owner_percentage'] as num).toDouble(),
      promoterPercentage: (json['promoter_percentage'] as num).toDouble(),
      platformPercentage: (json['platform_percentage'] as num).toDouble(),
      creatorPercentage: (json['creator_percentage'] as num?)?.toDouble() ?? 0,
      promoterWindowDays: (json['promoter_window_days'] as num?)?.toInt() ?? 30,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool,
      effectiveFrom: json['effective_from'] != null 
          ? DateTime.parse(json['effective_from'] as String) 
          : null,
      effectiveUntil: json['effective_until'] != null 
          ? DateTime.parse(json['effective_until'] as String) 
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scenario_name': scenarioName,
      'owner_percentage': ownerPercentage,
      'promoter_percentage': promoterPercentage,
      'platform_percentage': platformPercentage,
      'creator_percentage': creatorPercentage,
      'promoter_window_days': promoterWindowDays,
      'description': description,
      'is_active': isActive,
      'effective_from': effectiveFrom?.toIso8601String(),
      'effective_until': effectiveUntil?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class AdminCommissionShareConfigProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isUpdating = false;
  String? _error;
  List<CommissionShareConfig> _configs = [];
  CommissionShareConfig? _activeConfig;

  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  String? get error => _error;
  List<CommissionShareConfig> get configs => List.unmodifiable(_configs);
  CommissionShareConfig? get activeConfig => _activeConfig;

  Future<void> loadConfigs() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final resp = await _client.rpc('app_admin_list_commission_share_configs');
      if (resp is! Map<String, dynamic> || resp['success'] != true) {
        _error = resp?['error']?.toString() ?? 'Erreur lors du chargement.';
        return;
      }
      final data = resp['configs'];
      if (data is List) {
        _configs = data
            .whereType<Map>()
            .map((e) => CommissionShareConfig.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _activeConfig = _configs.firstWhere(
          (c) => c.isActive,
          orElse: () => CommissionShareConfig(
            id: '',
            scenarioName: 'default',
            ownerPercentage: 0,
            promoterPercentage: 0,
            platformPercentage: 0,
            isActive: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      } else {
        _configs = [];
        _activeConfig = null;
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> upsertConfig({
    required String scenarioName,
    required double ownerPercentage,
    required double promoterPercentage,
    required double platformPercentage,
    double creatorPercentage = 0,
    int promoterWindowDays = 30,
    String? description,
    bool isActive = true,
    DateTime? effectiveFrom,
    DateTime? effectiveUntil,
  }) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();
    try {
      final resp = await _client.rpc('app_admin_upsert_commission_share_config', params: {
        'p_scenario_name': scenarioName,
        'p_owner_percentage': ownerPercentage,
        'p_promoter_percentage': promoterPercentage,
        'p_platform_percentage': platformPercentage,
        'p_creator_percentage': creatorPercentage,
        'p_promoter_window_days': promoterWindowDays,
        'p_description': description,
        'p_is_active': isActive,
        'p_effective_from': effectiveFrom?.toIso8601String(),
        'p_effective_until': effectiveUntil?.toIso8601String(),
      });
      if (resp is! Map<String, dynamic> || resp['success'] != true) {
        _error = resp?['error']?.toString() ?? 'Erreur lors de la mise à jour.';
        return false;
      }
      await loadConfigs();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<bool> setActiveScenario(String scenarioName) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();
    try {
      final resp = await _client.rpc('app_admin_set_active_commission_scenario', params: {
        'p_scenario_name': scenarioName,
      });
      if (resp is! Map<String, dynamic> || resp['success'] != true) {
        _error = resp?['error']?.toString() ?? 'Erreur lors de l\'activation.';
        return false;
      }
      await loadConfigs();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }
}
