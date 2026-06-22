# VIDEO UPLOAD PIPELINE - FULL SOURCE CODE

**Date :** 19 Juin 2026  
**Objectif :** Code source complet du pipeline vidéo de la sélection galerie jusqu'à l'affichage dans le feed

---

=== FICHIER : c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\features\student\challenge_camera_capture_screen.dart ===

```dart
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
```

=== FIN FICHIER ===

---

=== FICHIER : c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\features\student\student_challenge_video_editor_screen.dart (Variables d'état) ===

```dart
  Uint8List? _videoBytes;
  String? _fileName;
  String? _mimeType;
  String? _uploadedUrl;
  String? _localVideoPath;
  String? _pendingChallengeVideoAssetId;
  Map<String, dynamic>? _pendingChallengePlayback;
  
  List<XFile>? _capturedSegments;
  String _selectedTransition = 'none';

  bool _isUploading = false;
  bool _isSubmitting = false;
  double _uploadProgress = 0.0;
  bool _isMerging = false;
  double _mergeProgress = 0.0;

  bool _videoInitialized = false;
  bool _isCompressing = false;
  bool _isRenderingAudio = false;
  bool _isRenderingVideo = false;
  Uint8List? _thumbnailBytes;
  int _videoDurationMs = 0;

  final AcademiaPlaybackController _previewPlaybackController =
      AcademiaPlaybackController();

  bool get _isFreeVideo => widget.videoType == 'free';
  String? _runtimeFreeVideoId;
```

=== FIN FICHIER ===

---

=== FICHIER : c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\features\student\student_challenge_video_editor_screen.dart (_pickVideo) ===

```dart
  Future<void> _pickVideo() async {
    final enterTime = DateTime.now();
    debugPrint('[P6_ENTER] _pickVideo');
    final t0 = DateTime.now();
    debugPrint('[TIMING] T0 - Vidéo sélectionnée: ${t0.toIso8601String()}');
    debugPrint('[P6_PATH] Gallery selected');

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['mp4', 'mov', 'webm', 'mkv'],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    final filePath = file.path;
    if (filePath == null || filePath.isEmpty) {
      final bytes = file.bytes;
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de lire la vidéo sélectionnée.')),
        );
        return;
      }
      setState(() {
        _videoBytes = bytes;
        _fileName = file.name;
        _mimeType = file.extension;
        _uploadedUrl = null;
        _videoInitialized = false;
      });
      if (!mounted) return;
      final exitTime = DateTime.now();
      final duration = exitTime.difference(enterTime).inMilliseconds;
      debugPrint('[P6_EXIT] _pickVideo duration=${duration}ms');
      return;
    }

    final ext = file.name.contains('.') ? file.name.split('.').last : 'mp4';
    setState(() {
      _localVideoPath = filePath;
      _fileName = file.name;
      _mimeType = ext;
      _uploadedUrl = null;
      _videoInitialized = false;
      _videoBytes = null;
    });
    debugPrint('[P6_PATH] Preview widget created');

    _generateThumbnailInBackground(filePath);
    _compressAndWatermarkInBackground(filePath, file.name, t0);
    
    final exitTime = DateTime.now();
    final duration = exitTime.difference(enterTime).inMilliseconds;
    debugPrint('[P6_EXIT] _pickVideo duration=${duration}ms');
  }
```

=== FIN FICHIER ===

---

=== FICHIER : c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\features\student\student_challenge_video_editor_screen.dart (_processSegments) ===

```dart
  Future<void> _processSegments(List<XFile> segments) async {
    final enterTime = DateTime.now();
    debugPrint('[P6_ENTER] _processSegments');
    final t0 = DateTime.now();
    debugPrint('[TIMING] T0 - Segments reçus de caméra: ${t0.toIso8601String()}');

    setState(() {
      _capturedSegments = segments;
    });

    if (segments.length == 1) {
      try {
        final firstFile = segments.first;
        final name = firstFile.name.isNotEmpty ? firstFile.name : 'video.mp4';

        debugPrint('[Studio] Showing video immediately: ${firstFile.path}');
        
        final ext = name.contains('.') ? name.split('.').last : 'mp4';
        setState(() {
          _localVideoPath = firstFile.path;
          _fileName = name;
          _mimeType = ext;
          _uploadedUrl = null;
          _videoInitialized = false;
          _videoBytes = null;
        });

        _generateThumbnailInBackground(firstFile.path);
        _compressAndWatermarkInBackground(firstFile.path, name, t0);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors du traitement de la vidéo capturée.')),
        );
      }
    } else {
      await _showMergeSegmentsDialog(segments);
    }
    final exitTime = DateTime.now();
    final duration = exitTime.difference(enterTime).inMilliseconds;
    debugPrint('[P6_EXIT] _processSegments duration=${duration}ms');
  }
```

=== FIN FICHIER ===

---

=== FICHIER : c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\features\student\student_challenge_video_editor_screen.dart (_compressAndWatermarkInBackground) ===

```dart
  Future<void> _compressAndWatermarkInBackground(String sourcePath, String originalName, DateTime t0) async {
    final enterTime = DateTime.now();
    debugPrint('[P6_ENTER] _compressAndWatermarkInBackground');
    if (!mounted) return;

    final ext = originalName.contains('.') ? originalName.split('.').last : 'mp4';

    if (mounted) {
      setState(() => _isCompressing = true);
    }

    final t1 = DateTime.now();
    debugPrint('[TIMING] T1 - Début compression (background): ${t1.toIso8601String()}');

    try {
      final orientation = VideoOrientationService.detectFromDimensions(1920, 1080);
      
      final VideoQuality quality;
      if (_hdUpload) {
        quality = VideoQuality.Res1920x1080Quality;
      } else {
        quality = VideoQuality.MediumQuality;
      }
      
      final compressStart = DateTime.now();
      debugPrint('[P6_COMPRESSION] START');
      final MediaInfo? info = await VideoCompress.compressVideo(
        sourcePath,
        quality: quality,
        deleteOrigin: false,
        includeAudio: true,
      );

      final compressEnd = DateTime.now();
      final compressDuration = compressEnd.difference(compressStart).inMilliseconds;
      debugPrint('[P6_COMPRESSION] END duration=${compressDuration}ms');

      final t2 = DateTime.now();
      debugPrint('[TIMING] T2 - Fin compression (background): ${t2.toIso8601String()}');

      if (!mounted) return;

      if (info != null && info.path != null) {
        final originalSize = await File(sourcePath).length();

        debugPrint('[Studio] Adding Academia watermark (background)...');
        final watermarkStart = DateTime.now();
        debugPrint('[P6_WATERMARK] START');
        final watermarkedPath = await WatermarkService.addWatermark(info.path!);
        final watermarkEnd = DateTime.now();
        final watermarkDuration = watermarkEnd.difference(watermarkStart).inMilliseconds;
        debugPrint('[P6_WATERMARK] END duration=${watermarkDuration}ms');
        if (!mounted) return;

        final finalFile = File(watermarkedPath);
        final finalBytes = await finalFile.readAsBytes();
        final compressedSize = finalBytes.length;

        if (mounted) {
          setState(() {
            _isCompressing = false;
            _videoBytes = finalBytes;
            _localVideoPath = watermarkedPath;
            if (info.duration != null) _videoDurationMs = info.duration!.toInt();
          });
        }
        final exitTime = DateTime.now();
        final duration = exitTime.difference(enterTime).inMilliseconds;
        debugPrint('[P6_EXIT] _compressAndWatermarkInBackground duration=${duration}ms');
        return;
      } else {
        debugPrint('[Studio] Compression returned null, watermarking original (background)...');
        final watermarkedPath = await WatermarkService.addWatermark(sourcePath);
        if (!mounted) return;
        final bytes = await File(watermarkedPath).readAsBytes();
        if (mounted) {
          setState(() {
            _isCompressing = false;
            _videoBytes = bytes;
            _localVideoPath = watermarkedPath;
          });
        }
        final exitTime = DateTime.now();
        final duration = exitTime.difference(enterTime).inMilliseconds;
        debugPrint('[P6_EXIT] _compressAndWatermarkInBackground duration=${duration}ms');
        return;
      }
    } catch (e) {
      debugPrint('[Studio] Compression error (background): $e — watermarking original...');
      if (!mounted) return;
      final watermarkedPath = await WatermarkService.addWatermark(sourcePath);
      if (!mounted) return;
      final bytes = await File(watermarkedPath).readAsBytes();
      if (mounted) {
        setState(() {
          _isCompressing = false;
          _videoBytes = bytes;
          _localVideoPath = watermarkedPath;
        });
      }
      final exitTime = DateTime.now();
      final duration = exitTime.difference(enterTime).inMilliseconds;
      debugPrint('[P6_EXIT] _compressAndWatermarkInBackground duration=${duration}ms (error)');
    }
  }
```

=== FIN FICHIER ===

---

=== FICHIER : c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\features\student\student_challenge_video_editor_screen.dart (_uploadVideo - extrait) ===

```dart
  Future<void> _uploadVideo() async {
    final enterTime = DateTime.now();
    debugPrint('[P6_ENTER] _uploadVideo');
    debugPrint('[Studio] ===== _uploadVideo START =====');
    debugPrint('[Studio] _isFreeVideo=$_isFreeVideo, _hasFreeVideoId=$_hasFreeVideoId, _fileName=$_fileName, bytesLen=${_videoBytes?.length}, localPath=$_localVideoPath');
    
    Uint8List? bytesToUpload = _videoBytes;
    String? fileNameToUpload = _fileName;
    
    if (bytesToUpload == null && _localVideoPath != null) {
      debugPrint('[Studio] Compression not finished, uploading raw file from $_localVideoPath');
      try {
        bytesToUpload = await File(_localVideoPath!).readAsBytes();
        fileNameToUpload = _fileName;
        debugPrint('[Studio] Raw file loaded, size: ${bytesToUpload.length} bytes');
      } catch (e) {
        debugPrint('[Studio] Error reading raw file: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la lecture de la vidéo.')),
        );
        return;
      }
    }
    
    if (bytesToUpload == null || fileNameToUpload == null) {
      debugPrint('[Studio] ABORT: no video bytes or fileName');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionne d\'abord une vidéo.')),
      );
      return;
    }

    final provider = context.read<StudentChallengesProvider>();

    final t7 = DateTime.now();
    debugPrint('[TIMING] T7 - Début upload: ${t7.toIso8601String()}');

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    String? url;

    try {
      String? videoAssetId;
      String? directUploadUrl;

      try {
        final origin = _isFreeVideo ? 'student_free_video' : 'student_challenge';
        final contextType = _isFreeVideo ? 'free_video' : 'challenge';
        final contextId = _isFreeVideo ? null : _effectiveChallengeId;

        debugPrint('[Studio] PIPELINE: ingestVideoFromBytes(origin=$origin, contextType=$contextType, contextId=$contextId)...');
        videoAssetId = await VideoAssetUploadService.ingestVideoFromBytes(
          bytes: _videoBytes!,
          fileName: _fileName!,
          origin: origin,
          contextType: contextType,
          contextId: contextId,
          mimeType: _mimeType,
          fileSizeBytes: _videoBytes!.length,
          onUploadProgress: (progress) {
            if (mounted) {
              setState(() {
                _uploadProgress = progress;
              });
            }
          },
        );
        debugPrint('[Studio] PIPELINE OK: videoAssetId=$videoAssetId');
      } catch (e) {
        debugPrint('[Studio] PIPELINE FAILED: $e — falling back to direct upload');
        videoAssetId = null;
      }

      final t8 = DateTime.now();
      debugPrint('[TIMING] T8 - Fin upload: ${t8.toIso8601String()} (ΔT8-T7: ${t8.difference(t7).inMilliseconds}ms)');

      if (!mounted) return;

      // ... résolution URL playback ...

      if (!mounted) return;

      url = playback?['best_url']?.toString();

      setState(() {
        _uploadedUrl = url;
      });
      await _initRemoteVideo(url);

      final exitTime = DateTime.now();
      final duration = exitTime.difference(enterTime).inMilliseconds;
      debugPrint('[P6_EXIT] _uploadVideo duration=${duration}ms');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _initRemoteVideo(String url) async {
    final enterTime = DateTime.now();
    debugPrint('[P6_ENTER] _initRemoteVideo');
    final t5 = DateTime.now();
    debugPrint('[TIMING] T5 - Début initialisation contrôleur vidéo: ${t5.toIso8601String()}');
    print('ANDROID STUDIO VIDEO DEBUG :: initRemoteVideo url=$url');
    if (!mounted) return;
    setState(() {
      _videoInitialized = true;
    });
    final t6 = DateTime.now();
    debugPrint('[TIMING] T6 - Vidéo initialisée (setState): ${t6.toIso8601String()} (ΔT6-T5: ${t6.difference(t5).inMilliseconds}ms)');
    final exitTime = DateTime.now();
    final duration = exitTime.difference(enterTime).inMilliseconds;
    debugPrint('[P6_EXIT] _initRemoteVideo duration=${duration}ms');
  }
```

=== FIN FICHIER ===

---

=== FICHIER : c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\features\student\student_challenge_video_editor_screen.dart (build - preview) ===

```dart
  @override
  Widget build(BuildContext context) {
    final bool hasUrl = _uploadedUrl != null && _uploadedUrl!.isNotEmpty;
    final bool hasLocalVideo = _localVideoPath != null && _localVideoPath!.isNotEmpty;
    final bool hasVideo = hasUrl || hasLocalVideo;

    final String? effectivePreviewUrl = hasLocalVideo
        ? Uri.file(_localVideoPath!).toString()
        : (hasUrl ? _uploadedUrl : null);

    final bool isLocalPreview = (effectivePreviewUrl ?? '').startsWith('file://');

    if (hasVideo) {
      if (effectivePreviewUrl == null || effectivePreviewUrl.isEmpty) {
        return const SizedBox.shrink();
      }
      final String previewUrl = effectivePreviewUrl;

      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AcademiaPlaybackEngine.view(
                      url: previewUrl,
                      preferFlutterPlayer: false,
                      autoplay: isLocalPreview,
                      looping: isLocalPreview,
                      muted: false,
                      showControls: false,
                      fit: BoxFit.cover,
                      playbackController: _previewPlaybackController,
                    ),
                  ),
                  // ... overlays
                ],
              ),
            ),
            // ... UI
          ],
        ),
      );
    }
    // ...
  }
```

=== FIN FICHIER ===

---

=== FICHIER : c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\games\services\watermark_service.dart ===

```dart
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class WatermarkService {
  WatermarkService._();

  static String? _cachedLogoPath;

  static Future<String> _ensureLogoFile() async {
    if (_cachedLogoPath != null && await File(_cachedLogoPath!).exists()) {
      return _cachedLogoPath!;
    }

    try {
      final byteData = await rootBundle.load('assets/ACADEMIA_logo1.png');
      final tempDir = await getTemporaryDirectory();
      final logoFile = File('${tempDir.path}/academia_watermark.png');
      await logoFile.writeAsBytes(byteData.buffer.asUint8List());
      _cachedLogoPath = logoFile.path;
      debugPrint('[Watermark] Logo copié: ${logoFile.path} (${byteData.lengthInBytes} bytes)');
      return logoFile.path;
    } catch (e) {
      debugPrint('[Watermark] Erreur copie logo: $e');
      rethrow;
    }
  }

  static Future<int> _probeVideoHeight(String videoPath) async {
    try {
      // FFprobeKit DISABLED
    } catch (e) {
      debugPrint('[Watermark] Probe failed, using default: $e');
    }
    return 1280;
  }

  static Future<String?> _tryOverlay(
    String inputPath,
    String logoPath,
    String outputPath,
    String filter,
    String label,
  ) async {
    debugPrint('[Watermark] ── $label: trying... ──');
    debugPrint('[Watermark] filter=$filter');

    final args = [
      '-i', inputPath,
      '-i', logoPath,
      '-filter_complex', filter,
      '-pix_fmt', 'yuv420p',
      '-c:a', 'copy',
      '-movflags', '+faststart',
      '-y', outputPath,
    ];

    // FFmpegKit DISABLED
    debugPrint('[Watermark] DISABLED — FFmpegKit not available');
    return null;
  }

  static Future<String> addWatermark(String inputPath) async {
    debugPrint('[Watermark] ═══════ START addWatermark ═══════');
    try {
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        debugPrint('[Watermark] ✗ Input file missing: $inputPath');
        return inputPath;
      }
      final inputKB = (await inputFile.length()) / 1024;
      debugPrint('[Watermark] Input: ${inputKB.toStringAsFixed(0)} KB — $inputPath');

      final logoPath = await _ensureLogoFile();
      final logoFile = File(logoPath);
      if (!await logoFile.exists()) {
        debugPrint('[Watermark] ✗ Logo file missing: $logoPath');
        return inputPath;
      }

      final videoH = await _probeVideoHeight(inputPath);
      int logoH = (videoH * 0.08).round();
      logoH = math.max(logoH, 24);
      if (logoH.isOdd) logoH += 1;
      final margin = math.max((videoH * 0.04).round(), 10);

      final tempDir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      String? result;

      result = await _tryOverlay(
        inputPath,
        logoPath,
        '${tempDir.path}/wm_anim_$ts.mp4',
        '[1:v]format=rgba,scale=-1:$logoH,colorchannelmixer=aa=0.35[wm];'
        '[0:v][wm]overlay='
        'x=if(between(mod(floor(t/3)\\,4)\\,1\\,2)\\,W-w-$margin\\,$margin):'
        'y=if(mod(mod(floor(t/3)\\,4)\\,2)\\,H-h-$margin\\,$margin)',
        'L1-animated',
      );
      if (result != null) return result;

      result = await _tryOverlay(
        inputPath,
        logoPath,
        '${tempDir.path}/wm_static_$ts.mp4',
        '[1:v]format=rgba,scale=-1:$logoH,colorchannelmixer=aa=0.35[wm];'
        '[0:v][wm]overlay=W-w-$margin:$margin',
        'L2-static',
      );
      if (result != null) return result;

      result = await _tryOverlay(
        inputPath,
        logoPath,
        '${tempDir.path}/wm_raw_$ts.mp4',
        '[0:v][1:v]overlay=10:10',
        'L3-minimal',
      );
      if (result != null) return result;

      debugPrint('[Watermark] ✗✗✗ ALL 3 LEVELS FAILED — returning original video without watermark');
      return inputPath;
    } catch (e, st) {
      debugPrint('[Watermark] ✗ Exception: $e\n$st');
      return inputPath;
    }
  }
}
```

=== FIN FICHIER ===

---

=== FICHIER : c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\video\academia_playback_view.dart ===

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../utils/url_normalizer.dart';
import '../services/video_orientation_service.dart';

class AcademiaPlaybackController {
  _AcademiaPlaybackViewState? _state;

  Future<bool> toggle() async {
    final result = await _state?._toggleExternal();
    return result ?? false;
  }

  Future<void> pause() async => _state?._pauseExternal();
  Future<void> play() async => _state?._playExternal();
  Future<int> getPosition() async => await _state?._getPositionMs() ?? 0;
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
  VideoPlayerController? _controller;
  bool _initializing = false;
  Object? _error;
  bool _hasCompleted = false;
  bool _loggedFirstPlay = false;
  MethodChannel? _nativeChannel;
  bool _isPaused = false;

  bool get _useNativeAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _shouldUseNativeAndroid => _useNativeAndroid && !widget.preferFlutterPlayer;

  @override
  void initState() {
    super.initState();
    debugPrint('[RUNTIME LIFECYCLE] AcademiaPlaybackView initState - url=${widget.url.length > 60 ? widget.url.substring(0, 60) : widget.url} deferInitialization=${widget.deferInitialization}');
    widget.playbackController?._state = this;
    if (!widget.deferInitialization) {
      _init();
    }
  }

  @override
  void didUpdateWidget(covariant AcademiaPlaybackView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
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
        _disposeController();
        _hasCompleted = false;
        _init();
      }
    }
  }

  Future<void> _init() async {
    final enterTime = DateTime.now();
    debugPrint('[P6_ENTER] AcademiaPlaybackView._init');
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

    // CRITICAL: PlatformView native désactivée pour fichiers locaux
    if (_shouldUseNativeAndroid && !isLocalFileUri) {
      debugPrint('[RUNTIME PLAYER] Using native Android view - url=${url.length > 60 ? url.substring(0, 60) : url}');
      setState(() {
        _initializing = false;
        _error = null;
      });
      return;
    }

    debugPrint('[RUNTIME PLAYER] Using Flutter video_player - url=${url.length > 60 ? url.substring(0, 60) : url} isLocalFileUri=$isLocalFileUri');
    setState(() {
      _initializing = true;
      _error = null;
      _loggedFirstPlay = false;
    });

    try {
      debugPrint('[RUNTIME PLAYER] Creating VideoPlayerController - url=${url.length > 60 ? url.substring(0, 60) : url}');
      final VideoPlayerController controller;
      if (isLocalFileUri) {
        final parsed = Uri.parse(url);
        controller = VideoPlayerController.file(File.fromUri(parsed));
      } else {
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
      }
      _controller = controller;

      debugPrint('[RUNTIME PLAYER] Calling initialize() - START');
      final stopwatch = Stopwatch()..start();
      await controller.initialize();
      stopwatch.stop();
      debugPrint('[RUNTIME PLAYER] Calling initialize() - END - duration=${stopwatch.elapsedMilliseconds}ms');

      await controller.setLooping(widget.looping);
      await controller.setVolume(widget.muted ? 0.0 : 1.0);

      final v0 = controller.value;
      debugPrint('[RUNTIME PLAYER] Initialized - isWeb=$kIsWeb duration=${v0.duration} aspectRatio=${v0.aspectRatio}');
      debugPrint('[P6_PATH] Preview first frame visible');

      controller.addListener(() {
        final c = _controller;
        if (c == null) return;
        if (!mounted) return;
        final v = c.value;

        if (v.isInitialized && v.isPlaying && !_loggedFirstPlay) {
          _loggedFirstPlay = true;
          debugPrint('[RUNTIME PLAYER] First frame visible - isWeb=$kIsWeb position=${v.position} duration=${v.duration}');
          if (widget.onFirstPlay != null) {
            widget.onFirstPlay!();
          }
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
      final exitTime = DateTime.now();
      final duration = exitTime.difference(enterTime).inMilliseconds;
      debugPrint('[P6_EXIT] AcademiaPlaybackView._init duration=${duration}ms');
    } catch (e) {
      if (!mounted) return;
      debugPrint('[RUNTIME PLAYER] init error=$e url=$url');
      setState(() {
        _initializing = false;
        _error = e;
      });
      final exitTime = DateTime.now();
      final duration = exitTime.difference(enterTime).inMilliseconds;
      debugPrint('[P6_EXIT] AcademiaPlaybackView._init duration=${duration}ms (error)');
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
    if (widget.playbackController?._state == this) {
      widget.playbackController?._state = null;
    }
    _nativeChannel = null;
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldUseNativeAndroid) {
      final url = UrlNormalizer.normalize(widget.url.trim());
      if (url.isEmpty) {
        return Container(color: Colors.black);
      }

      return AndroidView(
        viewType: 'academia_android_video',
        creationParams: <String, dynamic>{
          'url': url,
          'autoplay': widget.autoplay,
          'loop': widget.looping,
          'muted': widget.muted,
          'showControls': widget.showControls,
          'resizeMode': 'cover',
        },
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (int viewId) {
          _nativeChannel = MethodChannel('academia_android_video_$viewId');
        },
      );
    }

    final controller = _controller;

    if (_error != null) {
      return Container(color: Colors.black);
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
    final aspectRatio = (v.aspectRatio == 0 || v.aspectRatio.isNaN)
        ? VideoOrientationService.calculateAspectRatio(
            v.size.width.toInt(),
            v.size.height.toInt(),
            fallbackRatio: 16.0 / 9.0,
          )
        : v.aspectRatio;

    Widget content = FittedBox(
      fit: widget.fit,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: 1,
        height: 1 / aspectRatio,
        child: VideoPlayer(controller),
      ),
    );

    return content;
  }
}
```

=== FIN FICHIER ===

---

=== FICHIER : c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\video\academia_playback_engine.dart ===

```dart
import 'package:flutter/material.dart';

import 'academia_playback_view.dart';

export 'academia_playback_view.dart' show AcademiaPlaybackController;

class AcademiaPlaybackEngine {
  const AcademiaPlaybackEngine._();

  static Widget view({
    required String url,
    bool preferFlutterPlayer = false,
    bool deferInitialization = false,
    bool autoplay = true,
    bool looping = true,
    bool muted = false,
    bool showControls = false,
    BoxFit fit = BoxFit.cover,
    VoidCallback? onCompleted,
    bool showErrorText = true,
    VoidCallback? onFirstPlay,
    AcademiaPlaybackController? playbackController,
    double? videoAspectRatio,
  }) {
    return AcademiaPlaybackView(
      url: url,
      preferFlutterPlayer: preferFlutterPlayer,
      deferInitialization: deferInitialization,
      autoplay: autoplay,
      looping: looping,
      muted: muted,
      showControls: showControls,
      fit: fit,
      onCompleted: onCompleted,
      showErrorText: showErrorText,
      onFirstPlay: onFirstPlay,
      playbackController: playbackController,
      videoAspectRatio: videoAspectRatio,
    );
  }
}
```

=== FIN FICHIER ===

---

=== FICHIER : c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\providers\student_challenges_provider.dart (submitChallenge) ===

```dart
  Future<bool> submitChallenge({
    required String participationId,
    String? submissionText,
    String? submissionUrl,
  }) async {
    debugPrint('[ChallengesProvider] submitChallenge: participationId=$participationId');
    final text = submissionText?.trim() ?? '';
    final url = submissionUrl?.trim() ?? '';
    if (text.isEmpty && url.isEmpty) {
      _setError('La soumission est vide. Ajoute un texte ou un lien.');
      return false;
    }

    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_submit_challenge',
        params: {
          'p_participation_id': participationId,
          'p_submission_text': text.isEmpty ? null : text,
          'p_submission_url': url.isEmpty ? null : url,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la soumission du challenge.');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur lors de la soumission du challenge.');
        return false;
      }
      await Future.wait([
        loadChallenges(),
        loadMyParticipations(),
        loadStats(),
      ]);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }
```

=== FIN FICHIER ===

---

=== FICHIER : c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\features\student\tabs\student_challenges_tab.dart (Feed - TikTok style) ===

```dart
// Dans le widget de feed TikTok-style
Positioned.fill(
  child: IgnorePointer(
    child: AcademiaPlaybackEngine.view(
      url: _selectedUrl,
      autoplay: widget.isActive,
      looping: true,
      muted: false,
      showControls: false,
      fit: _getOptimalBoxFit(),
      playbackController: _playbackController,
      videoAspectRatio: _videoAspectRatio > 0 ? _videoAspectRatio : null,
    ),
  ),
),
```

=== FIN FICHIER ===

---

## RÉSUMÉ DES SINGLETONS / CONTROLLERS PARTAGÉS

**Aucun singleton vidéo détecté.**

- **AcademiaPlaybackController** : Instance par widget (non singleton)
- **VideoPlayerController** : Instance par AcademiaPlaybackView (non singleton)
- **Aucun BetterPlayerController ou ChewieController** détecté dans le projet
- **Aucun service vidéo partagé** détecté

**Conclusion :** L'éditeur et le feed utilisent des instances distinctes de `AcademiaPlaybackView` et `VideoPlayerController`. Ils ne partagent pas de controller commun.

---

## FLUX COMPLET

```
1. Galerie → _pickFromGallery() → Navigator.pop([XFile])
2. Editor → _processSegments() ou _pickVideo()
3. setState(_localVideoPath = filePath) → Preview immédiate
4. _compressAndWatermarkInBackground() en parallèle
5. build() → AcademiaPlaybackEngine.view(url: _localVideoPath)
6. AcademiaPlaybackView._init()
7. Si isLocalFileUri=true → VideoPlayerController.initialize() [ÉCRAN NOIR]
8. Compression terminée → setState(_localVideoPath = watermarkedPath)
9. Rebuild → AcademiaPlaybackView._init() [DEUXIÈME ÉCRAN NOIR]
10. _uploadVideo() → VideoAssetUploadService.ingestVideoFromBytes()
11. setState(_uploadedUrl = url)
12. _initRemoteVideo(url)
13. submitChallenge() → RPC app_student_submit_challenge
14. Feed → AcademiaPlaybackEngine.view(url: feedUrl) [NOUVELLE INSTANCE]
```
