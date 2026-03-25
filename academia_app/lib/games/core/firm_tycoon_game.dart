import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../core/kellenge_game_engine.dart';
import '../utils/game_constants.dart';

/// Firm Tycoon - Jeu de gestion d'entreprise
/// Les joueurs gèrent une entreprise pour maximiser les profits
class FirmTycoonGame extends KellengeGameEngine {
  // État du jeu
  double _capital = 1000.0;
  double _revenue = 0.0;
  double _costs = 0.0;
  double _profit = 0.0;
  int _marketShare = 10;
  int _round = 1;
  int _maxRounds = 6;
  
  // Décisions de l'entreprise
  double _productionLevel = 50.0; // 0-100
  double _priceLevel = 50.0; // 0-100
  double _marketingBudget = 50.0; // 0-100
  double _qualityInvestment = 50.0; // 0-100
  
  // Composants UI
  late TextComponent _capitalText;
  late TextComponent _revenueText;
  late TextComponent _costsText;
  late TextComponent _profitText;
  late TextComponent _marketShareText;
  late TextComponent _roundText;
  late PositionComponent _controls;
  late PositionComponent _sliders;
  
  FirmTycoonGame({
    required super.onScoreUpdated,
    required super.onGameEvent,
    super.onGameEnded,
  }) : super();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Créer l'interface du jeu
    _createGameUI();
    
    // Générer le premier scénario
    _generateBusinessScenario();
  }

  void _createGameUI() {
    // Titre du jeu
    final titleText = TextComponent(
      text: 'Magnat d\'Entreprise',
      position: Vector2(400, 30),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(titleText);
    
    // Panneau d'information financière
    _capitalText = TextComponent(
      text: 'Capital : \$${_capital.toStringAsFixed(2)}',
      position: Vector2(50, 80),
      textRenderer: TextPaint(
        style: TextStyle(
          color: _capital > 0 ? Colors.green : Colors.red,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(_capitalText);
    
    _revenueText = TextComponent(
      text: 'Revenus : \$${_revenue.toStringAsFixed(2)}',
      position: Vector2(50, 110),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.blue,
          fontSize: 18,
        ),
      ),
    );
    add(_revenueText);
    
    _costsText = TextComponent(
      text: 'Coûts : \$${_costs.toStringAsFixed(2)}',
      position: Vector2(50, 140),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.red,
          fontSize: 18,
        ),
      ),
    );
    add(_costsText);
    
    _profitText = TextComponent(
      text: 'Profit : \$${_profit.toStringAsFixed(2)}',
      position: Vector2(50, 170),
      textRenderer: TextPaint(
        style: TextStyle(
          color: _profit > 0 ? Colors.green : Colors.red,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(_profitText);
    
    _marketShareText = TextComponent(
      text: 'Part de marché : $_marketShare%',
      position: Vector2(50, 210),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.orange,
          fontSize: 18,
        ),
      ),
    );
    add(_marketShareText);
    
    _roundText = TextComponent(
      text: 'Trimestre : $_round/$_maxRounds',
      position: Vector2(50, 250),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
    );
    add(_roundText);
    
    // Contrôles de décision
    _createDecisionControls();
    
    // Boutons d'action
    _createActionButtons();
    
    // Instructions
    final instructions = TextComponent(
      text: 'Gérez votre entreprise pour maximiser le profit\nAjustez production, prix, marketing et qualité',
      position: Vector2(50, 450),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
        ),
      ),
    );
    add(instructions);
  }

  void _createDecisionControls() {
    _sliders = PositionComponent(position: Vector2(400, 100));
    add(_sliders);
    
    // Production Level
    _createSlider(
      'Production',
      _productionLevel,
      100,
      Vector2(0, 0),
      (value) {
        _productionLevel = value;
        _updateCalculations();
      },
    );
    
    // Price Level
    _createSlider(
      'Niveau de prix',
      _priceLevel,
      100,
      Vector2(0, 80),
      (value) {
        _priceLevel = value;
        _updateCalculations();
      },
    );
    
    // Marketing Budget
    _createSlider(
      'Marketing',
      _marketingBudget,
      100,
      Vector2(0, 160),
      (value) {
        _marketingBudget = value;
        _updateCalculations();
      },
    );
    
    // Quality Investment
    _createSlider(
      'Investissement qualité',
      _qualityInvestment,
      100,
      Vector2(0, 240),
      (value) {
        _qualityInvestment = value;
        _updateCalculations();
      },
    );
  }

  void _createSlider(String label, double value, double maxValue, Vector2 position, Function(double) onChanged) {
    final labelComponent = TextComponent(
      text: '$label: ${value.round()}%',
      position: position,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
      ),
    );
    _sliders.add(labelComponent);
    
    // Barre de slider visuelle
    final sliderBackground = RectangleComponent(
      size: Vector2(200, 8),
      position: Vector2(position.x, position.y + 25),
      paint: Paint()..color = Colors.grey,
    );
    _sliders.add(sliderBackground);
    
    final sliderFill = RectangleComponent(
      size: Vector2((value / maxValue) * 200, 8),
      position: Vector2(position.x, position.y + 25),
      paint: Paint()..color = Colors.blue,
    );
    _sliders.add(sliderFill);
    
    // Boutons de contrôle
    final decreaseButton = _SmallButtonComponent(
      text: '-',
      onPressed: () {
        final newValue = (value - 5).clamp(0.0, maxValue);
        onChanged(newValue);
        _updateSliderDisplay(labelComponent, sliderFill, newValue, maxValue);
      },
      backgroundColor: Colors.red,
      position: Vector2(position.x + 210, position.y + 15),
    );
    _sliders.add(decreaseButton);
    
    final increaseButton = _SmallButtonComponent(
      text: '+',
      onPressed: () {
        final newValue = (value + 5).clamp(0.0, maxValue);
        onChanged(newValue);
        _updateSliderDisplay(labelComponent, sliderFill, newValue, maxValue);
      },
      backgroundColor: Colors.green,
      position: Vector2(position.x + 240, position.y + 15),
    );
    _sliders.add(increaseButton);
  }

  void _updateSliderDisplay(TextComponent label, RectangleComponent fill, double value, double maxValue) {
    label.text = label.text.split(':')[0] + ': ${value.round()}%';
    fill.size.x = (value / maxValue) * 200;
  }

  void _createActionButtons() {
    _controls = PositionComponent(position: Vector2(400, 380));
    add(_controls);
    
    // Bouton de simulation
    final simulateButton = _GameButtonComponent(
      text: 'Simuler le trimestre',
      onPressed: _simulateQuarter,
      backgroundColor: Colors.blue,
      position: Vector2(0, 0),
    );
    _controls.add(simulateButton);
    
    // Bouton d'optimisation
    final optimizeButton = _GameButtonComponent(
      text: 'Auto-optimiser (-3 pts)',
      onPressed: _autoOptimize,
      backgroundColor: Colors.purple,
      position: Vector2(0, 60),
    );
    _controls.add(optimizeButton);
  }

  void _generateBusinessScenario() {
    // Réinitialiser les décisions pour le nouveau round
    _productionLevel = 50.0;
    _priceLevel = 50.0;
    _marketingBudget = 50.0;
    _qualityInvestment = 50.0;
    
    _updateCalculations();
    _updateUI();
    
    onGameEvent('Nouveau trimestre : Tour $_round');
  }

  void _updateCalculations() {
    // Calculer les revenus
    final baseDemand = 1000;
    final priceEffect = (100 - _priceLevel) / 100;
    final marketingEffect = _marketingBudget / 100;
    final qualityEffect = _qualityInvestment / 100;
    
    final demand = baseDemand * priceEffect * (1 + marketingEffect * 0.5) * (1 + qualityEffect * 0.3);
    final actualProduction = demand * (_productionLevel / 100);
    
    _revenue = actualProduction * (_priceLevel * 0.5 + 5); // Prix entre $5 et $55
    
    // Calculer les coûts
    final productionCosts = actualProduction * 2.0; // $2 par unité
    final marketingCosts = _marketingBudget * 10.0; // $10 par %
    final qualityCosts = _qualityInvestment * 15.0; // $15 par %
    final fixedCosts = 100.0; // Coûts fixes
    
    _costs = productionCosts + marketingCosts + qualityCosts + fixedCosts;
    
    // Calculer le profit
    _profit = _revenue - _costs;
    
    // Calculer la part de marché
    _marketShare = (10 + marketingEffect * 20 + qualityEffect * 15 - (_priceLevel - 50) * 0.2).round().clamp(0, 100);
  }

  void _simulateQuarter() {
    if (!isGameActive) return;
    
    // Appliquer les résultats du trimestre
    _capital += _profit;
    
    // Calculer le score
    int points = 0;
    if (_profit > 0) {
      final profitScore = (_profit / 50).round().clamp(1, 10);
      points = GameConstants.correctAnswerPoints * profitScore;
      
      addScore(points);
      onGameEvent('Excellent ! Profit de \$${_profit.toStringAsFixed(2)}. +$points points');
    } else {
      points = GameConstants.wrongAnswerPenalty;
      subtractScore(points);
      onGameEvent('Perte de \$${_profit.abs().toStringAsFixed(2)}. Ajustez votre stratégie !');
    }
    
    // Vérifier la faillite
    if (_capital <= 0) {
      onGameEvent('Faillite ! Fin de partie.');
      onGameEnded?.call();
      return;
    }
    
    // Passer au round suivant
    _nextRound();
  }

  void _autoOptimize() {
    if (!isGameActive) return;
    
    // Pénalité pour l'optimisation automatique
    subtractScore(3);
    
    // Stratégie simple : équilibrer production et prix
    _productionLevel = 70.0;
    _priceLevel = 60.0;
    _marketingBudget = 40.0;
    _qualityInvestment = 50.0;
    
    _updateCalculations();
    _updateUI();
    
    onGameEvent('Stratégie auto-optimisée (-3 points)');
  }

  void _nextRound() {
    _round++;
    
    if (_round > _maxRounds) {
      // Fin du jeu - calculer le score final
      _calculateFinalScore();
      onGameEnded?.call();
    } else {
      // Nouveau round
      _generateBusinessScenario();
    }
  }

  void _calculateFinalScore() {
    // Bonus basé sur le capital final
    if (_capital > 2000) {
      addScore(50); // Excellent performance
    } else if (_capital > 1500) {
      addScore(30); // Good performance
    } else if (_capital > 1000) {
      addScore(15); // Average performance
    }
    
    onGameEvent('Partie terminée ! Capital final : \$${_capital.toStringAsFixed(2)}');
  }

  void _updateUI() {
    _capitalText.text = 'Capital : \$${_capital.toStringAsFixed(2)}';
    _capitalText.textRenderer = TextPaint(
      style: TextStyle(
        color: _capital > 0 ? Colors.green : Colors.red,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
    
    _revenueText.text = 'Revenus : \$${_revenue.toStringAsFixed(2)}';
    _costsText.text = 'Coûts : \$${_costs.toStringAsFixed(2)}';
    
    _profitText.text = 'Profit : \$${_profit.toStringAsFixed(2)}';
    _profitText.textRenderer = TextPaint(
      style: TextStyle(
        color: _profit > 0 ? Colors.green : Colors.red,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
    
    _marketShareText.text = 'Part de marché : $_marketShare%';
    _roundText.text = 'Trimestre : $_round/$_maxRounds';
    
    // Mettre à jour les sliders
    _updateAllSliders();
  }

  void _updateAllSliders() {
    // Chaque slider crée 5 enfants : label, bg, fill, decreaseBtn, increaseBtn
    final sliders = _sliders.children.toList();
    const stride = 5;
    
    // Production (indices 0-4)
    if (sliders.length >= stride) {
      _updateSliderDisplay(
        sliders[0] as TextComponent,
        sliders[2] as RectangleComponent,
        _productionLevel,
        100,
      );
    }
    
    // Niveau de prix (indices 5-9)
    if (sliders.length >= stride * 2) {
      _updateSliderDisplay(
        sliders[stride] as TextComponent,
        sliders[stride + 2] as RectangleComponent,
        _priceLevel,
        100,
      );
    }
    
    // Marketing (indices 10-14)
    if (sliders.length >= stride * 3) {
      _updateSliderDisplay(
        sliders[stride * 2] as TextComponent,
        sliders[stride * 2 + 2] as RectangleComponent,
        _marketingBudget,
        100,
      );
    }
    
    // Qualité (indices 15-19)
    if (sliders.length >= stride * 4) {
      _updateSliderDisplay(
        sliders[stride * 3] as TextComponent,
        sliders[stride * 3 + 2] as RectangleComponent,
        _qualityInvestment,
        100,
      );
    }
  }

  // Getters pour l'état du jeu
  double get capital => _capital;
  double get revenue => _revenue;
  double get costs => _costs;
  double get profit => _profit;
  int get marketShare => _marketShare;
  int get round => _round;
  bool get isProfitable => _profit > 0;
  bool get isSolvent => _capital > 0;
}

/// Petit composant de bouton
class _SmallButtonComponent extends PositionComponent with TapCallbacks {
  final String text;
  final VoidCallback onPressed;
  final Color backgroundColor;
  
  late RectangleComponent _background;
  late TextComponent _textComponent;
  
  _SmallButtonComponent({
    required this.text,
    required this.onPressed,
    required this.backgroundColor,
    Vector2? position,
  }) : super(position: position);
  
  @override
  Future<void> onLoad() async {
    size = Vector2(25, 25);
    
    _background = RectangleComponent(
      size: size,
      paint: Paint()..color = backgroundColor,
    );
    add(_background);
    
    _textComponent = TextComponent(
      text: text,
      position: Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
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

/// Composant de bouton gaming réutilisable
class _GameButtonComponent extends PositionComponent with TapCallbacks {
  final String text;
  final VoidCallback onPressed;
  final Color backgroundColor;
  
  late RectangleComponent _background;
  late TextComponent _textComponent;
  
  _GameButtonComponent({
    required this.text,
    required this.onPressed,
    required this.backgroundColor,
    Vector2? position,
  }) : super(position: position);
  
  @override
  Future<void> onLoad() async {
    size = Vector2(180, 50);
    
    _background = RectangleComponent(
      size: size,
      paint: Paint()..color = backgroundColor,
    );
    add(_background);
    
    _textComponent = TextComponent(
      text: text,
      position: Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
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
