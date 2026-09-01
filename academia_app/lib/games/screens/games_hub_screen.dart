import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/game_session.dart';
import '../services/game_scoring_system.dart';
import '../services/gameplay_recorder_service.dart';
import '../services/watermark_service.dart';
import '../services/game_live_service.dart';
import '../services/game_results_service.dart';
import '../utils/game_constants.dart';
import '../providers/game_provider.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import '../../services/academia_room_options.dart';
import '../../services/livekit_token_service.dart';
import 'package:provider/provider.dart';
import '../../features/student/video_publish_screen.dart';
import '../../providers/student_challenges_provider.dart';
import '../../services/videoasset_upload_service.dart';
import 'package:share_plus/share_plus.dart';
import 'flutter_game_views.dart';

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
    _showPreGameDialog(context, gameType);
  }

  void _showPreGameDialog(BuildContext context, String gameType) {
    bool enableLive = true;
    bool enableCamera = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      gameType,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Durée : ${GameConstants.defaultGameDuration}s',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    // Option: Live
                    SwitchListTile(
                      value: enableLive,
                      onChanged: (v) => setSheetState(() => enableLive = v),
                      title: const Text('Diffuser en direct', style: TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: const Text('Les autres joueurs peuvent suivre ta partie', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      secondary: const Icon(Icons.live_tv, color: Colors.redAccent),
                      activeTrackColor: Colors.redAccent,
                      contentPadding: EdgeInsets.zero,
                    ),
                    // Option: Caméra
                    SwitchListTile(
                      value: enableCamera,
                      onChanged: (v) => setSheetState(() => enableCamera = v),
                      title: const Text('Activer ma caméra', style: TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: const Text('Montre ton visage pendant la partie', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      secondary: const Icon(Icons.videocam, color: Colors.blueAccent),
                      activeTrackColor: Colors.blueAccent,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _launchGame(context, gameType, enableLive: enableLive, enableCamera: enableCamera);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Commencer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _launchGame(BuildContext context, String gameType, {required bool enableLive, required bool enableCamera}) {
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
          enableLive: enableLive,
          enableCamera: enableCamera,
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

/// Écran de jeu principal — utilise des widgets Flutter natifs (responsive mobile)
class GamePlayScreen extends StatefulWidget {
  final GameSession session;
  final GameProvider gameProvider;
  final bool enableLive;
  final bool enableCamera;

  const GamePlayScreen({
    super.key,
    required this.session,
    required this.gameProvider,
    this.enableLive = true,
    this.enableCamera = false,
  });

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  late GameScoringSystem _scoringSystem;
  bool _isRecording = false;
  bool _isProcessingVideo = false;
  bool _isPaused = false;
  bool _isGameOver = false;
  final GlobalKey _gameBoundaryKey = GlobalKey();
  String? _uploadedAssetId;
  Map<String, dynamic>? _uploadedPlayback;

  // LiveKit room for live streaming during gameplay
  lk.Room? _lkRoom;
  bool _faceCamOn = false; // Caméra frontale OFF par défaut

  // Timer interne (remplace le timer Flame)
  int _timeRemaining = GameConstants.defaultGameDuration;
  Timer? _timer;
  int _gameViewKey = 0; // pour forcer le rebuild du jeu

  @override
  void initState() {
    super.initState();
    _scoringSystem = GameScoringSystem();
    _scoringSystem.startNewGame();
    _timeRemaining = widget.session.duration;
    _startTimer();
    // Démarrer automatiquement l'enregistrement + live
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoStartRecordingAndLive());
  }

  Future<void> _autoStartRecordingAndLive() async {
    // 1. Démarrer l'enregistrement EN PREMIER (local, instantané)
    GameplayRecorderService.boundaryKey = _gameBoundaryKey;
    final started = await GameplayRecorderService.startRecording();
    if (mounted && started) {
      setState(() => _isRecording = true);
    }
    debugPrint('[GamePlay] Recording started: $started');

    // 2. Démarrer le live (réseau) — crée session DB + Presence
    String? sessionId;
    if (widget.enableLive) {
      try {
        sessionId = await GameLiveService.startLive(gameType: widget.session.gameType);
      } catch (e) {
        debugPrint('[GamePlay] Live start failed (non-blocking): $e');
      }
    }

    // 3. Connecter à LiveKit pour le live
    if (sessionId != null && sessionId.isNotEmpty) {
      try {
        final tokenData = await LivekitTokenService.getTokenForSession(sessionId);
        final token = tokenData['token'] as String?;
        final url = tokenData['url'] as String?;
        if (token != null && url != null && token.isNotEmpty && url.isNotEmpty) {
          final room = lk.Room(roomOptions: AcademiaRoomOptions.gameplay);
          await room.connect(url, token);
          // Micro ON pour les commentaires audio du joueur
          await room.localParticipant?.setMicrophoneEnabled(true);
          // Caméra selon le choix du joueur
          if (widget.enableCamera) {
            await room.localParticipant?.setCameraEnabled(true);
            _faceCamOn = true;
          }
          _lkRoom = room;
          debugPrint('[GamePlay] LiveKit connected: room=${tokenData['room_name']}');
        }
      } catch (e) {
        debugPrint('[GamePlay] LiveKit connect failed (non-blocking): $e');
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isPaused || _isGameOver) return;
      setState(() {
        _timeRemaining--;
        if (_timeRemaining <= 0) {
          _timeRemaining = 0;
          _isGameOver = true;
          _timer?.cancel();
          _showGameEndDialog();
        }
      });
    });
  }

  void _addScore(int pts) {
    if (_isGameOver) return;
    _scoringSystem.addCorrectAnswer(bonusPoints: pts > GameConstants.correctAnswerPoints ? pts - GameConstants.correctAnswerPoints : 0);
    setState(() {});
  }

  void _subtractScore(int pts) {
    if (_isGameOver) return;
    _scoringSystem.addWrongAnswer();
    setState(() {});
  }

  void _onGameEvent(String event) {
    debugPrint('Game event: $event');
  }

  void _onGameEnd() {
    if (_isGameOver) return;
    _isGameOver = true;
    _timer?.cancel();
    _showGameEndDialog();
  }

  Widget _buildFlutterGameView() {
    switch (widget.session.gameType) {
      case GameConstants.marketMaster:
        return FlutterMarketMasterView(
          key: ValueKey('mm_$_gameViewKey'),
          onAddScore: _addScore,
          onSubtractScore: _subtractScore,
          onGameEvent: _onGameEvent,
          onGameEnd: _onGameEnd,
        );
      case GameConstants.consumerChoice:
        return FlutterConsumerChoiceView(
          key: ValueKey('cc_$_gameViewKey'),
          onAddScore: _addScore,
          onSubtractScore: _subtractScore,
          onGameEvent: _onGameEvent,
          onGameEnd: _onGameEnd,
        );
      case GameConstants.firmTycoon:
        return FlutterFirmTycoonView(
          key: ValueKey('ft_$_gameViewKey'),
          onAddScore: _addScore,
          onSubtractScore: _subtractScore,
          onGameEvent: _onGameEvent,
          onGameEnd: _onGameEnd,
        );
      case GameConstants.marketStructures:
        return FlutterMarketStructuresView(
          key: ValueKey('ms_$_gameViewKey'),
          onAddScore: _addScore,
          onSubtractScore: _subtractScore,
          onGameEvent: _onGameEvent,
          onGameEnd: _onGameEnd,
        );
      default:
        return FlutterMarketMasterView(
          key: ValueKey('def_$_gameViewKey'),
          onAddScore: _addScore,
          onSubtractScore: _subtractScore,
          onGameEvent: _onGameEvent,
          onGameEnd: _onGameEnd,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
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
          // Toggle caméra frontale (PiP)
          if (_lkRoom != null)
            IconButton(
              icon: Icon(
                _faceCamOn ? Icons.videocam : Icons.videocam_off,
                color: _faceCamOn ? Colors.greenAccent : Colors.white54,
                size: 24,
              ),
              tooltip: _faceCamOn ? 'Masquer ma caméra' : 'Afficher ma caméra',
              onPressed: _toggleFaceCam,
            ),
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            onPressed: _togglePause,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 400;
          final scoreFontSize = isSmall ? 13.0 : 18.0;
          final scoreBarPad = isSmall ? 8.0 : 14.0;

          return Column(
            children: [
              // Panneau de score
              Container(
                padding: EdgeInsets.symmetric(horizontal: scoreBarPad, vertical: scoreBarPad * 0.6),
                color: Colors.black87,
                child: Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Score : ${_scoringSystem.currentScore}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: scoreFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Temps : $_timeRemaining',
                          style: TextStyle(
                            color: _timeRemaining <= 10 ? Colors.red : Colors.white,
                            fontSize: scoreFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Combo : x${_scoringSystem.comboMultiplier}',
                          style: TextStyle(
                            color: Colors.yellow,
                            fontSize: scoreFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
              // Overlay pause
              if (_isPaused)
                Container(
                  color: Colors.orange.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pause_circle, color: Colors.orange, size: 16),
                      SizedBox(width: 6),
                      Text('Jeu en pause', style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              // Zone de jeu Flutter (enveloppée dans RepaintBoundary pour capture)
              Expanded(
                child: Stack(
                  children: [
                    RepaintBoundary(
                      key: _gameBoundaryKey,
                      child: IgnorePointer(
                        ignoring: _isPaused || _isGameOver,
                        child: Opacity(
                          opacity: _isPaused ? 0.4 : 1.0,
                          child: _buildFlutterGameView(),
                        ),
                      ),
                    ),
                    // PiP caméra frontale du joueur (coin bas-droite)
                    if (_faceCamOn && _lkRoom?.localParticipant != null)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _buildLocalCameraPreview(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
  }

  Future<void> _toggleFaceCam() async {
    _faceCamOn = !_faceCamOn;
    try {
      await _lkRoom?.localParticipant?.setCameraEnabled(_faceCamOn);
    } catch (e) {
      debugPrint('[GamePlay] Toggle camera error: $e');
    }
    if (mounted) setState(() {});
  }

  Widget _buildLocalCameraPreview() {
    final local = _lkRoom?.localParticipant;
    if (local == null) return const SizedBox.shrink();
    for (final pub in local.videoTrackPublications) {
      if (pub.source == lk.TrackSource.camera && pub.track is lk.VideoTrack) {
        return lk.VideoTrackRenderer(pub.track as lk.VideoTrack);
      }
    }
    return const Icon(Icons.videocam_off, color: Colors.white38);
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

      // Compression DISABLED - handled by Kamatera Edge Functions
      // Use raw video directly
      final watermarkedPath = await WatermarkService.addWatermark(rawPath);
      if (!mounted) return;

      setState(() => _isProcessingVideo = false);

      // Naviguer vers l'écran de publication
      final videoFile = File(watermarkedPath);
      if (!await videoFile.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fichier vidéo introuvable')),
        );
        return;
      }

      if (!mounted) return;

      // Proposer : publier dans le feed OU partager en externe
      _showPublishOrShareDialog(watermarkedPath);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingVideo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  void _showAutoPublishedDialog(String videoPath) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Icon(Icons.check_circle, size: 48, color: Color(0xFF1EA75C)),
            const SizedBox(height: 8),
            const Text('Vidéo publiée dans le feed !', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Ta vidéo de gameplay est maintenant visible par tous.',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _shareVideoExternal(videoPath);
                },
                icon: const Icon(Icons.share, size: 20),
                label: const Text('Partager (WhatsApp, Facebook, TikTok)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1EA75C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Fermer', style: TextStyle(color: Colors.grey[500])),
            ),
          ],
        ),
      ),
    );
  }

  void _showPublishOrShareDialog(String videoPath) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Gameplay enregistré !',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Avec le watermark Academia',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            // Bouton publier dans le feed
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  final url = (_uploadedPlayback?['best_url'] as String?) ?? videoPath;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VideoPublishScreen(
                        videoUrl: url,
                        videoType: 'free',
                        overlays: const {},
                        pendingVideoAssetId: _uploadedAssetId,
                        pendingPlayback: _uploadedPlayback,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.publish, size: 20),
                label: const Text('Publier dans le feed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1EA75C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Bouton partager en externe
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _shareVideoExternal(videoPath);
                },
                icon: const Icon(Icons.share, size: 20),
                label: const Text('Partager (WhatsApp, Facebook...)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Bouton annuler
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Plus tard', style: TextStyle(color: Colors.grey[500])),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareVideoExternal(String videoPath) async {
    try {
      final xFile = XFile(videoPath);
      await Share.shareXFiles(
        [xFile],
        text: 'Mon gameplay sur Academia ! 🎮🔥\nTélécharge Academia pour jouer.',
        subject: 'Gameplay Academia',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de partage : $e')),
        );
      }
    }
  }

  void _showGameEndDialog() {
    // Arrêter l'enregistrement et le live automatiquement
    _autoStopRecordingAndLive();

    // Conserver la partie (29/07/2026). Sans cette trace, le score disparaissait
    // avec l'écran : ni classement, ni progression n'étaient possibles.
    // L'enregistrement ne bloque pas l'affichage : il se fait en parallèle et le
    // record personnel s'affiche dès qu'il est connu.
    final recorded = GameResultsService.record(
      gameType: widget.session.gameType,
      score: _scoringSystem.currentScore,
      correctAnswers: _scoringSystem.totalCorrectAnswers,
      wrongAnswers: _scoringSystem.totalWrongAnswers,
      bestStreak: _scoringSystem.meilleureSerie,
      durationSec: GameConstants.defaultGameDuration - _timeRemaining,
    );

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Fin de partie !'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Score final : ${_scoringSystem.currentScore}'),
            FutureBuilder<GameResultOutcome?>(
              future: recorded,
              builder: (context, snap) {
                final outcome = snap.data;
                if (outcome == null) {
                  // Hors ligne, ou enregistrement encore en cours : on retombe
                  // sur le meilleur score local, jamais sur un écran vide.
                  return Text('Meilleur score : ${_scoringSystem.highScore}');
                }
                if (outcome.isPersonalBest) {
                  return const Text(
                    'Nouveau record personnel !',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1EA75C)),
                  );
                }
                return Text('Ton record : ${outcome.personalBest}');
              },
            ),
            const SizedBox(height: 16),
            const Text('Statistiques :'),
            Text('Bonnes réponses : ${_scoringSystem.totalCorrectAnswers}'),
            Text('Mauvaises réponses : ${_scoringSystem.totalWrongAnswers}'),
            // « Score moyen » affichait invariablement 0.0 : la moyenne n'est
            // calculée que par `endGame()`, que personne n'appelait. On montre
            // la meilleure série, qui est vraie et qui veut dire quelque chose
            // pour l'étudiant — plutôt qu'une statistique fausse mais stable.
            Text('Meilleure série : ${_scoringSystem.meilleureSerie}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Retour aux jeux'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _restartGame();
            },
            child: const Text('Rejouer'),
          ),
        ],
      ),
    );
  }

  Future<void> _autoStopRecordingAndLive() async {
    // 1. endLive sera appelé après l'upload pour inclure le replay

    // 2. Arrêter l'enregistrement → encoder → watermark → upload → auto-publier
    // On tente TOUJOURS l'arrêt, même si _isRecording est false
    setState(() {
      _isRecording = false;
      _isProcessingVideo = true;
    });

    try {
      final rawPath = await GameplayRecorderService.stopRecording();
      if (rawPath == null || !mounted) {
        if (mounted) {
          setState(() => _isProcessingVideo = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucune vidéo enregistrée (0 frame).')),
          );
        }
        return;
      }
      debugPrint('[GamePlay] Raw video: $rawPath');

      // Compression DISABLED - handled by Kamatera Edge Functions
      // Use raw video directly
      final watermarkedPath = await WatermarkService.addWatermark(rawPath);
      if (!mounted) return;

      final videoFile = File(watermarkedPath);
      if (!await videoFile.exists()) {
        if (mounted) setState(() => _isProcessingVideo = false);
        return;
      }

      // 3. Uploader vers Supabase Storage (pipeline existant)
      debugPrint('[GamePlay] Upload vers Supabase Storage...');
      final bytes = await videoFile.readAsBytes();
      final fileName = 'gameplay_eco_${DateTime.now().millisecondsSinceEpoch}.mp4';

      try {
        _uploadedAssetId = await VideoAssetUploadService.ingestVideoFromBytes(
          fileOrBytes: videoFile,
          fileName: fileName,
          origin: 'student_gameplay',
          contextType: 'free_video',
        );
        debugPrint('[GamePlay] VideoAsset créé: $_uploadedAssetId');

        _uploadedPlayback = await VideoAssetUploadService.triggerTranscode(
          videoAssetId: _uploadedAssetId!,
        );
        debugPrint('[GamePlay] Playback manifest: $_uploadedPlayback');
      } catch (e) {
        debugPrint('[GamePlay] Upload/transcode error: $e');
      }

      // 4. Déconnecter LiveKit et terminer le live
      try {
        _lkRoom?.disconnect();
        _lkRoom?.dispose();
        _lkRoom = null;
      } catch (_) {}
      GameLiveService.endLive(
        scoreFinal: _scoringSystem.currentScore,
        replayVideoAssetId: _uploadedAssetId,
      );

      // 5. Auto-publier dans le feed comme free_video
      String? publishedId;
      if (_uploadedAssetId != null && _uploadedPlayback != null && mounted) {
        try {
          final provider = context.read<StudentChallengesProvider>();
          publishedId = await provider.createFreeVideo(
            videoAssetId: _uploadedAssetId!,
            playback: _uploadedPlayback!,
            title: 'Gameplay ${widget.session.gameType}',
          );
          debugPrint('[GamePlay] Auto-publié dans le feed: $publishedId');
        } catch (e) {
          debugPrint('[GamePlay] Auto-publish error: $e');
        }
      }

      if (!mounted) return;
      setState(() => _isProcessingVideo = false);

      if (publishedId != null) {
        _showAutoPublishedDialog(watermarkedPath);
      } else {
        _showPublishOrShareDialog(watermarkedPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingVideo = false);
        debugPrint('[GamePlay] Erreur traitement vidéo: $e');
      }
    }
  }

  void _restartGame() {
    setState(() {
      _scoringSystem.startNewGame();
      _timeRemaining = widget.session.duration;
      _isPaused = false;
      _isGameOver = false;
      _gameViewKey++;
    });
    _startTimer();
    // Redémarrer enregistrement + live pour la nouvelle partie
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoStartRecordingAndLive());
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_isRecording) {
      GameplayRecorderService.cancelRecording();
    }
    // Disconnect LiveKit if still connected
    try {
      _lkRoom?.disconnect();
      _lkRoom?.dispose();
      _lkRoom = null;
    } catch (_) {}
    if (GameLiveService.isLive) {
      GameLiveService.cancelLive();
    }
    _scoringSystem.dispose();
    super.dispose();
  }
}

