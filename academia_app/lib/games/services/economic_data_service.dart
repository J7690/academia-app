import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service pour les données économiques réelles
class EconomicDataService {
  static const String _baseUrl = 'https://api.worldbank.org/v2';
  static const String _cacheKey = 'economic_data_cache';
  
  static final Map<String, List<EconomicIndicator>> _cache = {};
  
  /// Obtenir les données économiques pour un pays africain
  static Future<List<EconomicIndicator>> getAfricanMarketData({
    String? country,
    List<String>? indicators,
  }) async {
    final cacheKey = '${country ?? "all"}_${indicators?.join(',') ?? "all"}';
    
    // Vérifier le cache
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }
    
    // Charger depuis la base locale
    final localData = await _getLocalData(country, indicators);
    if (localData.isNotEmpty) {
      _cache[cacheKey] = localData;
      return localData;
    }
    
    // Charger depuis l'API World Bank
    final apiData = await _fetchFromWorldBank(country, indicators);
    if (apiData.isNotEmpty) {
      _cache[cacheKey] = apiData;
      await _saveLocalData(apiData);
      return apiData;
    }
    
    // Retourner les données par défaut
    return _getDefaultData(country);
  }
  
  /// Obtenir les scénarios de marché africains
  static Future<List<AfricanMarketScenario>> getAfricanMarketScenarios() async {
    try {
      final result = await Supabase.instance.client
          .from('african_market_scenarios')
          .select()
          .eq('is_active', true)
          .order('country');
      
      final scenarios = result.map((json) => AfricanMarketScenario.fromJson(json)).toList();
      
      // Mettre à jour les statistiques d'utilisation
      await _updateScenarioUsage(scenarios);
      
      return scenarios;
    } catch (e) {
      print('Erreur lors du chargement des scénarios: $e');
      return _getDefaultScenarios();
    }
  }
  
  /// Obtenir les indicateurs économiques pour un jeu spécifique
  static Future<Map<String, dynamic>> getGameDataForGame(String gameType) async {
    switch (gameType) {
      case 'market_master':
        return await _getMarketMasterData();
      case 'consumer_choice':
        return await _getConsumerChoiceData();
      case 'firm_tycoon':
        return await _getFirmTycoonData();
      case 'market_structures':
        return await _getMarketStructuresData();
      default:
        return {};
    }
  }
  
  /// Rafraîchir les données depuis l'API
  static Future<void> refreshData() async {
    _cache.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }
  
  /// Charger les données locales depuis Supabase
  static Future<List<EconomicIndicator>> _getLocalData(
    String? country,
    List<String>? indicators,
  ) async {
    try {
      var query = Supabase.instance.client.from('economic_indicators').select();
      
      if (country != null) {
        query = query.eq('country', country);
      }
      
      if (indicators != null && indicators.isNotEmpty) {
        query = query.filter('indicator', 'in', indicators);
      }
      
      final result = await query.order('date', ascending: false).limit(100);
      
      return result.map((json) => EconomicIndicator.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors du chargement des données locales: $e');
      return [];
    }
  }
  
  /// Charger depuis l'API World Bank
  static Future<List<EconomicIndicator>> _fetchFromWorldBank(
    String? country,
    List<String>? indicators,
  ) async {
    try {
      final countries = country != null ? [country] : _getAfricanCountries();
      final defaultIndicators = indicators ?? ['GDP', 'NY.GDP.DEFL.ZS', 'FP.CPI.TOTL.ZG', 'SL.UEM.TOTL.ZS'];
      
      final List<EconomicIndicator> allData = [];
      
      for (final country in countries) {
        for (final indicator in defaultIndicators) {
          try {
            final url = '$_baseUrl/country/$country/indicator/$indicator?format=json&per_page=50';
            final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 10));
            
            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              if (data is List && data.length > 1) {
                final indicators = data[1] as List;
                for (final item in indicators.take(5)) { // Limiter aux 5 dernières années
                  allData.add(EconomicIndicator.fromWorldBank(item, country));
                }
              }
            }
          } catch (e) {
            print('Erreur API pour $country/$indicator: $e');
            continue;
          }
        }
      }
      
      return allData;
    } catch (e) {
      print('Erreur lors du chargement depuis World Bank: $e');
      return [];
    }
  }
  
  /// Sauvegarder les données localement
  static Future<void> _saveLocalData(List<EconomicIndicator> data) async {
    try {
      for (final indicator in data) {
        // Schema `app` explicite (cf. adaptive_learning_service) : sans lui,
        // l'appel vise `public` et l'echec passe inapercu.
        await Supabase.instance.client
            .schema('app')
            .from('economic_indicators')
            .upsert(indicator.toJson(), onConflict: 'country,indicator,date');
      }
    } catch (e) {
      print('Erreur lors de la sauvegarde locale: $e');
    }
  }
  
  /// Obtenir les pays africains
  static List<String> _getAfricanCountries() {
    return [
      'NGA', // Nigeria
      'EGY', // Egypt
      'ZAF', // South Africa
      'KEN', // Kenya
      'ETH', // Ethiopia
      'GHA', // Ghana
      'CIV', // Ivory Coast
      'SEN', // Senegal
      'TZA', // Tanzania
      'UGA', // Uganda
      'DZA', // Algeria
      'MAR', // Morocco
      'TUN', // Tunisia
      'CMR', // Cameroon
      'ZWE', // Zimbabwe
    ];
  }
  
  /// Données par défaut
  static List<EconomicIndicator> _getDefaultData(String? country) {
    final defaultCountry = country ?? 'Nigeria';
    
    return [
      EconomicIndicator(
        country: defaultCountry,
        indicator: 'GDP',
        value: defaultCountry == 'Nigeria' ? 506.6 : 100.0,
        unit: 'billion USD',
        date: DateTime(2023, 12, 31),
        source: 'World Bank',
        category: 'macro',
      ),
      EconomicIndicator(
        country: defaultCountry,
        indicator: 'Inflation',
        value: defaultCountry == 'Nigeria' ? 31.7 : 8.5,
        unit: 'percent',
        date: DateTime(2023, 12, 31),
        source: 'IMF',
        category: 'macro',
      ),
      EconomicIndicator(
        country: defaultCountry,
        indicator: 'Unemployment',
        value: defaultCountry == 'Nigeria' ? 5.8 : 7.2,
        unit: 'percent',
        date: DateTime(2023, 12, 31),
        source: 'World Bank',
        category: 'macro',
      ),
    ];
  }
  
  /// Scénarios par défaut
  static List<AfricanMarketScenario> _getDefaultScenarios() {
    return [
      AfricanMarketScenario(
        id: 'default_1',
        country: 'Nigeria',
        product: 'Crude Oil',
        title: 'Pétrole Brut - Nigeria',
        description: 'Plus grand producteur de pétrole d''Afrique',
        realData: {
          'production_2023': 1.4,
          'price_per_barrel': 85.50,
          'opec_quota': 1.5,
          'global_demand': 'stable',
        },
        events: [
          MarketEvent(type: 'geopolitical', description: 'Décision OPEC sur la production'),
          MarketEvent(type: 'price', description: 'Fluctuation des prix énergétiques'),
        ],
        difficultyLevel: 2,
        gameType: 'market_master',
        isActive: true,
        usageCount: 0,
        successRate: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      AfricanMarketScenario(
        id: 'default_2',
        country: 'Ethiopia',
        product: 'Coffee',
        title: 'Café - Éthiopie',
        description: 'Origine du café Arabica',
        realData: {
          'production_2023': 764000,
          'export_value': 1.2,
          'price_per_kg': 3.15,
          'seasonal_factor': 1.2,
        },
        events: [
          MarketEvent(type: 'weather', description: 'Saison des pluies'),
          MarketEvent(type: 'price', description: 'Demande internationale'),
        ],
        difficultyLevel: 1,
        gameType: 'market_master',
        isActive: true,
        usageCount: 0,
        successRate: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }
  
  /// Mettre à jour les statistiques d'utilisation
  static Future<void> _updateScenarioUsage(List<AfricanMarketScenario> scenarios) async {
    try {
      for (final scenario in scenarios) {
        await Supabase.instance.client
            .from('african_market_scenarios')
            .update({'usage_count': scenario.usageCount + 1})
            .eq('id', scenario.id);
      }
    } catch (e) {
      print('Erreur lors de la mise à jour des statistiques: $e');
    }
  }
  
  /// Données pour Market Master
  static Future<Map<String, dynamic>> _getMarketMasterData() async {
    final indicators = await getAfricanMarketData(
      country: 'Nigeria',
      indicators: ['GDP', 'NY.GDP.DEFL.ZS', 'FP.CPI.TOTL.ZG'],
    );
    
    final scenarios = await getAfricanMarketScenarios()
        .then((s) => s.where((sc) => sc.gameType == 'market_master').toList());
    
    return {
      'indicators': indicators,
      'scenarios': scenarios,
      'market_trends': _calculateMarketTrends(indicators),
    };
  }
  
  /// Données pour Consumer Choice
  static Future<Map<String, dynamic>> _getConsumerChoiceData() async {
    final indicators = await getAfricanMarketData(
      indicators: ['FP.CPI.TOTL.ZG', 'SI.POV.NAHC', 'NY.GNP.PCAP.CD'],
    );
    
    return {
      'inflation_rate': _getLatestIndicator(indicators, 'FP.CPI.TOTL.ZG')?.value ?? 8.5,
      'poverty_rate': _getLatestIndicator(indicators, 'SI.POV.NAHC')?.value ?? 25.0,
      'income_per_capita': _getLatestIndicator(indicators, 'NY.GNP.PCAP.CD')?.value ?? 2000.0,
      'consumer_confidence': 0.65, // Valeur simulée
    };
  }
  
  /// Données pour Firm Tycoon
  static Future<Map<String, dynamic>> _getFirmTycoonData() async {
    final indicators = await getAfricanMarketData(
      indicators: ['IC.BUS.EASE.XQ', 'SL.IND.EMPL.ZS', 'NV.IND.TOTL.ZS'],
    );
    
    return {
      'business_ease': _getLatestIndicator(indicators, 'IC.BUS.EASE.XQ')?.value ?? 131.0,
      'industrial_employment': _getLatestIndicator(indicators, 'SL.IND.EMPL.ZS')?.value ?? 6.5,
      'industrial_output': _getLatestIndicator(indicators, 'NV.IND.TOTL.ZS')?.value ?? 25.0,
      'market_competition': 0.75, // Valeur simulée
    };
  }
  
  /// Données pour Market Structures
  static Future<Map<String, dynamic>> _getMarketStructuresData() async {
    final scenarios = await getAfricanMarketScenarios();
    
    return {
      'market_types': ['monopoly', 'oligopoly', 'perfect_competition', 'monopolistic_competition'],
      'concentration_ratios': {
        'telecom': 0.85, // Oligopole
        'banking': 0.72, // Oligopole
        'retail': 0.35, // Concurrence monopolistique
        'agriculture': 0.15, // Concurrence quasi-parfaite
      },
      'regulatory_environment': 'moderate',
      'scenarios': scenarios.where((s) => s.gameType == 'market_structures').toList(),
    };
  }
  
  /// Obtenir le dernier indicateur
  static EconomicIndicator? _getLatestIndicator(
    List<EconomicIndicator> indicators,
    String indicatorCode,
  ) {
    final filtered = indicators
        .where((ind) => ind.indicator == indicatorCode)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    
    return filtered.isNotEmpty ? filtered.first : null;
  }
  
  /// Calculer les tendances du marché
  static Map<String, dynamic> _calculateMarketTrends(List<EconomicIndicator> indicators) {
    final gdpIndicators = indicators
        .where((ind) => ind.indicator == 'GDP')
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    
    final inflationIndicators = indicators
        .where((ind) => ind.indicator == 'Inflation')
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    
    return {
      'gdp_trend': gdpIndicators.length >= 2 
          ? (gdpIndicators.last.value - gdpIndicators.first.value) / gdpIndicators.first.value
          : 0.05,
      'inflation_trend': inflationIndicators.length >= 2
          ? inflationIndicators.last.value - inflationIndicators.first.value
          : 0.5,
      'market_sentiment': 'neutral', // Calculé plus tard
    };
  }
}

/// Modèle d'indicateur économique
class EconomicIndicator {
  final String country;
  final String indicator;
  final double value;
  final String unit;
  final DateTime date;
  final String source;
  final String category;
  
  EconomicIndicator({
    required this.country,
    required this.indicator,
    required this.value,
    required this.unit,
    required this.date,
    required this.source,
    required this.category,
  });
  
  factory EconomicIndicator.fromJson(Map<String, dynamic> json) {
    return EconomicIndicator(
      country: json['country'],
      indicator: json['indicator'],
      value: (json['value'] as num).toDouble(),
      unit: json['unit'],
      date: DateTime.parse(json['date']),
      source: json['source'],
      category: json['category'],
    );
  }
  
  factory EconomicIndicator.fromWorldBank(Map<String, dynamic> json, String country) {
    return EconomicIndicator(
      country: country,
      indicator: json['indicator']['value'] as String,
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      unit: _parseUnit(json['indicator']['value'] as String),
      date: DateTime.parse(json['date']),
      source: 'World Bank',
      category: _getCategory(json['indicator']['value'] as String),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'country': country,
      'indicator': indicator,
      'value': value,
      'unit': unit,
      'date': date.toIso8601String(),
      'source': source,
      'category': category,
    };
  }
  
  static String _parseUnit(String indicator) {
    if (indicator.contains('GDP')) return 'billion USD';
    if (indicator.contains('CPI')) return 'index';
    if (indicator.contains('UEM')) return 'percent';
    return 'unit';
  }
  
  static String _getCategory(String indicator) {
    if (indicator.contains('GDP') || indicator.contains('GNP')) return 'macro';
    if (indicator.contains('CPI') || indicator.contains('inflation')) return 'macro';
    if (indicator.contains('UEM') || indicator.contains('employment')) return 'labor';
    if (indicator.contains('BUS') || indicator.contains('business')) return 'business';
    return 'other';
  }
}

/// Scénario de marché africain
class AfricanMarketScenario {
  final String id;
  final String country;
  final String product;
  final String title;
  final String description;
  final Map<String, dynamic> realData;
  final List<MarketEvent> events;
  final int difficultyLevel;
  final String gameType;
  final bool isActive;
  final int usageCount;
  final double successRate;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  AfricanMarketScenario({
    required this.id,
    required this.country,
    required this.product,
    required this.title,
    required this.description,
    required this.realData,
    required this.events,
    required this.difficultyLevel,
    required this.gameType,
    required this.isActive,
    required this.usageCount,
    required this.successRate,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory AfricanMarketScenario.fromJson(Map<String, dynamic> json) {
    return AfricanMarketScenario(
      id: json['id'],
      country: json['country'],
      product: json['product'],
      title: json['title'],
      description: json['description'],
      realData: json['real_data'] ?? {},
      events: (json['events'] as List<dynamic>?)
          ?.map((e) => MarketEvent.fromJson(e))
          .toList() ?? [],
      difficultyLevel: json['difficulty_level'] ?? 1,
      gameType: json['game_type'],
      isActive: json['is_active'] ?? true,
      usageCount: json['usage_count'] ?? 0,
      successRate: (json['success_rate'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

/// Événement de marché
class MarketEvent {
  final String type;
  final String description;
  final double probability;
  
  MarketEvent({
    required this.type,
    required this.description,
    this.probability = 0.5,
  });
  
  factory MarketEvent.fromJson(Map<String, dynamic> json) {
    return MarketEvent(
      type: json['type'],
      description: json['description'],
      probability: (json['probability'] as num?)?.toDouble() ?? 0.5,
    );
  }
}
