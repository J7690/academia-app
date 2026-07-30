import 'package:livekit_client/livekit_client.dart';

/// Source unique des options de salle LiveKit pour tout le Studio Live.
///
/// Objectif : plus aucun `Room()` nu dans le code. Un `Room()` sans options
/// désactive simulcast, dynacast et adaptive stream — c'est-à-dire l'essentiel
/// de ce qui rend un live tenable sur un réseau mobile ouest-africain.
///
/// Les trois mécanismes activés ici :
///
/// * **simulcast** — le publieur encode plusieurs couches de qualité, le SFU
///   sert à chaque abonné celle que sa bande passante supporte.
/// * **dynacast** — met en pause l'encodage des couches que personne ne
///   consomme. 30 à 60 % de CPU en moins, jusqu'à 60 % d'upload en moins, et
///   20 à 40 % d'autonomie de batterie en plus sur mobile.
/// * **adaptiveStream** — l'abonné ne reçoit que la résolution correspondant à
///   la taille réelle de la vignette affichée, et rien du tout si elle est
///   hors écran.
///
/// Le réglage fin des couches d'encodage (débits, images/s, choix de codec par
/// plateforme) relève de la vague 7 et doit s'appuyer sur une campagne de tests
/// sur parc réel. Ce fichier reste volontairement limité à ce qui est vérifié.
class AcademiaRoomOptions {
  const AcademiaRoomOptions._();

  /// Traitement du signal micro, appliqué à TOUS les profils.
  ///
  /// Ces trois filtres tournent dans le moteur WebRTC et sont la seule défense
  /// contre l'effet Larsen quand un participant écoute au haut-parleur — le cas
  /// normal sur téléphone. Ils étaient jusqu'ici laissés implicites : les
  /// rendre explicites documente l'intention et protège d'un changement de
  /// valeur par défaut du SDK.
  ///
  /// * **echoCancellation** — retire du micro le son que le haut-parleur vient
  ///   d'émettre. Sans lui, la voix de l'interlocuteur lui revient en écho.
  /// * **noiseSuppression** — atténue les bruits de fond continus (ventilateur,
  ///   rue), fréquents en contexte scolaire.
  /// * **autoGainControl** — égalise le niveau : l'élève qui parle loin du
  ///   téléphone reste audible sans saturer quand il se rapproche.
  static const AudioCaptureOptions _audio = AudioCaptureOptions(
    echoCancellation: true,
    noiseSuppression: true,
    autoGainControl: true,
  );

  /// Salle interactive : classe, atelier, consultation, TD.
  /// Tout le monde peut publier, la grille affiche plusieurs vignettes —
  /// c'est le cas où adaptiveStream rapporte le plus.
  static const RoomOptions classroom = RoomOptions(
    adaptiveStream: true,
    dynacast: true,
    defaultVideoPublishOptions: VideoPublishOptions(
      simulcast: true,
    ),
    defaultAudioCaptureOptions: _audio,
  );

  /// Diffusion verticale et duo : un ou deux publieurs, N spectateurs.
  /// Même configuration — la vidéo est plein écran côté spectateur, mais
  /// dynacast reste décisif côté publieur (batterie du téléphone qui diffuse).
  static const RoomOptions broadcast = RoomOptions(
    adaptiveStream: true,
    dynacast: true,
    defaultVideoPublishOptions: VideoPublishOptions(
      simulcast: true,
    ),
    defaultAudioCaptureOptions: _audio,
  );

  /// Live de partie de jeu : le joueur publie sa voix et éventuellement sa
  /// caméra frontale pendant que le jeu tourne. L'appareil est déjà chargé par
  /// le rendu du jeu, dynacast y est particulièrement utile.
  static const RoomOptions gameplay = RoomOptions(
    adaptiveStream: true,
    dynacast: true,
    defaultVideoPublishOptions: VideoPublishOptions(
      simulcast: true,
    ),
    defaultAudioCaptureOptions: _audio,
  );

  /// Entretien à deux : consultation d'orientation, aide TD individuelle.
  ///
  /// Le simulcast est ici désactivé à dessein. Avec deux participants, chacun
  /// affiche l'autre en grand : il n'existe aucun abonné à qui servir une
  /// couche basse. Encoder trois qualités reviendrait à consommer du CPU et de
  /// la bande passante montante pour rien — ce qui compte dans un entretien
  /// long, sur un téléphone d'entrée de gamme. adaptiveStream reste actif :
  /// c'est lui qui coupe la réception quand la vignette passe hors écran (le
  /// panneau contexte ouvert, par exemple).
  static const RoomOptions consultation = RoomOptions(
    adaptiveStream: true,
    dynacast: true,
    defaultVideoPublishOptions: VideoPublishOptions(
      simulcast: false,
    ),
    defaultAudioCaptureOptions: _audio,
  );

  /// Choisit le profil d'après le nombre de places de la séance.
  /// Une séance d'orientation individuelle est bornée à deux participants ;
  /// au-delà, on retombe sur la salle interactive.
  static RoomOptions pourSeance({required int maxParticipants}) =>
      maxParticipants <= 2 ? consultation : classroom;
}
