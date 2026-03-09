import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// Enregistreur audio pour les communautés (plateformes non-web).
///
/// Stratégie : tente AAC LC d'abord (petit fichier, bonne qualité).
/// Si le codec AAC n'est pas disponible sur l'appareil (ex: TECNO LD7,
/// certains appareils bas de gamme Android 10), bascule automatiquement
/// sur WAV (PCM 16 bits) qui fonctionne sur 100% des appareils Android.
class CommunityAudioRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;
  String _currentExt = 'm4a';

  /// Extension du dernier enregistrement ('m4a' ou 'wav').
  String get fileExtension => _currentExt;

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<void> start() async {
    final tempDir = Directory.systemTemp;
    final ts = DateTime.now().millisecondsSinceEpoch;

    // ── Tentative 1 : AAC LC (.m4a) ──
    try {
      final aacPath = '${tempDir.path}/community_recording_$ts.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: aacPath,
      );
      _currentPath = aacPath;
      _currentExt = 'm4a';
      debugPrint('[CommunityAudioRecorder] Started AAC → $aacPath');
      return;
    } catch (e) {
      debugPrint('[CommunityAudioRecorder] AAC failed ($e), falling back to WAV');
    }

    // ── Tentative 2 : WAV PCM 16 bits (fallback universel) ──
    try {
      final wavPath = '${tempDir.path}/community_recording_$ts.wav';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: wavPath,
      );
      _currentPath = wavPath;
      _currentExt = 'wav';
      debugPrint('[CommunityAudioRecorder] Started WAV → $wavPath');
      return;
    } catch (e) {
      debugPrint('[CommunityAudioRecorder] WAV also failed: $e');
      rethrow;
    }
  }

  Future<Uint8List?> stop() async {
    final path = await _recorder.stop();
    if (path == null || path.isEmpty) {
      debugPrint('[CommunityAudioRecorder] stop() returned null path');
      return null;
    }
    final file = File(path);
    if (!await file.exists()) {
      debugPrint('[CommunityAudioRecorder] File does not exist: $path');
      return null;
    }
    final bytes = await file.readAsBytes();
    debugPrint('[CommunityAudioRecorder] Recorded ${bytes.length} bytes ($_currentExt)');
    return bytes;
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
