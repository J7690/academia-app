import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../core/kellenge_game_engine.dart';
import '../utils/game_constants.dart';

/// Market Master - Jeu d'équilibre du marché
/// Les joueurs ajustent l'offre et la demande pour atteindre l'équilibre
class MarketMasterGame extends KellengeGameEngine {
  // État du jeu
  double _currentPrice = 50.0;
  double _equilibriumPrice = 50.0;
  int _demandQuantity = 100;
  int _supplyQuantity = 100;
  int _marketPhase = 0; // 0: Déséquilibre, 1: Proche, 2: Équilibre
  
  // Composants UI
  late TextComponent _priceText;
  late TextComponent _demandText;
  late TextComponent _supplyText;
  late TextComponent _phaseText;
  late RectangleComponent _demandBar;
  late RectangleComponent _supplyBar;
  late PositionComponent _controls;
  
  MarketMasterGame({
    required super.onScoreUpdated,
    required super.onGameEvent,
    super.onGameEnded,
  }) : super();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Initialiser le marché
    _initializeMarket();
    
    // Créer l'interface du jeu
    _createGameUI();
    
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
      text: 'Market Master',
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
      text: 'Price: \$${_currentPrice.toStringAsFixed(2)}',
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
      text: 'Demand: $_demandQuantity',
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
      text: 'Supply: $_supplyQuantity',
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
      text: 'Adjust price to balance supply and demand\nUse Arrow Keys or Buttons',
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
      text: 'Increase Price (+\$5)',
      onPressed: () => _adjustPrice(5.0),
      backgroundColor: Colors.green,
      position: Vector2(0, 0),
    );
    _controls.add(increaseButton);
    
    // Bouton diminution prix
    final decreaseButton = _GameButtonComponent(
      text: 'Decrease Price (-\$5)',
      onPressed: () => _adjustPrice(-5.0),
      backgroundColor: Colors.red,
      position: Vector2(0, 80),
    );
    _controls.add(decreaseButton);
    
    // Bouton ajustement fin
    final fineUpButton = _GameButtonComponent(
      text: 'Fine Tune (+\$1)',
      onPressed: () => _adjustPrice(1.0),
      backgroundColor: Colors.blue,
      buttonSize: Vector2(150, 40),
      position: Vector2(0, 160),
    );
    _controls.add(fineUpButton);
    
    final fineDownButton = _GameButtonComponent(
      text: 'Fine Tune (-\$1)',
      onPressed: () => _adjustPrice(-1.0),
      backgroundColor: Colors.blue,
      buttonSize: Vector2(150, 40),
      position: Vector2(0, 210),
    );
    _controls.add(fineDownButton);
    
    // Bouton de validation
    final submitButton = _GameButtonComponent(
      text: 'Submit Answer',
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
    
    onGameEvent('New market scenario generated');
  }

  void _adjustPrice(double delta) {
    if (!isGameActive) return;
    
    _currentPrice = (_currentPrice + delta).clamp(5.0, 100.0);
    _updateQuantities();
    _updateUI();
    
    onGameEvent('Price adjusted: ${delta > 0 ? '+' : ''}\$${delta.toStringAsFixed(1)}');
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
    _priceText.text = 'Price: \$${_currentPrice.toStringAsFixed(2)}';
    _demandText.text = 'Demand: $_demandQuantity';
    _supplyText.text = 'Supply: $_supplyQuantity';
    _phaseText.text = _getPhaseText();
    
    // Mettre à jour les barres
    _demandBar.size.x = _demandQuantity * 2;
    _supplyBar.size.x = _supplyQuantity * 2;
  }

  String _getPhaseText() {
    switch (_marketPhase) {
      case 2:
        return 'MARKET EQUILIBRIUM!';
      case 1:
        return 'Close to equilibrium';
      default:
        return 'Market imbalance';
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
      onGameEvent('Correct! Market balanced. +$points points');
      
      // Générer un nouveau scénario après un succès
      Future.delayed(const Duration(seconds: 2), () {
        if (isGameActive) {
          _generateMarketScenario();
        }
      });
    } else {
      subtractScore(GameConstants.wrongAnswerPenalty);
      onGameEvent('Market not balanced. Try again!');
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
class _GameButtonComponent extends PositionComponent {
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
  void render(Canvas canvas) {
    super.render(canvas);
  }
  
  @override
  void update(double dt) {
    super.update(dt);
  }
}
