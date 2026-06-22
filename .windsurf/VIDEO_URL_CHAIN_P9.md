# AUDIT P9 – VALIDATION DE L'URL EFFECTIVEMENT AFFICHÉE

**Date :** 19 Juin 2026  
**Objectif :** Tracer la chaîne complète de l'URL de la sélection jusqu'à ExoPlayer pour identifier où la valeur devient incorrecte ou vide

---

## 1. INSTRUMENTATION AJOUTÉE

### 1.1 student_challenge_video_editor_screen.dart

#### Dans _pickVideo() (ligne 503)

```dart
debugPrint('[P9_PICK] _localVideoPath=$filePath');
```

**Objectif :** Confirmer le chemin du fichier local immédiatement après sélection.

#### Dans build() (ligne 5377)

```dart
debugPrint('[P9_BUILD_EDITOR] local=$_localVideoPath effective=$effectivePreviewUrl uploaded=$_uploadedUrl');
```

**Objectif :** Confirmer les 3 variables d'état vidéo et l'URL effective utilisée pour la preview.

---

### 1.2 academia_playback_engine.dart

#### Dans view() (ligne 26)

```dart
debugPrint('[P9_ENGINE] url=$url');
```

**Objectif :** Confirmer l'URL reçue par le moteur de lecture.

---

### 1.3 academia_playback_view.dart

#### Dans initState() (ligne 94)

```dart
debugPrint('[P9_VIEW] widget.url=${widget.url}');
```

**Objectif :** Confirmer l'URL reçue par le widget de vue.

---

### 1.4 AcademiaAndroidVideoView.kt

#### Dans init() (ligne 111)

```kotlin
Log.e("P9_NATIVE", "INIT_URL=$url")
```

**Objectif :** Confirmer l'URL reçue depuis les creationParams.

#### Après currentUrl = url (ligne 168)

```kotlin
Log.e("P9_NATIVE", "CURRENT_URL=$currentUrl")
```

**Objectif :** Confirmer l'URL stockée dans la variable ExoPlayer.

---

## 2. CHAÎNE COMPLÈTE DE L'URL

```
1. _pickVideo()
   ↓
   [P9_PICK] _localVideoPath=/data/user/0/.../cache/video.mp4
   ↓
2. build()
   ↓
   [P9_BUILD_EDITOR] local=/data/.../cache/video.mp4 effective=file:///data/.../cache/video.mp4 uploaded=null
   ↓
3. AcademiaPlaybackEngine.view(url: previewUrl)
   ↓
   [P9_ENGINE] url=file:///data/.../cache/video.mp4
   ↓
4. AcademiaPlaybackView(widget.url: previewUrl)
   ↓
   [P9_VIEW] widget.url=file:///data/.../cache/video.mp4
   ↓
5. AndroidView(creationParams: {'url': previewUrl})
   ↓
6. AcademiaAndroidVideoView.init(creationParams)
   ↓
   [P9_NATIVE] INIT_URL=file:///data/.../cache/video.mp4
   ↓
7. currentUrl = url
   ↓
   [P9_NATIVE] CURRENT_URL=file:///data/.../cache/video.mp4
   ↓
8. player.setMediaItem(MediaItem.fromUri(currentUrl))
```

---

## 3. POINTS DE CONTRÔLE

### Point 1 : Sélection galerie/caméra
**Log :** `[P9_PICK] _localVideoPath=...`
**Attendu :** Chemin absolu du fichier local
**Exemple :** `/data/user/0/com.academia.nexiomgroup.app/cache/IMG_20240619_123456.mp4`

### Point 2 : Construction preview editor
**Log :** `[P9_BUILD_EDITOR] local=... effective=... uploaded=...`
**Attendu :**
- `local` = chemin du fichier local
- `effective` = `file://` + chemin local (si local existe) OU `uploaded` (si upload terminé)
- `uploaded` = null (avant upload) OU URL distante (après upload)

### Point 3 : Moteur de lecture
**Log :** `[P9_ENGINE] url=...`
**Attendu :** Même valeur que `effectivePreviewUrl`

### Point 4 : Widget de vue
**Log :** `[P9_VIEW] widget.url=...`
**Attendu :** Même valeur que `effectivePreviewUrl`

### Point 5 : PlatformView native
**Log :** `[P9_NATIVE] INIT_URL=...`
**Attendu :** Même valeur que `effectivePreviewUrl`

### Point 6 : Variable ExoPlayer
**Log :** `[P9_NATIVE] CURRENT_URL=...`
**Attendu :** Même valeur que `INIT_URL`

---

## 4. SCÉNARIOS ATTENDUS

### Scénario A : Vidéo locale avant upload
```
[P9_PICK] _localVideoPath=/data/.../cache/video.mp4
[P9_BUILD_EDITOR] local=/data/.../cache/video.mp4 effective=file:///data/.../cache/video.mp4 uploaded=null
[P9_ENGINE] url=file:///data/.../cache/video.mp4
[P9_VIEW] widget.url=file:///data/.../cache/video.mp4
[P9_NATIVE] INIT_URL=file:///data/.../cache/video.mp4
[P9_NATIVE] CURRENT_URL=file:///data/.../cache/video.mp4
```

### Scénario B : Vidéo distante après upload
```
[P9_BUILD_EDITOR] local=/data/.../cache/video.mp4 effective=https://storage.../video.mp4 uploaded=https://storage.../video.mp4
[P9_ENGINE] url=https://storage.../video.mp4
[P9_VIEW] widget.url=https://storage.../video.mp4
[P9_NATIVE] INIT_URL=https://storage.../video.mp4
[P9_NATIVE] CURRENT_URL=https://storage.../video.mp4
```

---

## 5. INDICATEURS D'ERREUR

### Erreur 1 : URL vide à un maillon
**Symptôme :** Un log montre `url=` ou `url=null`
**Cause possible :** Variable non initialisée ou perdue lors du setState

### Erreur 2 : URL incorrecte (mauvais format)
**Symptôme :** URL sans préfixe `file://` ou `https://`
**Cause possible :** Uri.file() non appelé ou UrlNormalizer échoue

### Erreur 3 : URL différente entre maillons
**Symptôme :** Les logs montrent des valeurs différentes
**Cause possible :** Variable modifiée entre les appels ou mauvaise variable passée

### Erreur 4 : URL locale mais ExoPlayer ne la reçoit pas
**Symptôme :** `[P9_NATIVE] INIT_URL=` vide ou null
**Cause possible :** AndroidView non créée ou creationParams mal passés

---

## 6. INSTRUCTIONS POUR TEST

1. **Compiler l'APK** avec les nouvelles instrumentations
2. **Installer sur device**
3. **Ouvrir logcat** avec filtre : `adb logcat | grep -E "P9_|P8_|P6_"`
4. **Sélectionner une vidéo locale** (galerie ou caméra)
5. **Observer la chaîne de logs** :
   - `[P9_PICK]` → Fichier sélectionné
   - `[P9_BUILD_EDITOR]` → Variables d'état
   - `[P9_ENGINE]` → URL vers moteur
   - `[P9_VIEW]` → URL vers widget
   - `[P9_NATIVE] INIT_URL` → URL vers native
   - `[P9_NATIVE] CURRENT_URL` → URL ExoPlayer
6. **Identifier le premier maillon** où l'URL devient incorrecte ou vide

---

## 7. RÉSULTATS ATTENDUS

### Si la chaîne est intacte :
Tous les logs montrent la même URL (avec transformations attendues : chemin → file://chemin).

### Si un maillon est cassé :
Le log correspondant montre une valeur différente, vide ou null.

**Exemple de problème détectable :**
```
[P9_PICK] _localVideoPath=/data/.../cache/video.mp4
[P9_BUILD_EDITOR] local=/data/.../cache/video.mp4 effective=file:///data/.../cache/video.mp4 uploaded=null
[P9_ENGINE] url=file:///data/.../cache/video.mp4
[P9_VIEW] widget.url=file:///data/.../cache/video.mp4
[P9_NATIVE] INIT_URL=                    ← VIDE : problème AndroidView
```

---

## 8. PROCHAINES ÉTAPES

1. **Compiler et tester** pour obtenir les logs réels
2. **Analyser la chaîne** pour identifier le maillon cassé
3. **Corriger le maillon** identifié
4. **Retester** pour confirmer la résolution
5. **Retirer les logs P9** une fois le problème résolu

---

## 9. MODIFICATIONS CODE

### student_challenge_video_editor_screen.dart
- **Ligne 503** : Ajout `debugPrint('[P9_PICK] ...')`
- **Ligne 5377** : Ajout `debugPrint('[P9_BUILD_EDITOR] ...')`

### academia_playback_engine.dart
- **Ligne 2** : Ajout `import 'package:flutter/foundation.dart'`
- **Ligne 26** : Ajout `debugPrint('[P9_ENGINE] ...')`

### academia_playback_view.dart
- **Ligne 94** : Ajout `debugPrint('[P9_VIEW] ...')`

### AcademiaAndroidVideoView.kt
- **Ligne 111** : Ajout `Log.e("P9_NATIVE", "INIT_URL=$url")`
- **Ligne 168** : Ajout `Log.e("P9_NATIVE", "CURRENT_URL=$currentUrl")`

---

**Statut :** Instrumentation ajoutée, en attente de test runtime
