import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// ---------------------------------------------------------------------------
// Color filter presets applied live on the camera preview (TikTok-style)
// ---------------------------------------------------------------------------
class _CameraFilter {
  final String label;
  final ColorFilter? filter;
  const _CameraFilter(this.label, this.filter);
}

final List<_CameraFilter> _kFilters = [
  const _CameraFilter('Normal', null),
  _CameraFilter(
    'Chaud',
    ColorFilter.matrix(<double>[
      1.2, 0.1, 0, 0, 10, //
      0, 1.0, 0, 0, 0,
      0, 0, 0.8, 0, 0,
      0, 0, 0, 1, 0,
    ]),
  ),
  _CameraFilter(
    'Froid',
    ColorFilter.matrix(<double>[
      0.8, 0, 0, 0, 0, //
      0, 1.0, 0.1, 0, 0,
      0, 0, 1.3, 0, 10,
      0, 0, 0, 1, 0,
    ]),
  ),
  _CameraFilter(
    'N&B',
    const ColorFilter.matrix(<double>[
      0.33, 0.59, 0.11, 0, 0, //
      0.33, 0.59, 0.11, 0, 0,
      0.33, 0.59, 0.11, 0, 0,
      0, 0, 0, 1, 0,
    ]),
  ),
  _CameraFilter(
    'Sépia',
    const ColorFilter.matrix(<double>[
      0.393, 0.769, 0.189, 0, 0, //
      0.349, 0.686, 0.168, 0, 0,
      0.272, 0.534, 0.131, 0, 0,
      0, 0, 0, 1, 0,
    ]),
  ),
  _CameraFilter(
    'Vif',
    ColorFilter.matrix(<double>[
      1.4, 0, 0, 0, -20, //
      0, 1.4, 0, 0, -20,
      0, 0, 1.4, 0, -20,
      0, 0, 0, 1, 0,
    ]),
  ),
];

// ---------------------------------------------------------------------------
// Segment data for multi-segment recording
// ---------------------------------------------------------------------------
class _RecordedSegment {
  final XFile file;
  final Duration duration;
  const _RecordedSegment({required this.file, required this.duration});
}

/// Écran de capture vidéo TikTok-style pour le mini TikTok.
///
/// Fonctionnalités :
/// - Filtres couleur live (Normal, Chaud, Froid, N&B, Sépia, Vif)
/// - Timer countdown avant enregistrement (off, 3s, 5s, 10s)
/// - Multi-segments : enregistrer plusieurs clips, supprimer le dernier
/// - Flash toggle (torche)
/// - Switch caméra front/back
/// - Sélecteur de vitesse (0.5x, 1x, 2x, 3x)
/// - Barre de progression multi-segments
/// - Retourne un `XFile` (ou liste via segments) via Navigator.pop
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
    extends State<ChallengeCameraCaptureScreen>
    with SingleTickerProviderStateMixin {
  // Camera
  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  int _currentCameraIndex = 0;
  bool _initializing = true;
  bool _isRecording = false;

  // Multi-segment
  final List<_RecordedSegment> _segments = [];
  Duration _currentSegmentElapsed = Duration.zero;
  Timer? _recordTimer;

  // Countdown timer
  int _countdownSetting = 0; // 0 = off, 3, 5, 10
  int _countdownRemaining = 0;
  Timer? _countdownTimer;
  bool _isCountingDown = false;

  // Filter
  int _filterIndex = 0;

  // Flash
  bool _flashOn = false;

  // Animated logo (TikTok-style floating watermark)
  late final AnimationController _logoAnimController;
  late final Animation<Alignment> _logoAlignment;

  // Speed
  double _speed = 1.0;
  static const List<double> _speeds = [0.5, 1.0, 2.0, 3.0];

  Duration get _totalRecorded {
    var total = Duration.zero;
    for (final s in _segments) {
      total += s.duration;
    }
    return total + _currentSegmentElapsed;
  }

  @override
  void initState() {
    super.initState();
    // Floating logo animation: drifts slowly between corners over 8 seconds
    _logoAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _logoAlignment = TweenSequence<Alignment>([
      TweenSequenceItem(tween: AlignmentTween(begin: const Alignment(0.85, -0.75), end: const Alignment(-0.80, -0.60)), weight: 1),
      TweenSequenceItem(tween: AlignmentTween(begin: const Alignment(-0.80, -0.60), end: const Alignment(0.75, 0.55)), weight: 1),
      TweenSequenceItem(tween: AlignmentTween(begin: const Alignment(0.75, 0.55), end: const Alignment(-0.70, 0.70)), weight: 1),
      TweenSequenceItem(tween: AlignmentTween(begin: const Alignment(-0.70, 0.70), end: const Alignment(0.85, -0.75)), weight: 1),
    ]).animate(CurvedAnimation(parent: _logoAnimController, curve: Curves.easeInOut));
    _initCameras();
  }

  Future<void> _initCameras() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() => _initializing = false);
        return;
      }
      _cameras = cameras;
      final initialIndex = _pickInitialCameraIndex(cameras);
      await _startControllerForIndex(initialIndex);
    } catch (_) {
      if (!mounted) return;
      setState(() => _initializing = false);
    }
  }

  int _pickInitialCameraIndex(List<CameraDescription> cameras) {
    if (kIsWeb) {
      final i = cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      return i != -1 ? i : 0;
    }
    final i = cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    return i != -1 ? i : 0;
  }

  Future<void> _startControllerForIndex(int index) async {
    _recordTimer?.cancel();
    _countdownTimer?.cancel();
    await _controller?.dispose();
    setState(() {
      _initializing = true;
      _isRecording = false;
      _isCountingDown = false;
      _currentSegmentElapsed = Duration.zero;
    });

    try {
      final camera = _cameras[index];
      final controller = CameraController(
        camera,
        ResolutionPreset.veryHigh,
        enableAudio: true,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      // Restore flash state
      if (_flashOn && camera.lensDirection == CameraLensDirection.back) {
        try {
          await controller.setFlashMode(FlashMode.torch);
        } catch (_) {}
      }
      setState(() {
        _controller = controller;
        _currentCameraIndex = index;
        _initializing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _initializing = false);
    }
  }

  @override
  void dispose() {
    _logoAnimController.dispose();
    _recordTimer?.cancel();
    _countdownTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  // --- Recording ---

  void _onRecordButtonPressed() {
    if (_isPhotoMode) {
      _takePhoto();
      return;
    }
    if (_isRecording) {
      _stopCurrentSegment();
      return;
    }
    if (_isCountingDown) {
      _cancelCountdown();
      return;
    }
    if (_countdownSetting > 0) {
      _startCountdown();
    } else {
      _startRecording();
    }
  }

  Future<void> _takePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final file = await controller.takePicture();
      if (mounted) {
        Navigator.of(context).pop<List<XFile>>([file]);
      }
    } catch (e) {
      debugPrint('[Camera] Photo capture error: $e');
    }
  }

  void _startCountdown() {
    setState(() {
      _isCountingDown = true;
      _countdownRemaining = _countdownSetting;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final next = _countdownRemaining - 1;
      if (next <= 0) {
        t.cancel();
        setState(() {
          _isCountingDown = false;
          _countdownRemaining = 0;
        });
        _startRecording();
      } else {
        setState(() => _countdownRemaining = next);
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _isCountingDown = false;
      _countdownRemaining = 0;
    });
  }

  Future<void> _startRecording() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_totalRecorded >= _effectiveMaxDuration) return;

    try {
      await controller.startVideoRecording();
      setState(() {
        _isRecording = true;
        _currentSegmentElapsed = Duration.zero;
      });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        final inc = Duration(milliseconds: (100 * _speed).round());
        final newElapsed = _currentSegmentElapsed + inc;
        if (_totalRecorded - _currentSegmentElapsed + newElapsed >=
            _effectiveMaxDuration) {
          t.cancel();
          _stopCurrentSegment();
          return;
        }
        setState(() => _currentSegmentElapsed = newElapsed);
      });
    } catch (_) {
      setState(() => _isRecording = false);
    }
  }

  Future<void> _stopCurrentSegment() async {
    _recordTimer?.cancel();
    final controller = _controller;
    if (controller == null) return;

    try {
      final file = await controller.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _segments.add(_RecordedSegment(
          file: file,
          duration: _currentSegmentElapsed,
        ));
        _currentSegmentElapsed = Duration.zero;
      });
    } catch (_) {
      setState(() => _isRecording = false);
    }
  }

  void _deleteLastSegment() {
    if (_segments.isEmpty || _isRecording) return;
    setState(() => _segments.removeLast());
  }

  // --- Flash ---

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null) return;
    final camera = _cameras[_currentCameraIndex];
    if (camera.lensDirection != CameraLensDirection.back) return;

    final newFlash = !_flashOn;
    try {
      await controller.setFlashMode(
        newFlash ? FlashMode.torch : FlashMode.off,
      );
      setState(() => _flashOn = newFlash);
    } catch (_) {}
  }

  // --- Switch camera ---

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isRecording) return;
    final nextIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _startControllerForIndex(nextIndex);
  }

  // --- Speed ---

  void _cycleSpeed() {
    if (_isRecording) return;
    final idx = _speeds.indexOf(_speed);
    final next = (idx + 1) % _speeds.length;
    setState(() => _speed = _speeds[next]);
  }

  // --- Countdown setting ---

  void _cycleCountdown() {
    if (_isRecording) return;
    const options = [0, 3, 5, 10];
    final idx = options.indexOf(_countdownSetting);
    final next = (idx + 1) % options.length;
    setState(() => _countdownSetting = options[next]);
  }

  // --- Pick from gallery (TikTok "Upload" button) ---

  Future<void> _pickFromGallery() async {
    final tGalleryStart = DateTime.now();
    debugPrint('[TIMING] T_GALLERY_START - Clic bouton galerie: ${tGalleryStart.toIso8601String()}');
    
    if (_isRecording || _isCountingDown) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickVideo(source: ImageSource.gallery);
      final tGalleryEnd = DateTime.now();
      debugPrint('[TIMING] T_GALLERY_END - Vidéo sélectionnée dans galerie: ${tGalleryEnd.toIso8601String()} (ΔT: ${tGalleryEnd.difference(tGalleryStart).inMilliseconds}ms)');
      
      if (picked != null && mounted) {
        Navigator.of(context).pop<List<XFile>>([picked]);
      }
    } catch (e) {
      debugPrint('[Camera] Gallery picker error: $e');
    }
  }

  // --- Confirm ---

  void _confirm() {
    if (_segments.isEmpty) return;
    Navigator.of(context).pop<List<XFile>>(
      _segments.map((s) => s.file).toList(),
    );
  }

  // --- Duration mode (15s / 60s / 3min) ---
  // Index into _durationModes
  int _durationModeIndex = 1; // default 60s
  static const List<_DurationMode> _durationModes = [
    _DurationMode('15s', Duration(seconds: 15)),
    _DurationMode('60s', Duration(seconds: 60)),
    _DurationMode('3min', Duration(minutes: 3)),
    _DurationMode('📷', Duration.zero), // Photo mode
  ];

  bool get _isPhotoMode => _durationModes[_durationModeIndex].duration == Duration.zero;

  Duration get _effectiveMaxDuration => _durationModes[_durationModeIndex].duration;

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final filter = _kFilters[_filterIndex];
    final isBack = _cameras.isNotEmpty &&
        _cameras[_currentCameraIndex].lensDirection ==
            CameraLensDirection.back;
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera preview (full screen, no SafeArea) ──
          Positioned.fill(
            child: _initializing
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : (controller == null || !controller.value.isInitialized)
                    ? const Center(
                        child: Text(
                          'Caméra indisponible',
                          style: TextStyle(color: Colors.white70, fontSize: 15),
                        ),
                      )
                    : ClipRect(
                        child: ColorFiltered(
                          colorFilter: filter.filter ??
                              const ColorFilter.mode(
                                Colors.transparent,
                                BlendMode.dst,
                              ),
                          child: SizedBox.expand(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              clipBehavior: Clip.hardEdge,
                              child: SizedBox(
                                width:
                                    controller.value.previewSize?.height ?? 1,
                                height:
                                    controller.value.previewSize?.width ?? 1,
                                child: CameraPreview(controller),
                              ),
                            ),
                          ),
                        ),
                      ),
          ),

          // ── Animated Academia logo (TikTok-style floating watermark) ──
          if (_isRecording)
            AnimatedBuilder(
              animation: _logoAlignment,
              builder: (context, child) => Align(
                alignment: _logoAlignment.value,
                child: child,
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Opacity(
                  opacity: 0.35,
                  child: Image.asset(
                    'assets/ACADEMIA_logo1.png',
                    width: 48,
                    height: 48,
                    errorBuilder: (_, __, ___) => const Text(
                      'Academia',
                      style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),

          // ── Countdown overlay ──
          if (_isCountingDown)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: Text(
                  '$_countdownRemaining',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 96,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // ── Top: close button + segment progress ──
          Positioned(
            top: topPad + 8,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Row(
                  children: [
                    _circleButton(
                      icon: Icons.close,
                      onTap: () =>
                          Navigator.of(context).pop<List<XFile>?>(null),
                    ),
                    const Spacer(),
                    // Add sound button (TikTok-style)
                    if (!_isRecording)
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('♫ Sélecteur de son — bientôt disponible'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.music_note, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Ajouter un son',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 14),
                            ],
                          ),
                        ),
                      ),
                    if (_isRecording)
                      const SizedBox.shrink(),
                    const Spacer(),
                    // Timer display
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isRecording
                            ? Colors.redAccent.withValues(alpha: 0.8)
                            : Colors.black38,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _formatDuration(_totalRecorded),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 36), // balance close button
                  ],
                ),
                const SizedBox(height: 10),
                _buildSegmentProgressBar(),
              ],
            ),
          ),

          // ── Right sidebar: vertical icon buttons ──
          Positioned(
            right: 8,
            top: topPad + 90,
            child: Column(
              children: [
                _sideButton(
                  icon: Icons.cameraswitch_outlined,
                  label: 'Flip',
                  onTap: _cameras.length < 2 ? null : _switchCamera,
                ),
                const SizedBox(height: 20),
                if (isBack) ...[
                  _sideButton(
                    icon: _flashOn ? Icons.flash_on : Icons.flash_off,
                    label: _flashOn ? 'Flash' : 'Flash',
                    active: _flashOn,
                    onTap: _toggleFlash,
                  ),
                  const SizedBox(height: 20),
                ],
                _sideButton(
                  icon: Icons.timer_outlined,
                  label: _countdownSetting == 0
                      ? 'Timer'
                      : '${_countdownSetting}s',
                  active: _countdownSetting > 0,
                  onTap: _cycleCountdown,
                ),
                const SizedBox(height: 20),
                _sideButton(
                  icon: Icons.speed,
                  label: '${_speed}x',
                  active: _speed != 1.0,
                  onTap: _cycleSpeed,
                ),
                const SizedBox(height: 20),
                _sideButton(
                  icon: Icons.auto_awesome,
                  label: _kFilters[_filterIndex].label,
                  active: _filterIndex != 0,
                  onTap: _cycleFilter,
                ),
              ],
            ),
          ),

          // ── Bottom controls ──
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomPad + 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Duration mode selector (15s / 60s / 3min / 📷)
                if (!_isRecording) _buildDurationModeSelector(),
                const SizedBox(height: 10),
                // Effects / Templates row (TikTok-style)
                if (!_isRecording) _buildEffectsRow(),
                const SizedBox(height: 14),
                // Main row: undo / gallery — record — confirm
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left: undo (if segments) or gallery upload (TikTok-style)
                      SizedBox(
                        width: 48,
                        child: _isRecording
                            ? const SizedBox.shrink()
                            : _segments.isNotEmpty
                                ? _bottomIconButton(
                                    icon: Icons.undo_rounded,
                                    label: 'Suppr.',
                                    onTap: _deleteLastSegment,
                                  )
                                : _bottomIconButton(
                                    icon: Icons.photo_library_outlined,
                                    label: 'Upload',
                                    color: Colors.white,
                                    onTap: _pickFromGallery,
                                  ),
                      ),
                      // Center: record button
                      _buildRecordButton(),
                      // Right: confirm or empty
                      SizedBox(
                        width: 48,
                        child: _segments.isNotEmpty && !_isRecording
                            ? _bottomIconButton(
                                icon: Icons.check_circle_rounded,
                                label: 'OK',
                                color: const Color(0xFF1EA75C),
                                onTap: _confirm,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UI helpers ---

  void _cycleFilter() {
    setState(() {
      _filterIndex = (_filterIndex + 1) % _kFilters.length;
    });
  }

  Widget _circleButton({
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _sideButton({
    required IconData icon,
    required String label,
    bool active = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.black38,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: active ? Colors.yellowAccent : Colors.white, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.yellowAccent : Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomIconButton({
    required IconData icon,
    required String label,
    Color color = Colors.white,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordButton() {
    final bool active = !_initializing &&
        _controller != null &&
        _controller!.value.isInitialized;

    if (_isPhotoMode) {
      // Photo shutter button — white circle
      return GestureDetector(
        onTap: active ? _onRecordButtonPressed : null,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 5),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: active ? _onRecordButtonPressed : null,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: _isRecording
                ? Colors.redAccent
                : _isCountingDown
                    ? Colors.amber
                    : Colors.white.withValues(alpha: 0.6),
            width: 5,
          ),
        ),
        alignment: Alignment.center,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: _isRecording ? 30 : 60,
          height: _isRecording ? 30 : 60,
          decoration: BoxDecoration(
            color: const Color(0xFFFF2D55),
            borderRadius: BorderRadius.circular(_isRecording ? 8 : 30),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentProgressBar() {
    final maxMs = _effectiveMaxDuration.inMilliseconds;
    if (maxMs <= 0) return const SizedBox.shrink();

    return SizedBox(
      height: 3,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final children = <Widget>[];

          for (final seg in _segments) {
            final frac = seg.duration.inMilliseconds / maxMs;
            children.add(Container(
              width: (totalWidth * frac).clamp(0, totalWidth),
              color: const Color(0xFF1EA75C),
            ));
            children.add(Container(width: 2, color: Colors.white));
          }

          if (_isRecording) {
            final frac = _currentSegmentElapsed.inMilliseconds / maxMs;
            children.add(Container(
              width: (totalWidth * frac).clamp(0, totalWidth),
              color: Colors.redAccent,
            ));
          }

          return ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(
              color: Colors.white24,
              child: Row(children: children),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEffectsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _effectsRowChip(
          icon: Icons.auto_awesome_outlined,
          label: 'Effects',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Effects en direct — bientôt disponible'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
        const SizedBox(width: 12),
        _effectsRowChip(
          icon: Icons.dashboard_outlined,
          label: 'Templates',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Templates vidéo — bientôt disponible'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _effectsRowChip({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationModeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_durationModes.length, (i) {
        final mode = _durationModes[i];
        final selected = i == _durationModeIndex;
        return GestureDetector(
          onTap: () {
            if (_isRecording || _segments.isNotEmpty) return;
            setState(() => _durationModeIndex = i);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              mode.label,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white70,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        );
      }),
    );
  }

  String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _DurationMode {
  final String label;
  final Duration duration;
  const _DurationMode(this.label, this.duration);
}
