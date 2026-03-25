import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/mime_type_helper.dart';
import 'chunked_upload_service.dart';

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
    ValueChanged<double>? onUploadProgress,
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
      // Use chunked upload for files > 4MB
      if (bytes.length > 4 * 1024 * 1024) {
        debugPrint('[VideoAssetUpload] Using chunked upload for ${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB file');
        final publicUrl = await ChunkedUploadService.uploadInChunks(
          bytes: bytes,
          bucket: bucket,
          basePath: path,
          contentType: normalizedMime,
          onProgress: onUploadProgress,
        );
        if (publicUrl == null) {
          throw Exception('Chunked upload failed');
        }
      } else {
        // Direct upload for small files
        await _client.storage.from(bucket).uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                contentType: normalizedMime,
                upsert: true,
              ),
            );
        onUploadProgress?.call(1.0);
      }
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

  /// Trigger the transcode-video Edge Function to mark the video_asset as
  /// ready and create the "original" rendition entry.
  /// Returns the playback manifest on success, null on failure.
  static Future<Map<String, dynamic>?> triggerTranscode({
    required String videoAssetId,
    String? posterUrl,
  }) async {
    try {
      debugPrint('[VideoAssetUpload] triggerTranscode: videoAssetId=$videoAssetId');
      final response = await _client.functions.invoke(
        'transcode-video',
        body: {
          'video_asset_id': videoAssetId,
          if (posterUrl != null) 'poster_url': posterUrl,
        },
      );

      if (response.status != 200) {
        debugPrint('[VideoAssetUpload] triggerTranscode: HTTP ${response.status}');
        return null;
      }

      final data = response.data;
      if (data is Map<String, dynamic> && data['success'] == true) {
        debugPrint('[VideoAssetUpload] triggerTranscode OK: ${data['playback']}');

        // Fire-and-forget: trigger multi-resolution transcoding
        _triggerMultiResolution(videoAssetId);

        return data['playback'] as Map<String, dynamic>?;
      }

      debugPrint('[VideoAssetUpload] triggerTranscode: unexpected response=$data');
      return null;
    } catch (e) {
      debugPrint('[VideoAssetUpload] triggerTranscode error: $e');
      return null;
    }
  }

  /// Fire-and-forget: enqueue multi-resolution transcoding jobs (720p, 480p, 240p).
  /// Runs asynchronously after the original transcode succeeds.
  static Future<void> _triggerMultiResolution(String videoAssetId) async {
    try {
      debugPrint('[VideoAssetUpload] triggerMultiResolution: videoAssetId=$videoAssetId');
      final response = await _client.functions.invoke(
        'transcode-multi-resolution',
        body: {'video_asset_id': videoAssetId},
      );
      if (response.status == 200) {
        final data = response.data;
        debugPrint('[VideoAssetUpload] multiResolution OK: jobs=${data is Map ? data['jobs_created'] : '?'}');
      } else {
        debugPrint('[VideoAssetUpload] multiResolution: HTTP ${response.status}');
      }
    } catch (e) {
      debugPrint('[VideoAssetUpload] multiResolution error (non-blocking): $e');
    }
  }
}
