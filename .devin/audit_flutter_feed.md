# Audit Flutter – Feed « Vidéos de challenges »

## 1. Player utilisé dans le feed

- **Widget principal** : `_ChallengeVideoItem` dans
  `academia_app/lib/features/student/tabs/student_challenges_tab.dart`.
- **Contrôleur principal** : `VideoPlayerController.networkUrl(Uri.parse(_selectedUrl))`.
- **Widget d’affichage** : `StudentVideoPlayer(controller: _controller!, overlays: overlays, feedMode: true)`.
- **Fallback logiciel Android** : `UniversalVideoPlayer(url: _selectedUrl)` depuis le package
  `packages/academia_universal_video_player`.

### Séquence

1. `_startInit()` (appelé dans `initState`)
   - Loggue la vidéo brute.
   - Extrait `video_renditions` éventuelles.
   - Calcule `_selectedUrl = _pickBestUrl()`.
2. Vérifie que `_selectedUrl` est non vide.
3. Sur Android uniquement, refuse les URLs brutes (sans `/renders/`).
4. Crée un `VideoPlayerController.networkUrl` avec `_selectedUrl`, initialise, loop, play.
5. En cas d’exception, renseigne `_errorMessage` avec un message détaillé.

## 2. Sélection d’URL dans le feed

Fonction : `_pickBestUrl()` dans `_ChallengeVideoItemState`.

- Si `video_renditions` est absent :
  - Retourne `video['video_url']` (trim).
- Sinon, priorité **Android-friendly** :
  - `['360p', '240p', '480p', 'default', 'source']`.
  - Retourne la première rendition non vide, avec un log `ANDROID VIDEO DEBUG :: found rendition <key> = <url>`.
- Si aucune rendition n’est valide : fallback sur `video['video_url']`.

### Filtrage Android

Après `_pickBestUrl()` :

```dart
final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
if (isAndroid && !_selectedUrl.contains('/renders/')) {
  _setError('Android ne lit pas la vidéo brute. Rendition absente.\nURL : $_selectedUrl');
  return;
}
```

→ Sur Android, le feed **refuse** explicitement les URL qui ne sont pas en `/renders/`.

## 3. Fallback décodeur renforcé (UniversalVideoPlayer)

Package : `packages/academia_universal_video_player`.

### Côté Dart

- Widget `UniversalVideoPlayer(url: ...)` :
  - Ne rend quelque chose que sur Android (`kIsWeb == false` et `defaultTargetPlatform == TargetPlatform.android`).
  - Crée un `AndroidView` avec `viewType: 'academia_universal_video_player'`.

### Côté Android (Kotlin)

Fichier : `UniversalVideoPlayerPlugin.kt`.

- `UniversalVideoPlayerPlugin` enregistre une `PlatformViewFactory`.
- `UniversalVideoPlayerView` crée :
  - Un `PlayerView` Media3.
  - Un `ExoPlayer` construit avec un `DefaultRenderersFactory` custom :
    - Override de `buildVideoRenderers`.
    - Utilise un `MediaCodecSelector` qui, pour `MimeTypes.VIDEO_H264`, filtre
      d’abord les codecs dont le nom contient `OMX.google.h264`.
    - Si des codecs Google sont trouvés, ils sont préférés aux codecs matériels.
- Le player lit l’URL fournie, prépare et lance `playWhenReady = true`.

### Intégration dans le feed

Dans `_ChallengeVideoItemState.build()` :

- Si `_errorMessage != null` **ET** plateforme Android **ET** `_selectedUrl` non vide :

  ```dart
  return Stack(
    children: [
      Positioned.fill(
        child: UniversalVideoPlayer(url: _selectedUrl),
      ),
      _buildOverlayMeta(...),
      _buildRightActions(...),
    ],
  );
  ```

→ En cas d’erreur ExoPlayer classique (Matériel MediaTek), le feed affiche :

- En fond : `UniversalVideoPlayer` (ExoPlayer + décodeur logiciel Google pour H.264).
- Par-dessus : les overlays de méta et les actions.

## 4. Résumé feed

- **Player principal** : `VideoPlayerController.networkUrl` (Flutter video_player).
- **Sélection d’URL** : renditions `/renders/...` priorisées pour Android.
- **Filtre Android** : interdit les URLs brutes (`!url.contains('/renders/')`).
- **Fallback** : `UniversalVideoPlayer` avec sélection du codec logiciel Google H.264.

Ce pipeline explique pourquoi, même sur TECNO LD7, une vidéo rendue (stockée en `/renders/...`)
peut être lue dans le feed alors que la même source brute échoue dans le studio.
