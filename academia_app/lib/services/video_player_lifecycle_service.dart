import 'package:flutter/foundation.dart';
import '../video/academia_playback_view.dart';

/// Global service to track and manage video player lifecycle across the app.
/// 
/// This service ensures that video players are properly paused when navigating
/// between screens (e.g., when opening the Studio from the feed) and resumed
/// when returning to the previous screen.
class VideoPlayerLifecycleService {
  static final VideoPlayerLifecycleService _instance = VideoPlayerLifecycleService._internal();
  factory VideoPlayerLifecycleService() => _instance;
  VideoPlayerLifecycleService._internal();

  final Map<String, AcademiaPlaybackController> _controllers = {};
  final Map<String, String> _controllerSources = {}; // 'feed', 'studio', 'viewer'
  bool _feedAutoplayEnabled = true;

  /// Set whether feed autoplay is enabled
  void setFeedAutoplayEnabled(bool enabled) {
    _feedAutoplayEnabled = enabled;
    debugPrint('[PLAYER_AUTOPLAY] Feed autoplay: $enabled');
  }

  /// Get whether feed autoplay is enabled
  bool get feedAutoplayEnabled => _feedAutoplayEnabled;

  /// Register a controller with a unique ID and source
  void registerController(String id, AcademiaPlaybackController controller, String source) {
    _controllers[id] = controller;
    _controllerSources[id] = source;
    debugPrint('[PLAYER_CREATED] id=$id source=$source total=${_controllers.length}');
  }

  /// Unregister a controller by ID
  void unregisterController(String id) {
    _controllers.remove(id);
    _controllerSources.remove(id);
    debugPrint('[PLAYER_DISPOSED] id=$id total=${_controllers.length}');
  }

  /// Pause all active controllers
  void pauseAll() {
    for (final entry in _controllers.entries) {
      if (entry.value.isAttached) {
        entry.value.pause();
        debugPrint('[PLAYER_PAUSED] id=${entry.key} source=${_controllerSources[entry.key]}');
      }
    }
  }

  /// Pause all feed controllers
  void pauseFeed() {
    for (final entry in _controllers.entries) {
      if (_controllerSources[entry.key] == 'feed' && entry.value.isAttached) {
        entry.value.pause();
        debugPrint('[PLAYER_PAUSED] id=${entry.key} source=feed');
      }
    }
  }

  /// Resume all feed controllers
  void resumeFeed() {
    for (final entry in _controllers.entries) {
      if (_controllerSources[entry.key] == 'feed' && entry.value.isAttached) {
        entry.value.play();
        debugPrint('[PLAYER_RESUMED] id=${entry.key} source=feed');
      }
    }
  }

  /// Get the count of active controllers
  int get activeCount => _controllers.values.where((c) => c.isAttached).length;

  /// Get all controller IDs for a specific source
  List<String> getControllersBySource(String source) {
    return _controllerSources.entries
        .where((entry) => entry.value == source)
        .map((entry) => entry.key)
        .toList();
  }

  /// Clear all controllers (use with caution)
  void clearAll() {
    final count = _controllers.length;
    _controllers.clear();
    _controllerSources.clear();
    debugPrint('[PLAYER_CLEARED] cleared $count controllers');
  }

  /// Pause all studio controllers
  void pauseStudio() {
    for (final entry in _controllers.entries) {
      if (_controllerSources[entry.key] == 'studio' && entry.value.isAttached) {
        entry.value.pause();
        debugPrint('[PLAYER_PAUSED] id=${entry.key} source=studio');
      }
    }
  }

  /// Pause all publish controllers
  void pausePublish() {
    for (final entry in _controllers.entries) {
      if (_controllerSources[entry.key] == 'publish' && entry.value.isAttached) {
        entry.value.pause();
        debugPrint('[PLAYER_PAUSED] id=${entry.key} source=publish');
      }
    }
  }
}
