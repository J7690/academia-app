import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

/// Vue plein écran du partage d'écran dans AcademiaClassroom.
///
/// Détecte la track ScreenShare du participant local ou distant
/// et l'affiche en priorité avec un badge identifiant le présentateur.
class AcademiaScreenShareView extends StatelessWidget {
  final Room? room;
  final List<RemoteParticipant> remoteParticipants;

  const AcademiaScreenShareView({
    super.key,
    required this.room,
    required this.remoteParticipants,
  });

  /// Retourne la track de screen share active (locale ou distante).
  VideoTrack? get activeScreenShareTrack {
    // Check local participant
    final local = room?.localParticipant;
    if (local != null) {
      for (final pub in local.videoTrackPublications) {
        if (pub.source == TrackSource.screenShareVideo &&
            pub.track != null &&
            !pub.muted) {
          return pub.track as VideoTrack;
        }
      }
    }
    // Check remote participants
    for (final remote in remoteParticipants) {
      for (final pub in remote.videoTrackPublications) {
        if (pub.source == TrackSource.screenShareVideo &&
            pub.subscribed &&
            pub.track != null &&
            !pub.muted) {
          return pub.track as VideoTrack;
        }
      }
    }
    return null;
  }

  /// Retourne le nom du présentateur du screen share.
  String get presenterName {
    final local = room?.localParticipant;
    if (local != null) {
      for (final pub in local.videoTrackPublications) {
        if (pub.source == TrackSource.screenShareVideo &&
            pub.track != null &&
            !pub.muted) {
          final name = local.name;
          return name.isNotEmpty ? '$name (vous)' : 'Vous';
        }
      }
    }
    for (final remote in remoteParticipants) {
      for (final pub in remote.videoTrackPublications) {
        if (pub.source == TrackSource.screenShareVideo &&
            pub.subscribed &&
            pub.track != null &&
            !pub.muted) {
          final name = remote.name;
          return name.isNotEmpty ? name : remote.identity;
        }
      }
    }
    return '';
  }

  /// Indique si un screen share est actif.
  bool get isActive => activeScreenShareTrack != null;

  @override
  Widget build(BuildContext context) {
    final track = activeScreenShareTrack;
    if (track == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF22C55E).withValues(alpha: 0.6),
          width: 2,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoTrackRenderer(track),
          // Badge présentateur
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.screen_share, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    presenterName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
