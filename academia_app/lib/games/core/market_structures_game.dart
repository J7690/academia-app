import 'package:flame/components.dart';
import 'package:flame/events.dart';
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
        description: "Beaucoup de petites entreprises vendant des produits identiques. Aucune ne peut influencer le prix.",
        characteristics: ["Nombreuses entreprises", "Produits identiques", "Preneurs de prix", "Pas de barrières"],
        correctAnswer: MarketStructure.perfectCompetition,
        difficulty: Difficulty.easy,
      ),
      MarketScenario(
        description: "Une seule entreprise contrôle tout le marché avec d'importantes barrières à l'entrée.",
        characteristics: ["Une entreprise", "Produit unique", "Fixe les prix", "Fortes barrières"],
        correctAnswer: MarketStructure.monopoly,
        difficulty: Difficulty.easy,
      ),
      MarketScenario(
        description: "Quelques grandes entreprises dominent le marché. Elles tiennent compte des actions des autres.",
        characteristics: ["Peu d'entreprises", "Interdépendantes", "Barrières à l'entrée", "Concurrence sur les prix"],
        correctAnswer: MarketStructure.oligopoly,
        difficulty: Difficulty.medium,
      ),
      MarketScenario(
        description: "Beaucoup d'entreprises vendent des produits similaires mais différenciés. Chacune a un certain pouvoir de marché.",
        characteristics: ["Nombreuses entreprises", "Différenciation", "Pouvoir de marché limité", "Faibles barrières"],
        correctAnswer: MarketStructure.monopolisticCompetition,
        difficulty: Difficulty.medium,
      ),
      MarketScenario(
        description: "Apple et Google dominent le marché des systèmes d'exploitation mobiles.",
        characteristics: ["Deux entreprises principales", "Effets de réseau", "Coûts R&D élevés", "Prix stratégiques"],
        correctAnswer: MarketStructure.duopoly,
        difficulty: Difficulty.hard,
      ),
      MarketScenario(
        description: "Marché local avec de nombreux vendeurs proposant des légumes similaires.",
        characteristics: ["Nombreux vendeurs", "Produits similaires", "Entrée/sortie facile", "Prix compétitifs"],
        correctAnswer: MarketStructure.perfectCompetition,
        difficulty: Difficulty.easy,
      ),
      MarketScenario(
        description: "De Beers a historiquement contrôlé la majorité de l'offre mondiale de diamants.",
        characteristics: ["Vendeur unique", "Contrôle de l'offre", "Fixation des prix", "Monopole naturel"],
        correctAnswer: MarketStructure.monopoly,
        difficulty: Difficulty.medium,
      ),
      MarketScenario(
        description: "Industrie du fast-food avec McDonald's, Burger King, Wendy's en compétition.",
        characteristics: ["Peu de grandes entreprises", "Guerre publicitaire", "Différenciation", "Compétition de menus"],
        correctAnswer: MarketStructure.oligopoly,
        difficulty: Difficulty.medium,
      ),
      MarketScenario(
        description: "Industrie de la restauration avec de nombreux établissements offrant différentes cuisines.",
        characteristics: ["Nombreux restaurants", "Menus uniques", "Avantage de localisation", "Fidélité à la marque"],
        correctAnswer: MarketStructure.monopolisticCompetition,
        difficulty: Difficulty.easy,
      ),
      MarketScenario(
        description: "Boeing et Airbus dominent le marché de la fabrication d'avions commerciaux.",
        characteristics: ["Deux fabricants", "Coûts d'entrée élevés", "Longs cycles de développement", "Contrats gouvernementaux"],
        correctAnswer: MarketStructure.duopoly,
        difficulty: Difficulty.hard,
      ),
    ]);
    
    _totalScenarios = _scenarios.length;
  }

  void _createGameUI() {
    // Titre du jeu
    final titleText = TextComponent(
      text: 'Structures de Marché',
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
      text: 'Score : $_score',
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
      text: 'Scénario : ${_currentScenario + 1}/$_totalScenarios',
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
      text: 'Quelle structure de marché décrit le mieux cette situation ?',
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
        return 'Concurrence parfaite';
      case MarketStructure.monopoly:
        return 'Monopole';
      case MarketStructure.oligopoly:
        return 'Oligopole';
      case MarketStructure.monopolisticCompetition:
        return 'Concurrence monopolistique';
      case MarketStructure.duopoly:
        return 'Duopole';
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
      onGameEvent('Correct ! +$points points');
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
          ? '✓ Correct ! C\'est ${_getStructureDisplayName(scenario.correctAnswer)}.'
          : '✗ Incorrect. C\'est ${_getStructureDisplayName(scenario.correctAnswer)}, pas ${_getStructureDisplayName(selectedStructure)}.',
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
      text: 'Caractéristiques clés : ${scenario.characteristics.join(", ")}',
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
        return 'La concurrence parfaite comporte de nombreuses entreprises, des produits identiques et aucun pouvoir de marché.';
      case MarketStructure.monopoly:
        return 'Un monopole est une seule entreprise avec de fortes barrières à l\'entrée et le pouvoir de fixer les prix.';
      case MarketStructure.oligopoly:
        return 'Un oligopole comporte peu d\'entreprises interdépendantes face à des barrières à l\'entrée.';
      case MarketStructure.monopolisticCompetition:
        return 'La concurrence monopolistique comporte de nombreuses entreprises avec des produits différenciés.';
      case MarketStructure.duopoly:
        return 'Un duopole est un type spécifique d\'oligopole avec exactement deux entreprises dominantes.';
    }
  }

  void _updateUI() {
    _scoreText.text = 'Score : $_score';
    _progressText.text = 'Scénario : ${_currentScenario + 1}/$_totalScenarios';
  }

  void _endGame() {
    // Calculer le score final
    final percentage = (_score / (_totalScenarios * GameConstants.correctAnswerPoints * 1.5)) * 100;
    
    String performance = '';
    if (percentage >= 90) {
      performance = 'Excellent ! Vous êtes un expert des structures de marché !';
    } else if (percentage >= 70) {
      performance = 'Bien ! Vous comprenez bien les structures de marché.';
    } else if (percentage >= 50) {
      performance = 'Correct. Continuez à étudier la microéconomie !';
    } else {
      performance = 'À améliorer. Révisez les bases des structures de marché.';
    }
    
    onGameEvent('Partie terminée ! $_score/$_totalScenarios corrects. $performance');
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
class _OptionButtonComponent extends PositionComponent with TapCallbacks {
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

  @override
  void onTapDown(TapDownEvent event) {
    onPressed();
  }
}
