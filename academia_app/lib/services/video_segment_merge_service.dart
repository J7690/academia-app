import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to merge multiple video segments with transitions.
/// Uploads segments to temporary storage, calls Edge Function to merge,
/// then returns the merged video URL.
class VideoSegmentMergeService {
  VideoSegmentMergeService._();

  static final SupabaseClient _client = Supabase.instance.client;

  /// Supported transition types
  static const List<VideoTransition> availableTransitions = [
    VideoTransition('none', 'Aucune'),
    VideoTransition('fade', 'Fondu'),
    VideoTransition('dissolve', 'Dissolution'),
    VideoTransition('slide', 'Glissement'),
  ];

  /// Merge multiple video segments with optional transitions.
  /// 
  /// [segmentFiles] - List of video files to merge
  /// [transition] - Transition type between segments
  /// [transitionDurationMs] - Duration of transition in milliseconds
  /// [onProgress] - Progress callback (0.0 to 1.0)
  /// 
  /// Returns the public URL of the merged video
  static Future<String?> mergeSegments({
    required List<File> segmentFiles,
    String transition = 'none',
    int transitionDurationMs = 300,
    ValueChanged<double>? onProgress,
  }) async {
    if (segmentFiles.isEmpty) {
      throw ArgumentError('No segments provided');
    }

    if (segmentFiles.length == 1 && transition == 'none') {
      // Single segment without transition, just upload directly
      debugPrint('[VideoSegmentMerge] Single segment, uploading directly');
      final file = segmentFiles.first;
      final bytes = await file.readAsBytes();
      final fileName = 'merged_${DateTime.now().millisecondsSinceEpoch}.mp4';
      
      final uploadPath = await _uploadToTemporary(bytes, fileName);
      if (uploadPath == null) return null;

      final publicUrlData = _client.storage
          .from('video-assets')
          .getPublicUrl(uploadPath);
      
      onProgress?.call(1.0);
      return publicUrlData;
    }

    debugPrint('[VideoSegmentMerge] Merging ${segmentFiles.length} segments with transition: $transition');

    try {
      // Upload all segments to temporary storage
      final segmentPaths = <String>[];
      final totalSteps = segmentFiles.length + 1; // Upload steps + merge step
      int completedSteps = 0;

      for (int i = 0; i < segmentFiles.length; i++) {
        debugPrint('[VideoSegmentMerge] Uploading segment ${i + 1}/${segmentFiles.length}');
        final file = segmentFiles[i];
        final bytes = await file.readAsBytes();
        final tempName = 'segment_${i.toString().padLeft(3, '0')}_${DateTime.now().millisecondsSinceEpoch}.mp4';
        
        final uploadPath = await _uploadToTemporary(bytes, tempName);
        if (uploadPath == null) {
          throw Exception('Failed to upload segment ${i + 1}');
        }
        
        segmentPaths.add(uploadPath);
        completedSteps++;
        onProgress?.call(completedSteps / totalSteps);
      }

      // Call Edge Function to merge segments
      debugPrint('[VideoSegmentMerge] Calling merge-video-segments Edge Function');
      final outputPath = 'merged_${DateTime.now().millisecondsSinceEpoch}.mp4';
      
      final response = await _client.functions.invoke(
        'merge-video-segments',
        body: {
          'segment_paths': segmentPaths,
          'bucket': 'video-assets',
          'output_path': outputPath,
          'transition': transition,
          'transition_duration_ms': transitionDurationMs,
        },
      );

      if (response.status != 200) {
        final error = response.data?['error'] ?? 'Unknown error';
        throw Exception('Merge failed: $error');
      }

      final publicUrl = response.data?['public_url'];
      if (publicUrl == null) {
        throw Exception('No public URL returned');
      }

      completedSteps++;
      onProgress?.call(1.0);
      
      // Cleanup temporary segments
      _cleanupTemporaryFiles(segmentPaths);

      debugPrint('[VideoSegmentMerge] Merge complete: $publicUrl');
      return publicUrl;

    } catch (e) {
      debugPrint('[VideoSegmentMerge] Error: $e');
      return null;
    }
  }

  /// Upload bytes to temporary storage location
  static Future<String?> _uploadToTemporary(Uint8List bytes, String fileName) async {
    try {
      final path = 'temp/segments/${DateTime.now().millisecondsSinceEpoch}/$fileName';
      await _client.storage
          .from('video-assets')
          .uploadBinary(path, bytes, fileOptions: const FileOptions(
            contentType: 'video/mp4',
            upsert: true,
          ));
      
      return path;
    } catch (e) {
      debugPrint('[VideoSegmentMerge] Upload error: $e');
      return null;
    }
  }

  /// Cleanup temporary files after merge
  static Future<void> _cleanupTemporaryFiles(List<String> paths) async {
    // Run cleanup in background, don't wait
    Future(() async {
      for (final path in paths) {
        try {
          await _client.storage.from('video-assets').remove([path]);
        } catch (e) {
          debugPrint('[VideoSegmentMerge] Cleanup error for $path: $e');
        }
      }
    });
  }
}

/// Video transition type
class VideoTransition {
  final String value;
  final String label;
  const VideoTransition(this.value, this.label);
}
