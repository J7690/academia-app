import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/kellenge_game_engine.dart';
import '../models/game_session.dart';
import '../services/game_scoring_system.dart';
import '../utils/game_constants.dart';
import '../providers/game_provider.dart';

/// Écran principal des jeux Kellenge
class GamesHubScreen extends StatelessWidget {
  const GamesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kellenge Games'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: const GamesHubBody(),
    );
  }
}

class GamesHubBody extends StatelessWidget {
  const GamesHubBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose Your Economic Challenge',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _GameCard(
                  title: GameConstants.marketMaster,
                  description: 'Master market dynamics',
                  icon: Icons.trending_up,
                  color: Colors.green,
                  onTap: () => _startGame(context, GameConstants.marketMaster),
                ),
                _GameCard(
                  title: GameConstants.consumerChoice,
                  description: 'Optimize consumer decisions',
                  icon: Icons.shopping_cart,
                  color: Colors.orange,
                  onTap: () => _startGame(context, GameConstants.consumerChoice),
                ),
                _GameCard(
                  title: GameConstants.firmTycoon,
                  description: 'Build your business empire',
                  icon: Icons.business,
                  color: Colors.purple,
                  onTap: () => _startGame(context, GameConstants.firmTycoon),
                ),
                _GameCard(
                  title: GameConstants.marketStructures,
                  description: 'Understand market types',
                  icon: Icons.account_tree,
                  color: Colors.red,
                  onTap: () => _startGame(context, GameConstants.marketStructures),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _startGame(BuildContext context, String gameType) {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    
    // Créer une session de jeu
    final session = GameSession.create(
      playerId: 'current_user', // Sera remplacé par l'ID utilisateur réel
      gameType: gameType,
      duration: GameConstants.defaultGameDuration,
    );

    // Naviguer vers l'écran de jeu
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GamePlayScreen(
          session: session,
          gameProvider: gameProvider,
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _GameCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.8),
                color.withValues(alpha: 0.6),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Écran de jeu principal
class GamePlayScreen extends StatefulWidget {
  final GameSession session;
  final GameProvider gameProvider;

  const GamePlayScreen({
    super.key,
    required this.session,
    required this.gameProvider,
  });

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  late KellengeGameEngine _gameEngine;
  late GameScoringSystem _scoringSystem;
  bool _isGameInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  Future<void> _initializeGame() async {
    // Initialiser le système de scoring
    _scoringSystem = GameScoringSystem();
    _scoringSystem.startNewGame();

    // Créer le moteur de jeu
    _gameEngine = KellengeGameEngine(
      onScoreUpdated: (score) {
        // Le score est géré par le système de scoring
        setState(() {});
      },
      onGameEvent: (event) {
        debugPrint('Game event: $event');
      },
      onGameEnded: () {
        _showGameEndDialog();
      },
    );

    setState(() {
      _isGameInitialized = true;
    });

    // Démarrer le jeu
    _gameEngine.startGame(widget.session);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isGameInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session.gameType),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.pause),
            onPressed: _togglePause,
          ),
        ],
      ),
      body: Column(
        children: [
          // Panneau de score
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black87,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Score: ${_scoringSystem.currentScore}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Time: ${_gameEngine.timeRemaining}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Combo: x${_scoringSystem.comboMultiplier}',
                  style: const TextStyle(
                    color: Colors.yellow,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Zone de jeu Flame
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: GameWidget(
                game: _gameEngine,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _togglePause() {
    if (_gameEngine.isGameActive) {
      _gameEngine.pauseGame();
    } else {
      _gameEngine.resumeGame();
    }
    setState(() {});
  }

  void _showGameEndDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Final Score: ${_scoringSystem.currentScore}'),
            Text('High Score: ${_scoringSystem.highScore}'),
            const SizedBox(height: 16),
            Text('Statistics:'),
            Text('Correct Answers: ${_scoringSystem.totalCorrectAnswers}'),
            Text('Wrong Answers: ${_scoringSystem.totalWrongAnswers}'),
            Text('Average Score: ${_scoringSystem.averageScore.toStringAsFixed(1)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Back to Games'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _restartGame();
            },
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  void _restartGame() {
    _scoringSystem.startNewGame();
    _gameEngine.startGame(widget.session);
    setState(() {});
  }

  @override
  void dispose() {
    // Nettoyer les ressources
    _scoringSystem.dispose();
    super.dispose();
  }
}

/// Widget GameWidget pour intégrer Flame
class GameWidget extends StatelessWidget {
  final KellengeGameEngine game;

  const GameWidget({
    super.key,
    required this.game,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: const Center(
        child: Text(
          'Game Area\n(Flame Engine will be rendered here)',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}
