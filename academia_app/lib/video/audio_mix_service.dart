import 'dart:io';

import 'package:flutter/foundation.dart';
// import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
// import 'package:ffmpeg_kit_flutter_new_audio/ffprobe_kit.dart';
// import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// DJ-style volume segment: controls volume of original audio OR music
// at a specific time range.
// ─────────────────────────────────────────────────────────────────────────────

/// A volume automation segment — like a DJ fader at a specific time range.
///
/// Example: between 5s–8s, lower the original audio to 20% so the music
/// dominates, then between 8s–10s fade the original back to 100%.
class VolumeSegment {
  final double startSec;
  final double endSec;
  final double volume; // 0.0 to 1.0

  const VolumeSegment({
    required this.startSec,
    required this.endSec,
    required this.volume,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// AudioMixService
// ─────────────────────────────────────────────────────────────────────────────

class AudioMixService {
  AudioMixService._();

  /// Downloads [url] to a temporary file and returns its path.
  static Future<String?> _downloadAudio(String url) async {
    try {
      debugPrint('[AudioMix] Downloading: $url');
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        debugPrint('[AudioMix] Download HTTP ${response.statusCode}');
        return null;
      }
      final tempDir = await Directory.systemTemp.createTemp('acad_audio_');
      final file = File('${tempDir.path}/bg_music.mp3');
      await file.writeAsBytes(response.bodyBytes);
      debugPrint('[AudioMix] Downloaded ${response.bodyBytes.length} bytes -> ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('[AudioMix] Download error: $e');
      return null;
    }
  }

  /// Probes whether the video file has an audio stream.
  static Future<bool> _videoHasAudio(String videoPath) async {
    try {
      // DISABLED for release white-screen test
      // final session = await FFprobeKit.getMediaInformation(videoPath);
      // final info = session.getMediaInformation();
      // if (info == null) return false;
      // final streams = info.getStreams();
      // for (final s in streams) {
      //   final type = s.getType();
      //   if (type != null && type.toLowerCase() == 'audio') return true;
      // }
      // return false;
      return false;
    } catch (e) {
      debugPrint('[AudioMix] Probe error: $e');
      return false;
    }
  }

  /// Probes a file and returns a diagnostic string about its streams.
  /// Used to verify that the mixed output actually contains audio.
  static Future<String> diagnoseMixedFile(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) return 'FILE_NOT_FOUND';
      final size = await f.length();
      // DISABLED for release white-screen test
      // final session = await FFprobeKit.getMediaInformation(path);
      // final info = session.getMediaInformation();
      // if (info == null) return 'PROBE_FAILED (size=$size)';
      // final streams = info.getStreams();
      // final streamDescs = <String>[];
      // for (final s in streams) {
      //   final type = s.getType() ?? '?';
      //   final codec = s.getCodec() ?? '?';
      //   streamDescs.add('$type/$codec');
      // }
      // final duration = info.getDuration() ?? '?';
      // return 'OK size=$size duration=$duration streams=[${streamDescs.join(", ")}]';
      return 'DISABLED (size=$size)';
    } catch (e) {
      return 'PROBE_ERROR: $e';
    }
  }

  /// Executes an FFmpeg command via argument list (avoids all quoting issues).
  static Future<String?> _execArgs(List<String> args, String outputPath) async {
    debugPrint('[AudioMix] ════════════════════════════════════════');
    debugPrint('[AudioMix] ARGS (${args.length}): ${args.join(' | ')}');
    debugPrint('[AudioMix] ════════════════════════════════════════');

    // DISABLED for release white-screen test
    // final session = await FFmpegKit.executeWithArguments(args);
    // final rc = await session.getReturnCode();
    // if (ReturnCode.isSuccess(rc)) {
    //   final f = File(outputPath);
    //   if (await f.exists() && await f.length() > 0) {
    //     debugPrint('[AudioMix] OK: $outputPath (${await f.length()} bytes)');
    //     return outputPath;
    //   }
    //   debugPrint('[AudioMix] RC success but output file missing or empty');
    // }
    // final logs = await session.getAllLogsAsString();
    // debugPrint('[AudioMix] FAIL rc=$rc');
    // final logStr = logs ?? '';
    // for (var i = 0; i < logStr.length; i += 800) {
    //   final end = (i + 800).clamp(0, logStr.length);
    //   debugPrint('[AudioMix] LOG: ${logStr.substring(i, end)}');
    // }
    // return null;
    debugPrint('[AudioMix] DISABLED — FFmpegKit not available');
    return null;
  }

  /// Mixes a background audio track into a video.
  ///
  /// **DJ-style volume segments**: Pass [originalVolumeSegments] to control
  /// the original audio volume at specific time ranges, and
  /// [musicVolumeSegments] to control the background music volume.
  ///
  /// Example — between 5s–8s lower original to 20%, music stays at 60%:
  /// ```dart
  /// originalVolumeSegments: [VolumeSegment(startSec: 5, endSec: 8, volume: 0.2)]
  /// musicVolumeSegments: [VolumeSegment(startSec: 5, endSec: 8, volume: 0.6)]
  /// ```
  static Future<String?> mixAudioIntoVideo({
    required String videoPath,
    required String audioUrl,
    int trimStartMs = 0,
    int? trimEndMs,
    double musicVolume = 0.5,
    double originalVolume = 1.0,
    bool loop = true,
    List<VolumeSegment> originalVolumeSegments = const [],
    List<VolumeSegment> musicVolumeSegments = const [],
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) return null;

    // ── Step 1: Download audio ──
    onProgress?.call(0.05);
    final audioPath = await _downloadAudio(audioUrl);
    if (audioPath == null) {
      debugPrint('[AudioMix] Audio download failed, aborting.');
      return null;
    }
    onProgress?.call(0.15);

    // ── Step 2: Probe video for audio stream ──
    final hasOriginalAudio = await _videoHasAudio(videoPath);
    debugPrint('[AudioMix] Video has audio: $hasOriginalAudio');
    onProgress?.call(0.2);

    // ── Step 3: Prepare paths ──
    final tempDir = await Directory.systemTemp.createTemp('acad_mix_');
    final outputPath = '${tempDir.path}/mixed_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final trimStartSec = trimStartMs / 1000.0;
    final trimDurationSec = trimEndMs != null && trimEndMs > trimStartMs
        ? (trimEndMs - trimStartMs) / 1000.0
        : null;

    // ── Step 4: Build FFmpeg command ──
    String? result;

    if (hasOriginalAudio) {
      result = await _mixWithOriginalAudio(
        videoPath: videoPath,
        audioPath: audioPath,
        outputPath: outputPath,
        trimStartSec: trimStartSec,
        trimDurationSec: trimDurationSec,
        musicVolume: musicVolume,
        originalVolume: originalVolume,
        loop: loop,
        originalVolumeSegments: originalVolumeSegments,
        musicVolumeSegments: musicVolumeSegments,
      );
    } else {
      result = await _addMusicOnly(
        videoPath: videoPath,
        audioPath: audioPath,
        outputPath: outputPath,
        trimStartSec: trimStartSec,
        trimDurationSec: trimDurationSec,
        musicVolume: musicVolume,
        loop: loop,
        musicVolumeSegments: musicVolumeSegments,
      );
    }

    onProgress?.call(0.9);

    // Clean up downloaded audio
    try { await File(audioPath).parent.delete(recursive: true); } catch (_) {}

    onProgress?.call(1.0);
    return result;
  }

  /// Builds a volume filter string for the -filter_complex graph.
  ///
  /// No segments → `volume=0.70`
  /// With segments → uses `volume` with `enable` for each segment, chained.
  ///
  /// NOTE: When used inside -filter_complex passed as a single argument to
  /// executeWithArguments, NO shell escaping is needed.
  static String _buildVolumeFilter(
    double baseVolume,
    List<VolumeSegment> segments,
  ) {
    if (segments.isEmpty) {
      return 'volume=${baseVolume.toStringAsFixed(2)}';
    }

    // Build nested if(between()) expression for eval=frame.
    // No shell quoting needed — executeWithArguments passes args directly.
    // e.g. volume=if(between(t\,5\,8)\,0.20\,0.70):eval=frame
    // Commas inside the expression must be escaped with backslash since
    // FFmpeg uses commas as filter separators in filter_complex.
    String expr = baseVolume.toStringAsFixed(2);
    for (final seg in segments.reversed) {
      final s = seg.startSec.toStringAsFixed(2);
      final e = seg.endSec.toStringAsFixed(2);
      final v = seg.volume.toStringAsFixed(2);
      expr = 'if(between(t\\,$s\\,$e)\\,$v\\,$expr)';
    }
    return 'volume=$expr:eval=frame';
  }

  /// Mix video's original audio with background music (DJ mode).
  static Future<String?> _mixWithOriginalAudio({
    required String videoPath,
    required String audioPath,
    required String outputPath,
    required double trimStartSec,
    double? trimDurationSec,
    required double musicVolume,
    required double originalVolume,
    required bool loop,
    required List<VolumeSegment> originalVolumeSegments,
    required List<VolumeSegment> musicVolumeSegments,
  }) async {
    final origFilter = _buildVolumeFilter(originalVolume, originalVolumeSegments);
    final musicFilter = _buildVolumeFilter(musicVolume, musicVolumeSegments);

    debugPrint('[AudioMix] origFilter: $origFilter');
    debugPrint('[AudioMix] musicFilter: $musicFilter');

    // Build the filter_complex graph as a single string.
    // amix with weights=1 1 prevents the default volume halving (amix divides
    // each input by N=2 by default).
    final filterGraph =
        '[0:a]$origFilter[orig];'
        '[1:a]$musicFilter[music];'
        '[orig][music]amix=inputs=2:duration=first:dropout_transition=2:weights=1|1:normalize=0[aout]';

    debugPrint('[AudioMix] filterGraph: $filterGraph');

    // Build argument list — each element is one argument, no shell quoting needed.
    final args = <String>[
      '-i', videoPath,
      if (loop) ...[ '-stream_loop', '-1'],
      '-ss', trimStartSec.toStringAsFixed(3),
      if (trimDurationSec != null && trimDurationSec > 0)
        ...['-t', trimDurationSec.toStringAsFixed(3)],
      '-i', audioPath,
      '-filter_complex', filterGraph,
      '-map', '0:v',
      '-map', '[aout]',
      '-c:v', 'copy',
      '-c:a', 'aac',
      '-b:a', '192k',
      '-shortest',
      '-y', outputPath,
    ];

    return _execArgs(args, outputPath);
  }

  /// Add music as the only audio track (video has no original audio).
  static Future<String?> _addMusicOnly({
    required String videoPath,
    required String audioPath,
    required String outputPath,
    required double trimStartSec,
    double? trimDurationSec,
    required double musicVolume,
    required bool loop,
    required List<VolumeSegment> musicVolumeSegments,
  }) async {
    final musicFilter = _buildVolumeFilter(musicVolume, musicVolumeSegments);

    debugPrint('[AudioMix] musicFilter (no orig): $musicFilter');

    final filterGraph = '[1:a]${musicFilter}[music]';

    debugPrint('[AudioMix] filterGraph: $filterGraph');

    final args = <String>[
      '-i', videoPath,
      if (loop) ...['-stream_loop', '-1'],
      '-ss', trimStartSec.toStringAsFixed(3),
      if (trimDurationSec != null && trimDurationSec > 0)
        ...['-t', trimDurationSec.toStringAsFixed(3)],
      '-i', audioPath,
      '-filter_complex', filterGraph,
      '-map', '0:v',
      '-map', '[music]',
      '-c:v', 'copy',
      '-c:a', 'aac',
      '-b:a', '192k',
      '-shortest',
      '-y', outputPath,
    ];

    return _execArgs(args, outputPath);
  }
}
