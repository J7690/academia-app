import 'package:flutter/material.dart';
import 'package:academia_app/services/video_orientation_service.dart';

/// Adaptive video container that adjusts its aspect ratio based on video orientation.
/// 
/// This widget is designed for future use with Option D (adaptive container architecture).
/// For now, it provides the foundation for adaptive video display while maintaining
/// compatibility with the current fixed horizontal container.
/// 
/// Usage:
/// ```dart
/// AdaptiveVideoContainer(
///   videoAspectRatio: 9.0 / 16.0, // 0.5625 for vertical
///   child: VideoPlayer(controller),
/// )
/// ```
class AdaptiveVideoContainer extends StatelessWidget {
  /// The aspect ratio of the video (width / height)
  final double videoAspectRatio;
  
  /// The child widget to display (typically a video player)
  final Widget child;
  
  /// Optional BoxFit mode. If null, uses optimal BoxFit based on orientation
  final BoxFit? fit;
  
  /// Whether to use adaptive container sizing (for future Option D)
  /// Currently defaults to false to maintain compatibility with fixed horizontal container
  final bool useAdaptiveSizing;
  
  const AdaptiveVideoContainer({
    super.key,
    required this.videoAspectRatio,
    required this.child,
    this.fit,
    this.useAdaptiveSizing = false,
  });
  
  @override
  Widget build(BuildContext context) {
    // Detect video orientation
    final orientation = VideoOrientationService.detectFromRatio(videoAspectRatio);
    
    // Get optimal container aspect ratio
    final containerAspectRatio = VideoOrientationService.getOptimalContainerAspectRatio(orientation);
    
    // Get optimal BoxFit (if not provided)
    final optimalFit = fit ?? VideoOrientationService.getOptimalBoxFitForAdaptiveContainer(orientation);
    
    if (useAdaptiveSizing) {
      // Future Option D: Adaptive container sizing
      // This will resize the container itself to match the video orientation
      return AspectRatio(
        aspectRatio: containerAspectRatio,
        child: _buildChild(optimalFit),
      );
    } else {
      // Current implementation: Fixed horizontal container with BoxFit adjustment
      // This maintains compatibility with the existing Challenge feed layout
      return _buildChild(optimalFit);
    }
  }
  
  Widget _buildChild(BoxFit boxFit) {
    // For now, we just return the child with the appropriate BoxFit
    // The actual BoxFit application happens in the parent AcademiaPlaybackView
    // This widget serves as a marker for future adaptive sizing
    return child;
  }
  
  /// Get the optimal container configuration for this video
  /// 
  /// This method returns a map with all the information needed to configure
  /// the container for adaptive sizing (when useAdaptiveSizing is true)
  Map<String, dynamic> getContainerConfig() {
    return VideoOrientationService.getOptimalContainer(videoAspectRatio);
  }
}
