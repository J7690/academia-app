import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

/// Tuile vidéo d'un participant dans AcademiaClassroom.
class AcademiaParticipantTile extends StatelessWidget {
  final Participant participant;
  final bool isLocal;
  final bool isHost;
  final bool isHandRaised;

  const AcademiaParticipantTile({
    super.key,
    required this.participant,
    required this.isLocal,
    required this.isHost,
    required this.isHandRaised,
  });

  @override
  Widget build(BuildContext context) {
    final videoTrack = _videoTrack();
    final isMuted = participant.isMicrophoneEnabled() == false;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHost
              ? const Color(0xFF3B82F6).withValues(alpha: 0.6)
              : Colors.transparent,
          width: isHost ? 2 : 0,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Vidéo ou avatar ─────────────────────────────────────────
          if (videoTrack != null)
            VideoTrackRenderer(videoTrack)
          else
            _buildAvatar(),

          // ── Overlay infos bas ────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF000000).withValues(alpha: 0.65),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _displayName(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isHost)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.school, color: Color(0xFF60A5FA), size: 13),
                    ),
                  if (isMuted)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.mic_off, color: Color(0xFFEF4444), size: 13),
                    ),
                ],
              ),
            ),
          ),

          // ── Main levée ───────────────────────────────────────────────
          if (isHandRaised)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('✋', style: TextStyle(fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }

  VideoTrack? _videoTrack() {
    if (participant is LocalParticipant) {
      final p = participant as LocalParticipant;
      for (final pub in p.videoTrackPublications) {
        if (pub.track != null &&
            pub.source == TrackSource.camera &&
            !pub.muted) {
          return pub.track as VideoTrack;
        }
      }
    } else if (participant is RemoteParticipant) {
      final p = participant as RemoteParticipant;
      for (final pub in p.videoTrackPublications) {
        if (pub.subscribed && pub.track != null && !pub.muted) {
          return pub.track as VideoTrack;
        }
      }
    }
    return null;
  }

  String _displayName() {
    final name = participant.name;
    if (name.isNotEmpty) return name;
    final id = participant.identity;
    return id.length > 8 ? id.substring(0, 8) : id;
  }

  Widget _buildAvatar() {
    final initials = _displayName();
    final letter = initials.isNotEmpty ? initials[0].toUpperCase() : '?';
    return Container(
      color: const Color(0xFF1E293B),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.3),
            child: Text(
              letter,
              style: const TextStyle(
                color: Color(0xFF60A5FA),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _displayName(),
            style: const TextStyle(color: Colors.white54, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
