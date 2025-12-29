import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../utils/url_normalizer.dart';

class AcademiaPlaybackView extends StatefulWidget {
  final String url;
  final bool autoplay;
  final bool looping;
  final bool muted;
  final bool showControls;
  final BoxFit fit;
  final VoidCallback? onCompleted;
  final bool showErrorText;

  const AcademiaPlaybackView({
    super.key,
    required this.url,
    this.autoplay = true,
    this.looping = true,
    this.muted = false,
    this.showControls = false,
    this.fit = BoxFit.cover,
    this.onCompleted,
    this.showErrorText = true,
  });

  @override
  State<AcademiaPlaybackView> createState() => _AcademiaPlaybackViewState();
}

class _AcademiaPlaybackViewState extends State<AcademiaPlaybackView> {
  VideoPlayerController? _controller;
  bool _initializing = false;
  Object? _error;
  bool _hasCompleted = false;
  bool _loggedFirstPlay = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant AcademiaPlaybackView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeController();
      _hasCompleted = false;
      _init();
    } else if (oldWidget.muted != widget.muted) {
      _controller?.setVolume(widget.muted ? 0.0 : 1.0);
    }
  }

  Future<void> _init() async {
    final original = widget.url.trim();
    if (original.isEmpty) {
      setState(() {
        _error = 'empty_url';
      });
      return;
    }

    final url = UrlNormalizer.normalize(original);

    setState(() {
      _initializing = true;
      _error = null;
      _loggedFirstPlay = false;
    });

    try {
      // Debug interne pour diagnostiquer les soucis de lecture vidéo sur certains appareils.
      // Ne change rien à l'UI utilisateur, mais permet de tracer l'URL exacte utilisée.
      debugPrint('[AcademiaPlaybackView] init url=$url');
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(widget.looping);
      await controller.setVolume(widget.muted ? 0.0 : 1.0);

      final v0 = controller.value;
      debugPrint(
        '[AcademiaPlaybackView] initialized isWeb=$kIsWeb duration=${v0.duration} '
        'aspectRatio=${v0.aspectRatio} muted=${widget.muted} looping=${widget.looping}',
      );

      controller.addListener(() {
        final c = _controller;
        if (c == null) return;
        if (!mounted) return;
        final v = c.value;

        if (v.isInitialized && v.isPlaying && !_loggedFirstPlay) {
          _loggedFirstPlay = true;
          debugPrint(
            '[AcademiaPlaybackView] playing isWeb=$kIsWeb '
            'position=${v.position} duration=${v.duration}',
          );
        }

        if (widget.looping) return;
        if (!v.isInitialized) return;
        final d = v.duration;
        if (d == Duration.zero) return;
        if (!v.isPlaying && v.position >= d && !_hasCompleted) {
          _hasCompleted = true;
          debugPrint(
            '[AcademiaPlaybackView] completed isWeb=$kIsWeb '
            'position=${v.position} duration=$d',
          );
          widget.onCompleted?.call();
        }
      });

      if (widget.autoplay) {
        await controller.play();
        debugPrint('[AcademiaPlaybackView] autoplay play() requested isWeb=$kIsWeb');
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
      debugPrint('[AcademiaPlaybackView] init error=$e url=$url');
      setState(() {
        _initializing = false;
        _error = e;
      });
    }
  }

  void _disposeController() {
    final c = _controller;
    _controller = null;
    if (c != null) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
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
    final controller = _controller;

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
    final aspectRatio = v.aspectRatio == 0 || v.aspectRatio.isNaN ? (16 / 9) : v.aspectRatio;

    Widget content = FittedBox(
      fit: widget.fit,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: 1,
        height: 1 / aspectRatio,
        child: VideoPlayer(controller),
      ),
    );

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
