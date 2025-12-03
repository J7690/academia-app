import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Écran de capture vidéo générique pour le mini TikTok.
///
/// - Utilise le plugin `camera` sur mobile, tablette et web.
/// - Retourne un `XFile` via Navigator.pop lorsque l'utilisateur valide
///   l'enregistrement.
class ChallengeCameraCaptureScreen extends StatefulWidget {
  final Duration maxDuration;

  const ChallengeCameraCaptureScreen({
    super.key,
    this.maxDuration = const Duration(seconds: 60),
  });

  @override
  State<ChallengeCameraCaptureScreen> createState() =>
      _ChallengeCameraCaptureScreenState();
}

class _ChallengeCameraCaptureScreenState
    extends State<ChallengeCameraCaptureScreen> {
  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  int _currentCameraIndex = 0;
  bool _initializing = true;
  bool _isRecording = false;
  XFile? _recordedFile;
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initCameras();
  }

  Future<void> _initCameras() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() {
          _initializing = false;
        });
        return;
      }
      _cameras = cameras;
      final initialIndex = _pickInitialCameraIndex(cameras);
      await _startControllerForIndex(initialIndex);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
      });
    }
  }

  int _pickInitialCameraIndex(List<CameraDescription> cameras) {
    if (kIsWeb) {
      final frontIndex = cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (frontIndex != -1) return frontIndex;
    } else {
      final backIndex = cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (backIndex != -1) return backIndex;
    }
    return 0;
  }

  Future<void> _startControllerForIndex(int index) async {
    _timer?.cancel();
    await _controller?.dispose();
    setState(() {
      _initializing = true;
      _isRecording = false;
      _recordedFile = null;
      _elapsed = Duration.zero;
    });

    try {
      final camera = _cameras[index];
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: true,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _currentCameraIndex = index;
        _initializing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (_isRecording) {
      try {
        final file = await controller.stopVideoRecording();
        _timer?.cancel();
        setState(() {
          _isRecording = false;
          _recordedFile = file;
        });
      } catch (_) {
        _timer?.cancel();
        setState(() {
          _isRecording = false;
        });
      }
      return;
    }

    try {
      await controller.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordedFile = null;
        _elapsed = Duration.zero;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (!mounted) return;
        final newElapsed = _elapsed + const Duration(seconds: 1);
        if (newElapsed >= widget.maxDuration) {
          timer.cancel();
          try {
            final file = await controller.stopVideoRecording();
            setState(() {
              _isRecording = false;
              _recordedFile = file;
              _elapsed = widget.maxDuration;
            });
          } catch (_) {
            setState(() {
              _isRecording = false;
            });
          }
        } else {
          setState(() {
            _elapsed = newElapsed;
          });
        }
      });
    } catch (_) {
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    final nextIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _startControllerForIndex(nextIndex);
  }

  void _confirm() {
    final file = _recordedFile;
    if (file == null) return;
    Navigator.of(context).pop<XFile>(file);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Enregistrer une vidéo'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _initializing
                  ? const CircularProgressIndicator()
                  : (controller == null || !controller.value.isInitialized)
                      ? const Text(
                          'Caméra indisponible',
                          style: TextStyle(color: Colors.white70),
                        )
                      : AspectRatio(
                          aspectRatio: controller.value.aspectRatio,
                          child: CameraPreview(controller),
                        ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isRecording || _elapsed > Duration.zero)
                  Text(
                    _formatDuration(_elapsed),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      onPressed: _cameras.length < 2 || _initializing
                          ? null
                          : _switchCamera,
                      icon: const Icon(
                        Icons.cameraswitch,
                        color: Colors.white,
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isRecording ? Colors.redAccent : Colors.white,
                        foregroundColor:
                            _isRecording ? Colors.white : Colors.black,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(18),
                      ),
                      onPressed: _initializing ? null : _toggleRecording,
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.videocam,
                      ),
                    ),
                    TextButton(
                      onPressed: _recordedFile == null ? null : _confirm,
                      child: const Text(
                        'Utiliser',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop<XFile?>(null);
                  },
                  child: const Text(
                    'Annuler',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
