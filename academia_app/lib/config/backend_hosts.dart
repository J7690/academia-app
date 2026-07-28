/// Point UNIQUE de configuration de l'hôte du VPS applicatif.
///
/// Contexte (25 juillet 2026) : migration Kamatera → LWS. Avant ce fichier, l'IP du
/// VPS était codée en dur à 3 endroits différents du code Flutter, ce qui rendait tout
/// changement d'infrastructure risqué (oubli d'un appel = fonctionnalité cassée en
/// silence). Désormais, **un seul endroit** détermine où l'app appelle le backend.
///
/// Services exposés par ce VPS (conteneurs `academia-backend`, cf. docker-compose.yml) :
///   - port 8000 : Bobodo vocal (WebSocket temps réel)
///   - port 8001 : proxy backend / compression vidéo
///
/// Le rendu Smart Whiteboard ne passe PAS par ici : son worker interrogera Supabase
/// directement (aucune IP côté app), il est donc déjà indépendant de l'infrastructure.
///
/// Pour basculer sur LWS :
///   - soit au build, sans toucher au code :
///       flutter build --dart-define=VPS_HOST=31.207.38.60
///   - soit définitivement, en changeant `defaultValue` ci-dessous.
///
/// ATTENTION : ne bascule cette valeur que lorsque les conteneurs `academia-backend`
/// tournent réellement sur la machine cible (Phase 2 de
/// `docs/MIGRATION_COMPLETE_KAMATERA_VERS_LWS.md`). Sinon Bobodo vocal et la
/// compression vidéo tombent immédiatement.
class BackendHosts {
  /// IP ou domaine du VPS applicatif (sans schéma ni port).
  static const String vpsHost = String.fromEnvironment(
    'VPS_HOST',
    defaultValue: '185.167.97.144', // Kamatera — à remplacer par LWS après Phase 2
  );

  /// WebSocket Bobodo vocal (port 8000).
  static String get bobodoVocalWs => 'ws://$vpsHost:8000/ws';

  /// Autorité (host:port) du proxy backend (port 8001).
  static String get backendProxyAuthority => '$vpsHost:8001';

  // ── Moteur de rendu Smart Whiteboard ──────────────────────────────────────
  /// Moteur demandé au générateur de storyboard.
  ///
  /// - `remotion` (défaut depuis le 25/07/2026) : moteur STUDIO. Écriture
  ///   manuscrite progressive, annotations ciblées sur les mots (cercle, souligné,
  ///   surlignage), rappel pédagogique (la caméra remonte vers une notion vue plus
  ///   haut, la ré-annote, puis redescend), cahier continu qui défile, voix off.
  /// - `vision` : moteur HTML/Playwright/KaTeX. Un rendu par scène (diaporama),
  ///   sans animation d'écriture ni annotation. Conservé comme REPLI de sécurité.
  ///
  /// Repli immédiat sans toucher au code, si un problème survient en production :
  ///   flutter build --dart-define=WHITEBOARD_ENGINE=vision
  ///
  /// Côté serveur, le worker refuse silencieusement de dégrader : si `remotion`
  /// est demandé mais indisponible, le job échoue explicitement au lieu de rendre
  /// avec le mauvais moteur — l'erreur est visible dans `whiteboard_renders`.
  static const String whiteboardEngine = String.fromEnvironment(
    'WHITEBOARD_ENGINE',
    // 'vision2' depuis le 25/07/2026 au soir : Remotion a été abandonné (4-5x le temps
    // réel sur ce serveur, échecs mémoire répétés). Vision v2 rend le même cahier animé
    // à ~1,5x le temps réel. Repli possible sans recompiler : --dart-define.
    defaultValue: 'vision2',
  );

  /// Style d'écriture : `handwriting` (manuscrit, défaut) ou `typed` (machine).
  /// Destiné à devenir un choix de l'étudiant dans l'écran de création.
  static const String whiteboardWritingStyle = String.fromEnvironment(
    'WHITEBOARD_WRITING_STYLE',
    defaultValue: 'handwriting',
  );

  /// Hôtes proxy historiques encore présents dans des URLs stockées en base.
  /// On les conserve TOUS (y compris les anciennes infras) pour que les URLs
  /// héritées restent normalisées après une migration d'hébergeur.
  static const Set<String> legacyProxyHosts = {
    'academia-app-production.up.railway.app', // Railway (retiré du dispositif)
    '185.167.97.144:8001', // Kamatera (migration vers LWS en cours)
    '185.167.97.144',
    '31.207.38.60:8001', // LWS
    '31.207.38.60',
  };
}
