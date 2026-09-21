import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

// Activé par défaut depuis l'application de la migration Phase 3 le 21/09/2026.
// Pour désactiver : --dart-define=APPLICATION_MESSAGE_MEDIA_ENABLED=false
const applicationMessageMediaEnabled =
    bool.fromEnvironment('APPLICATION_MESSAGE_MEDIA_ENABLED', defaultValue: true);

class ApplicationMediaFile {
  const ApplicationMediaFile(this.bytes, this.type, this.mime, this.extension);
  final Uint8List bytes;
  final String type;
  final String mime;
  final String extension;
  static const maxBytes = 25 * 1024 * 1024;

  static const formats = <String, String>{
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
    'm4a': 'audio/mp4',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'ogg': 'audio/ogg',
  };

  factory ApplicationMediaFile.fromBytes(Uint8List bytes, String name) {
    final extension = name.split('.').last.toLowerCase();
    final mime = formats[extension];
    if (mime == null) {
      throw const FormatException('Format de fichier non pris en charge.');
    }
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException(
          'Choisissez un fichier non vide de 25 Mo maximum.');
    }
    return ApplicationMediaFile(bytes, mime.split('/').first, mime, extension);
  }
}

/// Convertit le flux PCM16 mono de record en WAV lisible sur mobile et web.
Uint8List applicationVoiceWav(Uint8List pcm) {
  final result = Uint8List(44 + pcm.length);
  final header = ByteData.sublistView(result);
  void tag(int offset, String text) =>
      result.setRange(offset, offset + 4, text.codeUnits);
  tag(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, 16000, Endian.little);
  header.setUint32(28, 32000, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);
  result.setRange(44, result.length, pcm);
  return result;
}

class ApplicationMediaService {
  ApplicationMediaService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;
  static const bucket = 'application-media';

  Future<String> upload(
      String applicationId, String channel, ApplicationMediaFile file) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Reconnectez-vous pour joindre un fichier.');
    }
    if (!['student', 'university'].contains(channel)) {
      throw ArgumentError('Canal invalide');
    }
    final path =
        '$applicationId/$channel/$userId/${const Uuid().v4()}.${file.extension}';
    await _client.storage.from(bucket).uploadBinary(path, file.bytes,
        fileOptions: FileOptions(contentType: file.mime, upsert: false));
    return path;
  }

  Future<void> send(
      {required String applicationId,
      required String sender,
      required String channel,
      required ApplicationMediaFile file,
      required String path,
      required String caption}) async {
    final suffix = sender == 'admin' ? 'admin_to_$channel' : sender;
    if (!['student', 'university', 'admin'].contains(sender)) {
      throw ArgumentError('Rôle invalide');
    }
    final result =
        await _client.rpc('app_add_application_message_from_$suffix', params: {
      'p_application_id': applicationId,
      'p_content': caption.trim(),
      'p_type': file.type,
      'p_media_url': path,
      'p_media_mime': file.mime,
    });
    if (result is! Map || result['success'] != true) {
      throw StateError(
          'Envoi impossible. Vérifiez votre accès à la candidature puis réessayez.');
    }
  }

  Future<String> signedUrl(String path) {
    // La base stocke uniquement un chemin ; les liens expirants ne sont jamais persistés.
    if (path.contains('://') ||
        path.startsWith('/') ||
        path.split('/').length != 4) {
      throw const FormatException('Chemin de pièce jointe invalide.');
    }
    return _client.storage.from(bucket).createSignedUrl(path, 300);
  }

  Future<void> discard(String path) async {
    try {
      // La policy refuse de supprimer un objet déjà lié à un message envoyé.
      await _client.storage.from(bucket).remove([path]);
    } catch (_) {}
  }
}
