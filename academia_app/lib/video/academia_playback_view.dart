import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../utils/url_normalizer.dart';
import '../services/video_orientation_service.dart';

/// Controller that allows external code (e.g. the TikTok feed) to
/// toggle play/pause on an [AcademiaPlaybackView].
class AcademiaPlaybackController {
  _AcademiaPlaybackViewState? _state;

  /// Toggle play/pause. Returns true if now playing, false if paused.
  Future<bool> toggle() async {
    final result = await _state?._toggleExternal();
    return result ?? false;
  }

  Future<void> pause() async => _state?._pauseExternal();
  Future<void> play() async => _state?._playExternal();

  /// Imperatively set the audio volume (0.0 = muted, 1.0 = full).
  Future<void> setVolume(double volume) async =>
      _state?._setVolumeExternal(volume);

  /// Current playback position in milliseconds.
  Future<int> getPosition() async => await _state?._getPositionMs() ?? 0;

  /// Total duration in milliseconds.
  Future<int> getDuration() async => await _state?._getDurationMs() ?? 0;

  bool get isAttached => _state != null;
}

class AcademiaPlaybackView extends StatefulWidget {
  final String url;
  final bool preferFlutterPlayer;
  final bool deferInitialization;
  final bool autoplay;
  final bool looping;
  final bool muted;
  final bool showControls;
  final BoxFit fit;
  final VoidCallback? onCompleted;
  final bool showErrorText;
  final VoidCallback? onFirstPlay;
  final AcademiaPlaybackController? playbackController;
  final double? videoAspectRatio;

  const AcademiaPlaybackView({
    super.key,
    required this.url,
    this.preferFlutterPlayer = false,
    this.deferInitialization = false,
    this.autoplay = true,
    this.looping = true,
    this.muted = false,
    this.showControls = false,
    this.fit = BoxFit.cover,
    this.onCompleted,
    this.showErrorText = true,
    this.onFirstPlay,
    this.playbackController,
    this.videoAspectRatio,
  });

  @override
  State<AcademiaPlaybackView> createState() => _AcademiaPlaybackViewState();
}

class _AcademiaPlaybackViewState extends State<AcademiaPlaybackView> {
  // --- Web: uses Flutter video_player ---
  VideoPlayerController? _controller;

  // --- Shared state ---
  bool _initializing = false;
  Object? _error;
  bool _hasCompleted = false;
  bool _loggedFirstPlay = false;

  // Android native MethodChannel
  MethodChannel? _nativeChannel;
  bool _isPaused = false;

  /// True when running on Android (not web).
  bool get _useNativeAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Android always uses native player, iOS/Web always use Flutter video_player.
  bool get _shouldUseNativeAndroid => _useNativeAndroid;

  @override
  void initState() {
    super.initState();
    widget.playbackController?._state = this;
    if (!widget.deferInitialization) {
      _init();
    }
  }

  @override
  void didUpdateWidget(covariant AcademiaPlaybackView oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.url != widget.url) {
      // URL changed - hot-switch on native player, reinit on Flutter player
      if (_shouldUseNativeAndroid && _nativeChannel != null) {
        final newUrl = UrlNormalizer.normalize(widget.url.trim());
        if (newUrl.isNotEmpty) {
          _nativeChannel!.invokeMethod('setUrl', {
            'url': newUrl,
            'autoplay': widget.autoplay,
          });
        }
        _hasCompleted = false;
      } else {
        // Flutter player - dispose and reinit
        _disposeController();
        _hasCompleted = false;
        _init();
      }
    } else {
      // URL unchanged: apply mute and autoplay INDEPENDENTLY. Both can change in
      // the same rebuild when a feed page becomes active/inactive; the previous
      // `else if` chain dropped one of the two (e.g. unmuted but never played).
      if (oldWidget.muted != widget.muted) {
        if (_shouldUseNativeAndroid && _nativeChannel != null) {
          _nativeChannel!.invokeMethod('setVolume', {'volume': widget.muted ? 0.0 : 1.0});
        } else {
          _controller?.setVolume(widget.muted ? 0.0 : 1.0);
        }
      }
      if (oldWidget.autoplay != widget.autoplay) {
        if (_shouldUseNativeAndroid && _nativeChannel != null) {
          if (widget.autoplay) {
            _nativeChannel!.invokeMethod('play');
          } else {
            _nativeChannel!.invokeMethod('pause');
          }
        } else {
          final c = _controller;
          if (c != null && c.value.isInitialized) {
            if (widget.autoplay) {
              c.play();
            } else {
              c.pause();
            }
          }
        }
      }
    }
  }

  Future<void> _init() async {
    // Android always uses native player - no need to initialize VideoPlayerController
    if (_shouldUseNativeAndroid) {
      setState(() {
        _initializing = false;
        _error = null;
      });
      return;
    }

    // --- Web / iOS: Flutter video_player ---
    final original = widget.url.trim();
    if (original.isEmpty) {
      setState(() {
        _error = 'empty_url';
      });
      return;
    }

    final url = UrlNormalizer.normalize(original);

    final uri = Uri.tryParse(url);
    final isLocalFileUri = uri != null && uri.scheme.toLowerCase() == 'file';

    setState(() {
      _initializing = true;
      _error = null;
      _loggedFirstPlay = false;
    });

    try {
      final VideoPlayerController controller;
      if (isLocalFileUri) {
        final parsed = Uri.parse(url);
        controller = VideoPlayerController.file(File.fromUri(parsed));
      } else {
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
      }
      _controller = controller;
      debugPrint('[PLAYER_CREATED] VideoPlayerController initialized url=$url');

      await controller.initialize();
      await controller.setLooping(widget.looping);
      await controller.setVolume(widget.muted ? 0.0 : 1.0);

      controller.addListener(() {
        final c = _controller;
        if (c == null) return;
        if (!mounted) return;
        final v = c.value;

        if (v.isInitialized && v.isPlaying && !_loggedFirstPlay) {
          _loggedFirstPlay = true;
          if (widget.onFirstPlay != null) {
            widget.onFirstPlay!();
          }
        }

        if (widget.looping) return;
        if (!v.isInitialized) return;
        final d = v.duration;
        if (d == Duration.zero) return;
        if (!v.isPlaying && v.position >= d && !_hasCompleted) {
          _hasCompleted = true;
          widget.onCompleted?.call();
        }
      });

      if (widget.autoplay) {
        await controller.play();
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = e;
      });
      if (widget.onCompleted != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_hasCompleted) {
            _hasCompleted = true;
            widget.onCompleted?.call();
          }
        });
      }
    }
  }

  void _disposeController() {
    final c = _controller;
    _controller = null;
    if (c != null) {
      debugPrint('[PLAYER_DISPOSED] VideoPlayerController disposed');
      c.dispose();
    }
  }

  @override
  void dispose() {
    if (widget.playbackController?._state == this) {
      widget.playbackController?._state = null;
    }
    _nativeChannel = null;
    _disposeController();
    super.dispose();
  }

  /// External toggle (called by AcademiaPlaybackController)
  Future<bool> _toggleExternal() async {
    if (_useNativeAndroid) {
      final ch = _nativeChannel;
      if (ch == null) return !_isPaused; // PlatformView not ready yet
      try {
        final result = await ch.invokeMethod<bool>('toggle')
            .timeout(const Duration(seconds: 2), onTimeout: () => null);
        if (result != null) {
          _isPaused = !result;
        } else {
          _isPaused = !_isPaused;
        }
        if (mounted) setState(() {});
        return !_isPaused;
      } catch (_) {
        return !_isPaused;
      }
    }
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      if (c.value.isPlaying) {
        await c.pause();
        _isPaused = true;
      } else {
        await c.play();
        _isPaused = false;
      }
      if (mounted) setState(() {});
      return !_isPaused;
    }
    return false;
  }

  Future<void> _pauseExternal() async {
    debugPrint('[PLAYER_PAUSED] pause called');
    if (_useNativeAndroid) {
      final ch = _nativeChannel;
      if (ch == null) return;
      try {
        await ch.invokeMethod<bool>('pause')
            .timeout(const Duration(seconds: 2), onTimeout: () => null);
      } catch (_) {}
      _isPaused = true;
      if (mounted) setState(() {});
      return;
    }
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      await c.pause();
      _isPaused = true;
      if (mounted) setState(() {});
    }
  }

  /// Imperatively change the audio volume without rebuilding the widget.
  /// Used by the lifecycle service to mute feed players when leaving the feed.
  Future<void> _setVolumeExternal(double volume) async {
    final v = volume.clamp(0.0, 1.0);
    if (_useNativeAndroid) {
      final ch = _nativeChannel;
      if (ch == null) return;
      try {
        await ch.invokeMethod('setVolume', {'volume': v})
            .timeout(const Duration(seconds: 2), onTimeout: () => null);
      } catch (_) {}
      return;
    }
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      await c.setVolume(v);
    }
  }

  Future<void> _playExternal() async {
    debugPrint('[PLAYER_RESUMED] play called');
    if (_useNativeAndroid) {
      final ch = _nativeChannel;
      if (ch == null) return;
      try {
        await ch.invokeMethod<bool>('play')
            .timeout(const Duration(seconds: 2), onTimeout: () => null);
      } catch (_) {}
      _isPaused = false;
      if (mounted) setState(() {});
      return;
    }
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      await c.play();
      _isPaused = false;
      if (mounted) setState(() {});
    }
  }

  Future<int> _getPositionMs() async {
    if (_useNativeAndroid) {
      final ch = _nativeChannel;
      if (ch == null) return 0;
      try {
        final result = await ch.invokeMethod<int>('getPosition')
            .timeout(const Duration(seconds: 1), onTimeout: () => 0);
        return result ?? 0;
      } catch (_) {
        return 0;
      }
    }
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      return c.value.position.inMilliseconds;
    }
    return 0;
  }

  Future<int> _getDurationMs() async {
    if (_useNativeAndroid) {
      final ch = _nativeChannel;
      if (ch == null) return 0;
      try {
        final result = await ch.invokeMethod<int>('getDuration')
            .timeout(const Duration(seconds: 1), onTimeout: () => 0);
        return result ?? 0;
      } catch (_) {
        return 0;
      }
    }
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      return c.value.duration.inMilliseconds;
    }
    return 0;
  }

  void _toggle() {
    final c = _controller;
    if (c == null) return;
    final v = c.value;
    if (!v.isInitialized) return;
    if (v.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // --- Android: native PlatformView with MediaTek-safe codec selector ---
    if (_shouldUseNativeAndroid) {
      final url = UrlNormalizer.normalize(widget.url.trim());
      if (url.isEmpty) {
        return Container(color: Colors.black);
      }

      // Determine optimal resize mode based on video orientation
      final orientation = VideoOrientationService.detectFromRatio(
        widget.videoAspectRatio ?? (16.0 / 9.0),
      );
      final optimalResizeMode = VideoOrientationService.getOptimalAndroidResizeMode(orientation);
      
      // Map BoxFit to resize mode, but override with orientation-aware mode for contain
      final resizeMode = widget.fit == BoxFit.cover
          ? 'cover'
          : widget.fit == BoxFit.fill
              ? 'fill'
              : widget.fit == BoxFit.fitWidth
                  ? 'fitWidth'
                  : widget.fit == BoxFit.fitHeight
                      ? 'fitHeight'
                      : optimalResizeMode; // Use orientation-aware mode for contain

      debugPrint('[AcademiaPlaybackView] build AndroidView url=${url.length > 60 ? '${url.substring(0, 60)}...' : url}  autoplay=${widget.autoplay}');
      debugPrint('[P8_BUILD] url=$url native=$_shouldUseNativeAndroid flutter=${!_shouldUseNativeAndroid}');

      return AndroidView(
        viewType: 'academia_android_video',
        creationParams: <String, dynamic>{
          'url': url,
          'autoplay': widget.autoplay,
          'loop': widget.looping,
          'muted': widget.muted,
          'showControls': widget.showControls,
          'resizeMode': resizeMode,
        },
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (int viewId) {
          _nativeChannel = MethodChannel('academia_android_video_$viewId');
        },
      );
    }

    // --- Web / iOS: Flutter video_player ---
    final controller = _controller;

    if (widget.deferInitialization && controller == null && _error == null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          if (_initializing) return;
          await _init();
          final c = _controller;
          if (c != null && c.value.isInitialized) {
            try {
              await c.play();
            } catch (_) {}
          }
        },
        child: Container(
          color: Colors.black,
        ),
      );
    }

    if (_error != null) {
      if (!widget.showErrorText) {
        return Container(
          color: Colors.black,
        );
      }
      String message;
      if (_error == 'empty_url') {
        message = 'Vidéo indisponible.';
      } else {
        message = 'Une erreur est survenue lors de la lecture de la vidéo.';
      }
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_initializing || controller == null || !controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final v = controller.value;
    
    // Intelligent fallback: detect orientation from dimensions if aspectRatio is invalid
    final aspectRatio = (v.aspectRatio == 0 || v.aspectRatio.isNaN)
        ? VideoOrientationService.calculateAspectRatio(
            v.size.width.toInt(),
            v.size.height.toInt(),
            fallbackRatio: 16.0 / 9.0,
          )
        : v.aspectRatio;

    Widget content;
    if (kIsWeb) {
      // Sur le web, éviter les transforms complexes autour du <video> HTML
      // (FittedBox/scale) qui peuvent figer l'image. On laisse la vidéo
      // occuper simplement tout l'espace disponible fourni par le parent.
      content = SizedBox.expand(
        child: VideoPlayer(controller),
      );
    } else {
      content = FittedBox(
        fit: widget.fit,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: 1,
          height: 1 / aspectRatio,
          child: VideoPlayer(controller),
        ),
      );
    }

    if (widget.showControls) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: content),
            if (!kIsWeb)
              AnimatedOpacity(
                opacity: v.isPlaying ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: const Icon(
                  Icons.play_arrow,
                  size: 56,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      );
    }

    if (kDebugMode && kIsWeb) {
      content = Stack(
        children: [
          Positioned.fill(child: content),
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'VIDEO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return content;
  }
}
