import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flame/game.dart' as flame;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/kellenge_game_engine.dart';
import '../core/market_master_game.dart';
import '../core/consumer_choice_game.dart';
import '../core/firm_tycoon_game.dart';
import '../core/market_structures_game.dart';
import '../models/game_session.dart';
import '../services/game_scoring_system.dart';
import '../services/gameplay_recorder_service.dart';
import '../utils/game_constants.dart';
import '../providers/game_provider.dart';
import '../../features/student/video_publish_screen.dart';

/// Écran principal des jeux Kellenge
class GamesHubScreen extends StatelessWidget {
  const GamesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jeux Kellenge'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: const GamesHubBody(),
    );
  }
}

class GamesHubBody extends StatelessWidget {
  const GamesHubBody({super.key});

  static const _games = [
    _GameDef('Market Master', 'Offre & Demande', Icons.trending_up, Colors.green),
    _GameDef('Consumer Choice', 'Choix du consommateur', Icons.shopping_cart, Colors.orange),
    _GameDef('Firm Tycoon', 'Gestion d\'entreprise', Icons.business, Colors.purple),
    _GameDef('Market Structures', 'Structures de marché', Icons.account_tree, Colors.red),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final crossCount = w < 400 ? 2 : (w < 700 ? 2 : 3);
          final hPad = w * 0.04;
          final spacing = w * 0.03;

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(hPad, hPad, hPad, spacing),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Choisis ton défi économique',
                    style: TextStyle(
                      fontSize: w * 0.055 > 28 ? 28 : w * 0.055,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    childAspectRatio: 0.85,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final g = _games[index];
                      return _AdaptiveGameCard(
                        title: g.title,
                        description: g.description,
                        icon: g.icon,
                        color: g.color,
                        onTap: () => _startGame(context, g.title),
                      );
                    },
                    childCount: _games.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _startGame(BuildContext context, String gameType) {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    final session = GameSession.create(
      playerId: userId,
      gameType: gameType,
      duration: GameConstants.defaultGameDuration,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GamePlayScreen(
          session: session,
          gameProvider: GameProvider(),
        ),
      ),
    );
  }
}

class _GameDef {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  const _GameDef(this.title, this.description, this.icon, this.color);
}

class _AdaptiveGameCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AdaptiveGameCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardH = constraints.maxHeight;
            final cardW = constraints.maxWidth;
            final iconSize = cardH * 0.25;
            final titleSize = (cardW * 0.095).clamp(11.0, 18.0);
            final descSize = (cardW * 0.075).clamp(9.0, 13.0);
            final pad = cardW * 0.08;

            return Container(
              padding: EdgeInsets.all(pad),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.85),
                    color.withValues(alpha: 0.6),
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    flex: 3,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Icon(icon, size: iconSize, color: Colors.white),
                    ),
                  ),
                  SizedBox(height: cardH * 0.04),
                  Flexible(
                    flex: 3,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  SizedBox(height: cardH * 0.02),
                  Flexible(
                    flex: 2,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        description,
                        style: TextStyle(
                          fontSize: descSize,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
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
  bool _isRecording = false;
  bool _isProcessingVideo = false;
  final GlobalKey _gameBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  Future<void> _initializeGame() async {
    // Initialiser le système de scoring
    _scoringSystem = GameScoringSystem();
    _scoringSystem.startNewGame();

    // Créer le moteur de jeu approprié selon le type
    _gameEngine = _createGameEngine(widget.session.gameType);

    setState(() {
      _isGameInitialized = true;
    });

    // Démarrer le jeu
    _gameEngine.startGame(widget.session);
  }

  KellengeGameEngine _createGameEngine(String gameType) {
    final onScore = (int score) => setState(() {});
    final onEvent = (String event) => debugPrint('Game event: $event');
    final onEnd = () => _showGameEndDialog();

    switch (gameType) {
      case GameConstants.marketMaster:
        return MarketMasterGame(
          onScoreUpdated: onScore,
          onGameEvent: onEvent,
          onGameEnded: onEnd,
        );
      case GameConstants.consumerChoice:
        return ConsumerChoiceGame(
          onScoreUpdated: onScore,
          onGameEvent: onEvent,
          onGameEnded: onEnd,
        );
      case GameConstants.firmTycoon:
        return FirmTycoonGame(
          onScoreUpdated: onScore,
          onGameEvent: onEvent,
          onGameEnded: onEnd,
        );
      case GameConstants.marketStructures:
        return MarketStructuresGame(
          onScoreUpdated: onScore,
          onGameEvent: onEvent,
          onGameEnded: onEnd,
        );
      default:
        return KellengeGameEngine(
          onScoreUpdated: onScore,
          onGameEvent: onEvent,
          onGameEnded: onEnd,
        );
    }
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
          // Bouton enregistrement gameplay
          if (!_isProcessingVideo)
            IconButton(
              icon: Icon(
                _isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
                color: _isRecording ? Colors.white : Colors.red,
                size: 28,
              ),
              tooltip: _isRecording ? 'Arrêter l\'enregistrement' : 'Enregistrer le gameplay',
              onPressed: _isRecording ? _stopAndPublish : _startRecording,
            ),
          if (_isProcessingVideo)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
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
                  'Score : ${_scoringSystem.currentScore}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Temps : ${_gameEngine.timeRemaining}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Combo : x${_scoringSystem.comboMultiplier}',
                  style: const TextStyle(
                    color: Colors.yellow,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Indicateur d'enregistrement
          if (_isRecording)
            Container(
              color: Colors.red.withValues(alpha: 0.15),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
                  SizedBox(width: 6),
                  Text(
                    'Enregistrement en cours...',
                    style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          // Zone de jeu Flame (enveloppée dans RepaintBoundary pour capture)
          Expanded(
            child: RepaintBoundary(
              key: _gameBoundaryKey,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: _isRecording ? Colors.red : Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: flame.GameWidget(game: _gameEngine),
                ),
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

  Future<void> _startRecording() async {
    GameplayRecorderService.boundaryKey = _gameBoundaryKey;
    final started = await GameplayRecorderService.startRecording();
    if (!mounted) return;
    if (started) {
      setState(() => _isRecording = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enregistrement du gameplay démarré'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec du démarrage de l\'enregistrement')),
      );
    }
  }

  Future<void> _stopAndPublish() async {
    setState(() {
      _isRecording = false;
      _isProcessingVideo = true;
    });

    try {
      final rawPath = await GameplayRecorderService.stopRecording();
      if (!mounted) return;

      if (rawPath == null) {
        setState(() => _isProcessingVideo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucune vidéo capturée')),
        );
        return;
      }

      // Compresser la vidéo
      final compressedPath = await GameplayRecorderService.compressRecording(rawPath);
      if (!mounted) return;

      setState(() => _isProcessingVideo = false);

      // Naviguer vers l'écran de publication
      final videoFile = File(compressedPath);
      if (!await videoFile.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fichier vidéo introuvable')),
        );
        return;
      }

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoPublishScreen(
            videoUrl: compressedPath,
            videoType: 'free',
            overlays: const {},
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingVideo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  void _showGameEndDialog() {
    // Arrêter l'enregistrement si en cours
    if (_isRecording) {
      GameplayRecorderService.cancelRecording();
      _isRecording = false;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Fin de partie !'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Score final : ${_scoringSystem.currentScore}'),
            Text('Meilleur score : ${_scoringSystem.highScore}'),
            const SizedBox(height: 16),
            const Text('Statistiques :'),
            Text('Bonnes réponses : ${_scoringSystem.totalCorrectAnswers}'),
            Text('Mauvaises réponses : ${_scoringSystem.totalWrongAnswers}'),
            Text('Score moyen : ${_scoringSystem.averageScore.toStringAsFixed(1)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Retour aux jeux'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _restartGame();
            },
            child: const Text('Rejouer'),
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
    // Arrêter l'enregistrement si en cours
    if (_isRecording) {
      GameplayRecorderService.cancelRecording();
    }
    _scoringSystem.dispose();
    super.dispose();
  }
}

