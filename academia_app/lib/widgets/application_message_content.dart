import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/application_media_service.dart';

class ApplicationMessageContent extends StatelessWidget {
  const ApplicationMessageContent(
      {super.key, required this.message, required this.outgoing});
  final Map<String, dynamic> message;
  final bool outgoing;

  @override
  Widget build(BuildContext context) {
    final text = message['content']?.toString() ?? '';
    final type = message['type']?.toString() ?? 'text';
    final path = message['media_url']?.toString() ?? '';
    final read = message['read_at'] != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (path.isNotEmpty && ['image', 'audio', 'video'].contains(type))
          ApplicationMediaView(key: ValueKey(path), path: path, type: type),
        if (text.isNotEmpty) Text(text),
        if (outgoing)
          Tooltip(
            message: read
                ? 'Lu par le destinataire'
                : 'Envoyé — lecture non confirmée',
            child: Icon(read ? Icons.done_all : Icons.check,
                size: 16, color: read ? Colors.blue : null),
          ),
      ],
    );
  }
}

class ApplicationMediaView extends StatefulWidget {
  const ApplicationMediaView(
      {super.key, required this.path, required this.type});
  final String path;
  final String type;
  @override
  State<ApplicationMediaView> createState() => _ApplicationMediaViewState();
}

class _ApplicationMediaViewState extends State<ApplicationMediaView> {
  String? _url;
  String? _error;
  bool _loading = false;
  VideoPlayerController? _video;
  AudioPlayer? _audio;
  StreamSubscription<PlayerState>? _audioState;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    if (widget.type == 'image') unawaited(_load());
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = await ApplicationMediaService().signedUrl(widget.path);
      if (!mounted) return;
      _url = url;
      if (widget.type == 'video') {
        await _video?.dispose();
        if (!mounted) return;
        final video = VideoPlayerController.networkUrl(Uri.parse(url));
        _video = video;
        await video.initialize();
        if (!mounted) return;
        await video.play();
      } else if (widget.type == 'audio') {
        _audio ??= AudioPlayer();
        _audioState ??= _audio!.onPlayerStateChanged.listen((state) {
          if (mounted) setState(() => _playing = state == PlayerState.playing);
        });
        await _audio!.play(UrlSource(url));
      }
    } catch (_) {
      if (mounted) {
        _error = 'Média indisponible. Réessayez pour renouveler le lien.';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _audioState?.cancel();
    _audio?.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
          padding: EdgeInsets.all(12), child: CircularProgressIndicator());
    }
    if (_error != null) {
      return TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: Text(_error!));
    }
    if (widget.type == 'image') {
      if (_url == null) return const SizedBox.shrink();
      return Image.network(_url!,
          width: 280,
          height: 200,
          fit: BoxFit.contain,
          errorBuilder: (_, error, stack) => TextButton(
              onPressed: _load, child: const Text('Recharger l’image')));
    }
    if (widget.type == 'audio') {
      return TextButton.icon(
        onPressed: () async {
          if (_playing) {
            await _audio?.pause();
          } else if (_audio?.state == PlayerState.paused) {
            try {
              await _audio!.resume();
            } catch (_) {
              await _load();
            }
          } else {
            await _load();
          }
        },
        icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
        label: const Text('Message vocal'),
      );
    }
    final video = _video;
    if (video == null || !video.value.isInitialized) {
      return TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.play_circle),
          label: const Text('Lire la vidéo'));
    }
    return SizedBox(
        width: 280,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AspectRatio(
              aspectRatio: video.value.aspectRatio, child: VideoPlayer(video)),
          ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: video,
              builder: (_, value, child) => value.hasError
                  ? TextButton(
                      onPressed: _load, child: const Text('Recharger la vidéo'))
                  : IconButton(
                      tooltip: value.isPlaying ? 'Pause' : 'Lire',
                      icon: Icon(
                          value.isPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: () =>
                          value.isPlaying ? video.pause() : video.play())),
        ]));
  }
}
