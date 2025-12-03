import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AcademiaVideoWidget extends StatelessWidget {
  final String url;
  final bool autoplay;
  final bool loop;
  final bool muted;
  final bool showControls;
  final String resizeMode;

  const AcademiaVideoWidget({
    super.key,
    required this.url,
    this.autoplay = true,
    this.loop = true,
    this.muted = true,
    this.showControls = false,
    this.resizeMode = 'cover',
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      if (url.isEmpty) {
        return const SizedBox.shrink();
      }
      return AndroidView(
        viewType: 'academia_android_video',
        creationParams: <String, dynamic>{
          'url': url,
          'autoplay': autoplay,
          'loop': loop,
          'muted': muted,
          'showControls': showControls,
          'resizeMode': resizeMode,
        },
        creationParamsCodec: const StandardMessageCodec(),
      );
    }

    return const SizedBox.shrink();
  }
}
