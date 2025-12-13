# Audit Flutter – Studio « Éditeur de vidéo de challenge »

## 1. Player utilisé dans le studio

Fichier : `academia_app/lib/features/student/student_challenge_video_editor_screen.dart`.

- **Contrôleur** : `VideoPlayerController? _videoController;` (Flutter `video_player`).
- **Initialisation** :

  ```dart
  Future<void> _initRemoteVideo(String url) async {
    print('ANDROID STUDIO VIDEO DEBUG :: initRemoteVideo url=$url');
    _videoController?.dispose();
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoController = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      controller.setLooping(true);
      controller.play();
      setState(() {
        _videoInitialized = true;
      });
      print('ANDROID STUDIO VIDEO DEBUG :: controller initialized successfully');
    } catch (e) {
      print('ANDROID STUDIO VIDEO ERROR :: $e');
      if (!mounted) return;
      setState(() {
        _videoInitialized = false;
      });
    }
  }
  ```

- **Widget d’affichage** : `StudentVideoPlayer`, comme dans le feed, mais **sans** fallback UniversalVideoPlayer intégré au studio.
  - `StudentVideoPlayer` utilise `ValueListenableBuilder<VideoPlayerValue>` et affiche :
    - En cas d’erreur : texte `❌ Erreur Flutter/ExoPlayer : ...`.
    - En cas de succès : vidéo + timeline + overlays.

### Conclusion Player Studio

- Le studio utilise **uniquement** `VideoPlayerController.networkUrl` (plugin `video_player`).
- Il **n’utilise pas** `UniversalVideoPlayer` ni de décodeur Media3 custom.
- L’erreur ExoPlayer (MediaTek) est simplement affichée à l’écran.

## 2. Sélection d’URL dans le studio

### 2.1. Cas « réouverture d’une vidéo déjà rendue »

- Méthode : `_loadExistingOverlaysIfAny()`.
- Récupère la vidéo via `StudentChallengesProvider` :
  - `getFreeVideoById(_effectiveFreeVideoId)` ou
  - `getChallengeVideoById(_effectiveParticipationId)`.
- Sélectionne l’URL :

  ```dart
  String selectedUrl = _pickBestServerVideoUrl(video);
  ```

- `_pickBestServerVideoUrl` :
  - Lit `video['video_url']` et `video['video_renditions']`.
  - Si renditions présentes :
    - **Android** : ordre `['360p', '240p', '480p', 'default', 'source']`.
    - Autres plateformes : `['480p', '360p', '240p', 'default', 'source']`.
  - Retourne la première rendition non vide, sinon `video['video_url']`.
- Fallback clips (Android, mode challenge) : si `selectedUrl` vide ou ne contenant pas `/renders/` :
  - Charge `listMyChallengeVideos(_effectiveParticipationId)`.
  - `_pickBestClipUrl(clips)` :
    - Priorité aux URLs contenant `/renders/`.
- Si `selectedUrl` non vide :
  - `_uploadedUrl = selectedUrl;`
  - `await _initRemoteVideo(selectedUrl);`.

→ **Pour les vidéos déjà rendues**, le studio réutilise la même logique de renditions que le feed et favorise `/renders/...`.

### 2.2. Cas « nouvelle capture / nouvel upload » (problème principal)

- Méthode : `_uploadVideo()`.
- Upload challenge :

  ```dart
  url = await provider.uploadChallengeVideo(
    bytes: _videoBytes!,
    fileName: _fileName!,
    challengeId: _effectiveChallengeId,
    mimeType: _mimeType,
  );
  ```

- `uploadChallengeVideo` (provider) :
  - Upload dans `challenge-media` à l’URL :
    - `'{user.id}/challenges/{challengeId}/{fileName}'`.
  - Retourne l’URL publique **brute** (pas `/renders/`).
- Après upload :

  ```dart
  setState(() {
    _uploadedUrl = url;
  });
  // Initialisation du lecteur vidéo sur toutes les plateformes pour avoir
  // un studio plein écran (vidéo en fond + overlays).
  await _initRemoteVideoWithPreviewFallbackIfNeeded(url);
  ```

- Historiquement (avant pipeline preview), le studio faisait :

  ```dart
  await _initRemoteVideo(url);
  ```

  → Lecture **directement** sur l’URL **brute** (HEVC ou H.264 1440p) sur Android.
  → Sur TECNO LD7 : `DecoderInitializationException` du codec MediaTek.

### 2.3. Nouveau helper de fallback preview (actuel)

Méthode : `_initRemoteVideoWithPreviewFallbackIfNeeded(String url)`.

- Réinitialise `_hasTriedPreviewFallback = false`.
- Appelle d’abord `_initRemoteVideo(url)`.
- Si **non Android** ou vidéo **free** → retour, aucun fallback.
- Si `_videoInitialized == false` → appelle `_runPreviewFallback(url)`.
- Sinon :
  - Si `controller.value.hasError == true` → `_runPreviewFallback(url)`.
  - Sinon, planifie une vérification 2s plus tard :
    - Si `hasError` et qu’on n’a pas encore tenté le fallback, appelle `_runPreviewFallback(url)`.

`_runPreviewFallback(url)` :

- Appelle `StudioVideoService.renderPreview(participationId: _effectiveParticipationId, videoUrl: url)`.
- Analyse la réponse `{video_url, video_renditions}`.
- Utilise `_pickBestServerVideoUrl` pour choisir la meilleure rendition.
- Met à jour `_uploadedUrl` avec l’URL de preview (`/preview_renders/{participationId}/...`).
- Rappelle `_initRemoteVideo(selectedUrl)`.

### 2.4. Différences feed vs studio (actuel)

- Feed :
  - **n’essaie jamais** de lire la vidéo brute sur Android (`/renders/` obligatoire).
  - A un **fallback UniversalVideoPlayer** (décodeur logiciel Google H.264) en cas d’erreur.
- Studio :
  - En cas de nouvelle capture, **essaie d’abord toujours de lire l’upload brut**.
  - Ne possède **pas** de fallback `UniversalVideoPlayer`.
  - Le fallback actuel appelle `/studio/video/render_preview`, mais uniquement si l’erreur est détectée par `_videoInitialized` ou `controller.value.hasError`.

## 3. Réponses aux questions de l’audit Flutter

### A. Player utilisé dans le studio

- Utilise **uniquement** `VideoPlayerController.networkUrl` (plugin officiel `video_player`).
- Widget d’affichage : `StudentVideoPlayer`.
- Pas d’utilisation de `UniversalVideoPlayer` dans le studio.
- Il existe un `try/catch` autour de `initialize()` dans `_initRemoteVideo`, mais **pas** de onError distinct ni de widget alternatif.

### B. Sélection de l’URL vidéo dans le studio

- Pour les vidéos déjà rendues :
  - Utilise `video_renditions` avec la même priorité Android que le feed.
  - Fallback clips vers des URLs `.../renders/...`.
- Pour une nouvelle capture/upload :
  - Utilise l’URL **brute** de stockage `challenge-media/{user}/challenges/...`.
  - C’est cette URL qui est passée au player, donc au codec MediaTek, avant toute rendition.

### C. Décodeur renforcé

- Le décodeur renforcé (Media3 + `OMX.google.h264` via `UniversalVideoPlayer`) est **uniquement** utilisé dans le feed.
- Le studio **n’appelle jamais** `UniversalVideoPlayer` et repose entièrement sur le codec hardware par défaut (`OMX.MTK.VIDEO.DECODER.AVC` sur TECNO LD7).

## 4. Résumé Studio

- **Player** : `VideoPlayerController.networkUrl` + `StudentVideoPlayer`.
- **Sélection d’URL** :
  - OK pour les vidéos rendues (renditions + `/renders/`).
  - Problématique pour la toute première lecture après upload (URL brute).
- **Fallback** :
  - Pas de `UniversalVideoPlayer`.
  - Nouveau pipeline preview H.264 (`/preview_renders/`) déclenché uniquement après détection d’erreur ExoPlayer.

Le décalage principal avec le feed vient donc de :

- L’utilisation initiale de l’URL brute sur Android.
- L’absence de `UniversalVideoPlayer` dans le studio.
