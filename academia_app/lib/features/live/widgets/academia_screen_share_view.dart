import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

/// Vue plein écran du partage d'écran dans AcademiaClassroom.
///
/// **Règle fondamentale : on n'affiche JAMAIS son propre partage d'écran.**
///
/// Correctif du 31/07/2026. La version précédente cherchait la piste de partage
/// en commençant par le participant **local**, puis la rendait à l'écran. Or
/// une capture d'écran filme… l'écran. Afficher sa propre capture revient donc
/// à filmer l'affichage de ce qu'on est en train de filmer : l'image se
/// reproduit à l'intérieur d'elle-même, de plus en plus petite, en cascade —
/// l'effet « couloir de miroirs ». C'est exactement ce qu'on observait, et cela
/// rendait le partage inexploitable pour celui qui le lançait.
///
/// Tous les outils de visioconférence appliquent la même règle : celui qui
/// partage voit un simple bandeau de confirmation, jamais le flux lui-même.
/// Outre l'effet miroir, cela évite de décoder et d'afficher une vidéo dont on
/// possède déjà la source — travail inutile pour le processeur et la batterie.
class AcademiaScreenShareView extends StatelessWidget {
  final Room? room;
  final List<RemoteParticipant> remoteParticipants;

  /// Permet à celui qui partage d'arrêter depuis le bandeau, sans aller
  /// chercher le bouton dans la barre de commandes.
  final VoidCallback? onStopSharing;

  /// Renvoie à l'écran d'accueil du téléphone, le partage se poursuivant.
  /// C'est l'action la plus utile du bandeau : partager sert à montrer autre
  /// chose que l'application elle-même.
  final VoidCallback? onOpenPhone;

  const AcademiaScreenShareView({
    super.key,
    required this.room,
    required this.remoteParticipants,
    this.onStopSharing,
    this.onOpenPhone,
  });

  /// Piste de partage d'un participant **distant** uniquement.
  ///
  /// Le participant local est délibérément exclu : voir la note de classe.
  VideoTrack? get remoteScreenShareTrack {
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

  /// Vrai si c'est **moi** qui partage mon écran.
  bool get isLocalSharing {
    final local = room?.localParticipant;
    if (local == null) return false;
    for (final pub in local.videoTrackPublications) {
      if (pub.source == TrackSource.screenShareVideo &&
          pub.track != null &&
          !pub.muted) {
        return true;
      }
    }
    return false;
  }

  /// Nom du présentateur distant.
  String get presenterName {
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

  /// Un partage est en cours — le mien, ou celui d'un autre.
  bool get isActive => remoteScreenShareTrack != null || isLocalSharing;

  @override
  Widget build(BuildContext context) {
    final track = remoteScreenShareTrack;

    // Priorité au partage d'un autre participant : c'est ce qu'on a besoin de
    // voir. Si les deux existent, le sien passe devant le mien.
    if (track != null) {
      return _cadre(
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoTrackRenderer(track),
            _badge(presenterName),
          ],
        ),
      );
    }

    // C'est moi qui partage : bandeau de confirmation, PAS le flux vidéo.
    if (isLocalSharing) {
      return _cadre(child: _bandeauPartageLocal(context));
    }

    return const SizedBox.shrink();
  }

  Widget _cadre({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF22C55E).withValues(alpha: 0.6),
            width: 2,
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: child,
      );

  Widget _badge(String nom) => Positioned(
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
                nom,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );

  /// Ce que voit celui qui partage : une confirmation, pas un miroir.
  Widget _bandeauPartageLocal(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.screen_share,
                  color: Color(0xFF22C55E), size: 26),
            ),
            const SizedBox(height: 14),
            const Text(
              'Vous partagez votre écran',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Les autres participants voient votre écran en direct.\n'
              'Votre propre écran n\'est pas réaffiché ici, pour éviter '
              'un effet de miroir.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            if (onStopSharing != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                ),
                onPressed: onStopSharing,
                icon: const Icon(Icons.stop_screen_share, size: 16),
                label: const Text('Arrêter le partage'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
