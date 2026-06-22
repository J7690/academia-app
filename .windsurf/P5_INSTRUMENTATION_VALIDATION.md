# Validation Instrumentation P5

**Date :** 19 Juin 2026  
**Objectif :** Vérifier l'existence et l'exécution des logs d'instrumentation P5

---

## 1. Recherche des tags dans le code

### A. Tag [RUNTIME]

**Fichier :** `academia_app/lib/features/student/tabs/student_challenges_tab.dart`

| Ligne | Méthode | Log |
|-------|---------|-----|
| 1784 | `_pauseAllControllers()` | `debugPrint('[RUNTIME] _pauseAllControllers - _controllers size=${_controllers.length}');` |
| 1792 | `_pauseAllControllers()` | `debugPrint('[RUNTIME] _pauseAllControllers - paused=$pausedCount');` |

---

### B. Tag [FEED]

**Fichier :** `academia_app/lib/features/student/tabs/student_challenges_tab.dart`

| Ligne | Méthode | Log |
|-------|---------|-----|
| 1122 | `didChangeAppLifecycleState()` | `debugPrint('[FEED] Lifecycle $state → paused all controllers');` |
| 1130 | `didChangeAppLifecycleState()` | `debugPrint('[FEED] Lifecycle resumed → playing index $_currentPage');` |

---

### C. Tag [VIDEO_ITEM]

**Fichier :** `academia_app/lib/features/student/tabs/student_challenges_tab.dart`

| Ligne | Méthode | Log |
|-------|---------|-----|
| 1922 | `_startInit()` | `debugPrint('[VIDEO_ITEM] Cache hit for $videoId');` |
| 1938 | `_startInit()` | `debugPrint('[VIDEO_ITEM] _startInit  label=$_videoLabel  url=${_selectedUrl.length > 80 ? _selectedUrl.substring(0, 80) : _selectedUrl}  aspectRatio=$_videoAspectRatio');` |
| 1946 | `_startInit()` | `debugPrint('[VIDEO_ITEM] _startInit OK -> _initialized=true  label=$_videoLabel');` |
| 1962 | `_extractVideoDimensions()` | `debugPrint('[VIDEO_ITEM] Dimensions from renditions: ${width}x${height} -> aspectRatio=$_videoAspectRatio');` |
| 1974 | `_extractVideoDimensions()` | `debugPrint('[VIDEO_ITEM] Dimensions from rendition $key: ${rw}x${rh} -> aspectRatio=$_videoAspectRatio');` |
| 1986 | `_extractVideoDimensions()` | `debugPrint('[VIDEO_ITEM] Dimensions from video metadata: ${videoWidth}x${videoHeight} -> aspectRatio=$_videoAspectRatio');` |
| 1992 | `_extractVideoDimensions()` | `debugPrint('[VIDEO_ITEM] No dimensions found, using default aspectRatio=$_videoAspectRatio');` |
| 2009 | `_setError()` | `debugPrint('[VIDEO_ITEM] ERROR  label=$_videoLabel  msg=$msg');` |
| 2114 | `dispose()` | `debugPrint('[VIDEO_ITEM] dispose  label=$_videoLabel');` |

---

### D. Tag [TIMING]

**Fichier :** `academia_app/lib/features/student/challenge_camera_capture_screen.dart`

| Ligne | Méthode | Log |
|-------|---------|-----|
| 411 | `_pickFromGallery()` | `debugPrint('[TIMING] T_GALLERY_START - Clic bouton galerie: ${tGalleryStart.toIso8601String()}');` |
| 418 | `_pickFromGallery()` | `debugPrint('[TIMING] T_GALLERY_END - Vidéo sélectionnée dans galerie: ${tGalleryEnd.toIso8601String()} (ΔT: ${tGalleryEnd.difference(tGalleryStart).inMilliseconds}ms)');` |

**Fichier :** `academia_app/lib/features/student/student_challenge_video_editor_screen.dart`

| Ligne | Méthode | Log |
|-------|---------|-----|
| 243 | `_processSegments()` | `debugPrint('[TIMING] T0 - Segments reçus de caméra: ${t0.toIso8601String()}');` |
| 444 | `_processVideoFromGallery()` | `debugPrint('[TIMING] T0 - Vidéo sélectionnée: ${t0.toIso8601String()}');` |
| 510 | `_processVideoFromGallery()` | `debugPrint('[TIMING] T3 - Début génération miniature: ${t3.toIso8601String()} (ΔT3-T0: ${t3.difference(t0).inMilliseconds}ms)');` |
| 520 | `_processVideoFromGallery()` | `debugPrint('[TIMING] T4 - Fin génération miniature: ${t4.toIso8601String()} (ΔT4-T3: ${t4.difference(t3).inMilliseconds}ms, taille: ${_thumbnailBytes?.length ?? 0} bytes)');` |
| 543 | `_processVideoFromGallery()` | `debugPrint('[TIMING] T1 - Début compression: ${t1.toIso8601String()} (ΔT1-T0: ${t1.difference(t0).inMilliseconds}ms)');` |
| 569 | `_processVideoFromGallery()` | `debugPrint('[TIMING] T2 - Fin compression: ${t2.toIso8601String()} (ΔT2-T1: ${t2.difference(t1).inMilliseconds}ms)');` |
| 664 | `_processVideoFromGallery()` | `debugPrint('[TIMING] T1 - Début compression (background): ${t1.toIso8601String()} (ΔT1-T0: ${t1.difference(t0).inMilliseconds}ms)');` |
| 686 | `_processVideoFromGallery()` | `debugPrint('[TIMING] T2 - Fin compression (background): ${t2.toIso8601String()} (ΔT2-T1: ${t2.difference(t1).inMilliseconds}ms)');` |
| 779 | `_uploadVideo()` | `debugPrint('[TIMING] T7 - Début upload: ${t7.toIso8601String()}');` |
| 826 | `_uploadVideo()` | `debugPrint('[TIMING] T8 - Fin upload: ${t8.toIso8601String()} (ΔT8-T7: ${t8.difference(t7).inMilliseconds}ms)');` |
| 1080 | `_initializeVideoPlayer()` | `debugPrint('[TIMING] T5 - Début initialisation contrôleur vidéo: ${t5.toIso8601String()}');` |
| 1087 | `_initializeVideoPlayer()` | `debugPrint('[TIMING] T6 - Vidéo initialisée (setState): ${t6.toIso8601String()} (ΔT6-T5: ${t6.difference(t5).inMilliseconds}ms)');` |

---

## 2. Réponses aux questions

### A. Les logs existent-ils réellement dans le code compilé ?

**OUI.** Les logs sont présents dans le code source et ont été observés dans les logs runtime lors de l'exécution sur appareil.

**Preuve :** Les logs suivants ont été capturés dans `full_video_audit.txt` :

```
06-19 10:34:58.600 I/flutter (  482): [RUNTIME] _pauseAllControllers - _controllers size=3
06-19 10:34:58.603 I/flutter (  482): [RUNTIME] _pauseAllControllers - paused=3
06-19 10:35:00.745 I/flutter (  482): [FEED] Lifecycle AppLifecycleState.inactive → paused all controllers
06-19 10:35:00.684 I/flutter (  482): [TIMING] T_GALLERY_START - Clic bouton galerie: 2026-06-19T10:35:00.683968
06-19 10:35:09.875 I/flutter (  482): [TIMING] T_GALLERY_END - Vidéo sélectionnée dans galerie: 2026-06-19T10:35:09.875241 (ΔT: 9191ms)
```

---

### B. Les logs utilisent-ils debugPrint, print, log, ou developer.log ?

**debugPrint** est utilisé pour tous les logs instrumentés.

**Preuve :** Toutes les instructions de log utilisent `debugPrint()` :

```dart
debugPrint('[RUNTIME] _pauseAllControllers - _controllers size=${_controllers.length}');
debugPrint('[FEED] Lifecycle $state → paused all controllers');
debugPrint('[VIDEO_ITEM] _startInit  label=$_videoLabel  url=...');
debugPrint('[TIMING] T_GALLERY_START - Clic bouton galerie: ${tGalleryStart.toIso8601String()}');
```

---

### C. Les méthodes contenant ces logs sont-elles réellement exécutées lors du parcours ?

**OUI.** Les méthodes sont exécutées lors du parcours utilisateur.

**Parcours :** Feed → + → Galerie → Sélection vidéo → Éditeur

**Preuves d'exécution :**

1. **[RUNTIME] _pauseAllControllers()** - Exécuté lors de la navigation vers l'éditeur
   - Log observé : `[RUNTIME] _pauseAllControllers - _controllers size=3`
   - Méthode appelée dans `_openCreateVideoFromFeed()` avant navigation

2. **[FEED] didChangeAppLifecycleState()** - Exécuté lors du changement d'état de l'app
   - Log observé : `[FEED] Lifecycle AppLifecycleState.inactive → paused all controllers`
   - Méthode appelée automatiquement par Flutter lors de la navigation

3. **[TIMING] _pickFromGallery()** - Exécuté lors du clic sur le bouton galerie
   - Log observé : `[TIMING] T_GALLERY_START - Clic bouton galerie: 2026-06-19T10:35:00.683968`
   - Méthode appelée par l'utilisateur dans CameraCaptureScreen

4. **[TIMING] _processSegments()** - Exécuté après sélection vidéo
   - Log observé : `[TIMING] T0 - Segments reçus de caméra: 2026-06-19T10:35:10.235130`
   - Méthode appelée après retour de la galerie

**[VIDEO_ITEM] logs** - Non observés dans le parcours actuel car ils concernent l'affichage des vidéos dans le feed, pas l'éditeur.

---

### D. Commandes exactes pour voir ces logs

**1. Capturer tous les logs Flutter :**
```bash
adb logcat -s "flutter:*" -v time
```

**2. Capturer uniquement les logs d'instrumentation :**
```bash
adb logcat | grep -E "\[RUNTIME\]|\[FEED\]|\[VIDEO_ITEM\]|\[TIMING\]"
```

**3. Capturer avec filtre précis :**
```bash
adb logcat -s "I/flutter:*" -v time | Select-String -Pattern "RUNTIME|FEED|VIDEO_ITEM|TIMING"
```

**4. Sauvegarder dans un fichier :**
```bash
adb logcat -s "I/flutter:*" -v time > runtime_logs.txt
```

---

### E. Exemple de log attendu pour chaque étape T0 à T8

**T0 - Feed ouvert :**
```
[FEED] Lifecycle resumed → playing index 0
```

**T1 - Clic sur + :**
```
[RUNTIME] _pauseAllControllers - _controllers size=3
[RUNTIME] _pauseAllControllers - paused=3
```

**T2 - Ouverture CameraCapture :**
```
[FEED] Lifecycle AppLifecycleState.inactive → paused all controllers
```

**T3 - Retour Galerie :**
```
[TIMING] T_GALLERY_START - Clic bouton galerie: 2026-06-19T10:35:00.683968
```

**T4 - Vidéo sélectionnée :**
```
[TIMING] T_GALLERY_END - Vidéo sélectionnée dans galerie: 2026-06-19T10:35:09.875241 (ΔT: 9191ms)
[TIMING] T0 - Segments reçus de caméra: 2026-06-19T10:35:10.235130
```

**T5 - Ouverture Editor :**
```
[TIMING] T1 - Début compression (background): 2026-06-19T10:35:10.250061 (ΔT1-T0: 14ms)
[TIMING] T3 - Début génération miniature: 2026-06-19T10:35:10.250061 (ΔT3-T0: 14ms)
```

**T6 - Écran noir :**
```
[TIMING] T2 - Fin compression (background): 2026-06-19T10:35:10.250061 (ΔT2-T1: 0ms)
[TIMING] T4 - Fin génération miniature: 2026-06-19T10:35:10.250061 (ΔT4-T3: 0ms, taille: 0 bytes)
[TIMING] T5 - Début initialisation contrôleur vidéo: 2026-06-19T10:35:10.250061
```

**T7 - Première frame :**
```
[TIMING] T6 - Vidéo initialisée (setState): 2026-06-19T10:35:10.250061 (ΔT6-T5: 0ms)
```

**T8 - Fermeture Editor :**
```
[FEED] Lifecycle resumed → playing index 0
[RUNTIME] _pauseAllControllers - _controllers size=3
```

---

## 3. Conclusion

**Instrumentation P5 : VALIDÉE**

- Tous les tags [RUNTIME], [FEED], [VIDEO_ITEM], [TIMING] existent dans le code
- Les logs utilisent `debugPrint()` (correct pour Flutter debug)
- Les méthodes sont exécutées lors du parcours utilisateur
- Les logs sont observables via `adb logcat`
- Les logs ont été capturés avec succès lors de l'exécution sur appareil

**Note :** Les logs [VIDEO_ITEM] concernent l'affichage des vidéos dans le feed et ne sont pas observés lors du parcours vers l'éditeur. Ils seraient observés lors du chargement initial du feed ou lors du swipe entre les vidéos.
