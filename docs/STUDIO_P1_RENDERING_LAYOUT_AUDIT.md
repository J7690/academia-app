# P1 — RENDERING LAYOUT AUDIT

**Date :** 19 Juin 2026  
**Objectif :** Comprendre pourquoi les vidéos débordent du cadre

---

## PHASE D — ANALYSE DU PROBLÈME DE DÉBORDEMENT

### VideoPlayer utilisés

| Player | Plateforme | Fichier | Statut |
|--------|-----------|---------|--------|
| `video_player` (Flutter) | iOS/Web | `academia_playback_view.dart` | ✅ Actif |
| `ExoPlayer` (native Android) | Android | `AcademiaAndroidVideoView.kt` | ✅ Actif |
| `AcademiaPlaybackView` | Multi-plateforme (wrapper) | `academia_playback_view.dart` | ✅ Actif |

### AcademiaPlaybackView

**Fichier :** `academia_app/lib/video/academia_playback_view.dart`

**Code :**
```dart
Widget build(BuildContext context) {
  return AspectRatio(
    aspectRatio: _aspectRatio ?? 16 / 9,
    child: _shouldUseNativeAndroid
        ? AndroidView(
            viewType: 'AcademiaAndroidVideoView',
            creationParams: {
              'url': widget.url,
              'autoPlay': widget.autoPlay,
              'muted': widget.muted,
              'looping': widget.looping,
              'showControls': widget.showControls,
            },
            onPlatformViewCreated: _onPlatformViewCreated,
          )
        : VideoPlayer(_controller),
  );
}
```

**Observations :**
- Utilise `AspectRatio` widget avec `_aspectRatio` calculé dynamiquement
- Valeur par défaut : `16 / 9` si `_aspectRatio` est null
- Android : utilise `AndroidView` avec ExoPlayer natif
- iOS/Web : utilise `VideoPlayer` Flutter

### Calcul de l'aspect ratio

**Fichier :** `academia_app/lib/video/academia_playback_view.dart`

**Code :**
```dart
Future<void> _init() async {
  if (_shouldUseNativeAndroid) {
    setState(() {
      _initializing = false;
      _error = null;
    });
    return;
  }

  _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
  await _controller.initialize();

  final metadata = await _controller.getMetadata();
  if (metadata != null) {
    final width = metadata['width'];
    final height = metadata['height'];
    if (width != null && height != null) {
      setState(() {
        _aspectRatio = width / height;
      });
    }
  }

  setState(() {
    _initializing = false;
    _error = null;
  });
}
```

**Observations :**
- L'aspect ratio est calculé depuis les métadonnées vidéo
- Si les métadonnées ne sont pas disponibles, `_aspectRatio` reste null
- Si `_aspectRatio` est null, la valeur par défaut `16 / 9` est utilisée

### AcademiaAndroidVideoView (Android)

**Fichier :** `academia_app/android/app/src/main/kotlin/com/academia/nexiomgroup/app/AcademiaAndroidVideoView.kt`

**Code :**
```kotlin
player.setMediaItem(MediaItem.fromUri(url))
```

**Observations :**
- ExoPlayer utilise directement l'URL sans spécifier d'aspect ratio
- ExoPlayer calcule l'aspect ratio depuis les métadonnées vidéo
- Aucun conteneur avec aspect ratio explicif côté Android

---

## ÉCRANS ANALYSÉS

### 1. Feed

**Fichier :** `student_challenges_tab.dart`

**Widget :** `_ChallengeVideoItem`

**Code :**
```dart
AspectRatio(
  aspectRatio: 16 / 9,
  child: AcademiaPlaybackView(
    url: videoUrl,
    autoPlay: false,
    muted: true,
    looping: true,
    showControls: false,
  ),
)
```

**Observations :**
- Aspect ratio forcé à `16 / 9`
- Pas de calcul dynamique depuis les métadonnées
- Risque de débordement si la vidéo n'est pas en 16:9

### 2. Studio Preview

**Fichier :** `student_challenge_video_editor_screen.dart`

**Widget :** `_buildVideoPreview`

**Code :**
```dart
AspectRatio(
  aspectRatio: _aspectRatio ?? 16 / 9,
  child: AcademiaPlaybackView(
    url: _localVideoPath ?? _uploadedUrl ?? '',
    autoPlay: true,
    muted: false,
    looping: true,
    showControls: false,
  ),
)
```

**Observations :**
- Aspect ratio calculé dynamiquement depuis `_aspectRatio`
- Valeur par défaut `16 / 9` si `_aspectRatio` est null
- `_aspectRatio` est calculé depuis les métadonnées vidéo

### 3. Challenge Preview

**Fichier :** `student_challenge_detail_screen.dart`

**Widget :** `_buildChallengeVideo`

**Code :**
```dart
AspectRatio(
  aspectRatio: 16 / 9,
  child: AcademiaPlaybackView(
    url: videoUrl,
    autoPlay: false,
    muted: true,
    looping: true,
    showControls: false,
  ),
)
```

**Observations :**
- Aspect ratio forcé à `16 / 9`
- Pas de calcul dynamique depuis les métadonnées
- Risque de débordement si la vidéo n'est pas en 16:9

### 4. Lecture vidéo

**Fichier :** `academia_playback_view.dart`

**Widget :** `build`

**Code :**
```dart
AspectRatio(
  aspectRatio: _aspectRatio ?? 16 / 9,
  child: _shouldUseNativeAndroid
      ? AndroidView(...)
      : VideoPlayer(_controller),
)
```

**Observations :**
- Aspect ratio calculé dynamiquement depuis `_aspectRatio`
- Valeur par défaut `16 / 9` si `_aspectRatio` est null

---

## PROBLÈMES IDENTIFIÉS

### 1. Aspect ratio forcé dans le Feed

**Problème :** Le Feed utilise un aspect ratio forcé à `16 / 9` sans tenir compte des métadonnées vidéo.

**Preuve :** `student_challenges_tab.dart` :
```dart
AspectRatio(
  aspectRatio: 16 / 9,
  child: AcademiaPlaybackView(...),
)
```

**Conséquence :** Si une vidéo est en 9:16 (vertical), elle sera déformée ou débordante.

### 2. Aspect ratio forcé dans Challenge Preview

**Problème :** Le Challenge Preview utilise un aspect ratio forcé à `16 / 9` sans tenir compte des métadonnées vidéo.

**Preuve :** `student_challenge_detail_screen.dart` :
```dart
AspectRatio(
  aspectRatio: 16 / 9,
  child: AcademiaPlaybackView(...),
)
```

**Conséquence :** Si une vidéo est en 9:16 (vertical), elle sera déformée ou débordante.

### 3. Aspect ratio dynamique dans Studio Preview

**Problème :** Le Studio Preview utilise un aspect ratio dynamique mais avec une valeur par défaut `16 / 9`.

**Preuve :** `student_challenge_video_editor_screen.dart` :
```dart
AspectRatio(
  aspectRatio: _aspectRatio ?? 16 / 9,
  child: AcademiaPlaybackView(...),
)
```

**Conséquence :** Si les métadonnées ne sont pas disponibles, l'aspect ratio par défaut `16 / 9` est utilisé, ce qui peut causer un débordement pour les vidéos verticales.

### 4. Rotation vidéo non prise en compte

**Problème :** La rotation vidéo n'est pas prise en compte dans le calcul de l'aspect ratio.

**Preuve :** `academia_playback_view.dart` :
```dart
final width = metadata['width'];
final height = metadata['height'];
if (width != null && height != null) {
  setState(() {
    _aspectRatio = width / height;
  });
}
```

**Conséquence :** Si une vidéo est enregistrée en portrait mais stockée en paysage avec une rotation metadata, l'aspect ratio calculé sera incorrect.

---

## SOLUTIONS POTENTIELLES (NON IMPLÉMENTÉES)

**Note :** Ce document est un audit factuel. Aucune recommandation n'est fournie conformément à la directive de la mission.

---

## TABLEAU RÉCAPITULATIF

| Écran | Aspect Ratio attendu | Aspect Ratio réel | Mode de rendu | Problème |
|-------|---------------------|-------------------|---------------|----------|
| Feed | 16:9 (forcé) | Variable (dépend vidéo) | AspectRatio widget | ✅ Débordement possible |
| Studio Preview | Variable (calculé) | Variable (calculé) | AspectRatio widget | ⚠️ Débordement si métadonnées manquantes |
| Challenge Preview | 16:9 (forcé) | Variable (dépend vidéo) | AspectRatio widget | ✅ Débordement possible |
| Lecture vidéo | Variable (calculé) | Variable (calculé) | AspectRatio widget | ⚠️ Débordement si métadonnées manquantes |

---

**Statut :** ✅ TERMINÉ
