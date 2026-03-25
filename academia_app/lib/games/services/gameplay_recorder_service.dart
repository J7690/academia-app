import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

/// Service d'enregistrement de gameplay pour les jeux Kellenge.
///
/// Capture les frames du widget de jeu via [RepaintBoundary] à
/// intervalles réguliers, puis encode les images en vidéo MP4
/// via [FFmpegKit]. Aucune dépendance native screen recording.
class GameplayRecorderService {
  GameplayRecorderService._();

  static bool _isRecording = false;
  static Timer? _captureTimer;
  static int _frameCount = 0;
  static String? _framesDir;
  static GlobalKey? _boundaryKey;

  /// Fréquence de capture en images par seconde.
  static const int _fps = 10;

  static bool get isRecording => _isRecording;

  /// Clé du [RepaintBoundary] qui entoure la zone de jeu.
  /// Doit être assignée AVANT de démarrer l'enregistrement.
  static GlobalKey? get boundaryKey => _boundaryKey;
  static set boundaryKey(GlobalKey? key) => _boundaryKey = key;

  /// Démarre la capture de frames depuis le [RepaintBoundary]
  /// identifié par [boundaryKey].
  static Future<bool> startRecording() async {
    if (_isRecording) {
      debugPrint('[GameplayRecorder] Déjà en cours');
      return false;
    }

    if (_boundaryKey == null) {
      debugPrint('[GameplayRecorder] boundaryKey non assignée');
      return false;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      _framesDir = '${tempDir.path}/gameplay_frames_${DateTime.now().millisecondsSinceEpoch}';
      await Directory(_framesDir!).create(recursive: true);

      _frameCount = 0;
      _isRecording = true;

      _captureTimer = Timer.periodic(
        Duration(milliseconds: 1000 ~/ _fps),
        (_) => _captureFrame(),
      );

      debugPrint('[GameplayRecorder] Enregistrement démarré ($_fps fps)');
      return true;
    } catch (e) {
      debugPrint('[GameplayRecorder] Erreur démarrage: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Capture une frame du RepaintBoundary et la sauvegarde en PNG.
  static Future<void> _captureFrame() async {
    if (!_isRecording || _boundaryKey == null || _framesDir == null) return;

    try {
      final boundary = _boundaryKey!.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (byteData == null) return;

      final frameNum = _frameCount.toString().padLeft(6, '0');
      final framePath = '$_framesDir/frame_$frameNum.png';
      await File(framePath).writeAsBytes(byteData.buffer.asUint8List());
      _frameCount++;
    } catch (e) {
      // Silently skip failed frames
    }
  }

  /// Arrête la capture et encode les frames en vidéo MP4 via FFmpeg.
  /// Retourne le chemin du fichier MP4, ou `null` en cas d'erreur.
  static Future<String?> stopRecording() async {
    if (!_isRecording) {
      debugPrint('[GameplayRecorder] Pas d\'enregistrement en cours');
      return null;
    }

    _captureTimer?.cancel();
    _captureTimer = null;
    _isRecording = false;

    debugPrint('[GameplayRecorder] Arrêt — $_frameCount frames capturées');

    if (_frameCount == 0 || _framesDir == null) {
      debugPrint('[GameplayRecorder] Aucune frame capturée');
      await _cleanup();
      return null;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/gameplay_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Encoder les frames PNG en vidéo MP4 via FFmpeg
      final cmd = '-framerate $_fps '
          '-i "$_framesDir/frame_%06d.png" '
          '-c:v mpeg4 -q:v 5 '
          '-pix_fmt yuv420p '
          '-y "$outputPath"';

      debugPrint('[GameplayRecorder] FFmpeg: $cmd');

      final session = await FFmpegKit.execute(cmd);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final file = File(outputPath);
        if (await file.exists()) {
          final sizeBytes = await file.length();
          debugPrint(
            '[GameplayRecorder] Vidéo créée: '
            '${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB, '
            '$_frameCount frames',
          );
          await _cleanup();
          return outputPath;
        }
      }

      final logs = await session.getLogsAsString();
      debugPrint('[GameplayRecorder] FFmpeg error: $logs');
      await _cleanup();
      return null;
    } catch (e) {
      debugPrint('[GameplayRecorder] Erreur encodage: $e');
      await _cleanup();
      return null;
    }
  }

  /// Compresse la vidéo pour réduire la taille avant upload.
  static Future<String> compressRecording(String sourcePath) async {
    try {
      debugPrint('[GameplayRecorder] Compression en cours...');
      final info = await VideoCompress.compressVideo(
        sourcePath,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: false,
      );

      if (info != null && info.path != null) {
        final originalSize = await File(sourcePath).length();
        final compressedSize = await File(info.path!).length();
        debugPrint(
          '[GameplayRecorder] Compression: '
          '${(originalSize / 1024 / 1024).toStringAsFixed(1)} MB → '
          '${(compressedSize / 1024 / 1024).toStringAsFixed(1)} MB '
          '(${(100 - compressedSize * 100 / originalSize).toStringAsFixed(0)}% réduit)',
        );
        return info.path!;
      }

      return sourcePath;
    } catch (e) {
      debugPrint('[GameplayRecorder] Erreur compression: $e');
      return sourcePath;
    }
  }

  /// Lit les bytes d'un fichier vidéo.
  static Future<Uint8List> readVideoBytes(String path) async {
    return File(path).readAsBytes();
  }

  /// Annule l'enregistrement en cours.
  static Future<void> cancelRecording() async {
    _captureTimer?.cancel();
    _captureTimer = null;
    _isRecording = false;
    _frameCount = 0;
    await _cleanup();
    debugPrint('[GameplayRecorder] Enregistrement annulé');
  }

  /// Nettoie les frames temporaires.
  static Future<void> _cleanup() async {
    if (_framesDir != null) {
      try {
        final dir = Directory(_framesDir!);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (_) {}
      _framesDir = null;
    }
    _frameCount = 0;
  }
}
