library academia_universal_video_player;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UniversalVideoPlayer extends StatelessWidget {
  final String url;

  const UniversalVideoPlayer({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }

    if (url.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return AndroidView(
      viewType: 'academia_universal_video_player',
      creationParams: <String, dynamic>{'url': url.trim()},
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}
