import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Service that burns overlay layers (text, equations, drawings, stickers)
/// directly into a video file so they persist after download/share.
///
/// Uses [pro_video_editor] to composite a transparent PNG overlay image
/// on top of the original video, producing a new MP4 file.
class OverlayBurnInService {
  OverlayBurnInService._();

  /// Captures a Flutter widget tree as a transparent PNG image.
  ///
  /// [overlayBuilder] must return a widget that renders the overlays
  /// (e.g. [VideoOverlaysLayer]) at the given [videoSize].
  ///
  /// Returns the PNG bytes, or null if capture fails.
  static Future<Uint8List?> captureOverlayImage({
    required Widget Function(Size size) overlayBuilder,
    required Size videoSize,
  }) async {
    try {
      final widget = overlayBuilder(videoSize);

      // Create a repaint boundary pipeline to render the widget offscreen
      final repaintBoundary = RenderRepaintBoundary();

      final renderView = RenderView(
        view: ui.PlatformDispatcher.instance.implicitView!,
        child: RenderPositionedBox(
          child: repaintBoundary,
        ),
      );

      final pipelineOwner = PipelineOwner();
      pipelineOwner.rootNode = renderView;
      renderView.prepareInitialFrame();

      final buildOwner = BuildOwner(focusManager: FocusManager());
      final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
        container: repaintBoundary,
        child: MediaQuery(
          data: MediaQueryData(
            size: videoSize,
            devicePixelRatio: 1.0,
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: videoSize.width,
              height: videoSize.height,
              child: widget,
            ),
          ),
        ),
      ).attachToRenderTree(buildOwner);

      buildOwner.buildScope(rootElement);
      pipelineOwner.flushLayout();
      pipelineOwner.flushCompositingBits();
      pipelineOwner.flushPaint();

      final image = await repaintBoundary.toImage(
        pixelRatio: 1.0,
      );
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      image.dispose();

      buildOwner.finalizeTree();

      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('[OverlayBurnInService] captureOverlayImage error: $e');
      return null;
    }
  }

  /// Renders a video with overlays burned in.
  ///
  /// [videoPath] — path to the source video file on disk.
  /// [overlayPngBytes] — transparent PNG image of the overlays.
  /// [onProgress] — optional progress callback (0.0 to 1.0).
  ///
  /// Returns the path to the rendered output file, or null on failure.
  static Future<String?> renderWithOverlays({
    required String videoPath,
    required Uint8List overlayPngBytes,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final tempDir = await Directory.systemTemp.createTemp('academia_render_');
      final outputPath = '${tempDir.path}/rendered_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final renderData = VideoRenderData(
        video: EditorVideo.file(File(videoPath)),
        imageBytes: overlayPngBytes,
        outputFormat: VideoOutputFormat.mp4,
      );

      // Listen to progress if callback provided
      if (onProgress != null) {
        ProVideoEditor.instance
            .progressStreamById(renderData.id)
            .listen((progress) {
          onProgress(progress.progress);
        });
      }

      await ProVideoEditor.instance.renderVideoToFile(
        outputPath,
        renderData,
      );

      // Verify output exists
      final outputFile = File(outputPath);
      if (await outputFile.exists() && await outputFile.length() > 0) {
        debugPrint('[OverlayBurnInService] Render complete: $outputPath (${await outputFile.length()} bytes)');
        return outputPath;
      }

      debugPrint('[OverlayBurnInService] Render output missing or empty');
      return null;
    } catch (e) {
      debugPrint('[OverlayBurnInService] renderWithOverlays error: $e');
      return null;
    }
  }

  /// Convenience: captures overlays and renders them into the video in one call.
  ///
  /// [videoPath] — local video file path.
  /// [overlays] — the overlay payload map from _buildOverlaysPayload().
  /// [videoSize] — dimensions of the video (width x height).
  /// [overlayWidgetBuilder] — function that builds the overlay widget from the map.
  /// [onProgress] — optional progress callback.
  ///
  /// Returns the rendered output file path, or null on failure.
  static Future<String?> burnOverlaysIntoVideo({
    required String videoPath,
    required Map<String, dynamic> overlays,
    required Size videoSize,
    required Widget Function(Map<String, dynamic> overlays, Size size) overlayWidgetBuilder,
    void Function(double progress)? onProgress,
  }) async {
    // 1. Capture overlays as PNG
    debugPrint('[OverlayBurnInService] Step 1: Capturing overlay image...');
    final pngBytes = await captureOverlayImage(
      overlayBuilder: (size) => overlayWidgetBuilder(overlays, size),
      videoSize: videoSize,
    );

    if (pngBytes == null || pngBytes.isEmpty) {
      debugPrint('[OverlayBurnInService] Failed to capture overlay image');
      return null;
    }
    debugPrint('[OverlayBurnInService] Overlay PNG captured: ${pngBytes.length} bytes');

    // 2. Render video with overlay
    debugPrint('[OverlayBurnInService] Step 2: Rendering video with overlays...');
    return renderWithOverlays(
      videoPath: videoPath,
      overlayPngBytes: pngBytes,
      onProgress: onProgress,
    );
  }
}
