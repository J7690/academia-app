import 'package:flutter/widgets.dart';

/// Stub widget used on non-web platforms. On web, the real implementation
/// is provided by `hls_web.dart` via conditional import.
class HlsWebVideoPlayer extends StatelessWidget {
  final String url;
  final bool autoplay;
  final bool loop;
  final bool muted;
  final bool showControls;
  final VoidCallback? onEnded;

  const HlsWebVideoPlayer({
    super.key,
    required this.url,
    this.autoplay = true,
    this.loop = false,
    this.muted = true,
    this.showControls = false,
    this.onEnded,
  });

  @override
  Widget build(BuildContext context) {
    // This widget should never be used on non-web platforms for HLS.
    // Fallback to an empty box.
    return const SizedBox.shrink();
  }
}
