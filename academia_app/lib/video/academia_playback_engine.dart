import 'package:flutter/material.dart';

import 'academia_playback_view.dart';

export 'academia_playback_view.dart' show AcademiaPlaybackController;

class AcademiaPlaybackEngine {
  const AcademiaPlaybackEngine._();

  static Widget view({
    required String url,
    bool preferFlutterPlayer = false,
    bool deferInitialization = false,
    bool autoplay = true,
    bool looping = true,
    bool muted = false,
    bool showControls = false,
    BoxFit fit = BoxFit.cover,
    VoidCallback? onCompleted,
    bool showErrorText = true,
    VoidCallback? onFirstPlay,
    AcademiaPlaybackController? playbackController,
  }) {
    return AcademiaPlaybackView(
      url: url,
      preferFlutterPlayer: preferFlutterPlayer,
      deferInitialization: deferInitialization,
      autoplay: autoplay,
      looping: looping,
      muted: muted,
      showControls: showControls,
      fit: fit,
      onCompleted: onCompleted,
      showErrorText: showErrorText,
      onFirstPlay: onFirstPlay,
      playbackController: playbackController,
    );
  }
}
