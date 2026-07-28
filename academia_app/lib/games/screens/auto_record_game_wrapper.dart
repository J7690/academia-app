import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/game_live_service.dart';
import '../services/gameplay_recorder_service.dart';
import '../services/watermark_service.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import '../../services/academia_room_options.dart';
import '../../services/livekit_token_service.dart';
import 'package:provider/provider.dart';
import '../../features/student/video_publish_screen.dart';
import '../../providers/student_challenges_provider.dart';
import '../../services/videoasset_upload_service.dart';

/// Permet aux jeux enfants d'appeler [GameRecordController.of(context).onGameFinished()]
/// pour signaler la fin du jeu et déclencher le traitement vidéo.
class GameRecordController extends InheritedWidget {
  final VoidCallback onGameFinished;
  final String? videoPath;
  final bool isProcessing;
  final void Function(String path) publishToFeed;
  final void Function(String path) shareExternal;

  const GameRecordController({
    super.key,
    required super.child,
    required this.onGameFinished,
    required this.videoPath,
    required this.isProcessing,
    required this.publishToFeed,
    required this.shareExternal,
  });

  static GameRecordController? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GameRecordController>();
  }

  @override
  bool updateShouldNotify(GameRecordController oldWidget) =>
      videoPath != oldWidget.videoPath || isProcessing != oldWidget.isProcessing;
}

/// Wrapper qui entoure n'importe quel écran de jeu pour :
/// 1. Démarrer automatiquement l'enregistrement du gameplay
/// 2. Signaler le joueur en live dans le feed (Supabase Presence)
/// 3. Quand le jeu signale sa fin : arrêter, watermark, proposer publier/partager
class AutoRecordGameWrapper extends StatefulWidget {
  final String gameType;
  final Widget child;

  const AutoRecordGameWrapper({
    super.key,
    required this.gameType,
    required this.child,
  });

  @override
  State<AutoRecordGameWrapper> createState() => _AutoRecordGameWrapperState();
}

class _AutoRecordGameWrapperState extends State<AutoRecordGameWrapper> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _isRecording = false;
  bool _isProcessing = false;
  String? _videoPath;
  String? _uploadedAssetId;
  Map<String, dynamic>? _uploadedPlayback;
  bool _gameFinished = false;
  lk.Room? _lkRoom;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoStart());
  }

  Future<void> _autoStart() async {
    // 1. Démarrer l'enregistrement EN PREMIER (local, instantané)
    GameplayRecorderService.boundaryKey = _boundaryKey;
    final started = await GameplayRecorderService.startRecording();
    if (mounted && started) {
      setState(() => _isRecording = true);
    }
    debugPrint('[AutoRecord] Recording started: $started');

    // 2. Démarrer le live dans le feed (réseau) — crée session DB + Presence
    String? sessionId;
    try {
      sessionId = await GameLiveService.startLive(gameType: widget.gameType);
    } catch (e) {
      debugPrint('[AutoRecord] Live start failed (non-blocking): $e');
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
          _lkRoom = room;
          debugPrint('[AutoRecord] LiveKit connected: room=${tokenData['room_name']}');
        }
      } catch (e) {
        debugPrint('[AutoRecord] LiveKit connect failed (non-blocking): $e');
      }
    }
  }

  /// Appelé par le jeu quand il se termine.
  Future<void> _onGameFinished() async {
    if (_gameFinished) return;
    _gameFinished = true;

    // 1. Terminer le live (on passera le replayVideoAssetId après upload)
    // endLive sera appelé après l'upload pour inclure le replay

    // 2. Arrêter l'enregistrement et traiter la vidéo
    // On tente TOUJOURS l'arrêt, même si _isRecording est false
    // (le recording a pu démarrer mais le flag n'a pas été mis à jour)
    setState(() {
      _isRecording = false;
      _isProcessing = true;
    });

    try {
      final rawPath = await GameplayRecorderService.stopRecording();
      if (rawPath == null || !mounted) {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucune vidéo enregistrée (0 frame capturée).')),
          );
        }
        return;
      }
      debugPrint('[AutoRecord] Raw video: $rawPath');

      // Compression DISABLED - handled by Kamatera Edge Functions
      // Use raw video directly
      final watermarked = await WatermarkService.addWatermark(rawPath);
      if (!mounted) return;

      debugPrint('[AutoRecord] Watermarked video: $watermarked');

      final videoFile = File(watermarked);
      if (!await videoFile.exists()) {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fichier vidéo introuvable après traitement.')),
          );
        }
        return;
      }

      // 3. Uploader vers Supabase Storage (pipeline existant)
      debugPrint('[AutoRecord] Upload vers Supabase Storage...');
      final bytes = await videoFile.readAsBytes();
      final fileName = 'gameplay_${widget.gameType}_${DateTime.now().millisecondsSinceEpoch}.mp4';

      String? videoAssetId;
      Map<String, dynamic>? playback;
      try {
        videoAssetId = await VideoAssetUploadService.ingestVideoFromBytes(
          fileOrBytes: videoFile,
          fileName: fileName,
          origin: 'student_gameplay',
          contextType: 'free_video',
        );
        debugPrint('[AutoRecord] VideoAsset créé: $videoAssetId');

        // Déclencher le transcode pour obtenir le manifest playback
        playback = await VideoAssetUploadService.triggerTranscode(
          videoAssetId: videoAssetId!,
        );
        debugPrint('[AutoRecord] Playback manifest: $playback');
      } catch (e) {
        debugPrint('[AutoRecord] Upload/transcode error: $e');
      }

      if (!mounted) return;

      // Stocker le chemin local pour le partage externe
      _videoPath = watermarked;
      _uploadedAssetId = videoAssetId;
      _uploadedPlayback = playback;

      // 4. Déconnecter LiveKit et terminer le live
      try {
        _lkRoom?.disconnect();
        _lkRoom?.dispose();
        _lkRoom = null;
      } catch (_) {}
      GameLiveService.endLive(
        scoreFinal: 0,
        replayVideoAssetId: videoAssetId,
      );

      // 5. Auto-publier dans le feed comme free_video
      String? publishedId;
      if (videoAssetId != null && playback != null && mounted) {
        try {
          final provider = context.read<StudentChallengesProvider>();
          publishedId = await provider.createFreeVideo(
            videoAssetId: videoAssetId,
            playback: playback,
            title: 'Gameplay ${widget.gameType}',
          );
          debugPrint('[AutoRecord] Auto-publié dans le feed: $publishedId');
        } catch (e) {
          debugPrint('[AutoRecord] Auto-publish error: $e');
        }
      }

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (publishedId != null) {
        // Succès: proposer le partage externe
        _showAutoPublishedDialog(watermarked);
      } else if (videoAssetId != null) {
        // Upload OK mais publication échouée: proposer publication manuelle
        _showPublishOrShare(watermarked);
      } else {
        // Upload échoué: proposer quand même le partage du fichier local
        _showPublishOrShare(watermarked);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        debugPrint('[AutoRecord] Erreur: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur vidéo: $e')),
        );
      }
    }
  }

  void _publishToFeed(String path) {
    // Utiliser l'URL Supabase si disponible, sinon le chemin local en fallback
    final url = (_uploadedPlayback?['best_url'] as String?) ?? path;
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
  }

  void _shareExternal(String path) {
    Share.shareXFiles(
      [XFile(path)],
      text: 'Mon gameplay sur Academia ! 🎮🔥\nTélécharge Academia pour jouer.',
    );
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
                  _shareExternal(videoPath);
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

  void _showPublishOrShare(String videoPath) {
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
            const Icon(Icons.videocam, size: 40, color: Color(0xFF1EA75C)),
            const SizedBox(height: 8),
            const Text('Vidéo du gameplay prête !', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Avec le watermark Academia', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _publishToFeed(videoPath);
                },
                icon: const Icon(Icons.publish, size: 20),
                label: const Text('Publier la vidéo dans le feed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1EA75C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _shareExternal(videoPath);
                },
                icon: const Icon(Icons.share, size: 20),
                label: const Text('Partager la vidéo (WhatsApp...)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Plus tard', style: TextStyle(color: Colors.grey[500])),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_isRecording) {
      GameplayRecorderService.cancelRecording();
    }
    try {
      _lkRoom?.disconnect();
      _lkRoom?.dispose();
      _lkRoom = null;
    } catch (_) {}
    if (GameLiveService.isLive) {
      GameLiveService.cancelLive();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameRecordController(
      onGameFinished: _onGameFinished,
      videoPath: _videoPath,
      isProcessing: _isProcessing,
      publishToFeed: _publishToFeed,
      shareExternal: _shareExternal,
      child: Stack(
        children: [
          RepaintBoundary(
            key: _boundaryKey,
            child: widget.child,
          ),
          if (_isRecording)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
                        SizedBox(width: 4),
                        Text('EN DIRECT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Enregistrement en cours...', style: TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
