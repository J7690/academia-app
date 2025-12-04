import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class StudentVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final bool isAudio;
  final Map<String, dynamic>? overlays;
  final bool feedMode;

  const StudentVideoPlayer({
    super.key,
    required this.controller,
    this.isAudio = false,
    this.overlays,
    this.feedMode = false,
  });

  @override
  State<StudentVideoPlayer> createState() => _StudentVideoPlayerState();
}

class _StudentVideoPlayerState extends State<StudentVideoPlayer> {
  bool _muted = false;
  bool _isDragging = false;
  double _dragValue = 0.0;

  VideoPlayerController get _controller => widget.controller;

  Map<String, dynamic>? get _overlays => widget.overlays;
  bool get _feedMode => widget.feedMode;

  String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _seekRelative(int offsetSeconds) async {
    final value = _controller.value;
    if (!value.isInitialized) {
      return;
    }
    final current = value.position;
    final targetSeconds = current.inSeconds + offsetSeconds;
    final clampedSeconds = targetSeconds.clamp(0, value.duration.inSeconds);
    await _controller.seekTo(Duration(seconds: clampedSeconds));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _controller,
      builder: (context, value, child) {
        final isInitialized = value.isInitialized;
        final duration = isInitialized ? value.duration : Duration.zero;
        final position = isInitialized ? value.position : Duration.zero;

        final totalMs = duration.inMilliseconds;
        final maxSlider = totalMs > 0 ? totalMs.toDouble() : 1.0;
        final currentMs = position.inMilliseconds.clamp(0, totalMs > 0 ? totalMs : 0);

        final sliderValue = !_isDragging
            ? (totalMs > 0 ? currentMs.toDouble() : 0.0)
            : _dragValue.clamp(0.0, maxSlider);

        final aspectRatio = !isInitialized || value.aspectRatio == 0 || value.aspectRatio.isNaN
            ? 16 / 9
            : value.aspectRatio;

        final isPlaying = value.isPlaying;

        Widget _buildControls() {
          if (_feedMode) {
            return const SizedBox.shrink();
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Slider(
                value: sliderValue,
                max: maxSlider,
                onChangeStart: (v) {
                  setState(() {
                    _isDragging = true;
                    _dragValue = v;
                  });
                },
                onChanged: (v) {
                  setState(() {
                    _dragValue = v;
                  });
                },
                onChangeEnd: (v) async {
                  setState(() {
                    _isDragging = false;
                  });
                  if (totalMs > 0) {
                    final target = Duration(milliseconds: v.round());
                    await _controller.seekTo(target);
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Text(_formatDuration(position)),
                    const Spacer(),
                    Text(_formatDuration(duration)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => _seekRelative(-10),
                    icon: const Icon(Icons.replay_10),
                    tooltip: 'Reculer de 10 secondes',
                  ),
                  IconButton(
                    onPressed: () {
                      if (isPlaying) {
                        _controller.pause();
                      } else {
                        _controller.play();
                      }
                      setState(() {});
                    },
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                    tooltip: isPlaying ? 'Pause' : 'Lecture',
                  ),
                  IconButton(
                    onPressed: () => _seekRelative(10),
                    icon: const Icon(Icons.forward_10),
                    tooltip: 'Avancer de 10 secondes',
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _muted = !_muted;
                      });
                      _controller.setVolume(_muted ? 0.0 : 1.0);
                    },
                    icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
                    tooltip: _muted ? 'Activer le son' : 'Couper le son',
                  ),
                ],
              ),
            ],
          );
        }

        Widget _buildOverlayLayer(BoxConstraints constraints, Duration position) {
          final data = _overlays;
          if (data == null) {
            return const SizedBox.shrink();
          }

          final stickersRaw = data['stickers'];
          final textsRaw = data['texts'];
          final subtitlesRaw = data['subtitles'];

          final stickers = <Map<String, dynamic>>[];
          if (stickersRaw is List) {
            for (final item in stickersRaw) {
              if (item is Map) {
                stickers.add(Map<String, dynamic>.from(item));
              }
            }
          }

          final texts = <Map<String, dynamic>>[];
          if (textsRaw is List) {
            for (final item in textsRaw) {
              if (item is Map) {
                texts.add(Map<String, dynamic>.from(item));
              }
            }
          }

          final subtitles = <Map<String, dynamic>>[];
          if (subtitlesRaw is List) {
            for (final item in subtitlesRaw) {
              if (item is Map) {
                subtitles.add(Map<String, dynamic>.from(item));
              }
            }
          }

          String? currentSubtitleText;
          if (subtitles.isNotEmpty) {
            final currentMs = position.inMilliseconds;
            for (final s in subtitles) {
              final text = s['text']?.toString() ?? '';
              if (text.isEmpty) {
                continue;
              }
              final startRaw = s['start_ms'];
              final endRaw = s['end_ms'];

              int? startMs;
              int? endMs;

              if (startRaw is int) {
                startMs = startRaw;
              } else if (startRaw is num) {
                startMs = startRaw.toInt();
              } else if (startRaw is String) {
                startMs = int.tryParse(startRaw);
              }

              if (endRaw is int) {
                endMs = endRaw;
              } else if (endRaw is num) {
                endMs = endRaw.toInt();
              } else if (endRaw is String) {
                endMs = int.tryParse(endRaw);
              }

              if (startMs == null && endMs == null) {
                currentSubtitleText = text;
                break;
              }

              if (startMs != null && currentMs < startMs) {
                continue;
              }

              if (endMs != null && currentMs > endMs) {
                continue;
              }

              currentSubtitleText = text;
              break;
            }
          }

          if (stickers.isEmpty && texts.isEmpty && currentSubtitleText == null) {
            return const SizedBox.shrink();
          }

          double _getX(Map<String, dynamic> m) {
            final raw = m['x'];
            if (raw is num) return raw.toDouble().clamp(0.0, 1.0);
            return 0.5;
          }

          double _getY(Map<String, dynamic> m) {
            final raw = m['y'];
            if (raw is num) return raw.toDouble().clamp(0.0, 1.0);
            return 0.5;
          }

          return IgnorePointer(
            child: Stack(
              children: [
                for (final s in stickers)
                  Positioned(
                    left: _getX(s) * constraints.maxWidth - 16,
                    top: _getY(s) * constraints.maxHeight - 16,
                    child: _StickerIcon(type: s['type']?.toString() ?? ''),
                  ),
                for (final t in texts)
                  Positioned(
                    left: _getX(t) * constraints.maxWidth - 80,
                    top: _getY(t) * constraints.maxHeight - 20,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          t['text']?.toString() ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (currentSubtitleText != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 56,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          currentSubtitleText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final hasBoundedHeight = constraints.maxHeight < double.infinity;

            if (_feedMode && !widget.isAudio) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: AspectRatio(
                          aspectRatio: aspectRatio,
                          child: VideoPlayer(_controller),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (!isInitialized) {
                          return;
                        }
                        if (isPlaying) {
                          _controller.pause();
                        } else {
                          _controller.play();
                        }
                        setState(() {});
                      },
                    ),
                  ),
                  Positioned.fill(
                    child: _buildOverlayLayer(constraints, position),
                  ),
                  if (!isPlaying)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.35),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }

            if (!hasBoundedHeight) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!widget.isAudio)
                    AspectRatio(
                      aspectRatio: aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  if (widget.isAudio)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Icon(Icons.audiotrack, size: 48),
                    ),
                  _buildControls(),
                ],
              );
            }

            if (widget.isAudio) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Icon(Icons.audiotrack, size: 48),
                  ),
                ],
              );
            }

            return Stack(
              children: [
                Positioned.fill(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: AspectRatio(
                        aspectRatio: aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: _buildOverlayLayer(constraints, position),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: _buildControls(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _StickerIcon extends StatelessWidget {
  final String type;

  const _StickerIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (type) {
      case 'star':
        icon = Icons.star;
        break;
      case 'heart':
        icon = Icons.favorite;
        break;
      case 'idea':
        icon = Icons.lightbulb_outline;
        break;
      default:
        icon = Icons.circle;
    }
    return Icon(
      icon,
      color: Colors.white,
      size: 32,
    );
  }
}
