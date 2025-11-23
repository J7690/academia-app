// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'dart:js' as js;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class HlsWebVideoPlayer extends StatefulWidget {
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
  State<HlsWebVideoPlayer> createState() => _HlsWebVideoPlayerState();
}

class _HlsWebVideoPlayerState extends State<HlsWebVideoPlayer> {
  late final String _viewType;
  html.VideoElement? _videoElement;

  @override
  void initState() {
    super.initState();
    assert(kIsWeb, 'HlsWebVideoPlayer should only be used on web.');

    debugPrint('HlsWebVideoPlayer.initState url=' + widget.url);

    _viewType =
        'hls-video-${DateTime.now().microsecondsSinceEpoch}-${widget.url.hashCode}';

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      _videoElement = html.VideoElement()
        ..id = _viewType
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.objectPosition = 'center center'
        ..muted = widget.muted
        ..autoplay = widget.autoplay
        ..loop = widget.loop
        ..controls = widget.showControls;

      _videoElement!.onEnded.listen((_) {
        if (widget.onEnded != null) {
          widget.onEnded!();
        }
      });

      // Appelle la fonction JS définie dans web/index.html en lui passant
      // directement l'élément vidéo.
      js.context.callMethod('createHlsVideo', [
        _videoElement,
        widget.url,
        widget.autoplay,
        widget.loop,
        widget.muted,
      ]);

      return _videoElement!;
    });
  }

  @override
  void didUpdateWidget(covariant HlsWebVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_videoElement == null) {
      return;
    }

    final urlChanged = widget.url != oldWidget.url;
    final autoplayChanged = widget.autoplay != oldWidget.autoplay;
    final loopChanged = widget.loop != oldWidget.loop;
    final mutedChanged = widget.muted != oldWidget.muted;

    if (urlChanged || autoplayChanged || loopChanged || mutedChanged) {
      debugPrint('HlsWebVideoPlayer.didUpdateWidget url=' + widget.url);
      js.context.callMethod('createHlsVideo', [
        _videoElement,
        widget.url,
        widget.autoplay,
        widget.loop,
        widget.muted,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
