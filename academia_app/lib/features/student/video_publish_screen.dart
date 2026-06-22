import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;

import '../../providers/student_challenges_provider.dart';
import '../../services/video_player_lifecycle_service.dart';
import '../../services/videoasset_upload_service.dart';
import '../../video/academia_playback_engine.dart';

/// Écran de publication TikTok-style.
///
/// Affiche une miniature de la vidéo, un champ caption/description,
/// des hashtags, un sélecteur de visibilité, et un bouton "Publier".
class VideoPublishScreen extends StatefulWidget {
  final String videoUrl;
  final String videoType; // 'free' or 'challenge'
  final String? challengeId;
  final String? participationId;
  final String? freeVideoId;
  final bool asAdditionalVideo;
  final Map<String, dynamic> overlays;
  final Uint8List? thumbnailBytes;
  final String? pendingVideoAssetId;
  final Map<String, dynamic>? pendingPlayback;
  final String? localVideoPath;
  final int videoDurationMs;

  // TikTok-style background upload: when [videoUrl] is empty and these are
  // provided, the upload runs in the background while the user writes the
  // caption, and "Publier" waits for it to finish (processing indicator).
  final String? uploadLocalPath;
  final String? uploadOrigin;
  final String? uploadContextType;
  final String? uploadContextId;
  final String? uploadFileName;
  final String? uploadMimeType;

  const VideoPublishScreen({
    super.key,
    required this.videoUrl,
    required this.videoType,
    this.challengeId,
    this.participationId,
    this.freeVideoId,
    this.asAdditionalVideo = false,
    this.overlays = const {},
    this.thumbnailBytes,
    this.pendingVideoAssetId,
    this.pendingPlayback,
    this.localVideoPath,
    this.videoDurationMs = 0,
    this.uploadLocalPath,
    this.uploadOrigin,
    this.uploadContextType,
    this.uploadContextId,
    this.uploadFileName,
    this.uploadMimeType,
  });

  @override
  State<VideoPublishScreen> createState() => _VideoPublishScreenState();
}

enum _UploadPhase { idle, uploading, processing, ready, failed }

class _VideoPublishScreenState extends State<VideoPublishScreen> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _hashtagsController = TextEditingController();
  String _visibility = 'public'; // public, friends, private
  bool _isPublishing = false;
  Uint8List? _selectedCoverBytes;
  double _coverPositionMs = 0;
  bool _isExtractingCover = false;
  AcademiaPlaybackController? _videoController;

  // Background upload (TikTok flow) state.
  _UploadPhase _uploadPhase = _UploadPhase.idle;
  double _uploadProgress = 0.0;
  String? _bgVideoAssetId;
  Map<String, dynamic>? _bgPlayback;
  String? _bgUrl;
  String? _uploadError;
  Completer<bool>? _uploadCompleter;

  bool get _isFreeVideo => widget.videoType == 'free';

  String get _effectiveUrl =>
      (_bgUrl != null && _bgUrl!.isNotEmpty) ? _bgUrl! : widget.videoUrl;

  Uint8List? get _effectiveCover => _selectedCoverBytes ?? widget.thumbnailBytes;

  @override
  void initState() {
    super.initState();
    // Pause feed controllers when Publish screen opens
    VideoPlayerLifecycleService().pauseFeed();
    _videoController = AcademiaPlaybackController();

    // Start the background upload (TikTok flow) if the video has not been
    // uploaded yet but a local file + upload params were provided.
    if (widget.videoUrl.trim().isEmpty &&
        widget.uploadLocalPath != null &&
        (widget.uploadOrigin ?? '').isNotEmpty) {
      _startBackgroundUpload();
    }
  }

  @override
  void dispose() {
    // Pause video controller to prevent audio conflicts
    if (_videoController != null && _videoController!.isAttached) {
      _videoController!.pause();
    }
    // Resume feed controllers when Publish screen closes
    VideoPlayerLifecycleService().resumeFeed();
    _captionController.dispose();
    _hashtagsController.dispose();
    super.dispose();
  }

  /// Uploads the baked video in the background while the user writes the
  /// caption. Heavy compression/transcoding stays server-side (Kamatera).
  Future<void> _startBackgroundUpload() async {
    final path = widget.uploadLocalPath;
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (!await file.exists()) {
      if (mounted) {
        setState(() {
          _uploadPhase = _UploadPhase.failed;
          _uploadError = 'Fichier vidéo introuvable.';
        });
      }
      return;
    }

    _uploadCompleter = Completer<bool>();
    if (mounted) {
      setState(() {
        _uploadPhase = _UploadPhase.uploading;
        _uploadProgress = 0.0;
        _uploadError = null;
      });
    }

    try {
      final assetId = await VideoAssetUploadService.ingestVideoFromBytes(
        fileOrBytes: file,
        fileName: widget.uploadFileName ?? path.split('/').last,
        origin: widget.uploadOrigin!,
        contextType: widget.uploadContextType,
        contextId: widget.uploadContextId,
        mimeType: widget.uploadMimeType,
        onUploadProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );

      if (!mounted) return;
      setState(() => _uploadPhase = _UploadPhase.processing);

      // Mark ready + resolve playback. Server-side ABR renditions keep going
      // in the background (playback-ready is separate from transcode-complete).
      final playback =
          await VideoAssetUploadService.triggerTranscode(videoAssetId: assetId);
      if (!mounted) return;

      final url = playback?['best_url']?.toString();
      setState(() {
        _bgVideoAssetId = assetId;
        _bgPlayback = playback ??
            (url != null && url.isNotEmpty
                ? <String, dynamic>{'best_url': url}
                : null);
        _bgUrl = url;
        _uploadPhase = _UploadPhase.ready;
        _uploadProgress = 1.0;
      });
      if (!(_uploadCompleter?.isCompleted ?? true)) _uploadCompleter!.complete(true);
    } catch (e) {
      debugPrint('[Publish] Background upload failed: $e');
      if (!mounted) return;
      setState(() {
        _uploadPhase = _UploadPhase.failed;
        _uploadError = e.toString();
      });
      if (!(_uploadCompleter?.isCompleted ?? true)) _uploadCompleter!.complete(false);
    }
  }

  Future<void> _extractCoverAtPosition(double positionMs) async {
    final path = widget.localVideoPath;
    if (path == null || path.isEmpty) return;
    if (_isExtractingCover) return;

    setState(() => _isExtractingCover = true);

    try {
      final bytes = await vt.VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: vt.ImageFormat.JPEG,
        maxWidth: 480,
        quality: 80,
        timeMs: positionMs.round(),
      );
      if (!mounted) return;
      setState(() {
        _selectedCoverBytes = bytes;
        _isExtractingCover = false;
      });
    } catch (e) {
      debugPrint('[Publish] Cover extraction error: $e');
      if (mounted) setState(() => _isExtractingCover = false);
    }
  }

  Future<({String? videoAssetId, Map<String, dynamic> playback})> _resolveAssetAndPlayback({
    required StudentChallengesProvider provider,
    String? posterUrl,
  }) async {
    // 0) Background-upload result (TikTok flow) takes priority.
    final bgAssetId = _bgVideoAssetId?.trim() ?? '';
    if (bgAssetId.isNotEmpty) {
      Map<String, dynamic> pb;
      if (_bgPlayback != null) {
        pb = Map<String, dynamic>.from(_bgPlayback!);
      } else {
        final manifest = await provider.fetchPlaybackForVideoAsset(bgAssetId);
        final rawPb = manifest?['playback'];
        pb = rawPb is Map
            ? Map<String, dynamic>.from(rawPb)
            : <String, dynamic>{
                if (_bgUrl != null && _bgUrl!.isNotEmpty) 'best_url': _bgUrl,
              };
      }
      if (posterUrl != null && posterUrl.trim().isNotEmpty) {
        pb['poster_url'] ??= posterUrl.trim();
      }
      return (videoAssetId: bgAssetId, playback: pb);
    }

    final pendingAssetId = widget.pendingVideoAssetId?.trim() ?? '';
    if (pendingAssetId.isNotEmpty && widget.pendingPlayback != null) {
      final pb = Map<String, dynamic>.from(widget.pendingPlayback!);
      if (posterUrl != null && posterUrl.trim().isNotEmpty) {
        pb['poster_url'] ??= posterUrl.trim();
      }
      return (videoAssetId: pendingAssetId, playback: pb);
    }

    final manifest = await provider.fetchPlaybackForDirectUrl(_effectiveUrl);
    final assetId = manifest?['video_asset_id']?.toString().trim();
    final rawPlayback = manifest?['playback'];
    if (assetId != null && assetId.isNotEmpty && rawPlayback is Map) {
      final pb = Map<String, dynamic>.from(rawPlayback);
      if (posterUrl != null && posterUrl.trim().isNotEmpty) {
        pb['poster_url'] ??= posterUrl.trim();
      }
      return (videoAssetId: assetId, playback: pb);
    }

    final fallback = <String, dynamic>{
      'best_url': _effectiveUrl,
      if (posterUrl != null && posterUrl.trim().isNotEmpty) 'poster_url': posterUrl.trim(),
    };
    return (videoAssetId: null, playback: fallback);
  }

  Future<void> _publish() async {
    if (_isPublishing) return;

    setState(() => _isPublishing = true);

    // TikTok flow: wait for the background upload + processing to finish.
    if (_uploadPhase == _UploadPhase.uploading ||
        _uploadPhase == _UploadPhase.processing) {
      final ok = await (_uploadCompleter?.future ?? Future<bool>.value(true));
      if (!mounted) return;
      if (!ok) {
        setState(() => _isPublishing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_uploadError ?? 'Échec du téléversement. Réessaie.')),
        );
        return;
      }
    } else if (_uploadPhase == _UploadPhase.failed) {
      setState(() => _isPublishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_uploadError ?? 'Échec du téléversement. Réessaie.')),
      );
      return;
    }

    final provider = context.read<StudentChallengesProvider>();

    try {
      // Upload cover image (selected by user or default thumbnail)
      String? thumbnailUrl;
      final coverBytes = _effectiveCover;
      if (coverBytes != null && coverBytes.isNotEmpty) {
        debugPrint('[Publish] Uploading cover image (${coverBytes.length} bytes)...');
        thumbnailUrl = await provider.uploadThumbnail(
          bytes: coverBytes,
          videoFileName: _effectiveUrl.split('/').last,
        );
        debugPrint('[Publish] thumbnailUrl=$thumbnailUrl');
      }

      if (!mounted) return;

      if (_isFreeVideo) {
        await _publishFreeVideo(provider, thumbnailUrl: thumbnailUrl);
      } else {
        await _publishChallengeVideo(provider, thumbnailUrl: thumbnailUrl);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  Future<void> _publishFreeVideo(StudentChallengesProvider provider, {String? thumbnailUrl}) async {
    final freeVideoId = widget.freeVideoId;

    final resolved = await _resolveAssetAndPlayback(
      provider: provider,
      posterUrl: thumbnailUrl,
    );

    if (freeVideoId == null || freeVideoId.isEmpty) {
      // Créer la free_video si elle n'existe pas encore
      final newId = await provider.createFreeVideo(
        videoAssetId: resolved.videoAssetId,
        playback: resolved.playback,
        title: _captionController.text.trim().isNotEmpty
            ? _captionController.text.trim()
            : null,
        description: _hashtagsController.text.trim().isNotEmpty
            ? _hashtagsController.text.trim()
            : null,
      );

      if (!mounted) return;

      if (newId == null || newId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Erreur lors de la création de la vidéo.'),
          ),
        );
        return;
      }

      // Sauvegarder les overlays
      if (widget.overlays.isNotEmpty) {
        await provider.updateFreeVideoOverlays(
          freeVideoId: newId,
          layers: widget.overlays,
        );
      }
    } else {
      // Ensure the free_video has the video_asset_id + playback for feed visibility.
      await provider.updateFreeVideoMainRenditions(
        freeVideoId: freeVideoId,
        videoAssetId: resolved.videoAssetId,
        playback: resolved.playback,
      );

      // Sauvegarder les overlays sur la free_video existante
      if (widget.overlays.isNotEmpty) {
        final ok = await provider.updateFreeVideoOverlays(
          freeVideoId: freeVideoId,
          layers: widget.overlays,
        );

        if (!mounted) return;

        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                provider.error ?? 'Erreur lors de la sauvegarde des overlays.',
              ),
            ),
          );
          return;
        }
      }
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ta vidéo a été publiée avec succès !')),
    );

    // Pop back to Studio — the Studio will handle its own cleanup and pop
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _publishChallengeVideo(StudentChallengesProvider provider, {String? thumbnailUrl}) async {
    final participationId = widget.participationId;
    if (participationId == null || participationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Participation ID manquant.')),
      );
      return;
    }

    final resolved = await _resolveAssetAndPlayback(
      provider: provider,
      posterUrl: thumbnailUrl,
    );

    if (resolved.videoAssetId == null || resolved.videoAssetId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de résoudre le video_asset_id pour la publication.'),
        ),
      );
      return;
    }

    // Sauvegarder les overlays
    if (widget.overlays.isNotEmpty) {
      final okOverlays = await provider.updateChallengeVideoOverlays(
        participationId: participationId,
        layers: widget.overlays,
      );

      if (!mounted) return;

      if (!okOverlays) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.error ?? 'Erreur lors de la sauvegarde des overlays.',
            ),
          ),
        );
        return;
      }
    }

    // Ensure participation has video_asset_id for feed visibility.
    final okAdd = await provider.addChallengeVideo(
      participationId: participationId,
      videoAssetId: resolved.videoAssetId!,
      playback: resolved.playback,
    );

    if (!mounted) return;
    if (!okAdd) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.error ?? 'Erreur lors de l\'association de la vidéo au challenge.',
          ),
        ),
      );
      return;
    }

    // Soumettre le challenge
    final okSubmit = await provider.submitChallenge(
      participationId: participationId,
      submissionText: _captionController.text.trim().isEmpty
          ? null
          : _captionController.text.trim(),
      submissionUrl: _effectiveUrl,
    );

    if (!mounted) return;

    if (!okSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.error ?? 'Erreur lors de la soumission du challenge.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ta vidéo de challenge a été envoyée pour validation.'),
      ),
    );

    // Pop back to Studio — the Studio will handle its own cleanup and pop
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // ── Top bar ──
          Container(
            padding: EdgeInsets.only(
              top: topPad + 8,
              left: 12,
              right: 12,
              bottom: 8,
            ),
            color: Colors.black,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Publier',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Content ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),

                  // ── Cover image + caption ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cover image
                      GestureDetector(
                        onTap: widget.localVideoPath != null && widget.videoDurationMs > 0
                            ? () => _showCoverPicker()
                            : null,
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 100,
                                height: 140,
                                child: _effectiveCover != null
                                    ? Image.memory(
                                        _effectiveCover!,
                                        fit: BoxFit.cover,
                                      )
                                    : (_effectiveUrl.isNotEmpty
                                        ? AcademiaPlaybackEngine.view(
                                            url: _effectiveUrl,
                                            autoplay: false,
                                            looping: false,
                                            muted: true,
                                            showControls: false,
                                            fit: BoxFit.cover,
                                            playbackController: _videoController,
                                          )
                                        : Container(
                                            color: Colors.white10,
                                            child: const Center(
                                              child: Icon(
                                                Icons.movie_creation_outlined,
                                                color: Colors.white24,
                                                size: 32,
                                              ),
                                            ),
                                          )),
                              ),
                            ),
                            if (widget.localVideoPath != null)
                              Positioned(
                                bottom: 4,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Couverture',
                                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Caption
                      Expanded(
                        child: TextField(
                          controller: _captionController,
                          maxLines: 5,
                          minLines: 3,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Décris ta vidéo...',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Hashtags ──
                  TextField(
                    controller: _hashtagsController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.tag,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 20,
                      ),
                      hintText: 'Ajouter des hashtags (ex: #science #maths)',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Visibilité ──
                  const Text(
                    'Qui peut voir cette vidéo ?',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _visibilityChip('public', 'Tout le monde', Icons.public),
                      const SizedBox(width: 8),
                      _visibilityChip('friends', 'Amis', Icons.people_outline),
                      const SizedBox(width: 8),
                      _visibilityChip('private', 'Privé', Icons.lock_outline),
                    ],
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // ── Publish button ──
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: bottomPad + 12,
            ),
            color: Colors.black,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildUploadStatus(),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isPublishing ? null : _publish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2D55),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: _isPublishing
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(_publishingLabel),
                            ],
                          )
                        : const Text('Publier'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCoverPicker() {
    double tempPosition = _coverPositionMs;
    final totalMs = widget.videoDurationMs.toDouble().clamp(1.0, double.infinity);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Choisir la couverture',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fais glisser pour choisir le moment',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                    ),
                    const SizedBox(height: 16),

                    // Preview of selected frame
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 160,
                        height: 220,
                        child: _isExtractingCover
                            ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))
                            : (_effectiveCover != null
                                ? Image.memory(_effectiveCover!, fit: BoxFit.cover)
                                : Container(color: Colors.white10)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Time label
                    Text(
                      '${(tempPosition / 1000).toStringAsFixed(1)}s / ${(totalMs / 1000).toStringAsFixed(1)}s',
                      style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 4),

                    // Slider
                    SliderTheme(
                      data: SliderTheme.of(ctx2).copyWith(
                        activeTrackColor: const Color(0xFFFF2D55),
                        inactiveTrackColor: Colors.white12,
                        thumbColor: const Color(0xFFFF2D55),
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      ),
                      child: Slider(
                        value: tempPosition.clamp(0.0, totalMs),
                        min: 0,
                        max: totalMs,
                        onChanged: (v) {
                          setSheetState(() => tempPosition = v);
                        },
                        onChangeEnd: (v) {
                          setState(() => _coverPositionMs = v);
                          _extractCoverAtPosition(v).then((_) {
                            if (ctx2.mounted) setSheetState(() {});
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Confirm button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF2D55),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        ),
                        child: const Text('Confirmer', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String get _publishingLabel {
    switch (_uploadPhase) {
      case _UploadPhase.uploading:
        return 'Téléversement ${(_uploadProgress * 100).toStringAsFixed(0)}%';
      case _UploadPhase.processing:
        return 'Traitement…';
      default:
        return 'Publication…';
    }
  }

  Widget _buildUploadStatus() {
    const Color accent = Color(0xFF00D2FF);
    switch (_uploadPhase) {
      case _UploadPhase.uploading:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_upload_outlined, color: accent, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Téléversement ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _uploadProgress > 0 ? _uploadProgress : null,
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  color: accent,
                ),
              ),
            ],
          ),
        );
      case _UploadPhase.processing:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: accent),
              ),
              const SizedBox(width: 8),
              Text(
                'Traitement de la vidéo…',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
              ),
            ],
          ),
        );
      case _UploadPhase.failed:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Échec du téléversement.',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: _startBackgroundUpload,
                child: const Text('Réessayer', style: TextStyle(color: accent)),
              ),
            ],
          ),
        );
      case _UploadPhase.idle:
      case _UploadPhase.ready:
        return const SizedBox.shrink();
    }
  }

  Widget _visibilityChip(String value, String label, IconData icon) {
    final selected = _visibility == value;
    return GestureDetector(
      onTap: () => setState(() => _visibility = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFF2D55).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFFFF2D55) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? const Color(0xFFFF2D55) : Colors.white54,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFFFF2D55) : Colors.white54,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
