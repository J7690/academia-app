import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../core/kellenge_game_engine.dart';
import '../utils/game_constants.dart';
import '../services/economic_data_service.dart';
import '../services/adaptive_learning_service.dart';
import '../../themes/bloomberg_theme.dart';
import '../../config/feature_flags.dart';
import 'package:flame/events.dart';

/// Market Master - Jeu d'équilibre du marché avec données réelles et thème Bloomberg
class MarketMasterGame extends KellengeGameEngine {
  // État du jeu
  double _currentPrice = 50.0;
  double _equilibriumPrice = 50.0;
  int _demandQuantity = 100;
  int _supplyQuantity = 100;
  int _marketPhase = 0; // 0: Déséquilibre, 1: Proche, 2: Équilibre
  
  // Données économiques réelles
  List<EconomicIndicator> _realIndicators = [];
  AfricanMarketScenario? _currentScenario;
  AdaptiveScenario? _adaptiveScenario;
  
  // Composants UI Bloomberg
  late TextComponent _priceText;
  late TextComponent _demandText;
  late TextComponent _supplyText;
  late TextComponent _phaseText;
  late TextComponent _scenarioTitle;
  late TextComponent _marketData;
  late RectangleComponent _demandBar;
  late RectangleComponent _supplyBar;
  late PositionComponent _controls;
  late PositionComponent _bloombergHeader;
  late PositionComponent _marketChart;
  
  // Variables pour l'interface Bloomberg
  double _marketTrend = 0.0;
  String _marketStatus = 'NEUTRAL';
  List<Map<String, dynamic>> _chartData = [];
  
  MarketMasterGame({
    required super.onScoreUpdated,
    required super.onGameEvent,
    super.onGameEnded,
  }) : super();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Charger les données économiques réelles si activé
    if (FeatureFlags.economicData) {
      await _loadEconomicData();
    }
    
    // Générer un scénario adaptatif si activé
    if (FeatureFlags.adaptiveAI) {
      await _generateAdaptiveScenario();
    }
    
    // Initialiser le marché
    _initializeMarket();
    
    // Créer l'interface Bloomberg
    if (FeatureFlags.bloombergMode) {
      _createBloombergInterface();
    } else {
      _createGameUI();
    }
    
    // Générer le premier scénario
    _generateMarketScenario();
  }

  void _initializeMarket() {
    _equilibriumPrice = 30.0 + (DateTime.now().millisecond % 40).toDouble();
    _currentPrice = _equilibriumPrice + (DateTime.now().millisecond % 20 - 10).toDouble();
    _updateQuantities();
  }

  void _createGameUI() {
    // Titre du jeu
    final titleText = TextComponent(
      text: 'Maître du Marché',
      position: Vector2(400, 50),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(titleText);
    
    // Panneau d'information
    _priceText = TextComponent(
      text: 'Prix : \$${_currentPrice.toStringAsFixed(2)}',
      position: Vector2(50, 150),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(_priceText);
    
    _demandText = TextComponent(
      text: 'Demande : $_demandQuantity',
      position: Vector2(50, 200),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.cyan,
          fontSize: 20,
        ),
      ),
    );
    add(_demandText);
    
    _supplyText = TextComponent(
      text: 'Offre : $_supplyQuantity',
      position: Vector2(50, 240),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.orange,
          fontSize: 20,
        ),
      ),
    );
    add(_supplyText);
    
    _phaseText = TextComponent(
      text: _getPhaseText(),
      position: Vector2(50, 300),
      textRenderer: TextPaint(
        style: TextStyle(
          color: _getPhaseColor(),
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(_phaseText);
    
    // Barres de visualisation
    _demandBar = RectangleComponent(
      size: Vector2(0, 30),
      position: Vector2(250, 185),
      paint: Paint()..color = Colors.cyan,
    );
    add(_demandBar);
    
    _supplyBar = RectangleComponent(
      size: Vector2(0, 30),
      position: Vector2(250, 225),
      paint: Paint()..color = Colors.orange,
    );
    add(_supplyBar);
    
    // Contrôles
    _createControls();
    
    // Instructions
    final instructions = TextComponent(
      text: 'Ajustez le prix pour équilibrer offre et demande\nUtilisez les boutons',
      position: Vector2(50, 400),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 16,
        ),
      ),
    );
    add(instructions);
  }

  void _createControls() {
    _controls = PositionComponent(position: Vector2(500, 150));
    add(_controls);
    
    // Bouton augmentation prix
    final increaseButton = _GameButtonComponent(
      text: 'Augmenter (+\$5)',
      onPressed: () => _adjustPrice(5.0),
      backgroundColor: Colors.green,
      position: Vector2(0, 0),
    );
    _controls.add(increaseButton);
    
    // Bouton diminution prix
    final decreaseButton = _GameButtonComponent(
      text: 'Diminuer (-\$5)',
      onPressed: () => _adjustPrice(-5.0),
      backgroundColor: Colors.red,
      position: Vector2(0, 80),
    );
    _controls.add(decreaseButton);
    
    // Bouton ajustement fin
    final fineUpButton = _GameButtonComponent(
      text: 'Ajuster (+\$1)',
      onPressed: () => _adjustPrice(1.0),
      backgroundColor: Colors.blue,
      buttonSize: Vector2(150, 40),
      position: Vector2(0, 160),
    );
    _controls.add(fineUpButton);
    
    final fineDownButton = _GameButtonComponent(
      text: 'Ajuster (-\$1)',
      onPressed: () => _adjustPrice(-1.0),
      backgroundColor: Colors.blue,
      buttonSize: Vector2(150, 40),
      position: Vector2(0, 210),
    );
    _controls.add(fineDownButton);
    
    // Bouton de validation
    final submitButton = _GameButtonComponent(
      text: 'Valider',
      onPressed: _submitAnswer,
      backgroundColor: Colors.purple,
      position: Vector2(0, 280),
    );
    _controls.add(submitButton);
  }

  void _generateMarketScenario() {
    // Générer un nouveau scénario de marché
    _equilibriumPrice = 20.0 + (DateTime.now().millisecond % 60).toDouble();
    _currentPrice = _equilibriumPrice + (DateTime.now().millisecond % 30 - 15).toDouble();
    
    _updateQuantities();
    _updateUI();
    
    onGameEvent('Nouveau scénario de marché');
  }

  void _adjustPrice(double delta) {
    if (!isGameActive) return;
    
    _currentPrice = (_currentPrice + delta).clamp(5.0, 100.0);
    _updateQuantities();
    _updateUI();
    
    onGameEvent('Prix ajusté : ${delta > 0 ? '+' : ''}\$${delta.toStringAsFixed(1)}');
  }

  void _updateQuantities() {
    // Calculer la demande et l'offre en fonction du prix
    // Demande : diminue quand le prix augmente
    _demandQuantity = (200 - (_currentPrice * 2)).round().clamp(20, 180);
    
    // Offre : augmente quand le prix augmente  
    _supplyQuantity = (_currentPrice * 2).round().clamp(20, 180);
    
    // Mettre à jour la phase du marché
    final difference = (_demandQuantity - _supplyQuantity).abs();
    if (difference <= 5) {
      _marketPhase = 2; // Équilibre
    } else if (difference <= 15) {
      _marketPhase = 1; // Proche
    } else {
      _marketPhase = 0; // Déséquilibre
    }
  }

  void _updateUI() {
    _priceText.text = 'Prix : \$${_currentPrice.toStringAsFixed(2)}';
    _demandText.text = 'Demande : $_demandQuantity';
    _supplyText.text = 'Offre : $_supplyQuantity';
    _phaseText.text = _getPhaseText();
    
    // Mettre à jour les barres
    _demandBar.size.x = _demandQuantity * 2;
    _supplyBar.size.x = _supplyQuantity * 2;
  }

  String _getPhaseText() {
    switch (_marketPhase) {
      case 2:
        return 'ÉQUILIBRE DU MARCHÉ !';
      case 1:
        return 'Proche de l\'équilibre';
      default:
        return 'Déséquilibre du marché';
    }
  }

  Color _getPhaseColor() {
    switch (_marketPhase) {
      case 2:
        return Colors.green;
      case 1:
        return Colors.yellow;
      default:
        return Colors.red;
    }
  }

  void _submitAnswer() {
    if (!isGameActive) return;
    
    // Calculer le score basé sur la proximité de l'équilibre
    final quantityDifference = (_demandQuantity - _supplyQuantity).abs();
    
    int points = 0;
    if (quantityDifference <= 5) {
      points = GameConstants.correctAnswerPoints * 3; // Perfect equilibrium
    } else if (quantityDifference <= 15) {
      points = GameConstants.correctAnswerPoints * 2; // Close to equilibrium
    } else if (quantityDifference <= 30) {
      points = GameConstants.correctAnswerPoints; // Some understanding
    } else {
      points = GameConstants.wrongAnswerPenalty; // Poor understanding
    }
    
    if (points > 0) {
      addScore(points);
      onGameEvent('Correct ! Marché équilibré. +$points points');
      
      // Générer un nouveau scénario après un succès
      Future.delayed(const Duration(seconds: 2), () {
        if (isGameActive) {
          _generateMarketScenario();
        }
      });
    } else {
      subtractScore(GameConstants.wrongAnswerPenalty);
      onGameEvent('Marché non équilibré. Réessayez !');
    }
  }

  // Getters pour l'état du jeu
  double get currentPrice => _currentPrice;
  double get equilibriumPrice => _equilibriumPrice;
  int get demandQuantity => _demandQuantity;
  int get supplyQuantity => _supplyQuantity;
  int get marketPhase => _marketPhase;
  
  bool get isMarketBalanced => _marketPhase == 2;
  bool get isCloseToBalance => _marketPhase >= 1;
}

/// Composant de bouton gaming réutilisable
class _GameButtonComponent extends PositionComponent with TapCallbacks {
  final String text;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Vector2? buttonSize;
  
  late RectangleComponent _background;
  late TextComponent _textComponent;
  
  _GameButtonComponent({
    required this.text,
    required this.onPressed,
    this.backgroundColor = Colors.blue,
    this.buttonSize,
    Vector2? position,
  }) : super(position: position);
  
  @override
  Future<void> onLoad() async {
    size = buttonSize ?? Vector2(200, 60);
    
    // Créer le fond du bouton
    _background = RectangleComponent(
      size: size,
      paint: Paint()..color = backgroundColor,
    );
    add(_background);
    
    // Créer le texte
    _textComponent = TextComponent(
      text: text,
      position: Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(_textComponent);
  }
  
  @override
  void onTapDown(TapDownEvent event) {
    onPressed();
  }
}

// Nouvelles méthodes pour Market Master avec données réelles et Bloomberg
extension MarketMasterBloombergExtension on MarketMasterGame {
  
  /// Charger les données économiques réelles
  Future<void> _loadEconomicData() async {
    try {
      _realIndicators = await EconomicDataService.getAfricanMarketData(
        country: 'Nigeria',
        indicators: ['GDP', 'NY.GDP.DEFL.ZS', 'FP.CPI.TOTL.ZG'],
      );
      
      // Mettre à jour les données du marché avec les vraies données
      _updateMarketWithRealData();
    } catch (e) {
      print('Erreur lors du chargement des données économiques: $e');
    }
  }
  
  /// Générer un scénario adaptatif
  Future<void> _generateAdaptiveScenario() async {
    try {
      _adaptiveScenario = await AdaptiveLearningService.generateAdaptiveScenario(
        userId: 'demo_user',
        gameType: 'market_master',
        realData: _realIndicators,
      );
      
      if (_adaptiveScenario != null) {
        _currentScenario = _adaptiveScenario!.scenario;
      }
    } catch (e) {
      print('Erreur lors de la génération du scénario adaptatif: $e');
    }
  }
  
  /// Créer l'interface Bloomberg
  void _createBloombergInterface() {
    final screenSize = size;
    
    // Header Bloomberg
    _bloombergHeader = PositionComponent(
      position: Vector2(0, 0),
      size: Vector2(screenSize.x, 80),
    );
    add(_bloombergHeader);
    
    // Ajouter le titre du scénario
    _scenarioTitle = TextComponent(
      text: _currentScenario?.title ?? 'Market Master',
      position: Vector2(20, 20),
      textRenderer: TextPaint(
        style: TextStyle(
          color: BloombergTheme.accent,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'RobotoMono',
        ),
      ),
    );
    _bloombergHeader.add(_scenarioTitle);
    
    // Ajouter les données de marché
    _marketData = TextComponent(
      text: _getMarketDataText(),
      position: Vector2(20, 50),
      textRenderer: TextPaint(
        style: TextStyle(
          color: BloombergTheme.textSecondary,
          fontSize: 14,
          fontFamily: 'RobotoMono',
        ),
      ),
    );
    _bloombergHeader.add(_marketData);
    
    // Créer le graphique de marché
    _createMarketChart();
    
    // Créer les contrôles Bloomberg
    _createBloombergControls();
  }
  
  /// Créer le graphique de marché
  void _createMarketChart() {
    final screenSize = size;
    _marketChart = PositionComponent(
      position: Vector2(0, 100),
      size: Vector2(screenSize.x, 200),
    );
    add(_marketChart);
    
    // Initialiser les données du graphique
    _initializeChartData();
  }
  
  /// Initialiser les données du graphique
  void _initializeChartData() {
    _chartData.clear();
    
    // Ajouter des points de données simulés basés sur le marché actuel
    for (int i = 0; i < 20; i++) {
      _chartData.add({
        'price': _currentPrice + (i - 10) * 2,
        'demand': _demandQuantity.toDouble(),
        'supply': _supplyQuantity.toDouble(),
        'timestamp': DateTime.now().subtract(Duration(seconds: (20 - i) * 5)),
      });
    }
  }
  
  /// Créer les contrôles Bloomberg
  void _createBloombergControls() {
    final screenSize = size;
    _controls = PositionComponent(
      position: Vector2(0, screenSize.y - 120),
      size: Vector2(screenSize.x, 120),
    );
    add(_controls);
    
    // Boutons de contrôle Bloomberg
    final buttonY = 30;
    final buttonSpacing = screenSize.x / 4;
    
    // Bouton Augmenter Prix
    final increaseButton = _GameButtonComponent(
      text: 'PRICE ↑',
      onPressed: () => _adjustPrice(5.0),
      backgroundColor: BloombergTheme.marketUp,
      buttonSize: Vector2(120.0, 40.0),
      position: Vector2(buttonSpacing - 60, buttonY.toDouble()),
    );
    _controls.add(increaseButton);
    
    // Bouton Diminuer Prix
    final decreaseButton = _GameButtonComponent(
      text: 'PRICE ↓',
      onPressed: () => _adjustPrice(-5.0),
      backgroundColor: BloombergTheme.marketDown,
      buttonSize: Vector2(120.0, 40.0),
      position: Vector2(buttonSpacing * 2 - 60, buttonY.toDouble()),
    );
    _controls.add(decreaseButton);
    
    // Bouton Reset
    final resetButton = _GameButtonComponent(
      text: 'RESET',
      onPressed: () => _resetMarket(),
      backgroundColor: BloombergTheme.surface,
      buttonSize: Vector2(120.0, 40.0),
      position: Vector2(buttonSpacing * 3 - 60, buttonY.toDouble()),
    );
    _controls.add(resetButton);
  }
  
  /// Mettre à jour le marché avec les données réelles
  void _updateMarketWithRealData() {
    if (_realIndicators.isEmpty) return;
    
    // Utiliser les données réelles pour influencer le marché
    final gdpIndicator = _realIndicators.firstWhere(
      (ind) => ind.indicator == 'GDP',
      orElse: () => EconomicIndicator(
        country: 'Nigeria',
        indicator: 'GDP',
        value: 506.6,
        unit: 'billion USD',
        date: DateTime.now(),
        source: 'World Bank',
        category: 'macro',
      ),
    );
    
    final inflationIndicator = _realIndicators.firstWhere(
      (ind) => ind.indicator == 'Inflation',
      orElse: () => EconomicIndicator(
        country: 'Nigeria',
        indicator: 'Inflation',
        value: 31.7,
        unit: 'percent',
        date: DateTime.now(),
        source: 'IMF',
        category: 'macro',
      ),
    );
    
    // Ajuster l'équilibre du prix basé sur les données réelles
    final gdpFactor = gdpIndicator.value / 500; // Normalisé
    final inflationFactor = inflationIndicator.value / 10; // Normalisé
    
    _equilibriumPrice = 50.0 * gdpFactor * (1 + inflationFactor / 100);
    _currentPrice = _equilibriumPrice;
    
    // Mettre à jour la tendance
    _marketTrend = inflationIndicator.value > 20 ? 1.0 : -1.0;
    _marketStatus = inflationIndicator.value > 20 ? 'INFLATIONARY' : 'STABLE';
    
    _updateQuantities();
  }
  
  /// Obtenir le texte des données de marché
  String _getMarketDataText() {
    if (_currentScenario == null) {
      return 'MARKET: Equilibrium Price: \$${_equilibriumPrice.toStringAsFixed(2)} | Status: $_marketStatus';
    }
    
    return 'MARKET: ${_currentScenario!.country} - ${_currentScenario!.product} | '
           'Price: \$${_currentPrice.toStringAsFixed(2)} | Status: $_marketStatus';
  }
  
  /// Ajuster le prix
  void _adjustPrice(double delta) {
    _currentPrice = (_currentPrice + delta).clamp(10.0, 100.0);
    _updateQuantities();
    _updateMarketStatus();
    _updateChartData();
    
    // Notifier le changement
    onGameEvent('price_adjusted');
  }
  
  /// Réinitialiser le marché
  void _resetMarket() {
    _currentPrice = _equilibriumPrice;
    _updateQuantities();
    _updateMarketStatus();
    _updateChartData();
    
    onGameEvent('market_reset');
  }
  
  /// Mettre à jour le statut du marché
  void _updateMarketStatus() {
    final priceDiff = (_currentPrice - _equilibriumPrice).abs();
    final priceDiffPercent = priceDiff / _equilibriumPrice;
    
    if (priceDiffPercent < 0.05) {
      _marketStatus = 'EQUILIBRIUM';
      _marketPhase = 2;
    } else if (priceDiffPercent < 0.15) {
      _marketStatus = 'NEAR EQUILIBRIUM';
      _marketPhase = 1;
    } else {
      _marketStatus = 'DISEQUILIBRIUM';
      _marketPhase = 0;
    }
  }
  
  /// Mettre à jour les données du graphique
  void _updateChartData() {
    if (_chartData.length > 50) {
      _chartData.removeAt(0);
    }
    
    _chartData.add({
      'price': _currentPrice,
      'demand': _demandQuantity.toDouble(),
      'supply': _supplyQuantity.toDouble(),
      'timestamp': DateTime.now(),
    });
  }
  
  /// Mettre à jour les quantités
  void _updateQuantities() {
    // Calculer la demande et l'offre basées sur le prix
    _demandQuantity = (200 - _currentPrice * 2).round().clamp(10, 200);
    _supplyQuantity = (_currentPrice * 3 - 50).round().clamp(10, 200);
  }
}
