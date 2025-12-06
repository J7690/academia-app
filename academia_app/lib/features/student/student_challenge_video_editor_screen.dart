import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/student_challenges_provider.dart';
import '../../widgets/student_video_player.dart';
import 'challenge_camera_capture_screen.dart';
import 'student_challenge_video_overlays.dart';
import '../../services/studio_ai_service.dart';
import '../../services/studio_audio_service.dart';
import '../../services/studio_video_service.dart';
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
  final String challengeId;
  final String participationId;
  final String? initialMode;
  final bool asAdditionalVideo;

  const StudentChallengeVideoEditorScreen({
    super.key,
    required this.challengeId,
    required this.participationId,
    this.initialMode,
    this.asAdditionalVideo = false,
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

  bool _isUploading = false;
  bool _isSubmitting = false;

  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _overlayTextController = TextEditingController();
  final TextEditingController _equationController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();

  String _backgroundTheme = 'universite-vert';
  String _selectedFilter = 'none'; // none, warm, cool, bw
  String _selectedSticker = 'none'; // none, star, heart, idea

  VideoPlayerController? _videoController;
  bool _videoInitialized = false;

  bool _isTranscribing = false;
  bool _isAnalyzing = false;
  bool _isProofreading = false;
  List<Map<String, dynamic>>? _aiSubtitles;

  bool _isLoadingAudioAssets = false;
  bool _audioAssetsLoaded = false;
  List<Map<String, dynamic>> _audioAssets = [];
  final List<_StudioTimelineTrack> _timelineTracks = [];
  bool _isRenderingAudio = false;
  bool _isRenderingVideo = false;
  List<Map<String, dynamic>> _arObjects = [];
  List<Map<String, dynamic>> _textOverlays = [];
  bool _didLoadExistingOverlays = false;
  bool _isLoadingExtraClips = false;
  List<Map<String, dynamic>> _extraClips = [];
  List<String> _clipOrder = [];
  Map<String, Map<String, dynamic>> _clipEdits = {};
  final ScrollController _scrollController = ScrollController();

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
    _videoController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleInitialCaptureMode(String mode) {
    if (mode == 'gallery') {
      _pickVideo();
      return;
    }

    // Mode "camera" : on passe par l'écran unifié de capture.
    _openCameraCaptureFlow();
  }

  Future<void> _openCameraCaptureFlow() async {
    try {
      final result = await Navigator.of(context).push<XFile?>(
        MaterialPageRoute(
          builder: (_) => const ChallengeCameraCaptureScreen(),
        ),
      );

      if (!mounted) return;

      // Utilisateur a annulé ou la caméra est indisponible.
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Capture annulée ou caméra indisponible. Sélectionne une vidéo existante à uploader.',
            ),
          ),
        );
        return;
      }

      final bytes = await result.readAsBytes();
      final name = result.name.isNotEmpty ? result.name : 'video.mp4';
      final ext = name.contains('.') ? name.split('.').last : 'mp4';

      setState(() {
        _videoBytes = bytes;
        _fileName = name;
        _mimeType = ext;
        _uploadedUrl = null;
        _videoInitialized = false;
        _videoController?.dispose();
        _videoController = null;
      });

      await _uploadVideo();
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
    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 60),
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

    if (picked == null) {
      return;
    }

    final bytes = await picked.readAsBytes();
    final path = picked.path;
    final fileNameFromPath = path.split(Platform.pathSeparator).last;
    final name = picked.name.isNotEmpty ? picked.name : fileNameFromPath;
    final ext = name.contains('.') ? name.split('.').last : 'mp4';

    setState(() {
      _videoBytes = bytes;
      _fileName = name;
      _mimeType = ext;
      _uploadedUrl = null;
      _videoInitialized = false;
      _videoController?.dispose();
      _videoController = null;
    });
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
    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Impossible de lire la vidéo sélectionnée.')),
      );
      return;
    }

    setState(() {
      _videoBytes = bytes;
      _fileName = file.name;
      _mimeType = file.extension;
      _uploadedUrl = null;
      _videoInitialized = false;
      _videoController?.dispose();
      _videoController = null;
    });

    if (!mounted) {
      return;
    }

    await _uploadVideo();
  }

  Future<void> _uploadVideo() async {
    if (_videoBytes == null || _fileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionne d\'abord une vidéo.')),
      );
      return;
    }

    final provider = context.read<StudentChallengesProvider>();

    setState(() {
      _isUploading = true;
    });

    final url = await provider.uploadChallengeVideo(
      bytes: _videoBytes!,
      fileName: _fileName!,
      challengeId: widget.challengeId,
      mimeType: _mimeType,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isUploading = false;
    });

    if (url == null) {
      final error = provider.error ?? 'Erreur lors de l\'upload de la vidéo.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    setState(() {
      _uploadedUrl = url;
    });

    if (kIsWeb) {
      await _initRemoteVideo(url);
    }

    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _scrollToStudioSection();
      });
    }
  }

  Future<void> _initRemoteVideo(String url) async {
    _videoController?.dispose();
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoController = controller;
    try {
      await controller.initialize();
      if (!mounted) {
        return;
      }
      controller.setLooping(true);
      controller.play();
      setState(() {
        _videoInitialized = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _videoInitialized = false;
      });
    }
  }

  Future<void> _loadExistingOverlaysIfAny() async {
    if (_didLoadExistingOverlays) {
      return;
    }

    final provider = context.read<StudentChallengesProvider>();

    Map<String, dynamic>? video;
    try {
      video = await provider.getChallengeVideoById(widget.participationId);
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
      clips = await provider.listMyChallengeVideos(widget.participationId);
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
    final controller = _videoController;
    if (controller == null) {
      return 30.0;
    }
    final value = controller.value;
    if (!value.isInitialized) {
      return 30.0;
    }
    final seconds = value.duration.inSeconds;
    if (seconds <= 0) {
      return 30.0;
    }
    return seconds.toDouble();
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
        final videoUrl = clip['video_url']?.toString();
        if (videoUrl == null || videoUrl.isEmpty) {
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
          'video_url': videoUrl,
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

    setState(() {
      _isTranscribing = true;
    });

    try {
      final data = await StudioAiService.transcribe(
        participationId: widget.participationId,
      );

      if (!mounted) {
        return;
      }

      final rawSubtitles = data['subtitles'];
      if (rawSubtitles is! List) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Transcription IA vide ou invalide pour cette vidéo.',
            ),
          ),
        );
        return;
      }

      final segments = <Map<String, dynamic>>[];
      for (final item in rawSubtitles) {
        if (item is Map<String, dynamic>) {
          segments.add(Map<String, dynamic>.from(item));
        } else if (item is Map) {
          segments.add(Map<String, dynamic>.from(item));
        }
      }

      if (segments.isEmpty) {
        setState(() {
          _aiSubtitles = null;
          _subtitleController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aucun sous-titre n’a pu être généré pour cette vidéo.',
            ),
          ),
        );
        return;
      }

      setState(() {
        _aiSubtitles = segments;
        final texts = segments
            .map((e) => e['text']?.toString() ?? '')
            .where((t) => t.trim().isNotEmpty)
            .toList(growable: false);
        if (texts.isNotEmpty) {
          _subtitleController.text = texts.join(' ');
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sous-titres générés par l’IA pour cette vidéo.'),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la transcription IA de la vidéo: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
        });
      }
    }
  }

  Future<void> _runAnalysis() async {
    if (_isAnalyzing || _isSubmitting || _isUploading) {
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final data = await StudioAiService.analyze(
        participationId: widget.participationId,
      );
      final analysis = data['analysis']?.toString() ?? '';

      if (!mounted) {
        return;
      }

      if (analysis.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Analyse IA vide ou invalide pour cette vidéo.',
            ),
          ),
        );
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Analyse pédagogique de la vidéo'),
            content: SingleChildScrollView(
              child: Text(analysis),
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
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l’analyse IA de la vidéo: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
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

    setState(() {
      _isProofreading = true;
    });

    try {
      final corrected = await StudioAiService.proofread(text: text);
      if (!mounted) {
        return;
      }
      _overlayTextController.text = corrected;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Texte corrigé par l’IA.'),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la relecture IA: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProofreading = false;
        });
      }
    }
  }

  Future<void> _openAcademicPersonalizationSheet() async {
    if (_isSubmitting || _isUploading) {
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
        TextField(
          controller: _equationController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Équation (LaTeX ou texte mathématique)',
            border: OutlineInputBorder(),
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
    if (_isSubmitting || _isUploading) {
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

  Future<void> _openAudioStudioSheet() async {
    if (_isSubmitting || _isUploading) {
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
                  'Audio du Studio',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _buildAudioStudioContent(theme),
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
    if (_isRenderingAudio || _isSubmitting || _isUploading) {
      return;
    }

    if (_timelineTracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ajoute au moins une piste audio du Studio sur la timeline.',
          ),
        ),
      );
      return;
    }

    final tracksPayload = <Map<String, dynamic>>[];
    final durationSeconds = _getTimelineDurationSeconds();

    for (final track in _timelineTracks) {
      final assetUrl = track.assetUrl;
      if (assetUrl.isEmpty) {
        continue;
      }

      final start = track.range.start.clamp(0.0, durationSeconds);
      final minEnd = start + 0.1;
      final end = track.range.end.clamp(minEnd, durationSeconds);

      final startMs = (start * 1000).round();
      final endMs = (end * 1000).round();
      final volumeDb = _volumeToDb(track.volume);
      final kind = track.category.isEmpty ? 'music' : track.category;

      tracksPayload.add(<String, dynamic>{
        'asset_url': assetUrl,
        'kind': kind,
        'start_ms': startMs,
        'end_ms': endMs,
        'volume_db': volumeDb,
      });
    }

    if (tracksPayload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune piste audio valide pour le rendu.'),
        ),
      );
      return;
    }

    setState(() {
      _isRenderingAudio = true;
    });

    try {
      await StudioAudioService.render(
        participationId: widget.participationId,
        tracks: tracksPayload,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Une nouvelle vidéo mixée avec les pistes audio sélectionnées a été ajoutée à ta participation.',
          ),
        ),
      );
      await _loadExtraClipsIfAny();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du rendu audio du Studio: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRenderingAudio = false;
        });
      }
    }
  }

  Future<void> _runVideoRender() async {
    if (_isRenderingVideo || _isSubmitting || _isUploading) {
      return;
    }

    if (_videoBytes == null &&
        (_uploadedUrl == null || _uploadedUrl!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tu dois d\'abord uploader une vidéo de challenge avant de lancer le rendu vidéo.',
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
          content: Text('Upload de la vidéo requis pour le rendu vidéo.'),
        ),
      );
      return;
    }

    final provider = context.read<StudentChallengesProvider>();
    final overlays = _buildOverlaysPayload();

    setState(() {
      _isRenderingVideo = true;
    });

    try {
      final okOverlays = await provider.updateChallengeVideoOverlays(
        participationId: widget.participationId,
        layers: overlays,
      );

      if (!mounted) {
        return;
      }

      if (!okOverlays) {
        final error = provider.error ??
            'Erreur lors de la sauvegarde des éléments académiques de la vidéo.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
        return;
      }

      await StudioVideoService.render(
        participationId: widget.participationId,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Une nouvelle vidéo montée avec tes overlays académiques a été ajoutée à ta participation.',
          ),
        ),
      );
      await _loadExtraClipsIfAny();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du rendu vidéo du Studio: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRenderingVideo = false;
        });
      }
    }
  }

  Future<void> _openRenderJobsDialog() async {
    final provider = context.read<StudentChallengesProvider>();

    List<Map<String, dynamic>> jobs = [];
    try {
      jobs = await provider.listChallengeVideoRenderJobs(
        widget.participationId,
      );
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
          content:
              Text('Upload de la vidéo en cours, patiente quelques secondes.'),
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
          content: Text('Tu dois d\'abord uploader une vidéo de challenge.'),
        ),
      );
      return;
    }

    final provider = context.read<StudentChallengesProvider>();

    if (widget.asAdditionalVideo) {
      setState(() {
        _isSubmitting = true;
      });

      final okAdd = await provider.addChallengeVideo(
        participationId: widget.participationId,
        videoUrl: _uploadedUrl!,
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

      Navigator.of(context).pop(true);
      return;
    }

    final overlays = _buildOverlaysPayload();

    setState(() {
      _isSubmitting = true;
    });

    final okOverlays = await provider.updateChallengeVideoOverlays(
      participationId: widget.participationId,
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
      participationId: widget.participationId,
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

    try {
      await StudioVideoService.render(
        participationId: widget.participationId,
      );
    } catch (_) {
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ta vidéo de challenge a été envoyée pour validation.'),
      ),
    );

    Navigator.of(context).pop(true);
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

                            final seg = Map<String, dynamic>.from(segments[i]);

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
                                          participationId:
                                              widget.participationId,
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

  Widget _buildStudioActionIcon({
    required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: enabled ? Colors.black.withOpacity(0.7) : Colors.black26,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudioActionsColumn(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStudioActionIcon(
          icon: Icons.edit_note,
          tooltip: 'Textes',
          onTap:
              _isSubmitting || _isUploading ? null : _openAcademicPersonalizationSheet,
        ),
        _buildStudioActionIcon(
          icon: Icons.subtitles,
          tooltip: 'Sous-titres IA',
          onTap: _isSubmitting || _isUploading ? null : _openIaToolsSheet,
        ),
        _buildStudioActionIcon(
          icon: Icons.music_note,
          tooltip: 'Audio du Studio (render)',
          onTap: _isSubmitting || _isUploading ? null : _openAudioStudioSheet,
        ),
        _buildStudioActionIcon(
          icon: Icons.movie,
          tooltip: 'Rendu vidéo final',
          onTap: _isRenderingVideo || _isSubmitting || _isUploading
              ? null
              : _runVideoRender,
        ),
        _buildStudioActionIcon(
          icon: Icons.check_circle_outline,
          tooltip: 'Publier la vidéo de challenge',
          onTap: _isSubmitting || _isUploading ? null : _submitVideoChallenge,
        ),
      ],
    );
  }

  Widget _buildFullscreenBottomPanel(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prépare ta vidéo de challenge',
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white,
            ),
          ),
          if (_fileName != null) ...[
            const SizedBox(height: 4),
            Text(
              'Fichier : $_fileName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            maxLines: 2,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Note pour les correcteurs (optionnel)',
              hintStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.black.withOpacity(0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white24),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _isUploading || _isSubmitting ? null : _pickVideo,
                  icon: const Icon(Icons.video_file),
                  label: const Text('Changer de vidéo'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting || _isUploading
                      ? null
                      : _submitVideoChallenge,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('Publier ma vidéo'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const bool showCameraButton = true;
    final bool hasUploadedVideo =
        kIsWeb && _uploadedUrl != null && _uploadedUrl!.isNotEmpty;

    if (hasUploadedVideo) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Vidéo de challenge'),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: _videoController != null && _videoInitialized
                    ? StudentVideoPlayer(
                        controller: _videoController!,
                        overlays: _buildOverlaysPayload(),
                        feedMode: true,
                      )
                    : const Center(
                        child: CircularProgressIndicator(),
                      ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 24,
              child: _buildStudioActionsColumn(context),
            ),
            Positioned(
              left: 16,
              right: 96,
              bottom: 24,
              child: _buildFullscreenBottomPanel(theme),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vidéo de challenge'),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Crée une courte vidéo pour illustrer ta participation au challenge.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  if (showCameraButton) ...[
                    OutlinedButton.icon(
                      onPressed: _isUploading || _isSubmitting
                          ? null
                          : () => _handleInitialCaptureMode('camera'),
                      icon: const Icon(Icons.videocam),
                      label: const Text('Filmer une vidéo'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed:
                        _isUploading || _isSubmitting ? null : _pickVideo,
                    icon: const Icon(Icons.video_file),
                    label: Text(
                      _fileName == null
                          ? 'Sélectionner une vidéo depuis l\'appareil'
                          : 'Changer de vidéo',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isUploading ||
                            _isSubmitting ||
                            _videoBytes == null
                        ? null
                        : _uploadVideo,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload),
                    label: Text(
                      _uploadedUrl == null ? 'Uploader' : 'Ré-uploader',
                    ),
                  ),
                  if (_fileName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Fichier sélectionné : $_fileName',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (kIsWeb && _uploadedUrl != null)
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Aperçu de la vidéo en ligne',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_videoController != null &&
                                _videoInitialized) ...[
                              StudentVideoPlayer(
                                controller: _videoController!,
                                overlays: _buildOverlaysPayload(),
                                feedMode: true,
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    final url = _uploadedUrl;
                                    if (url == null || url.isEmpty) {
                                      return;
                                    }
                                    final overlays = _buildOverlaysPayload();
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            StudentChallengeVideoArCombinedScreen(
                                          videoUrl: url,
                                          overlays: overlays,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.view_in_ar),
                                  label:
                                      const Text('Vidéo + AR en live'),
                                ),
                              ),
                            ] else
                              const Center(
                                child: Padding(
                                  padding:
                                      EdgeInsets.symmetric(vertical: 16),
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Personnalisation académique',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configure le thème de fond, les filtres, le texte affiché, les stickers et les sous-titres dans le Studio.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting || _isUploading
                          ? null
                          : _openAcademicPersonalizationSheet,
                      icon: const Icon(Icons.edit),
                      label: const Text(
                        'Ouvrir la personnalisation académique',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Outils IA du Studio',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Utilise les sous-titres IA, l’analyse pédagogique et la correction du texte dans le Studio.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting || _isUploading
                          ? null
                          : _openIaToolsSheet,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text(
                        'Ouvrir les outils IA du Studio',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_extraClips.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Timeline multi-clips',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _isSubmitting || _isUploading
                              ? null
                              : _openClipsTimelineEditor,
                          icon:
                              const Icon(Icons.video_collection_outlined),
                          label: const Text(
                            'Organiser l\'ordre et les in/out des clips',
                          ),
                        ),
                      ],
                    ),
                  if (_extraClips.isNotEmpty) const SizedBox(height: 16),
                  Text(
                    'Audio du Studio',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configure les pistes audio et le mixage avancé dans le Studio.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting || _isUploading
                          ? null
                          : _openAudioStudioSheet,
                      icon: const Icon(Icons.music_note),
                      label: const Text(
                        'Ouvrir le mixeur audio du Studio',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText:
                          'Description pour les correcteurs (optionnel)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting || _isUploading
                          ? null
                          : _submitVideoChallenge,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: const Text(
                        'Publier ma vidéo de challenge',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 24,
            child: _buildStudioActionsColumn(context),
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
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    final url = widget.videoUrl.trim();
    if (url.isEmpty) {
      return;
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    controller.initialize().then((_) {
      if (!mounted) return;
      controller.setLooping(true);
      controller.play();
      setState(() {
        _initialized = true;
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() {
        _initialized = false;
      });
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Prévisualisation du rendu Studio'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _controller != null && _initialized
              ? StudentVideoPlayer(controller: _controller!)
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
  VideoPlayerController? _controller;
  bool _initialized = false;
  Map<String, dynamic>? _overlays;

  @override
  void initState() {
    super.initState();
    final url = widget.videoUrl.trim();
    if (url.isEmpty) {
      return;
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    controller.initialize().then((_) {
      if (!mounted) return;
      controller.setLooping(true);
      controller.play();
      setState(() {
        _initialized = true;
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() {
        _initialized = false;
      });
    });

    _loadOverlays();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Prévisualisation du clip'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _controller != null && _initialized
              ? StudentVideoPlayer(
                  controller: _controller!,
                  overlays: _overlays,
                )
              : const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
