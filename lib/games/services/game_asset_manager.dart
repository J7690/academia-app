import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../utils/game_assets.dart';

/// Gestionnaire simplifié des assets pour les jeux Kellenge
/// Gère les chemins d'assets et composants de base
class GameAssetManager {
  static GameAssetManager? _instance;
  static GameAssetManager get instance => _instance ??= GameAssetManager._();
  
  GameAssetManager._();
  
  // Assets préchargés (chemins uniquement)
  Map<String, String> _imageAssets = {};
  Map<String, String> _soundAssets = {};
  bool _isPreloaded = false;
  
  /// Initialise les chemins d'assets
  Future<void> preloadAssets() async {
    if (_isPreloaded) return;
    
    try {
      _initializeAssetPaths();
      _isPreloaded = true;
    } catch (e) {
      debugPrint('Error initializing assets: $e');
    }
  }
  
  void _initializeAssetPaths() {
    // Initialisation des chemins d'images
    final imagePaths = {
      'market_master': GameAssets.marketMasterIcon,
      'consumer_choice': GameAssets.consumerChoiceIcon,
      'firm_tycoon': GameAssets.firmTycoonIcon,
      'market_structures': GameAssets.marketStructuresIcon,
      'button_primary': GameAssets.buttonPrimary,
      'button_secondary': GameAssets.buttonSecondary,
      'background': GameAssets.backgroundGame,
      'score_panel': GameAssets.scorePanel,
    };
    
    // Initialisation des chemins de sons
    final soundPaths = {
      'correct': GameAssets.correctAnswer,
      'wrong': GameAssets.wrongAnswer,
      'start': GameAssets.gameStart,
      'end': GameAssets.gameEnd,
      'click': GameAssets.buttonClick,
    };
    
    _imageAssets.addAll(imagePaths);
    _soundAssets.addAll(soundPaths);
  }
  
  /// Récupère le chemin d'une image
  String? getImagePath(String assetName) {
    return _imageAssets[assetName];
  }
  
  /// Récupère le chemin d'un son
  String? getSoundPath(String soundName) {
    return _soundAssets[soundName];
  }
  
  /// Vérifie si les assets sont initialisés
  bool get isPreloaded => _isPreloaded;
  
  /// Libère les assets
  void dispose() {
    _imageAssets.clear();
    _soundAssets.clear();
    _isPreloaded = false;
  }
}

/// Composant de bouton gaming simplifié
class GameButtonComponent extends PositionComponent {
  final String text;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color textColor;
  final Vector2? buttonSize;
  
  late RectangleComponent _background;
  late TextComponent _textComponent;
  
  GameButtonComponent({
    required this.text,
    required this.onPressed,
    this.backgroundColor = Colors.blue,
    this.textColor = Colors.white,
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
        style: TextStyle(
          color: textColor,
          fontSize: 18,
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

/// Composant de panneau de score
class ScorePanelComponent extends PositionComponent {
  final int score;
  final int timeRemaining;
  final Color backgroundColor;
  final Color textColor;
  
  late RectangleComponent _background;
  late TextComponent _scoreText;
  late TextComponent _timeText;
  
  ScorePanelComponent({
    required this.score,
    required this.timeRemaining,
    this.backgroundColor = Colors.black87,
    this.textColor = Colors.white,
    Vector2? position,
    Vector2? panelSize,
  }) : super(position: position) {
    size = panelSize ?? Vector2(300, 80);
  }
  
  @override
  Future<void> onLoad() async {
    // Fond du panneau
    _background = RectangleComponent(
      size: size,
      paint: Paint()..color = backgroundColor,
    );
    add(_background);
    
    // Texte de score
    _scoreText = TextComponent(
      text: 'Score: $score',
      position: Vector2(10, 10),
      textRenderer: TextPaint(
        style: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(_scoreText);
    
    // Texte de temps
    _timeText = TextComponent(
      text: 'Time: $timeRemaining',
      position: Vector2(10, 40),
      textRenderer: TextPaint(
        style: TextStyle(
          color: textColor,
          fontSize: 16,
        ),
      ),
    );
    add(_timeText);
  }
  
  void updateScore(int newScore) {
    _scoreText.text = 'Score: $newScore';
  }
  
  void updateTime(int newTime) {
    _timeText.text = 'Time: $newTime';
  }
}
