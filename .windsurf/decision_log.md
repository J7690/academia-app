# Decision Log – Studio vs Feed Video Pipeline (Android)

## 1. Constat initial

- Les vidéos rendues (`/renders/...` + `video_renditions`) se lisent bien sur TECNO LD7 dans le **feed**.
- La même participation ouverte immédiatement dans le **studio** casse :
  - Player : `VideoPlayerController.networkUrl` sur l’URL brute `challenge-media/{user}/challenges/...`.
  - Codec : `OMX.MTK.VIDEO.DECODER.AVC` (MediaTek) → `DecoderInitializationException: start failed`.
- Les audits `.windsurf/audit_video_stack.md` et SQL montrent :
  - Le backend encode déjà en H.264 Baseline, yuv420p, max_width 720, renditions 480p/360p/240p.
  - Le feed utilise ces renditions avec priorité Android (360p → 240p → 480p → default → source).
  - Le feed possède un fallback logiciel (`UniversalVideoPlayer` → `OMX.google.h264`).

**Conclusion :**
- Le backend et le feed sont sains.
- Le bug est strictement dans le pipeline **Studio** (preview après capture).

## 2. Différences feed vs studio (avant correction)

### Feed

- URL :
  - Utilise `video_renditions` si présent.
  - Priorité Android : `['360p', '240p', '480p', 'default', 'source']`.
  - Garde-fou Android : refuse toute URL qui ne contient pas `/renders/`.
- Player :
  - `VideoPlayerController.networkUrl` (video_player).
  - En cas d’erreur :
    - `_errorMessage` renseigné.
    - UI remplace le player par `UniversalVideoPlayer(url: _selectedUrl)` (décodeur logiciel Google H.264) + overlays.

### Studio

- Cas « vidéo déjà rendue » :
  - Utilise `getChallengeVideoById` + `video_renditions`.
  - Priorité Android identique au feed.
- Cas « nouvelle capture / upload brut » :
  - Upload dans `challenge-media/{user}/challenges/{challengeId}/...`.
  - Player lit **directement** cette URL brut via `VideoPlayerController.networkUrl`.
  - Aucun usage de `UniversalVideoPlayer`.
  - Fallback preview (`/studio/video/render_preview`) n’était déclenché qu’après constat d’erreur, et pas de fallback logiciel.

## 3. Décision – Règle Studio Android

**Objectif :** sur Android, le studio doit devenir aussi robuste que le feed, sans modifier le feed.

Règle adoptée :

> Sur Android, le studio ne doit **jamais** lire l’URL brute uploadée. Après upload/capture, il déclenche immédiatement `render_preview` et ne lit que des URLs de rendu (`/preview_renders/` ou `/renders/`).

Implémentation concrète (Flutter) :

- Dans `StudentChallengeVideoEditorScreen._uploadVideo()` :
  - Après `uploadChallengeVideo`, si `!_isFreeVideo` et Android :
    - Appel de `_prepareAndroidPreviewAndInit(rawUrl)` au lieu de lire `rawUrl`.
- `_prepareAndroidPreviewAndInit(rawUrl)` :
  - Appelle `StudioVideoService.renderPreview(participationId, videoUrl: rawUrl)`.
  - Re-construit un `Map` `{ video_url, video_renditions }`.
  - Appelle `_pickBestServerVideoUrl(...)` pour choisir l’URL, avec priorité Android identique au feed :
    - `360p → 240p → 480p → default → source`.
  - Garde-fou :
    - Refuse toute URL qui ne contient **ni** `/preview_renders/` **ni** `/renders/`.
  - Stocke l’URL choisie dans `_uploadedUrl`.
  - Initialise le player **uniquement** sur cette URL : `await _initRemoteVideo(selectedUrl);`.

Effet :
- Le studio Android **ne lit plus jamais** l’upload brut.
- Il lit directement une rendition H.264 « safe mode » produite par `/studio/video/render_preview`.

## 4. Encodage preview – Safe mode

- `render_preview` réutilise les mêmes helpers que le rendu principal :
  - Conteneur : MP4.
  - Codec : H.264.
  - Profil : baseline.
  - Level : 3.0.
  - Pixel format : yuv420p.
  - Résolution max : 720p pour la rendition « main », 480p/360p/240p pour les autres.
  - Framerate : 30 fps pour 480p/360p, 24 fps pour 240p.
  - Audio : AAC stéréo 44.1 kHz.
- Le preview choisit par défaut une rendition 480p/360p/240p (priorité 480p → 360p → 240p → source), donc **nettement plus léger** que les 2560x1440 vus dans les crash logs.

Conclusion :
- `render_preview` fournit déjà un encodage « safe » pour la plupart des appareils, y compris MediaTek.

## 5. Fallback logiciel dans le studio

Pour couvrir les cas où même la preview H.264 safe échouerait sur certains appareils :

- Ajout d’un wrapper studio-only dans `StudentChallengeVideoEditorScreen` :

  - `_buildStudioVideoPlayer()` :
    - Si **non Android** ou `_uploadedUrl` vide → retourne `StudentVideoPlayer` classique.
    - Si Android et `_uploadedUrl` non vide → retourne `_StudioAndroidVideoWithFallback`.

  - `_StudioAndroidVideoWithFallback` :
    - Écoute `VideoPlayerController` via `ValueListenableBuilder`.
    - Si `value.hasError == true` → affiche `UniversalVideoPlayer(url: _uploadedUrl)` en plein écran.
    - Sinon → affiche `StudentVideoPlayer(controller: controller, overlays: overlays, feedMode: true)`.

Effet :
- Sur Android, même après passage par `render_preview`, si `VideoPlayerController` échoue, on bascule sur le **décodeur logiciel Google H.264** exactement comme dans le feed.
- Le feed n’est **pas modifié** : son propre fallback UniversalVideoPlayer reste inchangé.

## 6. Sélection d’URL – Alignement feed / studio

- **Feed** :
  - Priorité Android : `360p, 240p, 480p, default, source` sur `video_renditions`.
  - Refuse les URLs sans `/renders/`.
- **Studio (nouvelle capture Android)** :
  - Appelle `render_preview` pour obtenir `{ video_url, video_renditions }` sous `/preview_renders/{participation_id}/...`.
  - Utilise **exactement la même fonction** `_pickBestServerVideoUrl` que le studio et le feed.
  - Garde-fou supplémentaire :
    - Refuse les URLs qui ne contiennent ni `/preview_renders/` ni `/renders/`.
- **Studio (vidéos déjà rendues)** :
  - Continue d’utiliser `video_renditions` et `/renders/...` comme avant, sans changement.

Résultat :
- Sur Android, le studio lit désormais **les mêmes types d’URL** que le feed (renditions de rendu), jamais l’upload brut.

## 7. Plateformes non Android

- **Web / iOS** :
  - Conservent la logique précédente :
    - Lecture possible de l’URL brute en premier.
    - Fallback preview conservé via `_initRemoteVideoWithPreviewFallbackIfNeeded`.
  - UniversalVideoPlayer n’est pas utilisé sur ces plateformes.

## 8. Garantie « sans toucher au feed »

- Aucun changement dans :
  - `_ChallengeVideoItemState` (feed).
  - `UniversalVideoPlayer` (widget + plugin Android).
- Tous les changements sont localisés à :
  - `StudentChallengeVideoEditorScreen` (flux studio après upload).
  - `.windsurf/audit_flutter_*` et ce `decision_log`.

## 9. Prochaines étapes d’audit

- Vérifier via logs Flutter sur TECNO LD7 que :
  - Après upload en studio Android, **seul** `/studio/video/render_preview` est appelé (plus aucune tentative de lecture de l’URL brute).
  - L’URL finalement lue contient bien `/preview_renders/` ou `/renders/`.
  - En cas d’erreur `Video player had error ...`, `UniversalVideoPlayer` est effectivement instancié sur cette URL preview.
- Confirmer qu’aucun comportement du feed n’a changé (audit visuel + logs).
