import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/mime_type_helper.dart';

class VideoAssetUploadService {
  VideoAssetUploadService._();

  static final SupabaseClient _client = Supabase.instance.client;

  static Future<String> ingestVideoFromBytes({
    required Uint8List bytes,
    required String fileName,
    required String origin,
    String? contextType,
    String? contextId,
    String? mimeType,
    int? fileSizeBytes,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Utilisateur non authentifié.');
    }

    final normalizedMime = MimeTypeHelper.normalize(mimeType ?? fileName.split('.').last);
    final expectedSize = fileSizeBytes ?? bytes.length;

    final dynamic intentResponse = await _client.rpc(
      'app_videoasset_create_upload_intent',
      params: {
        'p_origin': origin,
        'p_context_type': contextType,
        'p_context_id': (contextId != null && contextId.trim().isNotEmpty)
            ? contextId.trim()
            : null,
        'p_role': 'primary',
        'p_mime_type': normalizedMime,
        'p_expected_size': expectedSize,
      },
    );

    if (intentResponse is! Map<String, dynamic>) {
      throw Exception('Réponse invalide lors de la création de l\'upload VideoAsset.');
    }
    if (intentResponse['success'] != true) {
      throw Exception(
        intentResponse['error']?.toString() ??
            'Erreur lors de la création de l\'upload VideoAsset.',
      );
    }

    final bucket = intentResponse['storage_bucket']?.toString();
    final path = intentResponse['storage_path']?.toString();
    final sourceId = intentResponse['source_id']?.toString();

    if (bucket == null || bucket.isEmpty || path == null || path.isEmpty) {
      throw Exception('Bucket ou chemin de stockage manquant pour l\'upload VideoAsset.');
    }
    if (sourceId == null || sourceId.isEmpty) {
      throw Exception('Identifiant de source VideoAsset manquant.');
    }

    try {
      await _client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: normalizedMime,
              upsert: true,
            ),
          );
    } on StorageException catch (e) {
      throw Exception(e.toString());
    }

    final dynamic registerResponse = await _client.rpc(
      'app_videoasset_register_uploaded_source',
      params: {
        'p_source_id': sourceId,
        'p_checksum_sha256': null,
        'p_width': null,
        'p_height': null,
        'p_duration_ms': null,
        'p_has_audio': null,
        'p_validation_report': null,
      },
    );

    if (registerResponse is! Map<String, dynamic>) {
      throw Exception('Réponse invalide lors de l\'enregistrement de la source VideoAsset.');
    }
    if (registerResponse['success'] != true) {
      throw Exception(
        registerResponse['error']?.toString() ??
            'Erreur lors de l\'enregistrement de la source VideoAsset.',
      );
    }

    final videoAssetId = registerResponse['video_asset_id']?.toString();
    if (videoAssetId == null || videoAssetId.trim().isEmpty) {
      throw Exception('Identifiant VideoAsset manquant après enregistrement.');
    }

    return videoAssetId.trim();
  }
}
