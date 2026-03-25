import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Service responsible for capturing a widget subtree as an image.
class ScreenshotService {
  const ScreenshotService();

  /// Captures the widget wrapped in a [RepaintBoundary] referenced by
  /// [boundaryKey] and returns PNG bytes.
  ///
  /// The [pixelRatio] should be at least 3.0 for social networks to
  /// display a sharp image on high-density screens.
  Future<Uint8List> captureRepaintBoundary(
    GlobalKey boundaryKey, {
    double pixelRatio = 3.0,
  }) async {
    final BuildContext? context = boundaryKey.currentContext;
    if (context == null) {
      throw StateError(
        'ScreenshotService: boundaryKey has no currentContext. Ensure the '
        'RepaintBoundary is mounted before capturing.',
      );
    }

    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw StateError(
        'ScreenshotService: RenderObject is not a RenderRepaintBoundary. '
        'Wrap the target widget in a RepaintBoundary using the same key.',
      );
    }

    final RenderRepaintBoundary boundary = renderObject;

    // Safety: enforce a minimum pixel ratio to keep images sharp.
    final double effectivePixelRatio = pixelRatio < 3.0 ? 3.0 : pixelRatio;

    final ui.Image image = await boundary.toImage(pixelRatio: effectivePixelRatio);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw StateError('ScreenshotService: failed to encode image as PNG.');
    }

    return byteData.buffer.asUint8List();
  }

  /// Captures a selected zone from the widget wrapped in a [RepaintBoundary]
  /// and returns cropped PNG bytes.
  ///
  /// The [selectionRect] defines the area to crop relative to the boundary.
  /// The [pixelRatio] should be at least 3.0 for social networks.
  Future<Uint8List> captureRepaintBoundaryWithCrop(
    GlobalKey boundaryKey,
    Rect selectionRect, {
    double pixelRatio = 3.0,
  }) async {
    final BuildContext? context = boundaryKey.currentContext;
    if (context == null) {
      throw StateError(
        'ScreenshotService: boundaryKey has no currentContext. Ensure the '
        'RepaintBoundary is mounted before capturing.',
      );
    }

    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw StateError(
        'ScreenshotService: RenderObject is not a RenderRepaintBoundary. '
        'Wrap the target widget in a RepaintBoundary using the same key.',
      );
    }

    final RenderRepaintBoundary boundary = renderObject;
    final Size boundarySize = boundary.size;

    // Valider les dimensions de sélection
    if (selectionRect.left < 0 || 
        selectionRect.top < 0 || 
        selectionRect.right > boundarySize.width || 
        selectionRect.bottom > boundarySize.height) {
      throw ArgumentError(
        'ScreenshotService: selectionRect must be within boundary bounds. '
        'Selection: $selectionRect, Boundary: ${Offset.zero & boundarySize}',
      );
    }

    // Safety: enforce a minimum pixel ratio to keep images sharp.
    final double effectivePixelRatio = pixelRatio < 3.0 ? 3.0 : pixelRatio;

    // Capturer l'image complète
    final ui.Image fullImage = await boundary.toImage(pixelRatio: effectivePixelRatio);
    
    // Calculer les coordonnées de crop en tenant compte du pixel ratio
    final Rect scaledCropRect = Rect.fromLTWH(
      selectionRect.left * effectivePixelRatio,
      selectionRect.top * effectivePixelRatio,
      selectionRect.width * effectivePixelRatio,
      selectionRect.height * effectivePixelRatio,
    );

    // Créer une image croppée
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    
    canvas.drawImageRect(
      fullImage,
      scaledCropRect,
      Offset.zero & Size(scaledCropRect.width, scaledCropRect.height),
      Paint(),
    );

    final ui.Picture picture = recorder.endRecording();
    final ui.Image croppedImage = await picture.toImage(
      scaledCropRect.width.round(),
      scaledCropRect.height.round(),
    );

    // Encoder en PNG
    final ByteData? byteData = await croppedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    // Nettoyer les ressources
    fullImage.dispose();
    croppedImage.dispose();
    picture.dispose();

    if (byteData == null) {
      throw StateError('ScreenshotService: failed to encode cropped image as PNG.');
    }

    return byteData.buffer.asUint8List();
  }
}
