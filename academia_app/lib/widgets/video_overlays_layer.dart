import 'package:flutter/material.dart';

class VideoOverlaysLayer extends StatelessWidget {
  final Map<String, dynamic>? overlays;

  const VideoOverlaysLayer({
    super.key,
    required this.overlays,
  });

  @override
  Widget build(BuildContext context) {
    final data = overlays;
    if (data == null || data.isEmpty) {
      return const SizedBox.shrink();
    }

    return const SizedBox.shrink();
  }
}
