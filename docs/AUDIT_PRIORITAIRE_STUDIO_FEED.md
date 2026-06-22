# AUDIT PRIORITAIRE - STUDIO VIDEO / FEED VIDEO

**Date :** 19 Juin 2026
**Objectif :** Identifier pourquoi les vidéos longues restent bloquées après compression et pourquoi l'audio du feed continue à jouer

---

## PARTIE A - VIDEOS LONGUES BLOQUEES

### Flux analysé

Video Picker → Compression → Fin compression → Navigation vers écran Description/Hashtags/Couverture

### Problème identifié

**Fichier :** `lib/features/student/student_challenge_video_editor_screen.dart`
**Méthode :** `_compressAndWatermarkInBackground()`

#### Blocage critique

```dart
// Ligne 776-787
if (mounted) {
  setState(() {
    _isCompressing = false;
    _videoBytes = finalBytes;
    _localVideoPath = watermarkedPath;
    if (info.duration != null) _videoDurationMs = info.duration!.toInt();
  });
}
final exitTime = DateTime.now();
final duration = exitTime.difference(enterTime).inMilliseconds;
debugPrint('[P6_EXIT] _compressAndWatermarkInBackground duration=${duration}ms');
return;  // ⚠️ RETURN PRÉMATURÉ BLOQUE TOUT
```

**Le problème :**
- Le `return` à la ligne 787 est exécuté **après** le setState
- Mais ce return empêche l'exécution du code qui suit
- Le setState s'exécute, mais le return prématuré empêche la navigation

#### Autre blocage

```dart
// Ligne 620-621
debugPrint('[P6_EXIT] _compressAndWatermarkInBackground duration=${duration}ms');
return;  // ⚠️ RETURN PRÉMATURÉ

setState(() {  // JAMAIS EXÉCUTÉ
  _isCompressing = false;
  _videoBytes = finalBytes;
  _fileName = originalName;
  _mimeType = ext;
  _uploadedUrl = null;
  _videoInitialized = false;
  _localVideoPath = watermarkedPath;
  if (info.duration != null) _videoDurationMs = info.duration!.toInt();
});
```

**Le problème :**
- Le return est AVANT le setState
- Le setState est JAMAIS exécuté
- `_isCompressing` reste à `true`
- `_videoBytes` reste à `null`
- L'écran reste bloqué en état de compression

### Limite de taille

**Aucune limite de taille configurée dans Flutter**
- Aucun check de `maxFileSize` dans le code
- Aucune validation avant compression
- Aucune validation avant upload

**Limite Supabase Storage**
- Non vérifiée dans ce fichier
- Potentiellement 50MB ou 100MB par défaut

### Logs actuels

```
[P6_COMPRESSION] SKIPPED - uploading raw video
[P6_COMPRESSION] END duration=0ms
[P6_WATERMARK] START
[P6_WATERMARK] END duration=XXXms
[P6_EXIT] _compressAndWatermarkInBackground duration=XXXms
```

**Logs manquants :**
- Taille fichier original
- Taille fichier compressé
- Durée vidéo
- État avant navigation

### Correctif minimal

**Supprimer les returns prématurés dans `_compressAndWatermarkInBackground()`**

```dart
// Ligne 620-621 - SUPPRIMER LE RETURN
// debugPrint('[P6_EXIT] _compressAndWatermarkInBackground duration=${duration}ms');
// return;  // ← SUPPRIMER CETTE LIGNE

setState(() {
  _isCompressing = false;
  _videoBytes = finalBytes;
  _fileName = originalName;
  _mimeType = ext;
  _uploadedUrl = null;
  _videoInitialized = false;
  _localVideoPath = watermarkedPath;
  if (info.duration != null) _videoDurationMs = info.duration!.toInt();
});
```

```dart
// Ligne 787 - SUPPRIMER LE RETURN
// debugPrint('[P6_EXIT] _compressAndWatermarkInBackground duration=${duration}ms');
// return;  // ← SUPPRIMER CETTE LIGNE

// Le code après doit s'exécuter normalement
```

### Logs à ajouter

```dart
// Dans _compressAndWatermarkInBackground()
final originalSize = await File(sourcePath).length();
debugPrint('[P6_SIZE] Original: ${(originalSize / 1024 / 1024).toStringAsFixed(1)} MB');

final compressedSize = finalBytes.length;
debugPrint('[P6_SIZE] Compressed: ${(compressedSize / 1024 / 1024).toStringAsFixed(1)} MB');

if (info.duration != null) {
  debugPrint('[P6_DURATION] Video duration: ${info.duration!.inSeconds}s');
}

debugPrint('[P6_STATE] Before setState: _isCompressing=$_isCompressing, _videoBytes=${_videoBytes != null}');

setState(() {
  _isCompressing = false;
  _videoBytes = finalBytes;
  // ...
});

debugPrint('[P6_STATE] After setState: _isCompressing=$_isCompressing, _videoBytes=${_videoBytes != null}');
```

---

## PARTIE B - DOUBLE AUDIO FEED + STUDIO

### Scénario

Feed vidéo actif → Clic + → Sélection vidéo locale → Retour Studio

### Problème identifié

**Service VideoPlayerLifecycleService déjà implémenté**
- `pauseFeed()` appelé dans `StudentChallengeVideoEditorScreen.initState()`
- `resumeFeed()` appelé dans `StudentChallengeVideoEditorScreen.dispose()`

**Mais le problème persiste car :**

1. **Le feed n'est pas pausé lors de la sélection vidéo**
   - Quand l'utilisateur clique sur "+", le feed continue de jouer
   - La navigation vers `ChallengeCameraCaptureScreen` ne pause pas le feed
   - La sélection vidéo dans la galerie ne pause pas le feed

2. **Multiple ExoPlayers actifs**
   - Feed : N controllers actifs (préchargement N-3..N+3)
   - Studio : 0-1 controller actif (vidéo locale)
   - Total : N+1 controllers actifs simultanément

3. **Autoplay du feed**
   - Le feed a un autoplay automatique
   - Quand on retourne au feed, la vidéo reprend automatiquement
   - Le `resumeFeed()` dans dispose() peut entrer en conflit avec l'autoplay

### Appels play()/resume() identifiés

**Dans student_challenges_tab.dart :**
```dart
// Ligne 1171
newCtrl.play();  // Play automatique lors du changement de page

// Ligne 1129
currentCtrl.play();  // Play lors du resume de l'app
```

**Dans academia_playback_view.dart :**
```dart
// Ligne 319
debugPrint('[PLAYER_RESUMED] play called');
// _playExternal() appelé par AcademiaPlaybackController.play()
```

### Pile d'appels menant au play() parasite

```
1. User navigue Feed → Studio
2. StudentChallengeVideoEditorScreen.initState()
3. VideoPlayerLifecycleService().pauseFeed()  ← PAUSE OK
4. User selects local video
5. Video loads in Studio
6. User navigates Studio → Feed
7. StudentChallengeVideoEditorScreen.dispose()
8. VideoPlayerLifecycleService().resumeFeed()  ← RESUME OK
9. _ChallengeVideosFeed.didChangeAppLifecycleState()  ← RESUME AUTO
10. currentCtrl.play()  ← DOUBLE RESUME
```

### Composant responsable

**Fichier :** `lib/features/student/tabs/student_challenges_tab.dart`
**Méthode :** `didChangeAppLifecycleState()`

```dart
case AppLifecycleState.resumed:
  // App returning to foreground — resume only the active video
  if (_wasPlayingBeforeBackground) {
    final currentCtrl = _controllers[_currentPage];
    if (currentCtrl != null && currentCtrl.isAttached) {
      currentCtrl.play();  // ← CONFLIT AVEC resumeFeed()
      debugPrint('[FEED] Lifecycle resumed → playing index $_currentPage');
    }
    _wasPlayingBeforeBackground = false;
  }
  break;
```

### Correctif minimal

**1. Désactiver l'autoplay lors du retour du Studio**

```dart
// Dans StudentChallengeVideoEditorScreen.initState()
VideoPlayerLifecycleService().pauseFeed();
// Flag pour désactiver l'autoplay du feed
VideoPlayerLifecycleService().setFeedAutoplayEnabled(false);
```

```dart
// Dans StudentChallengeVideoEditorScreen.dispose()
VideoPlayerLifecycleService().resumeFeed();
// Réactiver l'autoplay du feed
VideoPlayerLifecycleService().setFeedAutoplayEnabled(true);
```

**2. Ajouter un flag dans VideoPlayerLifecycleService**

```dart
bool _feedAutoplayEnabled = true;

void setFeedAutoplayEnabled(bool enabled) {
  _feedAutoplayEnabled = enabled;
  debugPrint('[PLAYER_AUTOPLAY] Feed autoplay: $enabled');
}

bool get feedAutoplayEnabled => _feedAutoplayEnabled;
```

**3. Modifier didChangeAppLifecycleState pour respecter le flag**

```dart
case AppLifecycleState.resumed:
  if (_wasPlayingBeforeBackground && VideoPlayerLifecycleService().feedAutoplayEnabled) {
    final currentCtrl = _controllers[_currentPage];
    if (currentCtrl != null && currentCtrl.isAttached) {
      currentCtrl.play();
      debugPrint('[FEED] Lifecycle resumed → playing index $_currentPage');
    }
    _wasPlayingBeforeBackground = false;
  }
  break;
```

### Comparaison TikTok/Reels

**Comportement attendu :**
- 1 seul player actif à la fois
- Entrée Studio = arrêt complet du feed
- Lecture locale = contrôle play/pause
- Barre de progression fonctionnelle
- Retour Feed = reprise du feed uniquement

**Comportement actuel :**
- N+1 players actifs simultanément
- Entrée Studio = feed pausé MAIS autoplay réactive
- Lecture locale = OK
- Barre de progression = OK
- Retour Feed = double resume (resumeFeed + autoplay)

### Risques de régression

**Faible risque :**
- Le flag `feedAutoplayEnabled` n'affecte que le feed
- Le Studio n'est pas impacté
- L'autoplay normal du feed (swipe) n'est pas impacté

**Test à effectuer :**
1. Ouvrir le feed, laisser une vidéo jouer
2. Naviguer vers une autre app (background)
3. Revenir dans l'app (foreground)
4. Vérifier que la vidéo reprend normalement

---

## ACTIONS REQUISES

### PARTIE A
1. Supprimer les returns prématurés dans `_compressAndWatermarkInBackground()`
2. Ajouter logs taille/durée/état
3. Tester avec vidéos longues (>60s)

### PARTIE B
1. Ajouter flag `feedAutoplayEnabled` dans VideoPlayerLifecycleService
2. Appeler `setFeedAutoplayEnabled(false)` dans Studio.initState()
3. Appeler `setFeedAutoplayEnabled(true)` dans Studio.dispose()
4. Modifier didChangeAppLifecycleState pour respecter le flag
5. Tester le scénario Feed → Studio → Feed
