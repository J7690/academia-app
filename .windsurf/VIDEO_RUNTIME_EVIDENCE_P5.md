# Audit P5 — Runtime Evidence (Preuves réelles sur appareil)

**Date :** 19 Juin 2026  
**Objectif :** Produire des preuves runtime observées pendant l'exécution réelle de l'application sur appareil Android  
**APK instrumenté :** `academia_app/build/app/outputs/flutter-apk/app-debug.apk`

---

## INSTRUMENTATION AJOUTÉE

### A. État des contrôleurs

**Logs ajoutés dans `student_challenges_tab.dart` :**

```dart
// T0 = Feed ouvert
[RUNTIME T0] Feed ouvert - videos={count}

// T1 = Clic sur +
[RUNTIME T1] Clic sur + - _controllers size={count}

// T2 = Ouverture CameraCapture
[RUNTIME T2] Ouverture CameraCapture - _controllers size={count}

// T3 = Retour Galerie
[RUNTIME T3] Retour Galerie - segments={count} - _controllers size={count}

// T4 = Vidéo sélectionnée
[RUNTIME T4] Vidéo sélectionnée - _controllers size={count}

// T5 = Ouverture Editor
[RUNTIME T5] Ouverture Editor - _controllers size={count}
[RUNTIME MEMORY] Before opening editor - controllers={count}

// Pause des contrôleurs
[RUNTIME] _pauseAllControllers - _controllers size={count}
[RUNTIME] _pauseAllControllers - paused={count}
```

**Fichier :** `student_challenges_tab.dart`  
**Lignes :** 1091, 1707, 1712, 1722, 1731, 1733, 1736, 1779-1787

---

### B. Cycle de vie

**Logs ajoutés pour initState/didUpdateWidget/dispose :**

```dart
// _ChallengeVideosFeed
[RUNTIME LIFECYCLE] _ChallengeVideosFeed initState
[RUNTIME LIFECYCLE] _ChallengeVideosFeed dispose - _controllers size={count}

// _ChallengeVideoItem
[RUNTIME LIFECYCLE] _ChallengeVideoItem initState - label={label} isActive={bool}
[RUNTIME LIFECYCLE] _ChallengeVideoItem didUpdateWidget - label={label} isActive: {old} -> {new}

// AcademiaPlaybackView
[RUNTIME LIFECYCLE] AcademiaPlaybackView initState - url={url} deferInitialization={bool}
```

**Fichiers :** `student_challenges_tab.dart` (lignes 1076, 1102, 1884, 1893), `academia_playback_view.dart` (ligne 93)

---

### C. Players natifs

**Logs ajoutés dans `academia_playback_view.dart` (Flutter) :**

```dart
[RUNTIME PLAYER] Using native Android view - url={url}
[RUNTIME PLAYER] Using Flutter video_player - url={url} isLocalFileUri={bool}
[RUNTIME PLAYER] Creating VideoPlayerController - url={url}
[RUNTIME PLAYER] Calling initialize() - START
[RUNTIME PLAYER] Calling initialize() - END - duration={ms}ms
[RUNTIME PLAYER] Initialized - isWeb={bool} duration={duration} aspectRatio={ratio} muted={bool} looping={bool}
[RUNTIME PLAYER] First frame visible - isWeb={bool} position={position} duration={duration}
[RUNTIME PLAYER] autoplay play() requested - isWeb={bool}
[RUNTIME PLAYER] Completed - isWeb={bool} position={position} duration={duration}
[RUNTIME PLAYER] init error={error} url={url}
```

**Fichier :** `academia_playback_view.dart`  
**Lignes :** 154, 163, 171, 181-185, 191-194, 204, 226, 216-219, 237

---

**Logs ajoutés dans `AcademiaAndroidVideoView.kt` (Android natif) :**

```kotlin
[RUNTIME NATIVE] AcademiaAndroidVideoView init - url={url} autoplay={bool} loop={bool} muted={bool}
[RUNTIME NATIVE] Creating ExoPlayer
[RUNTIME NATIVE] Calling setMediaItem - url={url}
[RUNTIME NATIVE] Calling prepare() - START
[RUNTIME NATIVE] Calling prepare() - END - duration={ms}ms
[RUNTIME NATIVE] MethodChannel: play
[RUNTIME NATIVE] MethodChannel: pause
[RUNTIME NATIVE] MethodChannel: toggle
[RUNTIME NATIVE] MethodChannel: setUrl - url={url} autoplay={bool}
[RUNTIME NATIVE] Calling prepare() after setUrl - START
[RUNTIME NATIVE] Calling prepare() after setUrl - END - duration={ms}ms
[RUNTIME NATIVE] MethodChannel: stop
[RUNTIME NATIVE] AcademiaAndroidVideoView dispose - releasing ExoPlayer
```

**Fichier :** `AcademiaAndroidVideoView.kt`  
**Lignes :** 109, 129, 155, 157, 161, 168, 173, 178, 193, 198, 202, 218, 231

---

### D. Audio

**Logs ajoutés pour les contrôles audio :**

```dart
// Dans _pauseAllControllers()
[RUNTIME] _pauseAllControllers - _controllers size={count}
[RUNTIME] _pauseAllControllers - paused={count}
```

**Fichier :** `student_challenges_tab.dart`  
**Lignes :** 1779-1787

---

### E. Mémoire

**Logs ajoutés pour l'état mémoire :**

```dart
[RUNTIME MEMORY] Before opening editor - controllers={count}
```

**Fichier :** `student_challenges_tab.dart`  
**Ligne :** 1736

**Note :** Une estimation mémoire basique est fournie (nombre de contrôleurs). Pour une mesure plus précise, il faudrait ajouter `dart:developer` et `Service.getInfo()`.

---

### F. Preload

**Logs ajoutés pour le preload des vidéos :**

```dart
[RUNTIME PRELOAD] Page changed: {old} -> {new} - _controllers size={count}
[RUNTIME PRELOAD]   Paused controller at index {index}
[RUNTIME PRELOAD]   Playing controller at index {index}
[RUNTIME PRELOAD]   No controller ready at index {index} (attached={bool})
[RUNTIME PRELOAD]   Cleaned up controllers: {list} - new size={count}
```

**Fichier :** `student_challenges_tab.dart`  
**Lignes :** 1139, 1152, 1172, 1174, 1186

---

## INSTRUCTIONS POUR COLLECTER LES LOGS

### 1. Installer l'APK

**Chemin :** `academia_app/build/app/outputs/flutter-apk/app-debug.apk`

Installer sur appareil Android via :
```bash
adb install academia_app/build/app/outputs/flutter-apk/app-debug.apk
```

### 2. Activer les logs

```bash
adb logcat -c  # Clear logs
adb logcat | grep -E "RUNTIME|VIDEO_ITEM|FEED" > runtime_logs.txt
```

### 3. Exécuter le parcours de test

1. Ouvrir l'application
2. Naviguer vers l'onglet Challenge
3. Attendre que le feed se charge (T0)
4. Cliquer sur le bouton + (T1)
5. Capturer une vidéo ou sélectionner depuis la galerie
6. Attendre l'ouverture de CameraCapture (T2)
7. Sélectionner une vidéo depuis la galerie
8. Attendre le retour (T3)
9. Sélectionner la vidéo (T4)
10. Attendre l'ouverture de l'éditeur (T5)
11. Observer l'écran noir (T6)
12. Attendre la première frame visible (T7)
13. Fermer l'éditeur (T8)

### 4. Arrêter la capture des logs

```bash
Ctrl+C  # Arrêter la capture
```

### 5. Analyser les logs

Extraire les lignes pertinentes :
```bash
grep "RUNTIME" runtime_logs.txt > runtime_filtered.txt
```

---

## TEMPLATE D'ANALYSE DES LOGS

### A. État des contrôleurs

| Moment | _controllers size | paused | Interprétation |
|--------|-------------------|--------|---------------|
| T0 (Feed ouvert) | ? | - | Nombre de contrôleurs au démarrage |
| T1 (Clic sur +) | ? | ? | Contrôleurs avant pause |
| T2 (CameraCapture) | ? | ? | Contrôleurs pendant capture |
| T3 (Retour Galerie) | ? | ? | Contrôleurs après sélection |
| T4 (Vidéo sélectionnée) | ? | ? | Contrôleurs avant éditeur |
| T5 (Ouverture Editor) | ? | ? | Contrôleurs à l'ouverture éditeur |
| T6 (Écran noir) | ? | ? | Contrôleurs pendant écran noir |
| T7 (Première frame) | ? | ? | Contrôleurs après première frame |
| T8 (Fermeture Editor) | ? | ? | Contrôleurs après fermeture |

---

### B. Cycle de vie

| Widget | initState | didUpdateWidget | dispose | Total appels |
|--------|-----------|-----------------|---------|--------------|
| _ChallengeVideosFeed | ? | ? | ? | ? |
| _ChallengeVideoItem | ? | ? | ? | ? |
| AcademiaPlaybackView | ? | ? | ? | ? |

---

### C. Players natifs

**Flutter (VideoPlayerController) :**

| Étape | Durée initialize() | Durée totale | Interprétation |
|-------|-------------------|-------------|---------------|
| Création controller | - | - | - |
| initialize() START | - | - | - |
| initialize() END | ? ms | - | Temps d'initialisation |
| First frame visible | - | ? ms | Temps total avant première frame |

**Android (ExoPlayer) :**

| Étape | Durée prepare() | Durée totale | Interprétation |
|-------|----------------|-------------|---------------|
| Création ExoPlayer | - | - | - |
| setMediaItem | - | - | - |
| prepare() START | - | - | - |
| prepare() END | ? ms | - | Temps de préparation |
| First frame visible | - | ? ms | Temps total avant première frame |

---

### D. Audio

| Moment | paused count | Contrôleurs actifs | Interprétation |
|--------|-------------|-------------------|---------------|
| T1 (Clic sur +) | ? | ? | - |
| T2 (CameraCapture) | ? | ? | - |
| T5 (Ouverture Editor) | ? | ? | - |

---

### E. Mémoire

| Moment | controllers count | Estimation mémoire | Interprétation |
|--------|------------------|-------------------|---------------|
| T5 (Ouverture Editor) | ? | ? | - |

---

### F. Preload

| Action | _controllers size | Cleaned up | Interprétation |
|--------|-------------------|------------|---------------|
| Page change | ? | ? | - |
| Swipe | ? | ? | - |

---

## QUESTION PRINCIPALE

### Au moment exact où l'utilisateur observe l'écran noir (T6) :

**À remplir après collecte des logs :**

- **Combien de players existent :** ?
- **Combien de contrôleurs existent :** ?
- **Combien sont actifs :** ?
- **Combien sont simplement conservés en mémoire :** ?

---

## CONCLUSION

**À remplir après collecte et analyse des logs :**

Basé sur les mesures réelles observées sur appareil, le composant responsable du délai est :

1. **[Composant]** - [Niveau de confiance %]
   - Preuve : [Logs observés]
   - Fichier : [Fichier]
   - Ligne : [Ligne]

2. **[Composant]** - [Niveau de confiance %]
   - Preuve : [Logs observés]
   - Fichier : [Fichier]
   - Ligne : [Ligne]

3. **[Composant]** - [Niveau de confiance %]
   - Preuve : [Logs observés]
   - Fichier : [Fichier]
   - Ligne : [Ligne]

---

## NOTES

- L'APK instrumenté est disponible : `academia_app/build/app/outputs/flutter-apk/app-debug.apk`
- Les logs sont filtrés avec le préfixe `[RUNTIME]` pour faciliter l'analyse
- Les durées sont mesurées en millisecondes pour les opérations critiques (initialize(), prepare())
- Le nombre de contrôleurs est journalisé à chaque étape clé du parcours
- Le cycle de vie des widgets est tracé pour identifier les reconstructions
- Les players natifs (ExoPlayer) sont instrumentés pour mesurer les durées réelles
