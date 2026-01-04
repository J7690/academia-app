import 'dart:io';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Implémentation réelle de l'enregistreur audio pour les plateformes non-web.
class CommunityAudioRecorder {
  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<void> start() async {
    // On laisse le plugin choisir un chemin temporaire, on récupère le path au stop().
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
    );
  }

  Future<Uint8List?> stop() async {
    final path = await _recorder.stop();
    if (path == null || path.isEmpty) {
      return null;
    }
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    return await file.readAsBytes();
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
