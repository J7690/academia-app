import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
// import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
// import 'package:ffmpeg_kit_flutter_new_audio/ffprobe_kit.dart';
// import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:path_provider/path_provider.dart';

/// Service pour ajouter le watermark Academia sur les vidéos.
///
/// Pipeline professionnel inspiré des best-practices TikTok / Mux / FFmpeg :
///   1. FFprobeKit  → dimensions réelles de la vidéo
///   2. scale       → taille logo en pixels (8% hauteur vidéo) + lanczos
///   3. format=rgba → canal alpha pour la transparence
///   4. colorchannelmixer → opacité 35%
///   5. overlay     → position TikTok-style (4 coins, saut diagonal toutes les 3s)
///   6. pix_fmt yuv420p → compatibilité mobile universelle
class WatermarkService {
  WatermarkService._();

  static String? _cachedLogoPath;

  /// Copie le logo des assets Flutter vers un fichier temporaire
  /// accessible par FFmpeg (qui ne peut pas lire les assets Flutter).
  static Future<String> _ensureLogoFile() async {
    if (_cachedLogoPath != null && await File(_cachedLogoPath!).exists()) {
      return _cachedLogoPath!;
    }

    try {
      final byteData = await rootBundle.load('assets/ACADEMIA_logo1.png');
      final tempDir = await getTemporaryDirectory();
      final logoFile = File('${tempDir.path}/academia_watermark.png');
      await logoFile.writeAsBytes(byteData.buffer.asUint8List());
      _cachedLogoPath = logoFile.path;
      debugPrint('[Watermark] Logo copié: ${logoFile.path} (${byteData.lengthInBytes} bytes)');
      return logoFile.path;
    } catch (e) {
      debugPrint('[Watermark] Erreur copie logo: $e');
      rethrow;
    }
  }

  /// Probes the video to retrieve its height in pixels.
  /// Falls back to 1280 (720p portrait) if probing fails.
  static Future<int> _probeVideoHeight(String videoPath) async {
    try {
      // DISABLED for release white-screen test
      // final session = await FFprobeKit.getMediaInformation(videoPath);
      // final info = session.getMediaInformation();
      // if (info != null) {
      //   for (final s in info.getStreams()) {
      //     final type = s.getType();
      //     if (type != null && type.toLowerCase() == 'video') {
      //       final h = s.getHeight();
      //       if (h != null && h > 0) return h;
      //     }
      //   }
      // }
    } catch (e) {
      debugPrint('[Watermark] Probe failed, using default: $e');
    }
    return 1280;
  }

  /// Runs a single FFmpeg overlay attempt. Returns output path on success, null on failure.
  static Future<String?> _tryOverlay(
    String inputPath,
    String logoPath,
    String outputPath,
    String filter,
    String label,
  ) async {
    debugPrint('[Watermark] ── $label: trying... ──');
    debugPrint('[Watermark] filter=$filter');

    final args = [
      '-i', inputPath,
      '-i', logoPath,
      '-filter_complex', filter,
      '-pix_fmt', 'yuv420p',
      '-c:a', 'copy',
      '-movflags', '+faststart',
      '-y', outputPath,
    ];

    // DISABLED for release white-screen test
    // final session = await FFmpegKit.executeWithArguments(args);
    // final returnCode = await session.getReturnCode();
    // if (ReturnCode.isSuccess(returnCode)) {
    //   final outFile = File(outputPath);
    //   if (await outFile.exists() && await outFile.length() > 1000) {
    //     final sizeKB = (await outFile.length()) / 1024;
    //     debugPrint('[Watermark] ✓ $label OK: ${sizeKB.toStringAsFixed(0)} KB');
    //     return outputPath;
    //   }
    //   debugPrint('[Watermark] ✗ $label: rc=success but output missing/empty');
    // }
    // final logs = await session.getLogsAsString();
    // final snippet = logs.length > 800
    //     ? logs.substring(logs.length - 800)
    //     : logs;
    // debugPrint('[Watermark] ✗ $label FAILED rc=$returnCode:\n$snippet');
    // return null;
    debugPrint('[Watermark] DISABLED — FFmpegKit not available');
    return null;
  }

  /// Ajoute le watermark Academia style TikTok sur la vidéo.
  ///
  /// **3-level fallback strategy :**
  /// 1. TikTok animated (4-corner jump every 3s) + scaled + transparent
  /// 2. Static top-right + scaled + transparent
  /// 3. Minimal raw overlay (no scale, no transparency) — diagnostic only
  ///
  /// [inputPath] chemin vidéo source MP4.
  /// Retourne le chemin de la vidéo watermarkée, ou [inputPath] si tout échoue.
  static Future<String> addWatermark(String inputPath) async {
    debugPrint('[Watermark] ═══════ START addWatermark ═══════');
    try {
      // ── Verify input file ──
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        debugPrint('[Watermark] ✗ Input file missing: $inputPath');
        return inputPath;
      }
      final inputKB = (await inputFile.length()) / 1024;
      debugPrint('[Watermark] Input: ${inputKB.toStringAsFixed(0)} KB — $inputPath');

      // ── Get logo ──
      final logoPath = await _ensureLogoFile();
      final logoFile = File(logoPath);
      if (!await logoFile.exists()) {
        debugPrint('[Watermark] ✗ Logo file missing: $logoPath');
        return inputPath;
      }
      debugPrint('[Watermark] Logo: ${(await logoFile.length())} bytes — $logoPath');

      // ── Probe video dimensions ──
      final videoH = await _probeVideoHeight(inputPath);
      int logoH = (videoH * 0.08).round();
      logoH = math.max(logoH, 24);
      if (logoH.isOdd) logoH += 1;
      final margin = math.max((videoH * 0.04).round(), 10);
      debugPrint('[Watermark] videoH=$videoH → logoH=$logoH margin=$margin');

      final tempDir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      String? result;

      // ── LEVEL 1: Animated TikTok-style overlay ──
      // 4-corner diagonal jump every 3s: TL→BR→TR→BL
      // Commas escaped as \, inside expressions for FFmpeg
      result = await _tryOverlay(
        inputPath,
        logoPath,
        '${tempDir.path}/wm_anim_$ts.mp4',
        '[1:v]format=rgba,scale=-1:$logoH,colorchannelmixer=aa=0.35[wm];'
        '[0:v][wm]overlay='
        'x=if(between(mod(floor(t/3)\\,4)\\,1\\,2)\\,W-w-$margin\\,$margin):'
        'y=if(mod(mod(floor(t/3)\\,4)\\,2)\\,H-h-$margin\\,$margin)',
        'L1-animated',
      );
      if (result != null) return result;

      // ── LEVEL 2: Static overlay at top-right (simpler filter) ──
      result = await _tryOverlay(
        inputPath,
        logoPath,
        '${tempDir.path}/wm_static_$ts.mp4',
        '[1:v]format=rgba,scale=-1:$logoH,colorchannelmixer=aa=0.35[wm];'
        '[0:v][wm]overlay=W-w-$margin:$margin',
        'L2-static',
      );
      if (result != null) return result;

      // ── LEVEL 3: Minimal raw overlay (no scale, no transparency) ──
      // If even this fails, the problem is with FFmpeg itself or the files.
      result = await _tryOverlay(
        inputPath,
        logoPath,
        '${tempDir.path}/wm_raw_$ts.mp4',
        '[0:v][1:v]overlay=10:10',
        'L3-minimal',
      );
      if (result != null) return result;

      debugPrint('[Watermark] ✗✗✗ ALL 3 LEVELS FAILED — returning original video without watermark');
      return inputPath;
    } catch (e, st) {
      debugPrint('[Watermark] ✗ Exception: $e\n$st');
      return inputPath;
    }
  }
}
