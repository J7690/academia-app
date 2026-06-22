import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/mime_type_helper.dart';
import 'tus_upload_service.dart';

class VideoAssetUploadService {
  VideoAssetUploadService._();

  static final SupabaseClient _client = Supabase.instance.client;

  static Future<String> ingestVideoFromBytes({
    required dynamic fileOrBytes, // File or Uint8List
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
    
    // Get file size - only read bytes if needed for direct upload
    late Uint8List bytes;
    late int expectedSize;
    final isFile = fileOrBytes is File;
    
    if (isFile) {
      expectedSize = fileSizeBytes ?? await (fileOrBytes as File).length();
      // Don't read bytes yet - will only read if needed for direct upload
      // For chunked upload, we use the File directly to save memory
    } else if (fileOrBytes is Uint8List) {
      bytes = fileOrBytes;
      expectedSize = fileSizeBytes ?? bytes.length;
    } else {
      throw Exception('fileOrBytes must be File or Uint8List');
    }

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
      // Files >= 6 MB use resumable TUS upload (robust on unstable networks).
      // Smaller files use a single direct upload. Compression/transcoding is
      // handled entirely server-side (Kamatera) after registration.
      final bool useResumable = expectedSize >= TusUploadService.chunkSize;

      if (isFile && useResumable) {
        debugPrint('[VideoAssetUpload] TUS resumable upload (File) ${(expectedSize / 1024 / 1024).toStringAsFixed(1)} MB');
        final publicUrl = await TusUploadService.uploadFile(
          file: fileOrBytes as File,
          bucket: bucket,
          objectPath: path,
          contentType: normalizedMime,
          onProgress: onUploadProgress,
        );
        if (publicUrl == null) {
          throw Exception('Upload résumable (TUS) échoué');
        }
      } else if (!isFile && useResumable) {
        debugPrint('[VideoAssetUpload] TUS resumable upload (bytes) ${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB');
        final tempFile = File(
            '${Directory.systemTemp.path}/tus_${DateTime.now().millisecondsSinceEpoch}.mp4');
        await tempFile.writeAsBytes(bytes);
        try {
          final publicUrl = await TusUploadService.uploadFile(
            file: tempFile,
            bucket: bucket,
            objectPath: path,
            contentType: normalizedMime,
            onProgress: onUploadProgress,
          );
          if (publicUrl == null) {
            throw Exception('Upload résumable (TUS) échoué');
          }
        } finally {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      } else {
        // Small files: single direct upload.
        if (isFile) {
          bytes = await (fileOrBytes as File).readAsBytes();
        }
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
        return data['playback'] as Map<String, dynamic>?;
      }

      debugPrint('[VideoAssetUpload] triggerTranscode: unexpected response=$data');
      return null;
    } catch (e) {
      debugPrint('[VideoAssetUpload] triggerTranscode error: $e');
      return null;
    }
  }
}
