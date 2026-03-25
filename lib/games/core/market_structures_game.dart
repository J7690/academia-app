import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../core/kellenge_game_engine.dart';
import '../utils/game_constants.dart';

/// Market Structures - Jeu d'identification des types de marchés
/// Les joueurs identifient les structures de marché basées sur des scénarios
class MarketStructuresGame extends KellengeGameEngine {
  // État du jeu
  int _currentScenario = 0;
  int _score = 0;
  int _totalScenarios = 0;
  final List<MarketScenario> _scenarios = [];
  
  // Composants UI
  late TextComponent _scenarioText;
  late TextComponent _questionText;
  late TextComponent _scoreText;
  late TextComponent _progressText;
  late PositionComponent _options;
  late PositionComponent _feedback;
  
  MarketStructuresGame({
    required super.onScoreUpdated,
    required super.onGameEvent,
    super.onGameEnded,
  }) : super();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Initialiser les scénarios
    _initializeScenarios();
    
    // Créer l'interface du jeu
    _createGameUI();
    
    // Afficher le premier scénario
    _showScenario(0);
  }

  void _initializeScenarios() {
    _scenarios.addAll([
      MarketScenario(
        description: "Many small firms selling identical products. No single firm can influence price.",
        characteristics: ["Many firms", "Identical products", "Price takers", "No barriers"],
        correctAnswer: MarketStructure.perfectCompetition,
        difficulty: Difficulty.easy,
      ),
      MarketScenario(
        description: "Single firm controls the entire market with significant barriers to entry.",
        characteristics: ["One firm", "Unique product", "Price maker", "High barriers"],
        correctAnswer: MarketStructure.monopoly,
        difficulty: Difficulty.easy,
      ),
      MarketScenario(
        description: "Few large firms dominate the market. They consider each other's actions.",
        characteristics: ["Few firms", "Interdependent", "Barriers to entry", "Price competition"],
        correctAnswer: MarketStructure.oligopoly,
        difficulty: Difficulty.medium,
      ),
      MarketScenario(
        description: "Many firms sell similar but differentiated products. Each has some market power.",
        characteristics: ["Many firms", "Product differentiation", "Some market power", "Low barriers"],
        correctAnswer: MarketStructure.monopolisticCompetition,
        difficulty: Difficulty.medium,
      ),
      MarketScenario(
        description: "Apple and Google dominate the smartphone operating system market.",
        characteristics: ["Two main firms", "Network effects", "High R&D costs", "Strategic pricing"],
        correctAnswer: MarketStructure.duopoly,
        difficulty: Difficulty.hard,
      ),
      MarketScenario(
        description: "Local farmers market with many vendors selling similar vegetables.",
        characteristics: ["Many sellers", "Similar products", "Easy entry/exit", "Competitive pricing"],
        correctAnswer: MarketStructure.perfectCompetition,
        difficulty: Difficulty.easy,
      ),
      MarketScenario(
        description: "De Beers historically controlled most of the world's diamond supply.",
        characteristics: ["Single seller", "Control of supply", "Price setting", "Natural monopoly"],
        correctAnswer: MarketStructure.monopoly,
        difficulty: Difficulty.medium,
      ),
      MarketScenario(
        description: "Fast food industry with McDonald's, Burger King, Wendy's competing.",
        characteristics: ["Few major firms", "Advertising wars", "Product differentiation", "Menu competition"],
        correctAnswer: MarketStructure.oligopoly,
        difficulty: Difficulty.medium,
      ),
      MarketScenario(
        description: "Restaurant industry with many eateries offering different cuisines and atmospheres.",
        characteristics: ["Many restaurants", "Unique menus", "Location advantages", "Brand loyalty"],
        correctAnswer: MarketStructure.monopolisticCompetition,
        difficulty: Difficulty.easy,
      ),
      MarketScenario(
        description: "Boeing and Airbus dominate the commercial aircraft manufacturing market.",
        characteristics: ["Two manufacturers", "High entry costs", "Long development cycles", "Government contracts"],
        correctAnswer: MarketStructure.duopoly,
        difficulty: Difficulty.hard,
      ),
    ]);
    
    _totalScenarios = _scenarios.length;
  }

  void _createGameUI() {
    // Titre du jeu
    final titleText = TextComponent(
      text: 'Market Structures',
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
    
    // Panneau de progression
    _scoreText = TextComponent(
      text: 'Score: $_score',
      position: Vector2(50, 80),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.green,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(_scoreText);
    
    _progressText = TextComponent(
      text: 'Scenario: ${_currentScenario + 1}/$_totalScenarios',
      position: Vector2(50, 110),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.blue,
          fontSize: 18,
        ),
      ),
    );
    add(_progressText);
    
    // Zone de scénario
    _scenarioText = TextComponent(
      text: '',
      position: Vector2(50, 150),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
    );
    add(_scenarioText);
    
    _questionText = TextComponent(
      text: 'What market structure best describes this situation?',
      position: Vector2(50, 250),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.yellow,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(_questionText);
    
    // Zone d'options
    _options = PositionComponent(position: Vector2(50, 300));
    add(_options);
    
    // Zone de feedback
    _feedback = PositionComponent(position: Vector2(50, 420));
    add(_feedback);
  }

  void _showScenario(int index) {
    if (index >= _scenarios.length) {
      _endGame();
      return;
    }
    
    _currentScenario = index;
    final scenario = _scenarios[index];
    
    // Mettre à jour le texte du scénario
    _scenarioText.text = scenario.description;
    
    // Créer les options de réponse
    _createOptions(scenario);
    
    // Effacer le feedback précédent
    for (final child in List.from(_feedback.children)) {
      _feedback.remove(child);
    }
    
    // Mettre à jour la progression
    _updateUI();
    
    onGameEvent('Scenario ${index + 1}: ${scenario.correctAnswer.name}');
  }

  void _createOptions(MarketScenario scenario) {
    // Effacer les options précédentes
    for (final child in List.from(_options.children)) {
      _options.remove(child);
    }
    
    final allStructures = MarketStructure.values;
    final shuffledOptions = List<MarketStructure>.from(allStructures)..shuffle();
    
    double yPosition = 0;
    for (int i = 0; i < shuffledOptions.length; i++) {
      final structure = shuffledOptions[i];
      
      final optionButton = _OptionButtonComponent(
        text: _getStructureDisplayName(structure),
        onPressed: () => _selectAnswer(structure, scenario),
        backgroundColor: _getStructureColor(structure),
        position: Vector2(0, yPosition),
      );
      _options.add(optionButton);
      
      yPosition += 50;
    }
  }

  String _getStructureDisplayName(MarketStructure structure) {
    switch (structure) {
      case MarketStructure.perfectCompetition:
        return 'Perfect Competition';
      case MarketStructure.monopoly:
        return 'Monopoly';
      case MarketStructure.oligopoly:
        return 'Oligopoly';
      case MarketStructure.monopolisticCompetition:
        return 'Monopolistic Competition';
      case MarketStructure.duopoly:
        return 'Duopoly';
    }
  }

  Color _getStructureColor(MarketStructure structure) {
    switch (structure) {
      case MarketStructure.perfectCompetition:
        return Colors.green;
      case MarketStructure.monopoly:
        return Colors.red;
      case MarketStructure.oligopoly:
        return Colors.orange;
      case MarketStructure.monopolisticCompetition:
        return Colors.blue;
      case MarketStructure.duopoly:
        return Colors.purple;
    }
  }

  void _selectAnswer(MarketStructure selectedStructure, MarketScenario scenario) {
    if (!isGameActive) return;
    
    final isCorrect = selectedStructure == scenario.correctAnswer;
    
    // Effacer les options
    for (final child in List.from(_options.children)) {
      _options.remove(child);
    }
    
    // Afficher le feedback
    _showFeedback(isCorrect, scenario, selectedStructure);
    
    // Calculer le score
    int points = 0;
    if (isCorrect) {
      switch (scenario.difficulty) {
        case Difficulty.easy:
          points = GameConstants.correctAnswerPoints;
          break;
        case Difficulty.medium:
          points = (GameConstants.correctAnswerPoints * 1.5).round();
          break;
        case Difficulty.hard:
          points = GameConstants.correctAnswerPoints * 2;
          break;
      }
      
      _score += points;
      addScore(points);
      onGameEvent('Correct! +$points points');
    } else {
      points = GameConstants.wrongAnswerPenalty;
      subtractScore(points);
      onGameEvent('Incorrect. -$points points');
    }
    
    _updateUI();
    
    // Passer au scénario suivant après un délai
    Future.delayed(const Duration(seconds: 3), () {
      if (isGameActive) {
        _showScenario(_currentScenario + 1);
      }
    });
  }

  void _showFeedback(bool isCorrect, MarketScenario scenario, MarketStructure selectedStructure) {
    for (final child in List.from(_feedback.children)) {
      _feedback.remove(child);
    }
    
    // Message de feedback
    final feedbackText = TextComponent(
      text: isCorrect 
          ? '✓ Correct! This is ${_getStructureDisplayName(scenario.correctAnswer)}.'
          : '✗ Incorrect. This is ${_getStructureDisplayName(scenario.correctAnswer)}, not ${_getStructureDisplayName(selectedStructure)}.',
      position: Vector2(0, 0),
      textRenderer: TextPaint(
        style: TextStyle(
          color: isCorrect ? Colors.green : Colors.red,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    _feedback.add(feedbackText);
    
    // Caractéristiques du scénario
    final characteristicsText = TextComponent(
      text: 'Key characteristics: ${scenario.characteristics.join(", ")}',
      position: Vector2(0, 30),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
        ),
      ),
    );
    _feedback.add(characteristicsText);
    
    // Explication
    final explanationText = TextComponent(
      text: _getExplanation(scenario.correctAnswer),
      position: Vector2(0, 60),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
        ),
      ),
    );
    _feedback.add(explanationText);
  }

  String _getExplanation(MarketStructure structure) {
    switch (structure) {
      case MarketStructure.perfectCompetition:
        return 'Perfect competition has many firms, identical products, and no market power.';
      case MarketStructure.monopoly:
        return 'A monopoly has one firm with significant barriers to entry and price-setting power.';
      case MarketStructure.oligopoly:
        return 'An oligopoly has few firms that are interdependent and face barriers to entry.';
      case MarketStructure.monopolisticCompetition:
        return 'Monopolistic competition has many firms with differentiated products and some market power.';
      case MarketStructure.duopoly:
        return 'A duopoly is a specific type of oligopoly with exactly two dominant firms.';
    }
  }

  void _updateUI() {
    _scoreText.text = 'Score: $_score';
    _progressText.text = 'Scenario: ${_currentScenario + 1}/$_totalScenarios';
  }

  void _endGame() {
    // Calculer le score final
    final percentage = (_score / (_totalScenarios * GameConstants.correctAnswerPoints * 1.5)) * 100;
    
    String performance = '';
    if (percentage >= 90) {
      performance = 'Excellent! You\'re a market structure expert!';
    } else if (percentage >= 70) {
      performance = 'Good! You understand market structures well.';
    } else if (percentage >= 50) {
      performance = 'Fair. Keep studying microeconomics!';
    } else {
      performance = 'Needs improvement. Review the basics of market structures.';
    }
    
    onGameEvent('Game completed! $_score/$_totalScenarios correct. $performance');
    onGameEnded?.call();
  }

  // Getters pour l'état du jeu
  int get currentScenarioIndex => _currentScenario;
  int get score => _score;
  int get totalScenarios => _totalScenarios;
  double get completionPercentage => (_currentScenario + 1) / _totalScenarios;
}

/// Modèle de scénario de marché
class MarketScenario {
  final String description;
  final List<String> characteristics;
  final MarketStructure correctAnswer;
  final Difficulty difficulty;
  
  MarketScenario({
    required this.description,
    required this.characteristics,
    required this.correctAnswer,
    required this.difficulty,
  });
}

/// Types de structures de marché
enum MarketStructure {
  perfectCompetition,
  monopoly,
  oligopoly,
  monopolisticCompetition,
  duopoly,
}

/// Niveaux de difficulté
enum Difficulty {
  easy,
  medium,
  hard,
}

/// Composant de bouton d'option
class _OptionButtonComponent extends PositionComponent {
  final String text;
  final VoidCallback onPressed;
  final Color backgroundColor;
  
  late RectangleComponent _background;
  late TextComponent _textComponent;
  
  _OptionButtonComponent({
    required this.text,
    required this.onPressed,
    required this.backgroundColor,
    Vector2? position,
  }) : super(position: position);
  
  @override
  Future<void> onLoad() async {
    size = Vector2(300, 40);
    
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
