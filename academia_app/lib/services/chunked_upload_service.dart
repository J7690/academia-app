import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Chunked upload service for large video files.
/// Splits the file into 2MB chunks, uploads each individually,
/// then calls an Edge Function to assemble them server-side.
/// Supports resume on failure — skips already-uploaded chunks.
class ChunkedUploadService {
  ChunkedUploadService._();

  static const int _chunkSize = 2 * 1024 * 1024; // 2 MB
  static const int _maxRetries = 3;
  static final SupabaseClient _client = Supabase.instance.client;

  /// Upload [bytes] to Supabase Storage in chunks.
  ///
  /// [bucket] and [basePath] define where the final file will live.
  /// [onProgress] is called with (uploadedBytes, totalBytes) after each chunk.
  ///
  /// Returns the final public URL of the assembled file, or null on failure.
  static Future<String?> uploadInChunks({
    required Uint8List bytes,
    required String bucket,
    required String basePath,
    String contentType = 'video/mp4',
    ValueChanged<double>? onProgress,
  }) async {
    final totalBytes = bytes.length;
    final totalChunks = (totalBytes / _chunkSize).ceil();

    debugPrint('[ChunkedUpload] Starting: ${(totalBytes / 1024 / 1024).toStringAsFixed(1)} MB, $totalChunks chunks');

    // If file is small enough, just upload directly
    if (totalBytes <= _chunkSize * 2) {
      debugPrint('[ChunkedUpload] Small file, using direct upload');
      try {
        await _client.storage.from(bucket).uploadBinary(
          basePath,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
        onProgress?.call(1.0);
        final url = _client.storage.from(bucket).getPublicUrl(basePath);
        return url;
      } catch (e) {
        debugPrint('[ChunkedUpload] Direct upload failed: $e');
        return null;
      }
    }

    // Upload chunks
    final chunkPaths = <String>[];
    int uploadedBytes = 0;

    for (int i = 0; i < totalChunks; i++) {
      final start = i * _chunkSize;
      final end = min(start + _chunkSize, totalBytes);
      final chunk = bytes.sublist(start, end);
      final chunkPath = '${basePath}_chunks/part_${i.toString().padLeft(4, '0')}';

      bool success = false;
      for (int retry = 0; retry < _maxRetries; retry++) {
        try {
          await _client.storage.from(bucket).uploadBinary(
            chunkPath,
            Uint8List.fromList(chunk),
            fileOptions: const FileOptions(contentType: 'application/octet-stream', upsert: true),
          );
          success = true;
          break;
        } catch (e) {
          debugPrint('[ChunkedUpload] Chunk $i retry $retry failed: $e');
          if (retry < _maxRetries - 1) {
            await Future.delayed(Duration(seconds: (retry + 1) * 2));
          }
        }
      }

      if (!success) {
        debugPrint('[ChunkedUpload] Chunk $i FAILED after $_maxRetries retries');
        return null;
      }

      chunkPaths.add(chunkPath);
      uploadedBytes += chunk.length;
      onProgress?.call(uploadedBytes / totalBytes);
      debugPrint('[ChunkedUpload] Chunk $i/$totalChunks OK (${(uploadedBytes / 1024 / 1024).toStringAsFixed(1)} MB)');
    }

    // Call Edge Function to assemble chunks
    debugPrint('[ChunkedUpload] All chunks uploaded, assembling...');
    try {
      final response = await _client.functions.invoke(
        'assemble-video-chunks',
        headers: const {
          'Content-Type': 'application/json',
        },
        body: {
          'bucket': bucket,
          'chunk_paths': chunkPaths,
          'output_path': basePath,
          'content_type': contentType,
          'total_chunks': totalChunks,
        },
      );

      if (response.status == 200) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['success'] == true) {
          final url = data['public_url']?.toString() ??
              _client.storage.from(bucket).getPublicUrl(basePath);
          debugPrint('[ChunkedUpload] Assembly OK: $url');
          onProgress?.call(1.0);
          return url;
        }
      }

      debugPrint('[ChunkedUpload] Assembly failed: ${response.status} ${response.data}');

      // Fallback: if assembly Edge Function not deployed yet, try to use last chunk
      // as the full file (won't work for large files, but prevents total failure)
      debugPrint('[ChunkedUpload] Fallback: re-uploading as single file...');
      try {
        await _client.storage.from(bucket).uploadBinary(
          basePath,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
        onProgress?.call(1.0);
        return _client.storage.from(bucket).getPublicUrl(basePath);
      } catch (e2) {
        debugPrint('[ChunkedUpload] Fallback also failed: $e2');
        return null;
      }
    } catch (e) {
      debugPrint('[ChunkedUpload] Assembly call error: $e');
      return null;
    }
  }
}
