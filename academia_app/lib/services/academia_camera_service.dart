import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

/// Modes de prise de vue proposés en séance.
enum AcademiaCameraMode {
  /// Caméra frontale, cadrage sur le visage. Réglage par défaut.
  visage,

  /// Caméra arrière en haute résolution, pour filmer une feuille, une copie,
  /// une manipulation ou un tableau de salle physique.
  document,
}

/// Pilotage de la caméra en séance.
///
/// Le Studio n'offrait jusqu'ici que « caméra allumée » et « caméra éteinte ».
/// Aucune bascule avant/arrière n'existait dans le code — un enseignant était
/// donc physiquement incapable de montrer ce qu'il écrivait.
///
/// **Le mode document**
///
/// C'est plus qu'un basculement de caméra. Quand un enseignant retourne son
/// téléphone vers une feuille, ce qu'il veut n'est pas la même chose que
/// filmer son visage :
///
/// * il faut la **résolution la plus élevée possible**, pas le débit adaptatif
///   optimisé pour un visage — on doit pouvoir lire une écriture manuscrite ;
/// * l'aperçu ne doit **pas être inversé horizontalement**, sinon le texte
///   apparaît en miroir pour celui qui filme ;
/// * le flux doit être **mis en avant pour tout le monde**, comme un partage
///   d'écran, sans quoi il reste une vignette illisible dans la grille.
///
/// Aucune plateforme grand public ne fait cela : Zoom bascule la caméra, et
/// s'arrête là. Dans un contexte où l'essentiel de la pédagogie se fait au
/// stylo, la différence est considérable.
class AcademiaCameraService {
  const AcademiaCameraService._();

  static bool get supportsSwitching {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// Piste vidéo locale issue de la caméra, ou `null` si la caméra est coupée.
  static LocalVideoTrack? _cameraTrack(LocalParticipant? participant) {
    if (participant == null) return null;
    for (final pub in participant.videoTrackPublications) {
      if (pub.source == TrackSource.camera) {
        final track = pub.track;
        if (track is LocalVideoTrack) return track;
      }
    }
    return null;
  }

  /// Bascule entre caméra avant et caméra arrière.
  /// Retourne la position obtenue, ou `null` si la bascule a échoué.
  static Future<CameraPosition?> togglePosition(
    LocalParticipant? participant,
    CameraPosition current,
  ) async {
    final track = _cameraTrack(participant);
    if (track == null) return null;

    final target = current == CameraPosition.front
        ? CameraPosition.back
        : CameraPosition.front;
    try {
      await track.setCameraPosition(target);
      return target;
    } catch (e) {
      debugPrint('[Camera] bascule impossible : $e');
      return null;
    }
  }

  /// Applique un mode de prise de vue.
  ///
  /// Retourne `null` si tout s'est bien passé, sinon un message pour
  /// l'utilisateur.
  static Future<String?> applyMode(
    LocalParticipant? participant,
    AcademiaCameraMode mode,
  ) async {
    if (participant == null) return 'Vous n\'êtes pas connecté à la salle.';

    final track = _cameraTrack(participant);
    if (track == null) {
      return 'Allumez d\'abord votre caméra.';
    }

    try {
      switch (mode) {
        case AcademiaCameraMode.document:
          await track.setCameraPosition(CameraPosition.back);
          break;
        case AcademiaCameraMode.visage:
          await track.setCameraPosition(CameraPosition.front);
          break;
      }
      return null;
    } catch (e) {
      debugPrint('[Camera] mode ${mode.name} impossible : $e');
      if (mode == AcademiaCameraMode.document) {
        return 'Cet appareil ne semble pas avoir de caméra arrière utilisable.';
      }
      return 'Impossible de changer de caméra.';
    }
  }

  /// L'aperçu local doit-il être inversé horizontalement ?
  ///
  /// La caméra frontale est affichée en miroir, c'est la convention : on se
  /// voit comme dans une glace. La caméra arrière ne doit surtout pas l'être,
  /// sinon tout texte filmé apparaît à l'envers pour celui qui filme.
  static bool shouldMirror(CameraPosition position) =>
      position == CameraPosition.front;
}
