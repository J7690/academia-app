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
}
