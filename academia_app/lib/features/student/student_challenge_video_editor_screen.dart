import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_compress/video_compress.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;

import '../../providers/student_challenges_provider.dart';
import '../../services/videoasset_upload_service.dart';
import '../../services/video_segment_merge_service.dart';
import '../../video/academia_playback_engine.dart';
import '../../video/audio_mix_service.dart';
import '../../video/overlay_burn_in_service.dart';
import '../../widgets/audio_picker_sheet.dart';
import '../../widgets/dj_mix_sheet.dart';
import '../../widgets/equation_editor.dart';
import '../../widgets/video_overlays_layer.dart';
import 'challenge_camera_capture_screen.dart';
import 'challenge_scientific_studio_screen.dart';
import 'challenge_video_edit_screen.dart';
import 'video_publish_screen.dart';
import 'student_challenge_video_overlays.dart';
import 'student_challenge_video_ar_screen.dart'
    if (dart.library.html) 'student_challenge_video_ar_screen_stub.dart';
import 'student_challenge_video_ar_combined_screen.dart'
    if (dart.library.html) 'student_challenge_video_ar_combined_screen_stub.dart';

class _StudioTimelineTrack {
  final String id;
  final String label;
  final String category;
  final String assetUrl;
  RangeValues range;
  double volume;

  _StudioTimelineTrack({
    required this.id,
    required this.label,
    required this.category,
    required this.assetUrl,
    required this.range,
    required this.volume,
  });
}

class StudentChallengeVideoEditorScreen extends StatefulWidget {
  final String? challengeId;
  final String? participationId;
  final String? initialMode;
  final bool asAdditionalVideo;
  final String videoType;
  final String? freeVideoId;
  final List<XFile>? initialSegments;

  const StudentChallengeVideoEditorScreen({
    super.key,
    this.challengeId,
    this.participationId,
    this.initialMode,
    this.asAdditionalVideo = false,
    this.videoType = 'challenge',
    this.freeVideoId,
    this.initialSegments,
  });

  @override
  State<StudentChallengeVideoEditorScreen> createState() =>
      _StudentChallengeVideoEditorScreenState();
}

class _StudentChallengeVideoEditorScreenState
    extends State<StudentChallengeVideoEditorScreen> {
  Uint8List? _videoBytes;
  String? _fileName;
  String? _mimeType;
  String? _uploadedUrl;
  String? _localVideoPath;
  String? _pendingChallengeVideoAssetId;
  Map<String, dynamic>? _pendingChallengePlayback;
  
  // Multi-segments support
  List<XFile>? _capturedSegments;
  String _selectedTransition = 'none';

  bool _isUploading = false;
  bool _isSubmitting = false;
  double _uploadProgress = 0.0;
  bool _isMerging = false;
  double _mergeProgress = 0.0;

  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _overlayTextController = TextEditingController();
  final TextEditingController _equationController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();

  String _backgroundTheme = 'universite-vert';
  String _selectedFilter = 'none'; // none, warm, cool, bw
  String _selectedSticker = 'none'; // none, star, heart, idea

  bool _videoInitialized = false;

  bool _isTranscribing = false;
  bool _isAnalyzing = false;
  bool _isProofreading = false;
  List<Map<String, dynamic>>? _aiSubtitles;

  bool _isLoadingAudioAssets = false;
  bool _audioAssetsLoaded = false;
  List<Map<String, dynamic>> _audioAssets = [];
  final List<_StudioTimelineTrack> _timelineTracks = [];
  bool _isCompressing = false;
  bool _isRenderingAudio = false;
  bool _isRenderingVideo = false;
  Uint8List? _thumbnailBytes;
  List<Map<String, dynamic>> _arObjects = [];
  List<Map<String, dynamic>> _textOverlays = [];
  List<Map<String, dynamic>> _zones = [];
  int _zoneIdCounter = 0;
  int? _selectedZoneIndex;
  bool _didLoadExistingOverlays = false;
  bool _isLoadingExtraClips = false;
  List<Map<String, dynamic>> _extraClips = [];
  List<String> _clipOrder = [];
  Map<String, Map<String, dynamic>> _clipEdits = {};
  final ScrollController _scrollController = ScrollController();

  final AcademiaPlaybackController _previewPlaybackController =
      AcademiaPlaybackController();

  bool get _isFreeVideo => widget.videoType == 'free';

  // Mutable free video ID — may be null when the Studio is opened from the
  // Feed before any upload. Gets assigned during _uploadVideo().
  String? _runtimeFreeVideoId;

  String get _effectiveChallengeId {
    final id = widget.challengeId;
    if (id == null || id.isEmpty) {
      throw StateError('challengeId manquant pour le mode challenge.');
    }
    return id;
  }

  String get _effectiveParticipationId {
    final id = widget.participationId;
    if (id == null || id.isEmpty) {
      throw StateError('participationId manquant pour le mode challenge.');
    }
    return id;
  }

  String get _effectiveFreeVideoId {
    final id = _runtimeFreeVideoId ?? widget.freeVideoId;
    if (id == null || id.isEmpty) {
      throw StateError('freeVideoId manquant pour le mode free.');
    }
    return id;
  }

  bool get _hasFreeVideoId {
    final id = _runtimeFreeVideoId ?? widget.freeVideoId;
    return id != null && id.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await _loadExistingOverlaysIfAny();
      await _loadExtraClipsIfAny();

      final mode = widget.initialMode;
      if (mode == null) {
        return;
      }
      _handleInitialCaptureMode(mode);
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _overlayTextController.dispose();
    _equationController.dispose();
    _subtitleController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Safely tear down video surfaces before popping the route.
  /// This prevents native crashes caused by abruptly destroying
  /// AndroidView PlatformViews while video codecs are still active.
  Future<void> _cleanupAndPop([bool result = true]) async {
    // Clear video state so the PlatformView is removed from the tree
    if (mounted) {
      setState(() {
        _uploadedUrl = null;
        _localVideoPath = null;
        _videoBytes = null;
      });
    }
    // Give the framework one frame to rebuild without the video widget
    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  void _handleInitialCaptureMode(String mode) {
    if (mode == 'gallery') {
      _pickVideo();
      return;
    }

    // Si des segments ont déjà été capturés (passés via initialSegments),
    // les traiter directement sans relancer la caméra.
    if (widget.initialSegments != null && widget.initialSegments!.isNotEmpty) {
      _processSegments(widget.initialSegments!);
      return;
    }

    // Mode "camera" : on passe par l'écran unifié de capture.
    _openCameraCaptureFlow();
  }

  Future<void> _processSegments(List<XFile> segments) async {
    setState(() {
      _capturedSegments = segments;
    });

    if (segments.length == 1) {
      // Single segment, use directly
      try {
        final firstFile = segments.first;
        final bytes = await firstFile.readAsBytes();
        final name = firstFile.name.isNotEmpty ? firstFile.name : 'video.mp4';
        final ext = name.contains('.') ? name.split('.').last : 'mp4';

        if (!mounted) return;
        setState(() {
          _videoBytes = bytes;
          _fileName = name;
          _mimeType = ext;
          _uploadedUrl = null;
          _videoInitialized = false;
          _localVideoPath = firstFile.path;
        });
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors du traitement de la vidéo capturée.'),
          ),
        );
      }
    } else {
      // Multiple segments, show merge dialog
      await _showMergeSegmentsDialog(segments);
    }
  }

  Future<void> _openCameraCaptureFlow() async {
    try {
      final result = await Navigator.of(context).push<List<XFile>?>(
        MaterialPageRoute(
          builder: (_) => const ChallengeCameraCaptureScreen(),
        ),
      );

      if (!mounted) return;

      // Utilisateur a annulé ou la caméra est indisponible.
      if (result == null || result.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Capture annulée ou caméra indisponible. Sélectionne une vidéo existante à uploader.',
            ),
          ),
        );
        return;
      }

      // Process captured segments
      await _processSegments(result);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible d\'utiliser la caméra. Essaie plutôt d\'uploader une vidéo existante.',
          ),
        ),
      );
    }
  }

  Future<void> _loadAudioAssetsIfNeeded() async {
    if (_audioAssetsLoaded || _isLoadingAudioAssets) {
      return;
    }

    setState(() {
      _isLoadingAudioAssets = true;
    });

    try {
      final client = Supabase.instance.client;
      final result = await client
          .from('app.challenge_video_assets')
          .select()
          .eq('is_active', true);

      final assets = <Map<String, dynamic>>[];
      if (result is List) {
        for (final item in result) {
          if (item is Map) {
            assets.add(Map<String, dynamic>.from(item));
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _audioAssets = assets;
        _audioAssetsLoaded = true;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Erreur lors du chargement des pistes audio Studio: $e'),
        ),
      );
      setState(() {
        _audioAssetsLoaded = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAudioAssets = false;
        });
      }
    }
  }

  Future<void> _openArStudio() async {
    if (_isSubmitting || _isUploading) {
      return;
    }

    final result = await Navigator.of(context).push<List<Map<String, dynamic>>>(
      MaterialPageRoute(
        builder: (_) => StudentChallengeVideoArScreen(
          initialObjects: _arObjects,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (result != null) {
      setState(() {
        _arObjects = result
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Objets AR 3D enregistrés pour cette vidéo (layers.ar_objects).',
          ),
        ),
      );
    }
  }

  Future<void> _recordVideoWithCamera() async {
    List<XFile>? segments;
    try {
      segments = await Navigator.of(context).push<List<XFile>>(
        MaterialPageRoute(
          builder: (_) => const ChallengeCameraCaptureScreen(
            maxDuration: Duration(seconds: 60),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible d\'ouvrir la caméra. Vérifie les autorisations de l\'appareil.',
          ),
        ),
      );
      return;
    }

    if (segments == null || segments.isEmpty) {
      return;
    }

    // Process all segments
    await _processSegments(segments);
  }

  Future<void> _pickVideo() async {
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
          const SnackBar(
              content: Text('Impossible de lire la vidéo sélectionnée.')),
        );
        return;
      }
      // Web or no path — skip compression, use raw bytes.
      setState(() {
        _videoBytes = bytes;
        _fileName = file.name;
        _mimeType = file.extension;
        _uploadedUrl = null;
        _videoInitialized = false;
      });
      if (!mounted) return;
      return;
    }

    await _compressAndSetVideo(filePath, file.name);
  }

  /// Compresses the video at [sourcePath] using hardware-accelerated
  /// LightCompressor, generates a thumbnail, then triggers upload.
  Future<void> _compressAndSetVideo(String sourcePath, String originalName) async {
    if (!mounted) return;

    final ext = originalName.contains('.')
        ? originalName.split('.').last
        : 'mp4';

    // Generate thumbnail before compression (from original for best quality).
    try {
      _thumbnailBytes = await vt.VideoThumbnail.thumbnailData(
        video: sourcePath,
        imageFormat: vt.ImageFormat.JPEG,
        maxWidth: 360,
        quality: 70,
      );
      debugPrint('[Studio] Thumbnail generated: ${_thumbnailBytes?.length ?? 0} bytes');
    } catch (e) {
      debugPrint('[Studio] Thumbnail generation failed: $e');
    }

    // Skip compression on web.
    if (kIsWeb) {
      final bytes = await File(sourcePath).readAsBytes();
      if (!mounted) return;
      setState(() {
        _videoBytes = bytes;
        _fileName = originalName;
        _mimeType = ext;
        _uploadedUrl = null;
        _videoInitialized = false;
        _localVideoPath = sourcePath;
      });
      return;
    }

    setState(() => _isCompressing = true);

    try {
      final MediaInfo? info = await VideoCompress.compressVideo(
        sourcePath,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (!mounted) return;

      if (info != null && info.path != null) {
        final compressedFile = File(info.path!);
        final compressedBytes = await compressedFile.readAsBytes();
        final originalSize = await File(sourcePath).length();
        final compressedSize = compressedBytes.length;
        debugPrint(
          '[Studio] Compression: ${(originalSize / 1024 / 1024).toStringAsFixed(1)} MB \u2192 '
          '${(compressedSize / 1024 / 1024).toStringAsFixed(1)} MB '
          '(${(100 - compressedSize * 100 / originalSize).toStringAsFixed(0)}% r\u00e9duit)',
        );

        setState(() {
          _isCompressing = false;
          _videoBytes = compressedBytes;
          _fileName = originalName;
          _mimeType = ext;
          _uploadedUrl = null;
          _videoInitialized = false;
          _localVideoPath = info.path;
        });
      } else {
        debugPrint('[Studio] Compression returned null, using original file');
        final bytes = await File(sourcePath).readAsBytes();
        if (!mounted) return;
        setState(() {
          _isCompressing = false;
          _videoBytes = bytes;
          _fileName = originalName;
          _mimeType = ext;
          _uploadedUrl = null;
          _videoInitialized = false;
          _localVideoPath = sourcePath;
        });
      }
    } catch (e) {
      debugPrint('[Studio] Compression error: $e \u2014 using original');
      if (!mounted) return;
      final bytes = await File(sourcePath).readAsBytes();
      if (!mounted) return;
      setState(() {
        _isCompressing = false;
        _videoBytes = bytes;
        _fileName = originalName;
        _mimeType = ext;
        _uploadedUrl = null;
        _videoInitialized = false;
        _localVideoPath = sourcePath;
      });
    }
  }

  Future<void> _uploadVideo() async {
    debugPrint('[Studio] ===== _uploadVideo START =====');
    debugPrint('[Studio] _isFreeVideo=$_isFreeVideo, _hasFreeVideoId=$_hasFreeVideoId, _fileName=$_fileName, bytesLen=${_videoBytes?.length}');
    if (_videoBytes == null || _fileName == null) {
      debugPrint('[Studio] ABORT: no video bytes or fileName');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionne d\'abord une vidéo.')),
      );
      return;
    }

    final provider = context.read<StudentChallengesProvider>();

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    String? url;

    try {
      // ────────────────────────────────────────────────────────────────────
      // PRIMARY PIPELINE: VideoAssetUploadService (unified)
      // Creates a video_asset, uploads to the correct bucket/path,
      // and registers the source — all in one call.
      // ────────────────────────────────────────────────────────────────────
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

      if (!mounted) return;

      // ────────────────────────────────────────────────────────────────────
      // FALLBACK: Direct Storage upload (if pipeline failed)
      // ────────────────────────────────────────────────────────────────────
      if (videoAssetId == null || videoAssetId.isEmpty) {
        debugPrint('[Studio] FALLBACK: direct Storage upload...');
        if (_isFreeVideo) {
          directUploadUrl = await provider.uploadFreeVideo(
            bytes: _videoBytes!,
            fileName: _fileName!,
            mimeType: _mimeType,
          );
        } else {
          directUploadUrl = await provider.uploadChallengeVideo(
            bytes: _videoBytes!,
            fileName: _fileName!,
            challengeId: _effectiveChallengeId,
            mimeType: _mimeType,
          );
        }

        if (!mounted) return;

        if (directUploadUrl == null) {
          final error = provider.error ?? 'Erreur lors de l\'upload de la vidéo.';
          debugPrint('[Studio] FALLBACK FAILED: $error');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
          return;
        }
        debugPrint('[Studio] FALLBACK OK: directUploadUrl=$directUploadUrl');
      }

      // ────────────────────────────────────────────────────────────────────
      // RESOLVE PLAYBACK URL
      // ────────────────────────────────────────────────────────────────────
      Map<String, dynamic>? playback;

      if (videoAssetId != null && videoAssetId.isNotEmpty) {
        // Pipeline succeeded — trigger Edge Function to mark ready + get playback
        debugPrint('[Studio] TRANSCODE: triggerTranscode($videoAssetId)...');
        try {
          final transcodeResult = await VideoAssetUploadService.triggerTranscode(
            videoAssetId: videoAssetId,
          );
          if (transcodeResult != null) {
            playback = Map<String, dynamic>.from(transcodeResult);
            debugPrint('[Studio] TRANSCODE OK: playback=$playback');
          }
        } catch (e) {
          debugPrint('[Studio] TRANSCODE failed: $e');
        }

        // Fallback: try RPC-based playback resolution
        if (playback == null || (playback['best_url']?.toString() ?? '').isEmpty) {
          debugPrint('[Studio] PLAYBACK: transcode empty, trying fetchPlaybackForVideoAsset...');
          try {
            final manifest = await provider.fetchPlaybackForVideoAsset(videoAssetId);
            if (manifest != null) {
              final rawPlayback = manifest['playback'];
              if (rawPlayback is Map<String, dynamic>) {
                playback = Map<String, dynamic>.from(rawPlayback);
              } else if (manifest['best_url'] != null) {
                playback = Map<String, dynamic>.from(manifest);
              }
            }
          } catch (e) {
            debugPrint('[Studio] PLAYBACK from asset RPC failed: $e');
          }
        }
      }

      // If we still don't have playback, resolve from direct URL
      if ((playback == null || (playback['best_url']?.toString() ?? '').isEmpty) && directUploadUrl != null) {
        debugPrint('[Studio] PLAYBACK: fetchPlaybackForDirectUrl($directUploadUrl)...');
        final manifest = await provider.fetchPlaybackForDirectUrl(directUploadUrl);
        if (!mounted) return;

        if (manifest != null) {
          final vid = manifest['video_asset_id']?.toString() ?? '';
          final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
          if (videoAssetId == null && uuidRegex.hasMatch(vid)) {
            videoAssetId = vid;
          }
          final rawPlayback = manifest['playback'];
          if (rawPlayback is Map<String, dynamic>) {
            playback = Map<String, dynamic>.from(rawPlayback);
          } else if (manifest['best_url'] != null) {
            playback = Map<String, dynamic>.from(manifest);
          }
        }

        // Ultimate fallback: use the direct URL as playback
        if (playback == null || (playback['best_url']?.toString() ?? '').isEmpty) {
          playback = {'best_url': directUploadUrl};
        }
      }

      if (!mounted) return;

      url = playback?['best_url']?.toString();

      // Ultimate safety net: if all resolution failed but we have a direct URL, use it.
      if ((url == null || url.isEmpty) && directUploadUrl != null && directUploadUrl.isNotEmpty) {
        debugPrint('[Studio] RESOLVED: url was null/empty, using directUploadUrl as final fallback');
        url = directUploadUrl;
        playback = {'best_url': directUploadUrl};
      }

      // Deterministic fallback: if we have a video_asset_id but no best_url,
      // build a public URL directly from the latest registered video_source.
      if ((url == null || url.isEmpty) && videoAssetId != null && videoAssetId.isNotEmpty) {
        debugPrint('[Studio] RESOLVED: url empty, trying fetchPublicUrlForVideoAssetSource($videoAssetId)...');
        try {
          final sourceUrl = await provider.fetchPublicUrlForVideoAssetSource(videoAssetId);
          if (sourceUrl != null && sourceUrl.isNotEmpty) {
            url = sourceUrl;
            playback = {'best_url': sourceUrl};
            debugPrint('[Studio] RESOLVED: using source publicUrl fallback');
          } else {
            debugPrint('[Studio] RESOLVED: source publicUrl fallback returned null/empty');
          }
        } catch (e) {
          debugPrint('[Studio] RESOLVED: source publicUrl fallback error: $e');
        }
      }
      debugPrint('[Studio] RESOLVED: url=$url, videoAssetId=$videoAssetId');

      // ────────────────────────────────────────────────────────────────────
      // REGISTER IN DB (free_video or challenge)
      // ────────────────────────────────────────────────────────────────────
      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      final String? resolvedAssetId = (videoAssetId != null && uuidRegex.hasMatch(videoAssetId))
          ? videoAssetId
          : null;
      final effectivePlayback = playback ?? {'best_url': url};

      if (_isFreeVideo) {
        if (!_hasFreeVideoId) {
          debugPrint('[Studio] DB: createFreeVideo(videoAssetId=$resolvedAssetId)...');
          final newId = await provider.createFreeVideo(
            videoAssetId: resolvedAssetId,
            playback: effectivePlayback,
          );
          if (!mounted) return;
          if (newId != null && newId.isNotEmpty) {
            _runtimeFreeVideoId = newId;
            debugPrint('[Studio] DB OK: _runtimeFreeVideoId=$newId');
          } else {
            debugPrint('[Studio] DB WARN: createFreeVideo failed — continuing with URL');
          }
        } else {
          debugPrint('[Studio] DB: updateFreeVideoMainRenditions(freeVideoId=$_effectiveFreeVideoId)...');
          await provider.updateFreeVideoMainRenditions(
            freeVideoId: _effectiveFreeVideoId,
            videoAssetId: resolvedAssetId,
            playback: effectivePlayback,
          );
          if (!mounted) return;
        }
      } else {
        _pendingChallengeVideoAssetId = resolvedAssetId;
        _pendingChallengePlayback = effectivePlayback;
        debugPrint('[Studio] CHALLENGE: pendingAssetId=$resolvedAssetId');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }

    if (!mounted) return;

    debugPrint('[Studio] POST-UPLOAD: url=$url');
    if (url == null || url.isEmpty) {
      // On a uploadé/ingéré la vidéo, mais le manifest de lecture n'est pas encore prêt.
      // Sur certains devices (ex: MediaTek), tenter de lire l'URL "raw" distante peut
      // crasher le décodeur. On garde donc l'aperçu local (file://) et on n'affiche
      // pas d'erreur bloquante.
      final error = provider.error ?? 'playback_url_missing';
      debugPrint('[Studio] FINAL WARN: url is null/empty, keeping local preview. error=$error');
      return;
    }
    debugPrint('[Studio] ===== _uploadVideo SUCCESS: url=$url =====');

    setState(() {
      _uploadedUrl = url;
    });
    await _initRemoteVideo(url);

    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToStudioSection();
      });
    }
  }

  String _pickBestServerVideoUrl(Map<String, dynamic> video) {
    final playback = video['playback'];
    if (playback is Map) {
      final playbackMap = Map<String, dynamic>.from(playback);
      final best = playbackMap['best_url']?.toString().trim() ?? '';
      if (best.isNotEmpty) {
        return best;
      }
    }

    return '';
  }

  String _pickBestClipUrl(List<Map<String, dynamic>> clips) {
    if (clips.isEmpty) {
      return '';
    }

    final reversed = clips.reversed;
    for (final clip in reversed) {
      final playback = clip['playback'];
      if (playback is Map) {
        final playbackMap = Map<String, dynamic>.from(playback);
        final url = playbackMap['best_url']?.toString().trim() ?? '';
        if (url.isNotEmpty && url.contains('/renders/')) {
          print(
            'ANDROID STUDIO VIDEO DEBUG :: pickBestClipUrl renders url=$url',
          );
          return url;
        }
      }
    }

    for (final clip in reversed) {
      final playback = clip['playback'];
      if (playback is Map) {
        final playbackMap = Map<String, dynamic>.from(playback);
        final url = playbackMap['best_url']?.toString().trim() ?? '';
        if (url.isNotEmpty) {
          print(
            'ANDROID STUDIO VIDEO DEBUG :: pickBestClipUrl fallback url=$url',
          );
          return url;
        }
      }
    }

    return '';
  }

  Future<void> _initRemoteVideo(String url) async {
    print('ANDROID STUDIO VIDEO DEBUG :: initRemoteVideo url=$url');
    if (!mounted) return;
    setState(() {
      _videoInitialized = true;
    });
  }

  Future<void> _loadExistingOverlaysIfAny() async {
    if (_didLoadExistingOverlays) {
      return;
    }

    // Skip if free video mode with no ID yet (new video from Feed).
    if (_isFreeVideo && !_hasFreeVideoId) {
      setState(() {
        _didLoadExistingOverlays = true;
      });
      return;
    }

    final provider = context.read<StudentChallengesProvider>();

    Map<String, dynamic>? video;
    try {
      if (_isFreeVideo) {
        video = await provider.getFreeVideoById(_effectiveFreeVideoId);
      } else {
        video = await provider.getChallengeVideoById(_effectiveParticipationId);
      }
    } catch (_) {
      // L'erreur sera exposée via provider.error si nécessaire.
    }

    if (!mounted) {
      return;
    }

    if (video == null) {
      setState(() {
        _didLoadExistingOverlays = true;
      });
      return;
    }

    String selectedUrl = _pickBestServerVideoUrl(video);

    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (!_isFreeVideo && (selectedUrl.isEmpty || (isAndroid && !selectedUrl.contains('/renders/')))) {
      List<Map<String, dynamic>> clips = [];
      try {
        clips = await provider.listMyChallengeVideos(_effectiveParticipationId);
      } catch (_) {}

      if (clips.isNotEmpty) {
        final clipUrl = _pickBestClipUrl(clips);
        if (clipUrl.isNotEmpty) {
          selectedUrl = clipUrl;
        }
      }
    }

    if (selectedUrl.isNotEmpty) {
      _uploadedUrl = selectedUrl;
      await _initRemoteVideo(selectedUrl);
    }

    Map<String, dynamic>? overlaysMap;
    final rawOverlays = video['overlays'] ?? video['layers'];
    if (rawOverlays is Map) {
      overlaysMap = Map<String, dynamic>.from(rawOverlays);
    }

    if (overlaysMap == null) {
      setState(() {
        _didLoadExistingOverlays = true;
      });
      return;
    }

    final existingClipLayers = <Map<String, dynamic>>[];
    final rawLayers = overlaysMap['layers'];
    if (rawLayers is Map) {
      final rawClips = rawLayers['clips'];
      if (rawClips is List) {
        for (final item in rawClips) {
          if (item is Map) {
            existingClipLayers.add(Map<String, dynamic>.from(item));
          }
        }
      }
    }

    ChallengeVideoOverlays overlays;
    try {
      overlays = ChallengeVideoOverlays.fromJson(overlaysMap);
    } catch (_) {
      setState(() {
        _didLoadExistingOverlays = true;
      });
      return;
    }

    setState(() {
      _didLoadExistingOverlays = true;

      _backgroundTheme = overlays.backgroundTheme;
      _selectedFilter = overlays.filter;

      _textOverlays = overlays.texts
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: true);

      if (_textOverlays.isNotEmpty) {
        final firstText = _textOverlays.first['text']?.toString() ?? '';
        if (firstText.isNotEmpty) {
          _overlayTextController.text = firstText;
        }
      }

      if (overlays.equations.isNotEmpty) {
        final first = overlays.equations.first;
        String eq = '';
        if (first['latex'] != null) {
          eq = first['latex'].toString();
        } else if (first['text'] != null) {
          eq = first['text'].toString();
        }
        if (eq.isNotEmpty) {
          _equationController.text = eq;
        }
      }

      if (overlays.subtitles.isNotEmpty) {
        _aiSubtitles = overlays.subtitles
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);

        final subtitleTexts = overlays.subtitles
            .map((e) => e['text']?.toString() ?? '')
            .where((t) => t.trim().isNotEmpty)
            .toList();
        if (subtitleTexts.isNotEmpty) {
          _subtitleController.text = subtitleTexts.join(' ');
        }
      }

      if (overlays.stickers.isNotEmpty) {
        final type = overlays.stickers.first['type']?.toString();
        if (type != null && type.isNotEmpty) {
          _selectedSticker = type;
        }
      }

      if (overlays.arObjects.isNotEmpty) {
        _arObjects = overlays.arObjects
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }

      if (existingClipLayers.isNotEmpty) {
        final order = <String>[];
        final edits = <String, Map<String, dynamic>>{};
        for (final clip in existingClipLayers) {
          final clipId = clip['clip_id']?.toString() ?? '';
          if (clipId.isEmpty) {
            continue;
          }
          order.add(clipId);

          final rawStart = clip['start_ms'];
          final rawEnd = clip['end_ms'];
          int? startMs;
          int? endMs;
          if (rawStart is int) {
            startMs = rawStart;
          } else if (rawStart is num) {
            startMs = rawStart.toInt();
          } else if (rawStart is String) {
            startMs = int.tryParse(rawStart);
          }
          if (rawEnd is int) {
            endMs = rawEnd;
          } else if (rawEnd is num) {
            endMs = rawEnd.toInt();
          } else if (rawEnd is String) {
            endMs = int.tryParse(rawEnd);
          }
          if (startMs != null || endMs != null) {
            edits[clipId] = {
              'start_ms': startMs,
              'end_ms': endMs,
            };
          }
        }
        _clipOrder = order;
        _clipEdits = edits;
      }
    });
  }

  Future<void> _loadExtraClipsIfAny() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoadingExtraClips = true;
    });
    final provider = context.read<StudentChallengesProvider>();
    List<Map<String, dynamic>> clips = [];
    try {
      if (_isFreeVideo) {
        clips = const [];
      } else {
        clips = await provider.listMyChallengeVideos(_effectiveParticipationId);
      }
    } catch (_) {
      // L'erreur éventuelle sera exposée via provider.error si besoin.
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _extraClips = clips
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
      _isLoadingExtraClips = false;

      final ids = <String>[];
      for (final clip in _extraClips) {
        final id = clip['id']?.toString();
        if (id != null && id.isNotEmpty) {
          ids.add(id);
        }
      }
      if (ids.isEmpty) {
        _clipOrder = [];
      } else if (_clipOrder.isEmpty) {
        _clipOrder = ids;
      } else {
        final existing = _clipOrder.where(ids.contains).toList();
        for (final id in ids) {
          if (!existing.contains(id)) {
            existing.add(id);
          }
        }
        _clipOrder = existing;
      }
    });
  }

  double _getTimelineDurationSeconds() {
    return 30.0;
  }

  void _scrollToStudioSection() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final target = (position.maxScrollExtent * 0.5)
        .clamp(0.0, position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  void _toggleTimelineTrackForAsset(Map<String, dynamic> asset) {
    final id = asset['id']?.toString() ?? '';
    if (id.isEmpty) {
      return;
    }

    final existingIndex = _timelineTracks.indexWhere((t) => t.id == id);
    if (existingIndex >= 0) {
      setState(() {
        _timelineTracks.removeAt(existingIndex);
      });
      return;
    }

    final label = asset['label']?.toString() ?? '';
    final category = asset['category']?.toString() ?? '';
    final assetUrl = asset['asset_url']?.toString() ?? '';
    if (label.isEmpty || assetUrl.isEmpty) {
      return;
    }

    final durationSeconds = _getTimelineDurationSeconds();

    setState(() {
      _timelineTracks.add(
        _StudioTimelineTrack(
          id: id,
          label: label,
          category: category,
          assetUrl: assetUrl,
          range: RangeValues(0.0, durationSeconds),
          volume: 1.0,
        ),
      );
    });
  }

  void _removeTimelineTrack(String id) {
    setState(() {
      _timelineTracks.removeWhere((t) => t.id == id);
    });
  }

  double _volumeToDb(double volume) {
    const double minDb = -24.0;
    const double maxDb = 0.0;
    final v = volume.clamp(0.0, 1.0);
    return minDb + (maxDb - minDb) * v;
  }

  String _formatTimelineSeconds(double seconds) {
    final total = seconds.floor();
    final minutes = (total ~/ 60).toString().padLeft(2, '0');
    final secs = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  String _formatMsLabel(int? ms) {
    if (ms == null || ms < 0) {
      return '--:--';
    }
    final totalSeconds = ms ~/ 1000;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  int? _parseMsFromLabel(String input) {
    final parts = input.split(':');
    if (parts.length != 2) {
      return null;
    }
    final minutes = int.tryParse(parts[0]);
    final seconds = int.tryParse(parts[1]);
    if (minutes == null || seconds == null) {
      return null;
    }
    if (minutes < 0 || seconds < 0 || seconds >= 60) {
      return null;
    }
    return (minutes * 60 + seconds) * 1000;
  }

  Map<String, dynamic> _buildOverlaysPayload() {
    final text = _overlayTextController.text.trim();
    final equation = _equationController.text.trim();
    final subtitle = _subtitleController.text.trim();

    final List<Map<String, dynamic>> texts = <Map<String, dynamic>>[];
    if (_textOverlays.isNotEmpty) {
      final currentText = text;
      if (currentText.isNotEmpty) {
        final first = Map<String, dynamic>.from(_textOverlays.first);
        first['text'] = currentText;
        _textOverlays[0] = first;
      }
      for (final item in _textOverlays) {
        texts.add(Map<String, dynamic>.from(item));
      }
    } else if (text.isNotEmpty) {
      texts.add({
        'text': text,
        'x': 0.5,
        'y': 0.8,
        'align': 'center',
      });
    }

    final List<Map<String, dynamic>> equations = <Map<String, dynamic>>[];
    if (equation.isNotEmpty) {
      equations.add({
        'latex': equation,
        'x': 0.5,
        'y': 0.2,
      });
    }

    final subtitles = <Map<String, dynamic>>[];
    if (_aiSubtitles != null && _aiSubtitles!.isNotEmpty) {
      for (final item in _aiSubtitles!) {
        if (item is Map<String, dynamic>) {
          subtitles.add(Map<String, dynamic>.from(item));
        } else if (item is Map) {
          subtitles.add(Map<String, dynamic>.from(item));
        }
      }
    } else if (subtitle.isNotEmpty) {
      subtitles.add({
        'text': subtitle,
        'start_ms': 0,
        'end_ms': 5000,
      });
    }

    final stickers = <Map<String, dynamic>>[];
    if (_selectedSticker != 'none') {
      stickers.add({
        'type': _selectedSticker,
        'x': 0.9,
        'y': 0.1,
      });
    }

    final arObjects = _arObjects
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);

    // Extract scientific studio data if present
    Map<String, dynamic>? scientificData;
    for (final item in _textOverlays) {
      if (item['type'] == 'scientific_studio' && item['data'] is Map) {
        scientificData = Map<String, dynamic>.from(item['data'] as Map);
        break;
      }
    }

    final List<Map<String, dynamic>> zonesCopy = _zones
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);

    final Map<String, dynamic> overlays = {
      'background': {
        'theme': _backgroundTheme,
      },
      'filter': _selectedFilter,
      'texts': texts,
      'equations': equations,
      'subtitles': subtitles,
      'stickers': stickers,
      'ar_objects': arObjects,
      if (scientificData != null) 'scientific': scientificData,
      if (zonesCopy.isNotEmpty) 'zones': zonesCopy,
    };

    if (_extraClips.isNotEmpty) {
      final clipsById = <String, Map<String, dynamic>>{};
      for (final clip in _extraClips) {
        final clipId = clip['id']?.toString();
        if (clipId == null || clipId.isEmpty) {
          continue;
        }
        clipsById[clipId] = clip;
      }

      final orderedIds = _clipOrder.isNotEmpty
          ? _clipOrder.where((id) => clipsById.containsKey(id)).toList()
          : clipsById.keys.toList();

      final clips = <Map<String, dynamic>>[];
      for (var i = 0; i < orderedIds.length; i++) {
        final id = orderedIds[i];
        final clip = clipsById[id]!;
        final playback = clip['playback'];
        String? bestUrl;
        if (playback is Map) {
          final playbackMap = Map<String, dynamic>.from(playback);
          bestUrl = playbackMap['best_url']?.toString();
        }
        if (bestUrl == null || bestUrl.isEmpty) {
          continue;
        }
        final edit = _clipEdits[id];
        int startMs = 0;
        int? endMs;
        final rawStart = edit != null ? edit['start_ms'] : null;
        final rawEnd = edit != null ? edit['end_ms'] : null;
        if (rawStart is int) {
          startMs = rawStart;
        } else if (rawStart is num) {
          startMs = rawStart.toInt();
        }
        if (rawEnd is int) {
          endMs = rawEnd;
        } else if (rawEnd is num) {
          endMs = rawEnd.toInt();
        }
        clips.add({
          'clip_id': id,
          'video_url': bestUrl,
          'order': i,
          'start_ms': startMs,
          'end_ms': endMs,
        });
      }
      if (clips.isNotEmpty) {
        overlays['layers'] = {
          'clips': clips,
        };
      }
    }

    return overlays;
  }

  Future<void> _runTranscription() async {
    if (_isTranscribing || _isSubmitting || _isUploading) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'La transcription IA est en cours de développement et est temporairement désactivée.',
        ),
      ),
    );
    return;
  }

  Future<void> _runAnalysis() async {
    if (_isAnalyzing || _isSubmitting || _isUploading) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'L’analyse IA est en cours de développement et est temporairement désactivée.',
        ),
      ),
    );
    return;
  }

  Future<void> _runProofreadOverlayText() async {
    if (_isProofreading || _isSubmitting || _isUploading) {
      return;
    }

    final text = _overlayTextController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le texte à afficher est vide.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'La relecture IA est en cours de développement et est temporairement désactivée.',
        ),
      ),
    );
    return;
  }

  Future<void> _openAcademicPersonalizationSheet() async {
    if (_isSubmitting) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: _buildAcademicPersonalizationContent(theme),
          ),
        );
      },
    );
  }

  Widget _buildAcademicPersonalizationContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personnalisation académique',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _backgroundTheme,
          decoration: const InputDecoration(
            labelText: 'Thème de fond',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: 'universite-vert',
              child: Text('Fond universitaire vert'),
            ),
            DropdownMenuItem(
              value: 'universite-bleu',
              child: Text('Fond universitaire bleu'),
            ),
            DropdownMenuItem(
              value: 'tableau-noir',
              child: Text('Tableau noir / équations'),
            ),
          ],
          onChanged: _isSubmitting
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() {
                    _backgroundTheme = value;
                  });
                },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: const Text('Sans filtre'),
              selected: _selectedFilter == 'none',
              onSelected: _isSubmitting
                  ? null
                  : (v) {
                      if (!v) return;
                      setState(() {
                        _selectedFilter = 'none';
                      });
                    },
            ),
            ChoiceChip(
              label: const Text('Chaud'),
              selected: _selectedFilter == 'warm',
              onSelected: _isSubmitting
                  ? null
                  : (v) {
                      if (!v) return;
                      setState(() {
                        _selectedFilter = 'warm';
                      });
                    },
            ),
            ChoiceChip(
              label: const Text('Froid'),
              selected: _selectedFilter == 'cool',
              onSelected: _isSubmitting
                  ? null
                  : (v) {
                      if (!v) return;
                      setState(() {
                        _selectedFilter = 'cool';
                      });
                    },
            ),
            ChoiceChip(
              label: const Text('Noir & blanc'),
              selected: _selectedFilter == 'bw',
              onSelected: _isSubmitting
                  ? null
                  : (v) {
                      if (!v) return;
                      setState(() {
                        _selectedFilter = 'bw';
                      });
                    },
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _overlayTextController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Texte à afficher (titre, explication courte)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _isSubmitting || _isUploading ? null : _openTextsEditor,
            icon: const Icon(Icons.edit_note),
            label: const Text('Éditer les textes en détails'),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _isSubmitting || _isUploading ? null : _openArStudio,
            icon: const Icon(Icons.view_in_ar),
            label: const Text('Ouvrir le Studio AR 3D'),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Sans sticker'),
              selected: _selectedSticker == 'none',
              onSelected: _isSubmitting
                  ? null
                  : (v) {
                      if (!v) return;
                      setState(() {
                        _selectedSticker = 'none';
                      });
                    },
            ),
            ChoiceChip(
              label: const Text('⭐'),
              selected: _selectedSticker == 'star',
              onSelected: _isSubmitting
                  ? null
                  : (v) {
                      if (!v) return;
                      setState(() {
                        _selectedSticker = 'star';
                      });
                    },
            ),
            ChoiceChip(
              label: const Text('❤'),
              selected: _selectedSticker == 'heart',
              onSelected: _isSubmitting
                  ? null
                  : (v) {
                      if (!v) return;
                      setState(() {
                        _selectedSticker = 'heart';
                      });
                    },
            ),
            ChoiceChip(
              label: const Text('💡'),
              selected: _selectedSticker == 'idea',
              onSelected: _isSubmitting
                  ? null
                  : (v) {
                      if (!v) return;
                      setState(() {
                        _selectedSticker = 'idea';
                      });
                    },
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _openScientificKeyboard,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: _equationController.text.trim().isEmpty
                ? const Text(
                    'Équation (tap pour ouvrir le clavier scientifique)',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          _equationController.text,
                          style: const TextStyle(fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit, size: 18, color: Colors.grey),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _subtitleController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Sous-titres / explication orale (court)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed:
                _isSubmitting || _isUploading ? null : _openSubtitlesEditor,
            icon: const Icon(Icons.edit_note),
            label: const Text('Éditer les sous-titres en détails'),
          ),
        ),
      ],
    );
  }

  Future<void> _openIaToolsSheet() async {
    if (_isSubmitting) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Outils IA du Studio',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Lance les sous-titres IA, l’analyse pédagogique et la correction du texte affiché.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed:
                          _isTranscribing || _isSubmitting || _isUploading
                              ? null
                              : _runTranscription,
                      icon: _isTranscribing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.subtitles),
                      label: const Text('Générer les sous-titres (IA)'),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          _isAnalyzing || _isSubmitting || _isUploading
                              ? null
                              : _runAnalysis,
                      icon: _isAnalyzing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.school),
                      label: const Text('Analyser pédagogiquement'),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          _isProofreading || _isSubmitting || _isUploading
                              ? null
                              : _runProofreadOverlayText,
                      icon: _isProofreading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.spellcheck),
                      label: const Text('Corriger le texte affiché'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Fermer'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openScientificStudio() async {
    if (_isSubmitting || _isUploading) return;
    if (_uploadedUrl == null || _uploadedUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload d\'abord une vidéo.')),
      );
      return;
    }

    // Collect existing scientific overlays if any
    Map<String, dynamic>? existing;
    final currentOverlays = _buildOverlaysPayload();
    if (currentOverlays != null) {
      final sci = currentOverlays['scientific'];
      if (sci is Map<String, dynamic>) {
        existing = sci;
      }
    }

    final result = await Navigator.of(context).push<Map<String, dynamic>?>(
      MaterialPageRoute(
        builder: (_) => ChallengeScientificStudioScreen(
          existingOverlays: existing,
          videoUrl: _uploadedUrl,
        ),
      ),
    );

    if (!mounted || result == null) return;

    // Store the scientific overlays in the text overlays list as a special entry
    setState(() {
      _textOverlays.removeWhere((o) => o['type'] == 'scientific_studio');
      _textOverlays.add({
        'type': 'scientific_studio',
        'data': result,
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Annotations scientifiques enregistrées.')),
    );
  }

  Future<void> _openVideoEditor() async {
    if (_isSubmitting || _isUploading) return;
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('L\'éditeur vidéo n\'est pas disponible sur le web.')),
      );
      return;
    }

    // Need a local file path. If we only have a URL, inform the user.
    if (_videoBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionne d\'abord une vidéo locale.')),
      );
      return;
    }

    // Write bytes to a temp file for the editor
    final tempDir = Directory.systemTemp;
    final tempFile = File('${tempDir.path}/academia_edit_${DateTime.now().millisecondsSinceEpoch}.mp4');
    await tempFile.writeAsBytes(_videoBytes!);

    if (!mounted) return;

    final editedPath = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (_) => ChallengeVideoEditScreen(
          videoPaths: [tempFile.path],
        ),
      ),
    );

    if (!mounted || editedPath == null || editedPath.isEmpty) return;

    // Read the edited file back
    final editedFile = File(editedPath);
    if (!editedFile.existsSync()) return;

    final editedBytes = await editedFile.readAsBytes();
    final name = editedPath.split(Platform.pathSeparator).last;
    final ext = name.contains('.') ? name.split('.').last : 'mp4';

    setState(() {
      _videoBytes = editedBytes;
      _fileName = name;
      _mimeType = ext;
      _uploadedUrl = null;
      _videoInitialized = false;
    });

    // Re-upload the edited video
    await _uploadVideo();
  }

  Future<void> _openAudioStudioSheet() async {
    if (_isSubmitting || _isUploading || _isRenderingAudio) {
      return;
    }

    // Find the currently selected bundled track id (if any)
    final currentBundledId = _timelineTracks
        .where((t) => t.id.startsWith('bundled_'))
        .map((t) => t.id.replaceFirst('bundled_', ''))
        .firstOrNull;

    final result = await showModalBottomSheet<AudioPickResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AudioPickerSheet(currentTrackId: currentBundledId),
    );

    if (result == null || !mounted) return;

    final track = result.track;

    // Remove any previous bundled track
    setState(() {
      _timelineTracks.removeWhere((t) => t.id.startsWith('bundled_'));
    });

    // If user selected "none", we're done
    if (track.id == 'none') return;

    // Add the selected track to the timeline with trim range
    final durationSeconds = _getTimelineDurationSeconds();
    final trimStartSec = result.trimStart.inMilliseconds / 1000.0;
    final trimEndSec = result.trimEnd.inMilliseconds / 1000.0;

    setState(() {
      _timelineTracks.add(
        _StudioTimelineTrack(
          id: 'bundled_${track.id}',
          label: '${track.title} (${_formatTimelineSeconds(trimStartSec)}→${_formatTimelineSeconds(trimEndSec)})',
          category: track.category.label,
          assetUrl: track.url,
          range: RangeValues(0, durationSeconds),
          volume: 0.5,
        ),
      );
    });

    // ── Open DJ Mix Sheet for volume control ──
    if (!mounted) return;

    final djResult = await showModalBottomSheet<DjMixResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DjMixSheet(
        trackTitle: track.title,
        videoDurationSec: durationSeconds,
      ),
    );

    if (djResult == null || !mounted) return;

    await _runAudioMixWithDialog(
      audioUrl: track.url,
      trimStartMs: result.trimStart.inMilliseconds,
      trimEndMs: result.trimEnd.inMilliseconds,
      musicVolume: djResult.musicVolume,
      originalVolume: djResult.originalVolume,
      originalSegments: djResult.originalSegments,
      musicSegments: djResult.musicSegments,
    );
  }

  /// Runs the FFmpeg audio mix with a visible progress dialog.
  Future<void> _runAudioMixWithDialog({
    required String audioUrl,
    required int trimStartMs,
    required int trimEndMs,
    required double musicVolume,
    double originalVolume = 1.0,
    List<VolumeSegment> originalSegments = const [],
    List<VolumeSegment> musicSegments = const [],
  }) async {
    if (_videoBytes == null && _localVideoPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sélectionne d\'abord une vidéo.')),
        );
      }
      return;
    }

    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le mixage audio n\'est pas disponible sur le web.')),
        );
      }
      return;
    }

    setState(() {
      _isRenderingAudio = true;
      _renderProgress = 0;
    });

    // Show a non-dismissible progress dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => StatefulBuilder(
          builder: (ctx, setDialogState) {
            return PopScope(
              canPop: false,
              child: AlertDialog(
                backgroundColor: const Color(0xFF1A1A2E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    const Icon(Icons.music_note, color: Color(0xFF00D2FF), size: 40),
                    const SizedBox(height: 16),
                    const Text(
                      'Mixage audio en cours...',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Téléchargement de la musique et fusion\navec la vidéo via FFmpeg',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _renderProgress > 0 ? _renderProgress : null,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        color: const Color(0xFF00D2FF),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _renderProgress > 0
                          ? '${(_renderProgress * 100).toInt()}%'
                          : 'Préparation...',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    try {
      // 1. Write current video bytes to a temp file (or use existing local path)
      String videoSourcePath;
      if (_localVideoPath != null && await File(_localVideoPath!).exists()) {
        videoSourcePath = _localVideoPath!;
      } else if (_videoBytes != null) {
        final tempDir = Directory.systemTemp;
        final sourceFile = File(
          '${tempDir.path}/academia_audio_src_${DateTime.now().millisecondsSinceEpoch}.mp4',
        );
        await sourceFile.writeAsBytes(_videoBytes!);
        videoSourcePath = sourceFile.path;
      } else {
        throw Exception('Pas de vidéo disponible');
      }

      if (!mounted) return;

      debugPrint('[Studio] _runAudioMixWithDialog: mixing $audioUrl into $videoSourcePath (musicVol=$musicVolume, origVol=$originalVolume, origSegs=${originalSegments.length}, musicSegs=${musicSegments.length})');
      final srcFile = File(videoSourcePath);
      debugPrint('[Studio] Source video size: ${await srcFile.length()} bytes');

      // 2. Mix audio into video using FFmpeg
      final mixedPath = await AudioMixService.mixAudioIntoVideo(
        videoPath: videoSourcePath,
        audioUrl: audioUrl,
        trimStartMs: trimStartMs,
        trimEndMs: trimEndMs > trimStartMs ? trimEndMs : null,
        musicVolume: musicVolume,
        originalVolume: originalVolume,
        loop: true,
        originalVolumeSegments: originalSegments,
        musicVolumeSegments: musicSegments,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _renderProgress = progress);
          }
        },
      );

      if (!mounted) return;

      // Close progress dialog
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      debugPrint('[Studio] mixedPath result: $mixedPath');

      if (mixedPath == null || mixedPath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors du mixage audio. Vérifie ta connexion et réessaie.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isRenderingAudio = false);
        return;
      }

      // 3. Read mixed video bytes and replace current video
      final mixedFile = File(mixedPath);
      final mixedSize = await mixedFile.length();
      final mixedBytes = await mixedFile.readAsBytes();
      debugPrint('[Studio] Mixed file: $mixedPath, size=$mixedSize bytes, readBytes=${mixedBytes.length}');

      if (!mounted) return;

      setState(() {
        _videoBytes = mixedBytes;
        _fileName = 'mixed_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
        _mimeType = 'video/mp4';
        _uploadedUrl = null;
        _videoInitialized = false;
        _localVideoPath = mixedPath;
      });

      debugPrint('[Studio] State updated: _videoBytes=${_videoBytes?.length}, _fileName=$_fileName, _uploadedUrl=$_uploadedUrl, _localVideoPath=$_localVideoPath');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎵 Audio mixé avec succès ! Upload en cours...'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );

      // 4. Re-upload the mixed video
      debugPrint('[Studio] Starting re-upload of mixed video...');
      await _uploadVideo();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Vidéo avec audio uploadée !'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      debugPrint('[Studio] _runAudioMixWithDialog error: $e');

      // Close progress dialog
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur mixage : $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRenderingAudio = false);
      }
    }
  }

  Widget _buildAudioStudioContent(ThemeData theme) {
    return FutureBuilder<void>(
      future: _audioAssetsLoaded ? null : _loadAudioAssetsIfNeeded(),
      builder: (context, snapshot) {
        if (_isLoadingAudioAssets) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          );
        }

        if (_audioAssets.isEmpty) {
          return const Text(
            'Aucune piste audio Studio n’est disponible pour le moment.',
            style: TextStyle(fontSize: 13),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final asset in _audioAssets)
                  Builder(
                    builder: (context) {
                      final id = asset['id']?.toString() ?? '';
                      final label = asset['label']?.toString() ?? '';
                      final category = asset['category']?.toString() ?? '';
                      final selected =
                          _timelineTracks.any((t) => t.id == id);
                      if (id.isEmpty || label.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return ChoiceChip(
                        label: Text(
                          category.isEmpty
                              ? label
                              : '$label ($category)',
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: selected,
                        onSelected: _isRenderingAudio || _isSubmitting
                            ? null
                            : (v) {
                                if (!v) return;
                                _toggleTimelineTrackForAsset(asset);
                              },
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_timelineTracks.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Timeline audio multi-pistes',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final track in _timelineTracks)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                track.category.isEmpty
                                    ? track.label
                                    : '${track.label} (${track.category})',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed:
                                  _isRenderingAudio || _isSubmitting
                                      ? null
                                      : () => _removeTimelineTrack(track.id),
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                              ),
                              tooltip:
                                  'Retirer la piste de la timeline',
                            ),
                          ],
                        ),
                        RangeSlider(
                          values: track.range,
                          min: 0.0,
                          max: _getTimelineDurationSeconds(),
                          labels: RangeLabels(
                            _formatTimelineSeconds(track.range.start),
                            _formatTimelineSeconds(track.range.end),
                          ),
                          onChanged: _isRenderingAudio || _isSubmitting
                              ? null
                              : (values) {
                                  final durationSeconds =
                                      _getTimelineDurationSeconds();
                                  final start = values.start
                                      .clamp(0.0, durationSeconds);
                                  final minEnd = start + 0.1;
                                  final end = values.end.clamp(
                                    minEnd,
                                    durationSeconds,
                                  );
                                  setState(() {
                                    track.range = RangeValues(
                                      start,
                                      end,
                                    );
                                  });
                                },
                        ),
                        Row(
                          children: [
                            const Text(
                              'Volume',
                              style: TextStyle(fontSize: 12),
                            ),
                            Expanded(
                              child: Slider(
                                value: track.volume,
                                min: 0.0,
                                max: 1.0,
                                onChanged:
                                    _isRenderingAudio || _isSubmitting
                                        ? null
                                        : (v) {
                                            setState(() {
                                              track.volume =
                                                  v.clamp(0.0, 1.0);
                                            });
                                          },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                ],
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isRenderingAudio || _isSubmitting
                    ? null
                    : _runAudioRender,
                icon: _isRenderingAudio
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.music_video),
                label: const Text(
                  'Mixer la vidéo avec les pistes audio',
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isRenderingVideo || _isSubmitting || _isUploading
                    ? null
                    : _runVideoRender,
                icon: _isRenderingVideo
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.movie),
                label: const Text(
                  'Monter la vidéo finale',
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isRenderingAudio ||
                        _isRenderingVideo ||
                        _isSubmitting
                    ? null
                    : _openRenderJobsDialog,
                icon: const Icon(Icons.list_alt),
                label: const Text(
                  'Voir l’historique des jobs de rendu',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runAudioRender() async {
    if (_isRenderingAudio || _isSubmitting || _isUploading) return;

    if (_timelineTracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoute au moins une piste audio.')),
      );
      return;
    }

    final audioTrack = _timelineTracks.firstWhere(
      (t) => t.assetUrl.isNotEmpty,
      orElse: () => _StudioTimelineTrack(
        id: '', label: '', category: '', assetUrl: '',
        range: const RangeValues(0, 0), volume: 0,
      ),
    );

    if (audioTrack.assetUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune piste audio valide.')),
      );
      return;
    }

    final trimStartMs = (audioTrack.range.start * 1000).round();
    final trimEndMs = (audioTrack.range.end * 1000).round();

    await _runAudioMixWithDialog(
      audioUrl: audioTrack.assetUrl,
      trimStartMs: trimStartMs,
      trimEndMs: trimEndMs,
      musicVolume: audioTrack.volume,
    );
  }

  double _renderProgress = 0;

  Future<void> _runVideoRender() async {
    if (_isRenderingVideo || _isSubmitting || _isUploading) {
      return;
    }

    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le rendu vidéo n\'est pas disponible sur le web.'),
        ),
      );
      return;
    }

    if (_videoBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tu dois d\'abord sélectionner une vidéo avant de lancer le rendu.',
          ),
        ),
      );
      return;
    }

    final overlays = _buildOverlaysPayload();

    // Check if there are any visible overlays to burn in
    final hasTexts = (overlays['texts'] as List?)?.isNotEmpty == true;
    final hasEquations = (overlays['equations'] as List?)?.isNotEmpty == true;
    final hasSubtitles = (overlays['subtitles'] as List?)?.isNotEmpty == true;
    final hasStickers = (overlays['stickers'] as List?)?.isNotEmpty == true;
    final hasScientific = overlays['scientific'] is Map;
    if (!hasTexts && !hasEquations && !hasSubtitles && !hasStickers && !hasScientific) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ajoute d\'abord du texte, des équations ou des dessins avant de lancer le rendu.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isRenderingVideo = true;
      _renderProgress = 0;
    });

    try {
      // 1. Write video bytes to a temp file
      final tempDir = Directory.systemTemp;
      final sourceFile = File(
        '${tempDir.path}/academia_src_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      await sourceFile.writeAsBytes(_videoBytes!);

      if (!mounted) return;

      // 2. Burn overlays into the video
      debugPrint('[Studio] _runVideoRender: starting burn-in render...');
      final renderedPath = await OverlayBurnInService.burnOverlaysIntoVideo(
        videoPath: sourceFile.path,
        overlays: overlays,
        videoSize: const Size(1080, 1920),
        overlayWidgetBuilder: (ovl, size) => SizedBox(
          width: size.width,
          height: size.height,
          child: VideoOverlaysLayer(overlays: ovl),
        ),
        onProgress: (progress) {
          if (mounted) {
            setState(() => _renderProgress = progress);
          }
        },
      );

      // Clean up source temp file
      try {
        await sourceFile.delete();
      } catch (_) {}

      if (!mounted) return;

      if (renderedPath == null || renderedPath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors du rendu vidéo. Réessaie.'),
          ),
        );
        setState(() => _isRenderingVideo = false);
        return;
      }

      // 3. Read rendered video bytes
      final renderedFile = File(renderedPath);
      final renderedBytes = await renderedFile.readAsBytes();
      final renderedName = 'rendered_${_fileName ?? "video.mp4"}';

      if (!mounted) return;

      // 4. Replace current video with rendered version
      setState(() {
        _videoBytes = renderedBytes;
        _fileName = renderedName;
        _mimeType = 'mp4';
        _uploadedUrl = null;
        _videoInitialized = false;
        _localVideoPath = renderedPath;
      });

      // 5. Re-upload the rendered video
      await _uploadVideo();

      if (!mounted) return;

      // 6. Save overlays to DB
      if (_uploadedUrl != null && _uploadedUrl!.isNotEmpty) {
        final provider = context.read<StudentChallengesProvider>();
        if (_isFreeVideo) {
          await provider.updateFreeVideoOverlays(
            freeVideoId: _effectiveFreeVideoId,
            layers: overlays,
          );
        } else {
          await provider.updateChallengeVideoOverlays(
            participationId: _effectiveParticipationId,
            layers: overlays,
          );
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Rendu terminé ! Les textes et équations sont maintenant intégrés dans la vidéo.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('[Studio] _runVideoRender error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de rendu : $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRenderingVideo = false;
          _renderProgress = 0;
        });
      }
    }
  }

  Future<void> _openRenderJobsDialog() async {
    final provider = context.read<StudentChallengesProvider>();

    List<Map<String, dynamic>> jobs = [];
    try {
      if (_isFreeVideo) {
        jobs = await provider.listFreeVideoRenderJobs(
          _effectiveFreeVideoId,
        );
      } else {
        jobs = await provider.listChallengeVideoRenderJobs(
          _effectiveParticipationId,
        );
      }
    } catch (_) {
      // L'erreur sera exposée via provider.error si besoin.
    }

    if (!mounted) {
      return;
    }

    final providerError = provider.error;
    if (providerError != null && providerError.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(providerError)),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        if (jobs.isEmpty) {
          return AlertDialog(
            title: const Text('Jobs de rendu audio/vidéo'),
            content: const Text(
              'Aucun job de rendu audio/vidéo trouvé pour cette participation pour le moment.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'),
              ),
            ],
          );
        }

        return AlertDialog(
          title: const Text('Jobs de rendu audio/vidéo'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: jobs.map((job) {
                  final status = job['status']?.toString() ?? '';
                  final type = job['job_type']?.toString() ?? '';
                  final createdAt = job['created_at']?.toString() ?? '';
                  final resultUrl = job['result_video_url']?.toString() ?? '';
                  final errorMessage = job['error_message']?.toString() ?? '';

                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      type.isEmpty ? 'Job audio/vidéo' : type,
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (status.isNotEmpty)
                          Text(
                            'Statut: $status',
                            style: const TextStyle(fontSize: 12),
                          ),
                        if (createdAt.isNotEmpty)
                          Text(
                            'Créé: $createdAt',
                            style: const TextStyle(fontSize: 12),
                          ),
                        if (resultUrl.isNotEmpty)
                          Text(
                            'Résultat: $resultUrl',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        if (errorMessage.isNotEmpty)
                          Text(
                            'Erreur: $errorMessage',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.redAccent,
                            ),
                          ),
                      ],
                    ),
                    onTap: resultUrl.isEmpty
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => _RenderJobVideoPreviewScreen(
                                  videoUrl: resultUrl,
                                ),
                              ),
                            );
                          },
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitVideoChallenge() async {
    if (_isUploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Upload de la vidéo en cours, patiente quelques secondes.',
          ),
        ),
      );
      return;
    }

    if ((_uploadedUrl == null || _uploadedUrl!.isEmpty) &&
        _videoBytes != null &&
        _fileName != null) {
      await _uploadVideo();
    }

    if (_uploadedUrl == null || _uploadedUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu dois d\'abord uploader une vidéo.'),
        ),
      );
      return;
    }

    // ── Free video publish path ──────────────────────────────────────────
    if (_isFreeVideo) {
      await _submitFreeVideo();
      return;
    }

    // ── Challenge video publish path ─────────────────────────────────────
    final provider = context.read<StudentChallengesProvider>();

    if (widget.asAdditionalVideo) {
      setState(() {
        _isSubmitting = true;
      });

      String? videoAssetId = _pendingChallengeVideoAssetId;
      Map<String, dynamic>? playback = _pendingChallengePlayback;

      if (videoAssetId == null || playback == null) {
        final manifest = await provider.fetchPlaybackForDirectUrl(_uploadedUrl!);
        if (!mounted) {
          return;
        }

        if (manifest == null) {
          setState(() {
            _isSubmitting = false;
          });
          final error = provider.error ??
              'Erreur lors de la résolution de la vidéo de challenge.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
          return;
        }

        videoAssetId = manifest['video_asset_id']?.toString();
        final rawPlayback = manifest['playback'];
        if (videoAssetId == null || videoAssetId.isEmpty ||
            rawPlayback is! Map<String, dynamic>) {
          setState(() {
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Playback vidéo invalide retourné par le serveur.'),
            ),
          );
          return;
        }

        playback = Map<String, dynamic>.from(rawPlayback);
      }

      final okAdd = await provider.addChallengeVideo(
        participationId: _effectiveParticipationId,
        videoAssetId: videoAssetId!,
        playback: playback!,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });

      if (!okAdd) {
        final error = provider.error ??
            'Erreur lors de l\'ajout de ta vidéo de challenge.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ta vidéo de challenge a été ajoutée.'),
        ),
      );

      await _cleanupAndPop(true);
      return;
    }

    final overlays = _buildOverlaysPayload();

    setState(() {
      _isSubmitting = true;
    });

    final okOverlays = await provider.updateChallengeVideoOverlays(
      participationId: _effectiveParticipationId,
      layers: overlays,
    );

    if (!mounted) {
      return;
    }

    if (!okOverlays) {
      setState(() {
        _isSubmitting = false;
      });
      final error = provider.error ??
          'Erreur lors de la sauvegarde des éléments académiques de la vidéo.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    final okSubmit = await provider.submitChallenge(
      participationId: _effectiveParticipationId,
      submissionText: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      submissionUrl: _uploadedUrl,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (!okSubmit) {
      final error = provider.error ??
          'Erreur lors de la soumission de ta vidéo de challenge.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ta vidéo de challenge a été envoyée pour validation.'),
      ),
    );

    await _cleanupAndPop(true);
  }

  /// Publish path for free videos — saves overlays then pops.
  Future<void> _submitFreeVideo() async {
    debugPrint('[Studio] _submitFreeVideo: _hasFreeVideoId=$_hasFreeVideoId, _uploadedUrl=$_uploadedUrl');

    // Safety net: si la vidéo est uploadée mais la free_video n'a pas été créée en DB,
    // on tente de la créer maintenant avant d'abandonner.
    if (!_hasFreeVideoId && _uploadedUrl != null && _uploadedUrl!.isNotEmpty) {
      debugPrint('[Studio] _submitFreeVideo: no freeVideoId but uploadedUrl exists — creating free_video now...');
      final provider = context.read<StudentChallengesProvider>();
      final newId = await provider.createFreeVideo(
        playback: {'best_url': _uploadedUrl},
      );
      debugPrint('[Studio] _submitFreeVideo: late createFreeVideo result=$newId, error=${provider.error}');
      if (newId != null && newId.isNotEmpty) {
        _runtimeFreeVideoId = newId;
      }
    }

    if (!_hasFreeVideoId) {
      debugPrint('[Studio] _submitFreeVideo: STILL no freeVideoId — aborting');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu dois d\'abord uploader une vidéo.'),
        ),
      );
      return;
    }

    final provider = context.read<StudentChallengesProvider>();
    final overlays = _buildOverlaysPayload();

    setState(() {
      _isSubmitting = true;
    });

    final okOverlays = await provider.updateFreeVideoOverlays(
      freeVideoId: _effectiveFreeVideoId,
      layers: overlays,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (!okOverlays) {
      final error = provider.error ??
          'Erreur lors de la sauvegarde des éléments de la vidéo.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ta vidéo a été publiée avec succès !'),
      ),
    );

    await _cleanupAndPop(true);
  }

  Future<void> _openScientificKeyboard() async {
    // Hide the system keyboard first
    FocusScope.of(context).unfocus();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: AcademiaEquationEditor(
            controller: _equationController,
            onChanged: () {
              if (mounted) setState(() {});
            },
            onDone: () {
              Navigator.of(sheetContext).pop();
            },
          ),
        );
      },
    );

    // Refresh the UI after closing the keyboard
    if (mounted) setState(() {});
  }

  Future<void> _openTextsEditor() async {
    if (_isSubmitting || _isUploading) {
      return;
    }

    final initial = <Map<String, dynamic>>[];
    if (_textOverlays.isNotEmpty) {
      for (final item in _textOverlays) {
        initial.add(Map<String, dynamic>.from(item));
      }
    } else {
      final text = _overlayTextController.text.trim();
      if (text.isNotEmpty) {
        initial.add(<String, dynamic>{
          'text': text,
          'start_ms': 0,
          'end_ms': 2000,
          'x': 0.5,
          'y': 0.8,
          'align': 'center',
        });
      }
    }

    final segments = initial.isEmpty
        ? <Map<String, dynamic>>[
            <String, dynamic>{
              'text': '',
              'start_ms': 0,
              'end_ms': 2000,
              'x': 0.5,
              'y': 0.8,
              'align': 'center',
            },
          ]
        : initial;

    int? _parseIntMs(dynamic raw) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) {
        return int.tryParse(raw);
      }
      return null;
    }

    final textControllers = segments
        .map<TextEditingController>(
          (seg) => TextEditingController(
            text: seg['text']?.toString() ?? '',
          ),
        )
        .toList(growable: true);

    final startControllers = segments.map<TextEditingController>((seg) {
      final startMs = _parseIntMs(seg['start_ms']);
      return TextEditingController(
        text: _formatMsLabel(startMs),
      );
    }).toList(growable: true);

    final endControllers = segments.map<TextEditingController>((seg) {
      final endMs = _parseIntMs(seg['end_ms']);
      return TextEditingController(
        text: _formatMsLabel(endMs),
      );
    }).toList(growable: true);

    final updatedSegments =
        await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Édition détaillée des textes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (segments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Aucun texte pour le moment. Ajoute une ligne pour commencer.',
                        style: TextStyle(fontSize: 13),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: segments.length,
                        itemBuilder: (context, index) {
                          final startController = startControllers[index];
                          final endController = endControllers[index];
                          final textController = textControllers[index];

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Texte ${index + 1}: '
                                        '${startController.text} → ${endController.text}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                      ),
                                      tooltip: 'Supprimer ce texte',
                                      onPressed: () {
                                        setSheetState(() {
                                          segments.removeAt(index);
                                          textControllers.removeAt(index);
                                          startControllers.removeAt(index);
                                          endControllers.removeAt(index);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: startController,
                                        decoration: const InputDecoration(
                                          labelText: 'Début (MM:SS)',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: endController,
                                        decoration: const InputDecoration(
                                          labelText: 'Fin (MM:SS)',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: textController,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    hintText: 'Texte à afficher',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          int baseStart = 0;
                          if (segments.isNotEmpty) {
                            final last = segments.last;
                            final lastEnd = _parseIntMs(last['end_ms']);
                            if (lastEnd != null && lastEnd >= 0) {
                              baseStart = lastEnd;
                            }
                          }

                          final newSeg = <String, dynamic>{
                            'text': '',
                            'start_ms': baseStart,
                            'end_ms': baseStart + 2000,
                            'x': 0.5,
                            'y': 0.8,
                            'align': 'center',
                          };

                          setSheetState(() {
                            segments.add(newSeg);
                            textControllers.add(
                              TextEditingController(text: ''),
                            );
                            startControllers.add(
                              TextEditingController(
                                text: _formatMsLabel(baseStart),
                              ),
                            );
                            endControllers.add(
                              TextEditingController(
                                text: _formatMsLabel(baseStart + 2000),
                              ),
                            );
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter un texte'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final normalized = <Map<String, dynamic>>[];

                          for (var i = 0; i < segments.length; i++) {
                            final rawText = textControllers[i].text.trim();
                            if (rawText.isEmpty) {
                              continue;
                            }

                            final seg = Map<String, dynamic>.from(
                              segments[i],
                            );

                            final rawStart = startControllers[i].text.trim();
                            final rawEnd = endControllers[i].text.trim();

                            int? startMs = _parseMsFromLabel(rawStart);
                            int? endMs = _parseMsFromLabel(rawEnd);
                            if (startMs == null || startMs < 0) {
                              startMs = 0;
                            }
                            if (endMs == null || endMs <= startMs) {
                              endMs = startMs + 2000;
                            }

                            seg['text'] = rawText;
                            seg['start_ms'] = startMs;
                            seg['end_ms'] = endMs;

                            normalized.add(seg);
                          }

                          Navigator.of(sheetContext)
                              .pop<List<Map<String, dynamic>>>(normalized);
                        },
                        child: const Text('Enregistrer'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (updatedSegments == null) {
      return;
    }

    if (updatedSegments.isEmpty) {
      setState(() {
        _textOverlays = [];
        _overlayTextController.clear();
      });
      return;
    }

    setState(() {
      _textOverlays = updatedSegments;
      final firstText = updatedSegments.first['text']?.toString() ?? '';
      if (firstText.isNotEmpty) {
        _overlayTextController.text = firstText;
      } else {
        _overlayTextController.clear();
      }
    });
  }

  Future<void> _openSubtitlesEditor() async {
    if (_isSubmitting || _isUploading) {
      return;
    }

    final initial = <Map<String, dynamic>>[];
    if (_aiSubtitles != null && _aiSubtitles!.isNotEmpty) {
      for (final item in _aiSubtitles!) {
        if (item is Map<String, dynamic>) {
          initial.add(Map<String, dynamic>.from(item));
        } else if (item is Map) {
          initial.add(Map<String, dynamic>.from(item));
        }
      }
    } else {
      final text = _subtitleController.text.trim();
      if (text.isNotEmpty) {
        initial.add(<String, dynamic>{
          'text': text,
          'start_ms': 0,
          'end_ms': 5000,
        });
      }
    }

    final segments = initial.isEmpty
        ? <Map<String, dynamic>>[
            <String, dynamic>{
              'text': '',
              'start_ms': 0,
              'end_ms': 2000,
            },
          ]
        : initial;

    final controllers = segments
        .map<TextEditingController>(
          (seg) => TextEditingController(
            text: seg['text']?.toString() ?? '',
          ),
        )
        .toList(growable: true);

    List<Map<String, dynamic>>? updatedSegments =
        await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Édition détaillée des sous-titres',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isLoadingExtraClips)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    )
                  else if (_extraClips.isNotEmpty) ...[
                    const Text(
                      'Clips existants de la participation',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _extraClips.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final clip = _extraClips[index];
                          final url = clip['video_url']?.toString() ?? '';
                          final createdAt =
                              clip['created_at']?.toString() ?? '';
                          return InkWell(
                            onTap: url.isEmpty
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => _ExtraClipPreviewScreen(
                                          videoUrl: url,
                                          participationId: _effectiveParticipationId,
                                        ),
                                      ),
                                    );
                                  },
                            child: Container(
                              width: 140,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Clip ${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Expanded(
                                    child: Text(
                                      createdAt.isEmpty
                                          ? 'Clip de participation'
                                          : createdAt,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else
                    const SizedBox(height: 24),
                  if (segments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Aucun sous-titre pour le moment. Ajoute une ligne pour commencer.',
                        style: TextStyle(fontSize: 13),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: segments.length,
                        itemBuilder: (context, index) {
                          final seg = segments[index];

                          int? _parseIntMs(dynamic raw) {
                            if (raw is int) return raw;
                            if (raw is num) return raw.toInt();
                            if (raw is String) {
                              return int.tryParse(raw);
                            }
                            return null;
                          }

                          final startMs = _parseIntMs(seg['start_ms']);
                          final endMs = _parseIntMs(seg['end_ms']);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Sous-titre ${index + 1}: '
                                        '${_formatMsLabel(startMs)} → ${_formatMsLabel(endMs)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                      ),
                                      tooltip: 'Supprimer ce sous-titre',
                                      onPressed: () {
                                        setSheetState(() {
                                          segments.removeAt(index);
                                          controllers.removeAt(index);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                TextField(
                                  controller: controllers[index],
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    hintText: 'Texte du sous-titre',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          int baseStart = 0;
                          if (segments.isNotEmpty) {
                            final last = segments.last;

                            int? _parseIntMs(dynamic raw) {
                              if (raw is int) return raw;
                              if (raw is num) return raw.toInt();
                              if (raw is String) {
                                return int.tryParse(raw);
                              }
                              return null;
                            }

                            final lastEnd = _parseIntMs(last['end_ms']);
                            if (lastEnd != null && lastEnd >= 0) {
                              baseStart = lastEnd;
                            }
                          }

                          final newSeg = <String, dynamic>{
                            'text': '',
                            'start_ms': baseStart,
                            'end_ms': baseStart + 2000,
                          };

                          setSheetState(() {
                            segments.add(newSeg);
                            controllers.add(
                              TextEditingController(text: ''),
                            );
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter un sous-titre'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final normalized = <Map<String, dynamic>>[];

                          for (var i = 0; i < segments.length; i++) {
                            final rawText = controllers[i].text.trim();
                            if (rawText.isEmpty) {
                              continue;
                            }
                            final seg = Map<String, dynamic>.from(
                              segments[i],
                            );
                            seg['text'] = rawText;
                            normalized.add(seg);
                          }

                          Navigator.of(sheetContext)
                              .pop<List<Map<String, dynamic>>>(normalized);
                        },
                        child: const Text('Enregistrer'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (updatedSegments == null) {
      return;
    }

    if (updatedSegments.isEmpty) {
      setState(() {
        _aiSubtitles = null;
        _subtitleController.clear();
      });
      return;
    }

    setState(() {
      _aiSubtitles = updatedSegments;
      final texts = updatedSegments
          .map((e) => e['text']?.toString() ?? '')
          .where((t) => t.trim().isNotEmpty)
          .toList(growable: false);
      if (texts.isNotEmpty) {
        _subtitleController.text = texts.join(' ');
      }
    });
  }

  Future<void> _openClipsTimelineEditor() async {
    if (_isSubmitting || _isUploading) {
      return;
    }

    if (_extraClips.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aucun clip supplémentaire n’est disponible pour le moment.',
          ),
        ),
      );
      return;
    }

    final clipsById = <String, Map<String, dynamic>>{};
    for (final clip in _extraClips) {
      final id = clip['id']?.toString();
      if (id == null || id.isEmpty) {
        continue;
      }
      clipsById[id] = clip;
    }

    if (clipsById.isEmpty) {
      return;
    }

    if (_clipOrder.isEmpty) {
      setState(() {
        _clipOrder = clipsById.keys.toList(growable: false);
      });
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final orderedIds = _clipOrder
                .where((id) => clipsById.containsKey(id))
                .toList(growable: true);

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Timeline multi-clips',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Réorganise l’ordre des clips et ajuste leurs points d’entrée/sortie.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: orderedIds.length,
                      itemBuilder: (context, index) {
                        final id = orderedIds[index];
                        final clip = clipsById[id]!;
                        final createdAt = clip['created_at']?.toString() ?? '';
                        final edit = _clipEdits[id];
                        final startMs = edit?['start_ms'] as int?;
                        final endMs = edit?['end_ms'] as int?;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Clip ${index + 1}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.arrow_upward,
                                        size: 18,
                                      ),
                                      onPressed: index == 0
                                          ? null
                                          : () {
                                              setState(() {
                                                final currentIndex =
                                                    _clipOrder.indexOf(id);
                                                if (currentIndex > 0) {
                                                  final tmp = _clipOrder[
                                                      currentIndex - 1];
                                                  _clipOrder[currentIndex - 1] =
                                                      _clipOrder[currentIndex];
                                                  _clipOrder[currentIndex] =
                                                      tmp;
                                                }
                                              });
                                              setSheetState(() {});
                                            },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.arrow_downward,
                                        size: 18,
                                      ),
                                      onPressed: index == orderedIds.length - 1
                                          ? null
                                          : () {
                                              setState(() {
                                                final currentIndex =
                                                    _clipOrder.indexOf(id);
                                                if (currentIndex >= 0 &&
                                                    currentIndex <
                                                        _clipOrder.length - 1) {
                                                  final tmp = _clipOrder[
                                                      currentIndex + 1];
                                                  _clipOrder[currentIndex + 1] =
                                                      _clipOrder[currentIndex];
                                                  _clipOrder[currentIndex] =
                                                      tmp;
                                                }
                                              });
                                              setSheetState(() {});
                                            },
                                    ),
                                  ],
                                ),
                                if (createdAt.isNotEmpty)
                                  Text(
                                    createdAt,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black54,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () async {
                                          final currentLabel = startMs == null
                                              ? ''
                                              : _formatMsLabel(startMs);
                                          final controller =
                                              TextEditingController(
                                            text: currentLabel,
                                          );
                                          final result =
                                              await showDialog<String>(
                                            context: sheetContext,
                                            builder: (dialogContext) {
                                              return AlertDialog(
                                                title: const Text(
                                                  'Point d’entrée (mm:ss)',
                                                ),
                                                content: TextField(
                                                  controller: controller,
                                                  decoration:
                                                      const InputDecoration(
                                                    hintText: 'mm:ss',
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                                dialogContext)
                                                            .pop(),
                                                    child:
                                                        const Text('Annuler'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                                dialogContext)
                                                            .pop(controller.text
                                                                .trim()),
                                                    child: const Text(
                                                      'Enregistrer',
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                          if (result == null) {
                                            return;
                                          }
                                          final ms = result.isEmpty
                                              ? null
                                              : _parseMsFromLabel(result);
                                          setState(() {
                                            final existing =
                                                Map<String, dynamic>.from(
                                              _clipEdits[id] ??
                                                  <String, dynamic>{},
                                            );
                                            existing['start_ms'] = ms ?? 0;
                                            _clipEdits[id] = existing;
                                          });
                                          setSheetState(() {});
                                        },
                                        child: Text(
                                          'In: ${_formatMsLabel(startMs)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () async {
                                          final currentLabel = endMs == null
                                              ? ''
                                              : _formatMsLabel(endMs);
                                          final controller =
                                              TextEditingController(
                                            text: currentLabel,
                                          );
                                          final result =
                                              await showDialog<String>(
                                            context: sheetContext,
                                            builder: (dialogContext) {
                                              return AlertDialog(
                                                title: const Text(
                                                  'Point de sortie (mm:ss)',
                                                ),
                                                content: TextField(
                                                  controller: controller,
                                                  decoration:
                                                      const InputDecoration(
                                                    hintText:
                                                        'mm:ss (laisser vide = fin du clip)',
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                                dialogContext)
                                                            .pop(),
                                                    child:
                                                        const Text('Annuler'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                                dialogContext)
                                                            .pop(controller.text
                                                                .trim()),
                                                    child: const Text(
                                                      'Enregistrer',
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                          if (result == null) {
                                            return;
                                          }
                                          int? ms;
                                          if (result.isNotEmpty) {
                                            ms = _parseMsFromLabel(result);
                                          }
                                          setState(() {
                                            final existing =
                                                Map<String, dynamic>.from(
                                              _clipEdits[id] ??
                                                  <String, dynamic>{},
                                            );
                                            existing['end_ms'] = ms;
                                            _clipEdits[id] = existing;
                                          });
                                          setSheetState(() {});
                                        },
                                        child: Text(
                                          'Out: ${endMs == null ? '--:--' : _formatMsLabel(endMs)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Fermer'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Zone management (Step 3 — CapCut-like zones)
  // ---------------------------------------------------------------------------

  void _addZone() {
    setState(() {
      _zoneIdCounter++;
      _zones.add({
        'id': 'zone_$_zoneIdCounter',
        'x': 0.1,
        'y': 0.3,
        'w': 0.8,
        'h': 0.15,
        'style': {
          'blur_sigma': 8.0,
          'bg_opacity': 0.45,
          'bg_color': 0xFF000000,
          'radius': 12.0,
          'padding': 10.0,
          'border_width': 1.0,
          'border_color': 0x40FFFFFF,
        },
        'content': {'text': 'Texte ici'},
      });
      _selectedZoneIndex = _zones.length - 1;
    });
  }

  Future<void> _editZoneText(int index) async {
    if (index < 0 || index >= _zones.length) return;
    final zone = _zones[index];
    final contentRaw = zone['content'];
    final content = contentRaw is Map ? Map<String, dynamic>.from(contentRaw) : <String, dynamic>{};
    final currentText = (content['text'] ?? zone['text'] ?? '').toString();
    final ctrl = TextEditingController(text: currentText);

    // Get video duration for the range slider
    int videoDurationMs = 30000; // default 30s
    try {
      final dur = await _previewPlaybackController.getDuration();
      if (dur > 0) videoDurationMs = dur;
    } catch (_) {}

    final currentStartMs = (zone['start_ms'] as num?)?.toDouble() ?? 0.0;
    final currentEndMs = (zone['end_ms'] as num?)?.toDouble() ?? videoDurationMs.toDouble();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _ZoneEditDialog(
        initialText: currentText,
        initialStartMs: currentStartMs,
        initialEndMs: currentEndMs,
        videoDurationMs: videoDurationMs.toDouble(),
      ),
    );
    ctrl.dispose();
    if (!mounted) return;
    if (result == null) return;
    if (result['action'] == 'delete') {
      setState(() {
        _zones.removeAt(index);
        _selectedZoneIndex = null;
      });
      return;
    }
    setState(() {
      final updated = Map<String, dynamic>.from(_zones[index]);
      updated['content'] = {'text': result['text'] ?? ''};
      updated['start_ms'] = (result['start_ms'] as num).toInt();
      updated['end_ms'] = (result['end_ms'] as num).toInt();
      _zones[index] = updated;
    });
  }

  // ---------------------------------------------------------------------------
  // Studio TikTok/CapCut — barre d'outils horizontale en bas
  // ---------------------------------------------------------------------------

  Widget _buildStudioToolbarItem({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: enabled
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudioToolbar() {
    final busy = _isSubmitting;
    return Container(
      color: Colors.black.withAlpha(153),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            // Upload button with progress indicator
            if (_videoBytes != null && _uploadedUrl == null)
              _isUploading
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: _uploadProgress,
                                  strokeWidth: 3,
                                  color: const Color(0xFF00D2FF),
                                ),
                                Text(
                                  '${(_uploadProgress * 100).toInt()}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Upload...',
                            style: TextStyle(color: Colors.white70, fontSize: 10),
                          ),
                        ],
                      ),
                    )
                  : _buildStudioToolbarItem(
                      icon: Icons.cloud_upload,
                      label: 'Upload',
                      onTap: busy ? null : _uploadVideo,
                    ),
            _buildStudioToolbarItem(
              icon: Icons.add_box_outlined,
              label: '+ Zone',
              onTap: busy ? null : _addZone,
            ),
            _buildStudioToolbarItem(
              icon: Icons.edit_note,
              label: 'Texte',
              onTap: busy ? null : _openAcademicPersonalizationSheet,
            ),
            _buildStudioToolbarItem(
              icon: Icons.functions,
              label: 'Écrire',
              onTap: busy ? null : _openScientificKeyboard,
            ),
            _buildStudioToolbarItem(
              icon: Icons.subtitles_outlined,
              label: 'Sous-titres',
              onTap: busy ? null : _openIaToolsSheet,
            ),
            _buildStudioToolbarItem(
              icon: Icons.music_note_outlined,
              label: 'Audio',
              onTap: busy ? null : _openAudioStudioSheet,
            ),
            _buildStudioToolbarItem(
              icon: Icons.science_outlined,
              label: 'Tableau',
              onTap: busy ? null : _openScientificStudio,
            ),
            _buildStudioToolbarItem(
              icon: Icons.content_cut,
              label: 'Trim',
              onTap: busy ? null : _openVideoEditor,
            ),
            _buildStudioToolbarItem(
              icon: Icons.view_in_ar,
              label: 'AR 3D',
              onTap: busy ? null : _openArStudio,
            ),
            _isRenderingVideo
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: _renderProgress > 0 ? _renderProgress : null,
                                strokeWidth: 3,
                                color: const Color(0xFF1EA75C),
                              ),
                              Text(
                                _renderProgress > 0
                                    ? '${(_renderProgress * 100).toInt()}%'
                                    : '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Rendu...',
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  )
                : _buildStudioToolbarItem(
                    icon: Icons.movie_outlined,
                    label: 'Rendu',
                    onTap: busy ? null : _runVideoRender,
                  ),
            _buildStudioToolbarItem(
              icon: Icons.video_file_outlined,
              label: 'Changer',
              onTap: busy ? null : _pickVideo,
            ),
            // Show merge button if multiple segments captured
            if (_capturedSegments != null && _capturedSegments!.length > 1 && !_isUploading)
              _buildStudioToolbarItem(
                icon: Icons.merge,
                label: 'Fusionner',
                onTap: busy || _isMerging ? null : () => _showMergeSegmentsDialog(_capturedSegments!),
              ),
            // Buttons for initial capture if no video yet
            if (_videoBytes == null && _uploadedUrl == null) ...[
              _buildStudioToolbarItem(
                icon: Icons.videocam,
                label: 'Filmer',
                onTap: busy || _isCompressing ? null : _recordVideoWithCamera,
              ),
              _buildStudioToolbarItem(
                icon: Icons.photo_library,
                label: 'Galerie',
                onTap: busy || _isCompressing ? null : _pickVideo,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStudioActionsColumn(BuildContext context) {
    // Kept for fallback (no-video) mode — simplified
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStudioToolbarItem(
          icon: Icons.check_circle_outline,
          label: 'Publier',
          onTap: _isSubmitting || _isUploading ? null : _submitVideoChallenge,
        ),
      ],
    );
  }

  Future<void> _showMergeSegmentsDialog(List<XFile> segments) async {
    setState(() {
      _isMerging = true;
      _mergeProgress = 0.0;
    });

    // Show transition selector dialog
    final selectedTransition = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Fusionner les segments'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${segments.length} segments capturés'),
            const SizedBox(height: 16),
            const Text('Choisir une transition:'),
            const SizedBox(height: 8),
            ...VideoSegmentMergeService.availableTransitions.map((transition) {
              return RadioListTile<String>(
                title: Text(transition.label),
                value: transition.value,
                groupValue: _selectedTransition,
                onChanged: (value) {
                  setState(() {
                    _selectedTransition = value ?? 'none';
                  });
                  Navigator.of(ctx).pop(value);
                },
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );

    if (!mounted || selectedTransition == null) {
      setState(() {
        _isMerging = false;
      });
      return;
    }

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Fusion en cours...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(value: _mergeProgress),
              const SizedBox(height: 16),
              Text('${(_mergeProgress * 100).toInt()}%'),
            ],
          ),
        ),
      ),
    );

    try {
      // Convert XFiles to Files
      final segmentFiles = segments.map((xFile) => File(xFile.path)).toList();
      
      final mergedUrl = await VideoSegmentMergeService.mergeSegments(
        segmentFiles: segmentFiles,
        transition: selectedTransition,
        transitionDurationMs: 300,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _mergeProgress = progress;
            });
          }
        },
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close progress dialog

      if (mergedUrl != null) {
        // Download merged video to process it
        final response = await http.get(Uri.parse(mergedUrl));
        final bytes = response.bodyBytes;
        
        setState(() {
          _videoBytes = bytes;
          _fileName = 'merged_${DateTime.now().millisecondsSinceEpoch}.mp4';
          _mimeType = 'mp4';
          _uploadedUrl = mergedUrl;
          _videoInitialized = false;
          _localVideoPath = null;
          _isMerging = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Segments fusionnés avec succès!')),
        );
      } else {
        throw Exception('Échec de la fusion');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close progress dialog
        setState(() {
          _isMerging = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la fusion: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _openPublishScreen() async {
    debugPrint('[Studio] _openPublishScreen: _uploadedUrl=$_uploadedUrl, _fileName=$_fileName, _videoBytes=${_videoBytes?.length}, _localVideoPath=$_localVideoPath');

    if ((_uploadedUrl == null || _uploadedUrl!.isEmpty) && !_isUploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload en cours...')),
      );
      await _uploadVideo();
      if (!mounted) return;
    }

    if (_uploadedUrl == null || _uploadedUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload non terminé. Réessaie dans quelques secondes.')),
      );
      return;
    }

    debugPrint('[Studio] Publishing with URL: $_uploadedUrl');

    final result = await Navigator.of(context).push<bool?>(
      MaterialPageRoute(
        builder: (_) => VideoPublishScreen(
          videoUrl: _uploadedUrl!,
          videoType: widget.videoType,
          challengeId: widget.challengeId,
          participationId: widget.participationId,
          freeVideoId: _runtimeFreeVideoId ?? widget.freeVideoId,
          asAdditionalVideo: widget.asAdditionalVideo,
          overlays: _buildOverlaysPayload(),
          thumbnailBytes: _thumbnailBytes,
          pendingVideoAssetId: _pendingChallengeVideoAssetId,
          pendingPlayback: _pendingChallengePlayback,
        ),
      ),
    );

    // Si la publication a réussi, on ferme aussi le Studio
    if (result == true && mounted) {
      await _cleanupAndPop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasUrl = _uploadedUrl != null && _uploadedUrl!.isNotEmpty;
    final bool hasLocalVideo = _localVideoPath != null && _localVideoPath!.isNotEmpty;
    final bool hasVideo = hasUrl || hasLocalVideo;

    final String? effectivePreviewUrl = hasLocalVideo
        ? Uri.file(_localVideoPath!).toString()
        : (hasUrl ? _uploadedUrl : null);

    final bool isLocalPreview = (effectivePreviewUrl ?? '').startsWith('file://');

    // Mode studio plein écran TikTok/CapCut : vidéo en fond, barre d'outils
    // horizontale en bas, bouton "Suivant" en haut à droite.
    if (hasVideo) {
      if (effectivePreviewUrl == null || effectivePreviewUrl.isEmpty) {
        return const SizedBox.shrink();
      }
      final String previewUrl = effectivePreviewUrl;
      final topPad = MediaQuery.of(context).padding.top;
      final bottomPad = MediaQuery.of(context).padding.bottom;

      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Vidéo plein écran + overlays ──
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
                  Positioned.fill(
                    child: _TimedStudioOverlaysLayer(
                      overlays: _buildOverlaysPayload(),
                      controller: _previewPlaybackController,
                    ),
                  ),
                  Positioned.fill(
                    child: _DraggableZonesLayer(
                      zones: _zones,
                      selectedIndex: _selectedZoneIndex,
                      onZoneMoved: (index, dx, dy) {
                        setState(() {
                          final z = Map<String, dynamic>.from(_zones[index]);
                          z['x'] = ((z['x'] as num?)?.toDouble() ?? 0.1) + dx;
                          z['y'] = ((z['y'] as num?)?.toDouble() ?? 0.1) + dy;
                          _zones[index] = z;
                        });
                      },
                      onZoneTapped: (index) {
                        setState(() => _selectedZoneIndex = index);
                        _editZoneText(index);
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ── Top bar : retour + titre + Suivant ──
            Positioned(
              top: topPad + 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _isSubmitting || _isUploading
                        ? null
                        : _openPublishScreen,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isSubmitting
                            ? Colors.grey
                            : const Color(0xFFFF2D55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Suivant',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Timeline + Barre d'outils horizontale en bas ──
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomPad,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_zones.isNotEmpty)
                    _StudioTimelinePoller(
                      controller: _previewPlaybackController,
                      zones: _zones,
                      selectedIndex: _selectedZoneIndex,
                      onZoneTapped: (i) {
                        setState(() => _selectedZoneIndex = i);
                        _editZoneText(i);
                      },
                    ),
                  _buildStudioToolbar(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Fallback minimal : aucun fichier local ni URL — écran de sélection.
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_outlined, color: Colors.white54, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Crée ta vidéo',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isUploading || _isSubmitting || _isCompressing
                    ? null
                    : () => _handleInitialCaptureMode('camera'),
                icon: const Icon(Icons.videocam),
                label: const Text('Filmer une vidéo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2D55),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isUploading || _isSubmitting || _isCompressing ? null : _pickVideo,
                icon: const Icon(Icons.video_file, color: Colors.white70),
                label: const Text('Choisir depuis la galerie', style: TextStyle(color: Colors.white70)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white38),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Text(
                  'Annuler',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimedStudioOverlaysLayer extends StatefulWidget {
  final Map<String, dynamic>? overlays;
  final AcademiaPlaybackController? controller;

  const _TimedStudioOverlaysLayer({
    required this.overlays,
    required this.controller,
  });

  @override
  State<_TimedStudioOverlaysLayer> createState() => _TimedStudioOverlaysLayerState();
}

class _TimedStudioOverlaysLayerState extends State<_TimedStudioOverlaysLayer> {
  Timer? _timer;
  double _positionMs = 0.0;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void didUpdateWidget(covariant _TimedStudioOverlaysLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _positionMs = 0.0;
      _timer?.cancel();
      _startPolling();
    }
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      final ctrl = widget.controller;
      if (ctrl == null || !ctrl.isAttached) return;
      try {
        final pos = await ctrl.getPosition();
        if (!mounted) return;
        setState(() {
          _positionMs = pos.toDouble();
        });
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VideoOverlaysLayer(
      overlays: widget.overlays,
      positionMs: _positionMs,
    );
  }
}

class _DraggableZonesLayer extends StatelessWidget {
  final List<Map<String, dynamic>> zones;
  final int? selectedIndex;
  final void Function(int index, double dx, double dy) onZoneMoved;
  final void Function(int index) onZoneTapped;

  const _DraggableZonesLayer({
    required this.zones,
    required this.selectedIndex,
    required this.onZoneMoved,
    required this.onZoneTapped,
  });

  @override
  Widget build(BuildContext context) {
    if (zones.isEmpty) return const SizedBox.shrink();
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        for (int i = 0; i < zones.length; i++)
          _DraggableZoneHandle(
            index: i,
            zone: zones[i],
            screenSize: size,
            isSelected: i == selectedIndex,
            onMoved: onZoneMoved,
            onTapped: onZoneTapped,
          ),
      ],
    );
  }
}

class _DraggableZoneHandle extends StatelessWidget {
  final int index;
  final Map<String, dynamic> zone;
  final Size screenSize;
  final bool isSelected;
  final void Function(int index, double dx, double dy) onMoved;
  final void Function(int index) onTapped;

  const _DraggableZoneHandle({
    required this.index,
    required this.zone,
    required this.screenSize,
    required this.isSelected,
    required this.onMoved,
    required this.onTapped,
  });

  @override
  Widget build(BuildContext context) {
    final x = (zone['x'] as num?)?.toDouble() ?? 0.1;
    final y = (zone['y'] as num?)?.toDouble() ?? 0.1;
    final w = (zone['w'] as num?)?.toDouble() ?? 0.8;
    final h = (zone['h'] as num?)?.toDouble() ?? 0.2;

    final left = (screenSize.width * x).clamp(0.0, screenSize.width);
    final top = (screenSize.height * y).clamp(0.0, screenSize.height);
    final width = (screenSize.width * w).clamp(24.0, screenSize.width);
    final height = (screenSize.height * h).clamp(24.0, screenSize.height);

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTapped(index),
        onPanUpdate: (details) {
          final dx = details.delta.dx / screenSize.width;
          final dy = details.delta.dy / screenSize.height;
          onMoved(index, dx, dy);
        },
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            border: isSelected
                ? Border.all(color: const Color(0xFF1EA75C), width: 2.0)
                : Border.all(color: Colors.transparent, width: 0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: isSelected
              ? Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1EA75C),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 14),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Zone edit dialog — text + timing (start_ms / end_ms) via RangeSlider
// ---------------------------------------------------------------------------
class _ZoneEditDialog extends StatefulWidget {
  final String initialText;
  final double initialStartMs;
  final double initialEndMs;
  final double videoDurationMs;

  const _ZoneEditDialog({
    required this.initialText,
    required this.initialStartMs,
    required this.initialEndMs,
    required this.videoDurationMs,
  });

  @override
  State<_ZoneEditDialog> createState() => _ZoneEditDialogState();
}

class _ZoneEditDialogState extends State<_ZoneEditDialog> {
  late final TextEditingController _textCtrl;
  late RangeValues _range;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.initialText);
    _range = RangeValues(
      widget.initialStartMs.clamp(0.0, widget.videoDurationMs),
      widget.initialEndMs.clamp(0.0, widget.videoDurationMs),
    );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  String _formatMs(double ms) {
    final totalSec = (ms / 1000).round();
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier la zone'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _textCtrl,
              maxLines: 4,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Saisir le texte...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Apparition / Disparition',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatMs(_range.start),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  _formatMs(_range.end),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            RangeSlider(
              values: _range,
              min: 0,
              max: widget.videoDurationMs,
              divisions: (widget.videoDurationMs / 500).round().clamp(1, 600),
              activeColor: const Color(0xFF1EA75C),
              labels: RangeLabels(
                _formatMs(_range.start),
                _formatMs(_range.end),
              ),
              onChanged: (v) => setState(() => _range = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, <String, dynamic>{'action': 'delete'}),
          child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, <String, dynamic>{
            'text': _textCtrl.text,
            'start_ms': _range.start,
            'end_ms': _range.end,
          }),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Poller wrapper — polls playback position and renders _ZoneTimelineStrip
// ---------------------------------------------------------------------------
class _StudioTimelinePoller extends StatefulWidget {
  final AcademiaPlaybackController? controller;
  final List<Map<String, dynamic>> zones;
  final int? selectedIndex;
  final void Function(int index) onZoneTapped;

  const _StudioTimelinePoller({
    required this.controller,
    required this.zones,
    required this.selectedIndex,
    required this.onZoneTapped,
  });

  @override
  State<_StudioTimelinePoller> createState() => _StudioTimelinePollerState();
}

class _StudioTimelinePollerState extends State<_StudioTimelinePoller> {
  Timer? _timer;
  double _positionMs = 0.0;
  double _durationMs = 30000.0;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void didUpdateWidget(covariant _StudioTimelinePoller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _timer?.cancel();
      _startPolling();
    }
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) async {
      final ctrl = widget.controller;
      if (ctrl == null || !ctrl.isAttached) return;
      try {
        final pos = await ctrl.getPosition();
        final dur = await ctrl.getDuration();
        if (!mounted) return;
        setState(() {
          _positionMs = pos.toDouble();
          if (dur > 0) _durationMs = dur.toDouble();
        });
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ZoneTimelineStrip(
      zones: widget.zones,
      videoDurationMs: _durationMs,
      currentPositionMs: _positionMs,
      selectedIndex: widget.selectedIndex,
      onZoneTapped: widget.onZoneTapped,
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline strip — shows zone segments + playhead above the toolbar
// ---------------------------------------------------------------------------
class _ZoneTimelineStrip extends StatelessWidget {
  final List<Map<String, dynamic>> zones;
  final double videoDurationMs;
  final double currentPositionMs;
  final int? selectedIndex;
  final void Function(int index) onZoneTapped;

  const _ZoneTimelineStrip({
    required this.zones,
    required this.videoDurationMs,
    required this.currentPositionMs,
    this.selectedIndex,
    required this.onZoneTapped,
  });

  @override
  Widget build(BuildContext context) {
    if (zones.isEmpty || videoDurationMs <= 0) return const SizedBox.shrink();
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      height: 40,
      color: Colors.black.withValues(alpha: 0.7),
      child: Stack(
        children: [
          // Track background
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          // Zone segments
          for (int i = 0; i < zones.length; i++)
            Builder(builder: (context) {
              final z = zones[i];
              final startMs =
                  (z['start_ms'] as num?)?.toDouble() ?? 0.0;
              final endMs =
                  (z['end_ms'] as num?)?.toDouble() ?? videoDurationMs;
              final leftFrac = (startMs / videoDurationMs).clamp(0.0, 1.0);
              final widthFrac =
                  ((endMs - startMs) / videoDurationMs).clamp(0.01, 1.0);
              final isSelected = i == selectedIndex;
              return Positioned(
                left: 8 + leftFrac * (screenWidth - 16),
                top: 8,
                child: GestureDetector(
                  onTap: () => onZoneTapped(i),
                  child: Container(
                    width: (widthFrac * (screenWidth - 16)).clamp(8.0, screenWidth),
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF1EA75C).withValues(alpha: 0.7)
                          : const Color(0xFF4FC3F7).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                      border: isSelected
                          ? Border.all(
                              color: const Color(0xFF1EA75C), width: 1.5)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Z${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }),
          // Playhead
          Positioned(
            left: 8 +
                (currentPositionMs / videoDurationMs).clamp(0.0, 1.0) *
                    (screenWidth - 16),
            top: 4,
            child: Container(
              width: 2,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(1),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RenderJobVideoPreviewScreen extends StatefulWidget {
  final String videoUrl;

  const _RenderJobVideoPreviewScreen({required this.videoUrl});

  @override
  State<_RenderJobVideoPreviewScreen> createState() =>
      _RenderJobVideoPreviewScreenState();
}

class _RenderJobVideoPreviewScreenState
    extends State<_RenderJobVideoPreviewScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    final url = widget.videoUrl.trim();
    if (url.isEmpty) {
      return;
    }
    setState(() {
      _initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Prévisualisation du rendu'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _initialized && widget.videoUrl.trim().isNotEmpty
              ? AcademiaPlaybackEngine.view(
                  url: widget.videoUrl.trim(),
                  preferFlutterPlayer: false,
                  autoplay: false,
                  looping: false,
                  muted: false,
                  showControls: true,
                  fit: BoxFit.contain,
                )
              : const CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class _ExtraClipPreviewScreen extends StatefulWidget {
  final String videoUrl;
  final String participationId;

  const _ExtraClipPreviewScreen({
    required this.videoUrl,
    required this.participationId,
  });

  @override
  State<_ExtraClipPreviewScreen> createState() =>
      _ExtraClipPreviewScreenState();
}

class _ExtraClipPreviewScreenState extends State<_ExtraClipPreviewScreen> {
  bool _initialized = false;
  Map<String, dynamic>? _overlays;

  @override
  void initState() {
    super.initState();
    final url = widget.videoUrl.trim();
    if (url.isEmpty) {
      return;
    }
    setState(() {
      _initialized = true;
    });
    _loadOverlays();
  }

  Future<void> _loadOverlays() async {
    final provider =
        Provider.of<StudentChallengesProvider>(context, listen: false);

    Map<String, dynamic>? video;
    try {
      video = await provider.getChallengeVideoById(widget.participationId);
    } catch (_) {
      // L'erreur éventuelle sera déjà exposée via provider.error si besoin.
    }

    if (!mounted) {
      return;
    }

    if (video == null) {
      return;
    }

    final rawOverlays = video['overlays'] ?? video['layers'];
    Map<String, dynamic>? overlays;
    if (rawOverlays is Map) {
      overlays = Map<String, dynamic>.from(rawOverlays);
    }

    if (overlays == null) {
      return;
    }

    setState(() {
      _overlays = overlays;
    });
  }

  @override
  Widget build(BuildContext context) {
    final effectivePreviewUrl = widget.videoUrl.trim();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Prévisualisation du clip'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _initialized && widget.videoUrl.trim().isNotEmpty
              ? Stack(
                  children: [
                    Positioned.fill(
                      child: AcademiaPlaybackEngine.view(
                        url: effectivePreviewUrl,
                        preferFlutterPlayer: false,
                        autoplay: false,
                        looping: false,
                        muted: false,
                        showControls: false,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: VideoOverlaysLayer(overlays: _overlays),
                      ),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
