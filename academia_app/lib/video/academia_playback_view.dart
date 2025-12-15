import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AcademiaPlaybackView extends StatefulWidget {
  final String url;
  final bool autoplay;
  final bool looping;
  final bool muted;
  final bool showControls;
  final BoxFit fit;
  final VoidCallback? onCompleted;

  const AcademiaPlaybackView({
    super.key,
    required this.url,
    this.autoplay = true,
    this.looping = true,
    this.muted = false,
    this.showControls = false,
    this.fit = BoxFit.cover,
    this.onCompleted,
  });

  @override
  State<AcademiaPlaybackView> createState() => _AcademiaPlaybackViewState();
}

class _AcademiaPlaybackViewState extends State<AcademiaPlaybackView> {
  VideoPlayerController? _controller;
  bool _initializing = false;
  Object? _error;
  bool _hasCompleted = false;

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
    final url = widget.url.trim();
    if (url.isEmpty) {
      setState(() {
        _error = 'empty_url';
      });
      return;
    }

    setState(() {
      _initializing = true;
      _error = null;
    });

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(widget.looping);
      await controller.setVolume(widget.muted ? 0.0 : 1.0);

      controller.addListener(() {
        final c = _controller;
        if (c == null) return;
        if (!mounted) return;
        if (widget.looping) return;
        final v = c.value;
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

    return content;
  }
}
