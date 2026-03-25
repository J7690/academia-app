import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../core/kellenge_game_engine.dart';
import '../utils/game_constants.dart';

/// Consumer Choice - Jeu d'optimisation des décisions du consommateur
/// Les joueurs maximisent l'utilité sous contrainte budgétaire
class ConsumerChoiceGame extends KellengeGameEngine {
  // État du jeu
  double _budget = 100.0;
  double _remainingBudget = 100.0;
  int _currentUtility = 0;
  int _targetUtility = 0;
  int _round = 1;
  int _maxRounds = 5;
  
  // Produits disponibles
  final List<Product> _products = [];
  final Map<String, int> _selectedQuantities = {};
  
  // Composants UI
  late TextComponent _budgetText;
  late TextComponent _utilityText;
  late TextComponent _roundText;
  late TextComponent _targetText;
  late PositionComponent _productList;
  late PositionComponent _controls;
  
  ConsumerChoiceGame({
    required super.onScoreUpdated,
    required super.onGameEvent,
    super.onGameEnded,
  }) : super();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Initialiser les produits
    _initializeProducts();
    
    // Créer l'interface du jeu
    _createGameUI();
    
    // Générer le premier scénario
    _generateConsumerScenario();
  }

  void _initializeProducts() {
    _products.clear();
    _products.addAll([
      Product(
        name: 'Apples',
        price: 2.0,
        utility: 8,
        color: Colors.red,
        description: 'Fresh apples',
      ),
      Product(
        name: 'Bread',
        price: 3.0,
        utility: 10,
        color: Colors.brown,
        description: 'Whole grain bread',
      ),
      Product(
        name: 'Milk',
        price: 4.0,
        utility: 12,
        color: Colors.blueGrey,
        description: 'Organic milk',
      ),
      Product(
        name: 'Chicken',
        price: 8.0,
        utility: 20,
        color: Colors.orange,
        description: 'Fresh chicken',
      ),
      Product(
        name: 'Rice',
        price: 2.5,
        utility: 9,
        color: Colors.white,
        description: 'Basmati rice',
      ),
      Product(
        name: 'Vegetables',
        price: 5.0,
        utility: 15,
        color: Colors.green,
        description: 'Mixed vegetables',
      ),
    ]);
    
    // Initialiser les quantités sélectionnées
    for (final product in _products) {
      _selectedQuantities[product.name] = 0;
    }
  }

  void _createGameUI() {
    // Titre du jeu
    final titleText = TextComponent(
      text: 'Consumer Choice',
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
    
    // Panneau d'information
    _budgetText = TextComponent(
      text: 'Budget: \$${_remainingBudget.toStringAsFixed(2)}',
      position: Vector2(50, 80),
      textRenderer: TextPaint(
        style: TextStyle(
          color: _remainingBudget > 0 ? Colors.green : Colors.red,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(_budgetText);
    
    _utilityText = TextComponent(
      text: 'Utility: $_currentUtility',
      position: Vector2(50, 120),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.blue,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(_utilityText);
    
    _targetText = TextComponent(
      text: 'Target: $_targetUtility',
      position: Vector2(50, 160),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.purple,
          fontSize: 20,
        ),
      ),
    );
    add(_targetText);
    
    _roundText = TextComponent(
      text: 'Round: $_round/$_maxRounds',
      position: Vector2(50, 200),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
        ),
      ),
    );
    add(_roundText);
    
    // Liste des produits
    _productList = PositionComponent(position: Vector2(50, 250));
    add(_productList);
    
    // Contrôles
    _createControls();
    
    // Instructions
    final instructions = TextComponent(
      text: 'Maximize utility within budget\nSelect quantities and submit',
      position: Vector2(500, 400),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
        ),
      ),
    );
    add(instructions);
  }

  void _createControls() {
    _controls = PositionComponent(position: Vector2(500, 100));
    add(_controls);
    
    // Bouton de validation
    final submitButton = _GameButtonComponent(
      text: 'Submit Choice',
      onPressed: _submitChoice,
      backgroundColor: Colors.green,
      position: Vector2(0, 0),
    );
    _controls.add(submitButton);
    
    // Bouton de réinitialisation
    final resetButton = _GameButtonComponent(
      text: 'Reset Selection',
      onPressed: _resetSelection,
      backgroundColor: Colors.orange,
      position: Vector2(0, 70),
    );
    _controls.add(resetButton);
    
    // Bouton d'optimisation automatique
    final optimizeButton = _GameButtonComponent(
      text: 'Auto Optimize (-5 pts)',
      onPressed: _autoOptimize,
      backgroundColor: Colors.purple,
      position: Vector2(0, 140),
    );
    _controls.add(optimizeButton);
  }

  void _generateConsumerScenario() {
    // Générer un nouveau scénario de consommation
    _budget = 80.0 + (DateTime.now().millisecond % 40).toDouble();
    _remainingBudget = _budget;
    
    // Calculer l'utilité cible (70-90% de l'utilité maximale possible)
    final maxUtility = _calculateMaxUtility();
    _targetUtility = (maxUtility * 0.8).round();
    
    // Réinitialiser les sélections
    _resetSelection();
    
    _updateUI();
    
    onGameEvent('New consumer scenario: Budget \$${_budget.toStringAsFixed(2)}, Target utility $_targetUtility');
  }

  int _calculateMaxUtility() {
    int maxUtility = 0;
    for (final product in _products) {
      final maxQuantity = (_budget / product.price).floor();
      maxUtility += maxQuantity * product.utility;
    }
    return maxUtility;
  }

  void _createProductList() {
    // Supprimer tous les enfants existants
    for (final child in List.from(_productList.children)) {
      _productList.remove(child);
    }
    
    double yPosition = 0;
    for (int i = 0; i < _products.length; i++) {
      final product = _products[i];
      final quantity = _selectedQuantities[product.name] ?? 0;
      
      // Créer un composant pour chaque produit
      final productComponent = _ProductComponent(
        product: product,
        quantity: quantity,
        onQuantityChanged: (newQuantity) {
          _updateProductQuantity(product.name, newQuantity);
        },
        position: Vector2(0, yPosition),
      );
      _productList.add(productComponent);
      
      yPosition += 80;
    }
  }

  void _updateProductQuantity(String productName, int newQuantity) {
    if (!isGameActive) return;
    
    final product = _products.firstWhere((p) => p.name == productName);
    final currentQuantity = _selectedQuantities[productName] ?? 0;
    
    // Calculer le coût de la modification
    final priceDifference = (newQuantity - currentQuantity) * product.price;
    
    // Vérifier si le budget le permet
    if (_remainingBudget - priceDifference >= 0) {
      _selectedQuantities[productName] = newQuantity;
      _remainingBudget -= priceDifference;
      _updateUtility();
      _updateUI();
      
      onGameEvent('Updated $productName: $newQuantity units');
    } else {
      onGameEvent('Insufficient budget for $productName');
    }
  }

  void _updateUtility() {
    _currentUtility = 0;
    for (final product in _products) {
      final quantity = _selectedQuantities[product.name] ?? 0;
      _currentUtility += quantity * product.utility;
    }
  }

  void _resetSelection() {
    for (final product in _products) {
      _selectedQuantities[product.name] = 0;
    }
    _remainingBudget = _budget;
    _updateUtility();
    _createProductList();
    _updateUI();
    
    onGameEvent('Selection reset');
  }

  void _autoOptimize() {
    if (!isGameActive) return;
    
    // Pénalité pour l'optimisation automatique
    subtractScore(5);
    
    // Réinitialiser
    _resetSelection();
    
    // Algorithme simple : maximiser l'utilité par dollar
    final sortedProducts = List.from(_products);
    sortedProducts.sort((a, b) => (b.utility / b.price).compareTo(a.utility / a.price));
    
    double remainingBudget = _budget;
    
    for (final product in sortedProducts) {
      final maxQuantity = (remainingBudget / product.price).floor();
      if (maxQuantity > 0) {
        _selectedQuantities[product.name] = maxQuantity;
        remainingBudget -= maxQuantity * product.price;
      }
    }
    
    _remainingBudget = remainingBudget;
    _updateUtility();
    _createProductList();
    _updateUI();
    
    onGameEvent('Auto-optimized selection (-5 points penalty)');
  }

  void _submitChoice() {
    if (!isGameActive) return;
    
    // Calculer le score
    int points = 0;
    if (_currentUtility >= _targetUtility) {
      // Atteint ou dépasse la cible
      final efficiency = (_currentUtility / _targetUtility).clamp(1.0, 1.5);
      points = (GameConstants.correctAnswerPoints * efficiency).round();
      
      addScore(points);
      onGameEvent('Excellent! Target achieved. +$points points');
    } else {
      // N'atteint pas la cible
      final achievementRate = _currentUtility / _targetUtility;
      if (achievementRate >= 0.7) {
        points = (GameConstants.correctAnswerPoints * 0.5).round();
        addScore(points);
        onGameEvent('Good effort! Close to target. +$points points');
      } else {
        subtractScore(GameConstants.wrongAnswerPenalty);
        onGameEvent('Below target. Try to optimize better!');
      }
    }
    
    // Passer au round suivant
    _nextRound();
  }

  void _nextRound() {
    _round++;
    
    if (_round > _maxRounds) {
      // Fin du jeu - appeler la méthode parente
      onGameEnded?.call();
    } else {
      // Nouveau round
      _generateConsumerScenario();
    }
  }

  void _updateUI() {
    _budgetText.text = 'Budget: \$${_remainingBudget.toStringAsFixed(2)}';
    _budgetText.textRenderer = TextPaint(
      style: TextStyle(
        color: _remainingBudget > 0 ? Colors.green : Colors.red,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    );
    _utilityText.text = 'Utility: $_currentUtility';
    _targetText.text = 'Target: $_targetUtility';
    _roundText.text = 'Round: $_round/$_maxRounds';
    
    // Mettre à jour la liste des produits
    _createProductList();
  }

  // Getters pour l'état du jeu
  double get budget => _budget;
  double get remainingBudget => _remainingBudget;
  int get currentUtility => _currentUtility;
  int get targetUtility => _targetUtility;
  int get round => _round;
  bool get isTargetAchieved => _currentUtility >= _targetUtility;
}

/// Modèle de produit
class Product {
  final String name;
  final double price;
  final int utility;
  final Color color;
  final String description;
  
  Product({
    required this.name,
    required this.price,
    required this.utility,
    required this.color,
    required this.description,
  });
  
  double get utilityPerDollar => utility / price;
}

/// Composant de produit individuel
class _ProductComponent extends PositionComponent {
  final Product product;
  final int quantity;
  final Function(int) onQuantityChanged;
  
  late TextComponent _nameText;
  late TextComponent _priceText;
  late TextComponent _utilityText;
  late TextComponent _quantityText;
  late RectangleComponent _background;
  late PositionComponent _controls;
  
  _ProductComponent({
    required this.product,
    required this.quantity,
    required this.onQuantityChanged,
    Vector2? position,
  }) : super(position: position);
  
  @override
  Future<void> onLoad() async {
    size = Vector2(400, 70);
    
    // Fond
    _background = RectangleComponent(
      size: size,
      paint: Paint()..color = product.color.withValues(alpha: 0.2),
    );
    add(_background);
    
    // Informations du produit
    _nameText = TextComponent(
      text: product.name,
      position: Vector2(10, 10),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(_nameText);
    
    _priceText = TextComponent(
      text: '\$${product.price.toStringAsFixed(2)}',
      position: Vector2(10, 30),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
        ),
      ),
    );
    add(_priceText);
    
    _utilityText = TextComponent(
      text: 'Utility: ${product.utility}',
      position: Vector2(10, 50),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.yellow,
          fontSize: 12,
        ),
      ),
    );
    add(_utilityText);
    
    // Contrôles de quantité
    _createQuantityControls();
  }
  
  void _createQuantityControls() {
    _controls = PositionComponent(position: Vector2(250, 20));
    add(_controls);
    
    // Bouton de diminution
    final decreaseButton = _SmallButtonComponent(
      text: '-',
      onPressed: () {
        final newQuantity = (quantity - 1).clamp(0, double.infinity).toInt();
        onQuantityChanged(newQuantity);
      },
      backgroundColor: Colors.red,
      position: Vector2(0, 0),
    );
    _controls.add(decreaseButton);
    
    // Affichage de la quantité
    _quantityText = TextComponent(
      text: quantity.toString(),
      position: Vector2(30, 5),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    _controls.add(_quantityText);
    
    // Bouton d'augmentation
    final increaseButton = _SmallButtonComponent(
      text: '+',
      onPressed: () {
        final newQuantity = quantity + 1;
        onQuantityChanged(newQuantity);
      },
      backgroundColor: Colors.green,
      position: Vector2(60, 0),
    );
    _controls.add(increaseButton);
  }
}

/// Petit composant de bouton
class _SmallButtonComponent extends PositionComponent {
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
}

/// Composant de bouton gaming réutilisable
class _GameButtonComponent extends PositionComponent {
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
    size = Vector2(150, 50);
    
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
}
