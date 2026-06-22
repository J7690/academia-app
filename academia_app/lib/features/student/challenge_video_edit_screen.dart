import 'dart:io';

import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// CapCut-style video editor screen.
///
/// Features:
/// - Trim (start/end sliders)
/// - Speed adjustment (0.5x, 1x, 1.5x, 2x, 3x)
/// - Rotate (90°, 180°, 270°)
/// - Crop (16:9, 9:16, 1:1, 4:3)
/// - Merge multiple clips
/// - Export with progress indicator
/// Note: Compression disabled - handled by Kamatera Edge Functions
///
/// Returns the exported file path via Navigator.pop.
class ChallengeVideoEditScreen extends StatefulWidget {
  /// Paths of video files to edit. If multiple, they will be merged.
  final List<String> videoPaths;

  const ChallengeVideoEditScreen({
    super.key,
    required this.videoPaths,
  });

  @override
  State<ChallengeVideoEditScreen> createState() =>
      _ChallengeVideoEditScreenState();
}

class _ChallengeVideoEditScreenState extends State<ChallengeVideoEditScreen> {
  // Player
  VideoPlayerController? _playerController;
  bool _playerReady = false;

  // Trim
  double _trimStartMs = 0;
  double _trimEndMs = 0;
  double _videoDurationMs = 0;

  // Speed
  double _speed = 1.0;
  static const List<double> _speeds = [0.5, 1.0, 1.5, 2.0, 3.0];

  // Rotate
  int _rotationSteps = 0; // 0, 1, 2, 3 → 0°, 90°, 180°, 270°

  // Crop
  String _cropLabel = 'Original';
  VideoAspectRatio? _cropRatio;

  // Compress DISABLED - handled by Kamatera Edge Functions
  // String _compressLabel = '720p';
  // VideoResolution _compressResolution = VideoResolution.p720;

  // Export
  bool _isExporting = false;
  double _exportProgress = 0;

  // Active tool
  String _activeTool = 'trim'; // trim, speed, rotate, crop

  String get _primaryPath => widget.videoPaths.first;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (kIsWeb) return; // Video editing not supported on web
    try {
      final ctrl = VideoPlayerController.file(File(_primaryPath));
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.play();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _playerController = ctrl;
        _playerReady = true;
        _videoDurationMs = ctrl.value.duration.inMilliseconds.toDouble();
        _trimEndMs = _videoDurationMs;
      });
    } catch (e) {
      debugPrint('[ChallengeVideoEditScreen] player init error: $e');
    }
  }

  @override
  void dispose() {
    _playerController?.dispose();
    super.dispose();
  }

  // --- Export ---

  Future<void> _export() async {
    if (_isExporting) return;
    setState(() {
      _isExporting = true;
      _exportProgress = 0;
    });

    try {
      var builder = VideoEditorBuilder(videoPath: _primaryPath);

      // Merge if multiple clips
      if (widget.videoPaths.length > 1) {
        builder = builder.merge(
          otherVideoPaths: widget.videoPaths.sublist(1),
        );
      }

      // Trim
      if (_trimStartMs > 0 || _trimEndMs < _videoDurationMs) {
        builder = builder.trim(
          startTimeMs: _trimStartMs.round(),
          endTimeMs: _trimEndMs.round(),
        );
      }

      // Speed
      if (_speed != 1.0) {
        builder = builder.speed(speed: _speed);
      }

      // Rotate
      if (_rotationSteps > 0) {
        final degree = _rotationSteps == 1
            ? RotationDegree.degree90
            : _rotationSteps == 2
                ? RotationDegree.degree180
                : RotationDegree.degree270;
        builder = builder.rotate(degree: degree);
      }

      // Crop
      if (_cropRatio != null) {
        builder = builder.crop(aspectRatio: _cropRatio!);
      }

      // Compress DISABLED - handled by Kamatera Edge Functions
      // builder = builder.compress(resolution: _compressResolution);

      // Export
      final outputPath = await builder.export(
        onProgress: (progress) {
          if (mounted) {
            setState(() => _exportProgress = progress);
          }
        },
      );

      if (!mounted) return;

      if (outputPath != null && outputPath.isNotEmpty) {
        Navigator.of(context).pop<String>(outputPath);
      } else {
        _showError('Erreur lors de l\'export de la vidéo.');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Erreur d\'export : $e');
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            _buildTopBar(),
            // Video preview
            Expanded(child: _buildPreview()),
            // Tool panel
            _buildToolPanel(),
            // Tool selector
            _buildToolSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop<String?>(null),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
          const Spacer(),
          if (widget.videoPaths.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.videoPaths.length} clips',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          _isExporting
              ? SizedBox(
                  width: 100,
                  child: LinearProgressIndicator(
                    value: _exportProgress,
                    backgroundColor: Colors.white24,
                    color: const Color(0xFF1EA75C),
                  ),
                )
              : ElevatedButton(
                  onPressed: _export,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1EA75C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                  ),
                  child: const Text('Exporter',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (!_playerReady || _playerController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final ctrl = _playerController!;
    final aspectRatio = ctrl.value.aspectRatio;

    return Center(
      child: AspectRatio(
        aspectRatio: aspectRatio > 0 ? aspectRatio : 9 / 16,
        child: Transform.rotate(
          angle: _rotationSteps * 1.5707963, // π/2
          child: VideoPlayer(ctrl),
        ),
      ),
    );
  }

  Widget _buildToolPanel() {
    switch (_activeTool) {
      case 'trim':
        return _buildTrimPanel();
      case 'speed':
        return _buildSpeedPanel();
      case 'rotate':
        return _buildRotatePanel();
      case 'crop':
        return _buildCropPanel();
      // Compress DISABLED - handled by Kamatera Edge Functions
      // case 'compress':
      //   return _buildCompressPanel();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- Trim panel ---

  Widget _buildTrimPanel() {
    if (_videoDurationMs <= 0) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Chargement...', style: TextStyle(color: Colors.white70)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmtMs(_trimStartMs.round()),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              Text(
                'Durée : ${_fmtMs((_trimEndMs - _trimStartMs).round())}',
                style: const TextStyle(
                    color: Color(0xFF1EA75C),
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              Text(
                _fmtMs(_trimEndMs.round()),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          RangeSlider(
            values: RangeValues(_trimStartMs, _trimEndMs),
            min: 0,
            max: _videoDurationMs,
            activeColor: const Color(0xFF1EA75C),
            inactiveColor: Colors.white24,
            onChanged: (v) {
              setState(() {
                _trimStartMs = v.start;
                _trimEndMs = v.end;
              });
              // Seek to start for preview
              _playerController?.seekTo(
                Duration(milliseconds: v.start.round()),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Speed panel ---

  Widget _buildSpeedPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _speeds.map((s) {
          final selected = s == _speed;
          return GestureDetector(
            onTap: () {
              setState(() => _speed = s);
              _playerController?.setPlaybackSpeed(s);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF1EA75C) : Colors.white12,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${s}x',
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Rotate panel ---

  Widget _buildRotatePanel() {
    final labels = ['0°', '90°', '180°', '270°'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(4, (i) {
          final selected = i == _rotationSteps;
          return GestureDetector(
            onTap: () => setState(() => _rotationSteps = i),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF1EA75C) : Colors.white12,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // --- Crop panel ---

  Widget _buildCropPanel() {
    final options = <MapEntry<String, VideoAspectRatio?>>[
      const MapEntry('Original', null),
      const MapEntry('16:9', VideoAspectRatio.ratio16x9),
      const MapEntry('9:16', VideoAspectRatio.ratio9x16),
      const MapEntry('1:1', VideoAspectRatio.ratio1x1),
      const MapEntry('4:3', VideoAspectRatio.ratio4x3),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: options.map((o) {
          final selected = o.key == _cropLabel;
          return GestureDetector(
            onTap: () => setState(() {
              _cropLabel = o.key;
              _cropRatio = o.value;
            }),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF1EA75C) : Colors.white12,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                o.key,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Compress panel DISABLED - handled by Kamatera Edge Functions ---

  // Widget _buildCompressPanel() {
  //   final options = <MapEntry<String, VideoResolution>>[
  //     const MapEntry('360p', VideoResolution.p360),
  //     const MapEntry('480p', VideoResolution.p480),
  //     const MapEntry('720p', VideoResolution.p720),
  //     const MapEntry('1080p', VideoResolution.p1080),
  //   ];

  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 12),
  //     child: Row(
  //       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //       children: options.map((o) {
  //         final selected = o.key == _compressLabel;
  //         return GestureDetector(
  //           onTap: () => setState(() {
  //             _compressLabel = o.key;
  //             _compressResolution = o.value;
  //           }),
  //           child: Container(
  //             padding:
  //                 const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  //             decoration: BoxDecoration(
  //               color: selected ? const Color(0xFF1EA75C) : Colors.white12,
  //               borderRadius: BorderRadius.circular(20),
  //             ),
  //             child: Text(
  //               o.key,
  //               style: TextStyle(
  //                 color: selected ? Colors.white : Colors.white70,
  //                 fontWeight:
  //                     selected ? FontWeight.w600 : FontWeight.normal,
  //                 fontSize: 14,
  //               ),
  //             ),
  //           ),
  //         );
  //       }).toList(),
  //     ),
  //   );
  // }

  // --- Tool selector ---

  Widget _buildToolSelector() {
    final tools = <MapEntry<String, IconData>>[
      const MapEntry('trim', Icons.content_cut),
      const MapEntry('speed', Icons.speed),
      const MapEntry('rotate', Icons.rotate_right),
      const MapEntry('crop', Icons.crop),
      // Compress DISABLED - handled by Kamatera Edge Functions
      // const MapEntry('compress', Icons.compress),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: tools.map((t) {
          final selected = t.key == _activeTool;
          return GestureDetector(
            onTap: () => setState(() => _activeTool = t.key),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  t.value,
                  color: selected ? const Color(0xFF1EA75C) : Colors.white54,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  _toolLabel(t.key),
                  style: TextStyle(
                    color:
                        selected ? const Color(0xFF1EA75C) : Colors.white54,
                    fontSize: 11,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _toolLabel(String key) {
    switch (key) {
      case 'trim':
        return 'Couper';
      case 'speed':
        return 'Vitesse';
      case 'rotate':
        return 'Rotation';
      case 'crop':
        return 'Recadrer';
      case 'compress':
        return 'Qualité';
      default:
        return key;
    }
  }

  String _fmtMs(int ms) {
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}
