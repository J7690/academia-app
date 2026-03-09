import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/student_challenges_provider.dart';
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
  });

  @override
  State<VideoPublishScreen> createState() => _VideoPublishScreenState();
}

class _VideoPublishScreenState extends State<VideoPublishScreen> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _hashtagsController = TextEditingController();
  String _visibility = 'public'; // public, friends, private
  bool _isPublishing = false;

  bool get _isFreeVideo => widget.videoType == 'free';

  @override
  void dispose() {
    _captionController.dispose();
    _hashtagsController.dispose();
    super.dispose();
  }

  Future<({String? videoAssetId, Map<String, dynamic> playback})> _resolveAssetAndPlayback({
    required StudentChallengesProvider provider,
    String? posterUrl,
  }) async {
    final pendingAssetId = widget.pendingVideoAssetId?.trim() ?? '';
    if (pendingAssetId.isNotEmpty && widget.pendingPlayback != null) {
      final pb = Map<String, dynamic>.from(widget.pendingPlayback!);
      if (posterUrl != null && posterUrl.trim().isNotEmpty) {
        pb['poster_url'] ??= posterUrl.trim();
      }
      return (videoAssetId: pendingAssetId, playback: pb);
    }

    final manifest = await provider.fetchPlaybackForDirectUrl(widget.videoUrl);
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
      'best_url': widget.videoUrl,
      if (posterUrl != null && posterUrl.trim().isNotEmpty) 'poster_url': posterUrl.trim(),
    };
    return (videoAssetId: null, playback: fallback);
  }

  Future<void> _publish() async {
    if (_isPublishing) return;

    setState(() => _isPublishing = true);

    final provider = context.read<StudentChallengesProvider>();

    try {
      // Upload thumbnail if available
      String? thumbnailUrl;
      if (widget.thumbnailBytes != null && widget.thumbnailBytes!.isNotEmpty) {
        debugPrint('[Publish] Uploading thumbnail...');
        thumbnailUrl = await provider.uploadThumbnail(
          bytes: widget.thumbnailBytes!,
          videoFileName: widget.videoUrl.split('/').last,
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
      submissionUrl: widget.videoUrl,
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

                  // ── Video preview + caption ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Miniature vidéo
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 100,
                          height: 140,
                          child: widget.thumbnailBytes != null
                              ? Image.memory(
                                  widget.thumbnailBytes!,
                                  fit: BoxFit.cover,
                                )
                              : AcademiaPlaybackEngine.view(
                                  url: widget.videoUrl,
                                  autoplay: false,
                                  looping: false,
                                  muted: true,
                                  showControls: false,
                                  fit: BoxFit.cover,
                                ),
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
            child: SizedBox(
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
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Publier'),
              ),
            ),
          ),
        ],
      ),
    );
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
