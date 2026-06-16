import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Service for detecting video orientation and providing optimal BoxFit and container recommendations.
/// 
/// This service helps determine the best display strategy for videos based on their
/// aspect ratio and dimensions, supporting both temporary BoxFit adjustments and
/// future adaptive container implementations.
class VideoOrientationService {
  VideoOrientationService._();
  
  static final VideoOrientationService _instance = VideoOrientationService._();
  
  factory VideoOrientationService() => _instance;
  
  /// Cache for orientation detection results to avoid redundant calculations
  final Map<String, VideoOrientation> _orientationCache = {};
  
  /// Clear the orientation cache (useful for testing or memory management)
  void clearCache() {
    _orientationCache.clear();
  }
  
  /// Detect video orientation from aspect ratio
  /// 
  /// [aspectRatio] The width/height ratio of the video
  /// Returns the detected orientation
  static VideoOrientation detectFromRatio(double aspectRatio) {
    if (aspectRatio <= 0 || aspectRatio.isNaN || aspectRatio.isInfinite) {
      return VideoOrientation.unknown;
    }
    
    if (aspectRatio > 1.2) {
      return VideoOrientation.horizontal;
    } else if (aspectRatio < 0.8) {
      return VideoOrientation.vertical;
    } else {
      return VideoOrientation.square;
    }
  }
  
  /// Detect video orientation from dimensions
  /// 
  /// [width] Video width in pixels
  /// [height] Video height in pixels
  /// Returns the detected orientation
  static VideoOrientation detectFromDimensions(int width, int height) {
    if (width <= 0 || height <= 0) {
      return VideoOrientation.unknown;
    }
    
    final ratio = width / height;
    return detectFromRatio(ratio);
  }
  
  /// Detect video orientation with caching
  /// 
  /// [cacheKey] Unique identifier for the video (e.g., URL or asset ID)
  /// [aspectRatio] The width/height ratio of the video
  /// Returns the detected orientation (cached if available)
  VideoOrientation detectWithCache(String cacheKey, double aspectRatio) {
    if (_orientationCache.containsKey(cacheKey)) {
      return _orientationCache[cacheKey]!;
    }
    
    final orientation = detectFromRatio(aspectRatio);
    _orientationCache[cacheKey] = orientation;
    return orientation;
  }
  
  /// Get the optimal BoxFit for a given orientation
  /// 
  /// [orientation] The video orientation
  /// Returns the recommended BoxFit mode
  /// 
  /// For all orientations: contain (shows full content with letterboxing)
  /// 
  /// Note: Using contain for all orientations ensures videos are displayed entirely
  /// without cropping, matching standard video player behavior.
  static BoxFit getOptimalBoxFit(VideoOrientation orientation) {
    // Always use contain to ensure full video content is visible
    // This matches standard video player behavior where videos don't overflow
    return BoxFit.contain;
  }
  
  /// Get the optimal BoxFit for adaptive container (future use)
  /// 
  /// [orientation] The video orientation
  /// Returns the recommended BoxFit mode for adaptive containers
  /// 
  /// For use with adaptive containers (Option D):
  /// - All orientations: cover (container adapts to video)
  static BoxFit getOptimalBoxFitForAdaptiveContainer(VideoOrientation orientation) {
    // With adaptive containers, BoxFit.cover works for all orientations
    // because the container itself adapts to the video ratio
    return BoxFit.cover;
  }
  
  /// Get the recommended container aspect ratio for a video orientation
  /// 
  /// [orientation] The video orientation
  /// Returns the recommended container aspect ratio
  /// 
  /// For future adaptive container implementation (Option D):
  /// - Vertical: 9/16 (0.5625)
  /// - Horizontal: 16/9 (1.777...)
  /// - Square: 1/1 (1.0)
  /// - Unknown: 16/9 (safe default)
  static double getOptimalContainerAspectRatio(VideoOrientation orientation) {
    switch (orientation) {
      case VideoOrientation.vertical:
        return 9.0 / 16.0; // 0.5625
      case VideoOrientation.horizontal:
        return 16.0 / 9.0; // 1.777...
      case VideoOrientation.square:
        return 1.0;
      case VideoOrientation.unknown:
        return 16.0 / 9.0; // Safe default
    }
  }
  
  /// Get the optimal container configuration for a video
  /// 
  /// [aspectRatio] The video aspect ratio
  /// Returns a map with container configuration
  /// 
  /// This method provides all the information needed to configure
  /// an adaptive container for a given video:
  /// - orientation: The detected orientation
  /// - containerAspectRatio: The recommended container aspect ratio
  /// - boxFit: The recommended BoxFit mode
  /// - androidResizeMode: The recommended Android RESIZE_MODE
  static Map<String, dynamic> getOptimalContainer(double aspectRatio) {
    final orientation = detectFromRatio(aspectRatio);
    
    return {
      'orientation': orientation,
      'containerAspectRatio': getOptimalContainerAspectRatio(orientation),
      'boxFit': getOptimalBoxFitForAdaptiveContainer(orientation),
      'androidResizeMode': getOptimalAndroidResizeMode(orientation),
    };
  }
  
  /// Get the recommended Android RESIZE_MODE for a given orientation
  /// 
  /// [orientation] The video orientation
  /// Returns the RESIZE_MODE string for Android native player
  /// 
  /// Mapping to AspectRatioFrameLayout constants:
  /// - All orientations: "fit" (RESIZE_MODE_FIT) - shows full content with letterboxing
  /// 
  /// Note: Using "fit" for all orientations ensures videos are displayed entirely
  /// without cropping, matching standard video player behavior.
  static String getOptimalAndroidResizeMode(VideoOrientation orientation) {
    // Always use "fit" to ensure full video content is visible
    // This matches standard video player behavior where videos don't overflow
    return "fit"; // RESIZE_MODE_FIT - no crop, shows full content
  }
  
  /// Calculate aspect ratio from dimensions with intelligent fallback
  /// 
  /// [width] Video width in pixels
  /// [height] Video height in pixels
  /// [fallbackRatio] Fallback ratio if dimensions are invalid (default: 16/9)
  /// Returns the calculated aspect ratio
  static double calculateAspectRatio(
    int width, 
    int height, {
    double fallbackRatio = 16.0 / 9.0,
  }) {
    if (width <= 0 || height <= 0) {
      return fallbackRatio;
    }
    
    final ratio = width / height;
    
    // Validate the calculated ratio
    if (ratio.isNaN || ratio.isInfinite || ratio <= 0) {
      return fallbackRatio;
    }
    
    return ratio;
  }
}

/// Video orientation enum
enum VideoOrientation {
  /// Horizontal video (width > height, ratio > 1.2)
  horizontal,
  
  /// Vertical video (height > width, ratio < 0.8)
  vertical,
  
  /// Square video (ratio between 0.8 and 1.2)
  square,
  
  /// Unknown orientation (invalid dimensions or ratio)
  unknown,
}

/// Extension on VideoOrientation for convenience methods
extension VideoOrientationExtension on VideoOrientation {
  /// Check if this orientation is vertical
  bool get isVertical => this == VideoOrientation.vertical;
  
  /// Check if this orientation is horizontal
  bool get isHorizontal => this == VideoOrientation.horizontal;
  
  /// Check if this orientation is square
  bool get isSquare => this == VideoOrientation.square;
  
  /// Check if this orientation is unknown
  bool get isUnknown => this == VideoOrientation.unknown;
  
  /// Get a human-readable description
  String get description {
    switch (this) {
      case VideoOrientation.horizontal:
        return 'Horizontal (16:9)';
      case VideoOrientation.vertical:
        return 'Vertical (9:16)';
      case VideoOrientation.square:
        return 'Square (1:1)';
      case VideoOrientation.unknown:
        return 'Unknown';
    }
  }
}
