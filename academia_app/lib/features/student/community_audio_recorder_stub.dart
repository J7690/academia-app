import 'dart:typed_data';

/// Stub pour les plateformes web où l'enregistrement audio n'est pas supporté.
class CommunityAudioRecorder {
  String get fileExtension => 'm4a';

  Future<bool> hasPermission() async => false;

  Future<void> start() async {
    throw UnsupportedError('Enregistrement audio non supporté sur cette plateforme.');
  }

  Future<Uint8List?> stop() async {
    return null;
  }

  Future<void> dispose() async {}
}
