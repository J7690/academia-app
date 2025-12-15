import 'package:flutter/material.dart';

import 'academia_playback_view.dart';

class AcademiaPlaybackEngine {
  const AcademiaPlaybackEngine._();

  static Widget view({
    required String url,
    bool autoplay = true,
    bool looping = true,
    bool muted = false,
    bool showControls = false,
    BoxFit fit = BoxFit.cover,
    VoidCallback? onCompleted,
  }) {
    return AcademiaPlaybackView(
      url: url,
      autoplay: autoplay,
      looping: looping,
      muted: muted,
      showControls: showControls,
      fit: fit,
      onCompleted: onCompleted,
    );
  }
}
