# Audit Statique Pipeline Vidéo - Écran Noir Preview

**Date :** 19 Juin 2026  
**Objectif :** Identifier la cause du délai/écran noir lors de l'affichage preview après sélection galerie  
**Appareil cible :** TECNO LD7

---

## ÉTAPE 1 : CARTOGRAPHIE COMPLÈTE DU FLUX

### Parcours Galerie → Preview (mode camera capture)

```
1. challenge_camera_capture_screen.dart
   └─ _pickFromGallery() (ligne 409)
      ├─ ImagePicker.pickVideo(source: ImageSource.gallery)
      └─ Navigator.pop<List<XFile>>([picked])

2. student_challenge_video_editor_screen.dart
   └─ _openCameraCaptureFlow() (ligne 292)
      └─ _processSegments(segments) (ligne 241)
         ├─ setState(_localVideoPath = firstFile.path) (ligne 263)
         ├─ _generateThumbnailInBackground(firstFile.path) (ligne 272)
         └─ _compressAndWatermarkInBackground(firstFile.path, name, t0) (ligne 275)

3. student_challenge_video_editor_screen.dart
   └─ _compressAndWatermarkInBackground() (ligne 688)
      ├─ VideoCompress.compressVideo() (ligne 717)
      ├─ WatermarkService.addWatermark() (ligne 740)
      ├─ File(watermarkedPath).readAsBytes() (ligne 747)
      └─ setState(_videoBytes = finalBytes, _localVideoPath = watermarkedPath) (ligne 756)

4. student_challenge_video_editor_screen.dart
   └─ build() (ligne 5367)
      └─ AcademiaPlaybackEngine.view(url: previewUrl) (ligne 5397)
         └─ AcademiaPlaybackView._init() (ligne 135)
            └─ VideoPlayerController.initialize() (ligne 185)
```

### Parcours Galerie → Preview (mode direct FilePicker)

```
1. student_challenge_video_editor_screen.dart
   └─ _pickVideo() (ligne 448)
      ├─ FilePicker.platform.pickFiles()
      └─ setState(_localVideoPath = filePath) (ligne 496)
         ├─ _generateThumbnailInBackground(filePath) (ligne 506)
         └─ _compressAndWatermarkInBackground(filePath, file.name, t0) (ligne 509)

2. [Même suite que ci-dessus]
```

---

## ÉTAPE 2 : INVENTAIRE DES OPÉRATIONS COÛTEUSES

### A. Compressions vidéo

| Fichier | Ligne | Méthode | Description |
|---------|-------|---------|-------------|
| student_challenge_video_editor_screen.dart | 581 | VideoCompress.compressVideo() | Compression HD/MediumQuality |
| student_challenge_video_editor_screen.dart | 717 | VideoCompress.compressVideo() | Compression HD/MediumQuality (background) |

**Durée estimée :** 5-30s selon taille vidéo et puissance CPU (TECNO LD7)

---

### B. Watermarking

| Fichier | Ligne | Méthode | Description |
|---------|-------|---------|-------------|
| student_challenge_video_editor_screen.dart | 603 | WatermarkService.addWatermark() | Watermark après compression |
| student_challenge_video_editor_screen.dart | 634 | WatermarkService.addWatermark() | Watermark fallback (compression null) |
| student_challenge_video_editor_screen.dart | 651 | WatermarkService.addWatermark() | Watermark fallback (erreur compression) |
| student_challenge_video_editor_screen.dart | 740 | WatermarkService.addWatermark() | Watermark background |
| student_challenge_video_editor_screen.dart | 769 | WatermarkService.addWatermark() | Watermark fallback background |
| student_challenge_video_editor_screen.dart | 787 | WatermarkService.addWatermark() | Watermark fallback erreur background |

**Durée estimée :** 3-15s selon taille vidéo (FFmpeg burn-in)

---

### C. Copies de fichiers (readAsBytes)

| Fichier | Ligne | Taille | Contexte |
|---------|-------|--------|----------|
| student_challenge_video_editor_screen.dart | 610 | Vidéo compressée | Après watermark |
| student_challenge_video_editor_screen.dart | 636 | Vidéo watermarkée | Fallback compression null |
| student_challenge_video_editor_screen.dart | 653 | Vidéo watermarkée | Fallback erreur compression |
| student_challenge_video_editor_screen.dart | 747 | Vidéo compressée | Background |
| student_challenge_video_editor_screen.dart | 771 | Vidéo watermarkée | Fallback background |
| student_challenge_video_editor_screen.dart | 789 | Vidéo watermarkée | Fallback erreur background |
| student_challenge_video_editor_screen.dart | 817 | Vidéo brute | Upload fallback |

**Durée estimée :** 1-5s pour 50-200MB sur TECNO LD7

---

### D. Initialisation Player

| Fichier | Ligne | Méthode | Description |
|---------|-------|---------|-------------|
| academia_playback_view.dart | 185 | VideoPlayerController.initialize() | Décode première frame |

**Durée estimée :** 0.5-3s selon codec et résolution

---

## ÉTAPE 3 : GOULOTS D'ÉTRANGLEMENT DÉTECTÉS

### 🔴 CRITIQUE #1 : Code mort dans _compressAndSetVideo()

**Fichier :** `student_challenge_video_editor_screen.dart`  
**Lignes :** 617-631

```dart
final exitTime = DateTime.now();
final duration = exitTime.difference(enterTime).inMilliseconds;
debugPrint('[P6_EXIT] _compressAndSetVideo duration=${duration}ms');
return;  // ← PROBLÈME : return prématuré

setState(() {  // ← JAMAIS EXÉCUTÉ
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

**Impact :** 
- `_compressAndSetVideo()` ne met jamais à jour `_videoBytes` ni `_localVideoPath`
- Cette méthode n'est **PAS utilisée** dans le flux galerie → preview
- Elle est définie mais jamais appelée (recherche grep montre 0 appels)

**Conclusion :** Code mort, pas d'impact sur le bug actuel.

---

### 🟡 MAJEUR #2 : Compression + Watermark en background NON-BLOQUANT

**Fichier :** `student_challenge_video_editor_screen.dart`  
**Lignes :** 506-509

```dart
// Generate thumbnail in background (non-blocking)
_generateThumbnailInBackground(filePath);

// Compress and watermark in background (non-blocking)
_compressAndWatermarkInBackground(filePath, file.name, t0);
```

**Problème :**
- La preview est affichée **immédiatement** avec `_localVideoPath = filePath` (ligne 496)
- La compression/watermark se fait en **background**
- Mais `_localVideoPath` est **remplacé** par le chemin watermarké à la fin (ligne 759)
- Pendant ce temps, la preview utilise le fichier **original non compressé**

**Impact sur TECNO LD7 :**
- Fichier original peut être 50-200MB
- Décodeur vidéo peut avoir du mal avec gros fichiers non optimisés
- Si le fichier est en codec non supporté, écran noir

---

### 🟡 MAJEUR #3 : VideoPlayerController.initialize() sur fichier local

**Fichier :** `academia_playback_view.dart`  
**Lignes :** 155-180

```dart
if (_shouldUseNativeAndroid && !isLocalFileUri) {
  // Utilise PlatformView native pour URLs distantes
  setState(() { _initializing = false; _error = null; });
  return;
}

// Pour fichiers locaux (file://), utilise Flutter video_player
debugPrint('[RUNTIME PLAYER] Using Flutter video_player');
setState(() { _initializing = true; });

final VideoPlayerController controller;
if (isLocalFileUri) {
  controller = VideoPlayerController.file(File.fromUri(parsed));
} else {
  controller = VideoPlayerController.networkUrl(Uri.parse(url));
}

await controller.initialize();  // ← Peut être long
```

**Problème :**
- Pour fichiers locaux (`file://`), le code **force** l'utilisation de Flutter `video_player`
- La PlatformView native Android est **désactivée** pour les fichiers locaux
- `VideoPlayerController.initialize()` décode la première frame
- Sur TECNO LD7, décodage d'un gros fichier non optimisé peut prendre plusieurs secondes

**Impact :**
- Écran noir pendant `initialize()`
- Aucun indicateur de chargement visible pour l'utilisateur
- Si codec non supporté, initialize échoue silencieusement

---

### 🟢 MINEUR #4 : setState multiples pendant compression

**Fichier :** `student_challenge_video_editor_screen.dart`  
**Lignes :** 756-761

```dart
if (mounted) {
  setState(() {
    _isCompressing = false;
    _videoBytes = finalBytes;
    _localVideoPath = watermarkedPath;  // ← Remplace le chemin
    if (info.duration != null) _videoDurationMs = info.duration!.toInt();
  });
}
```

**Problème :**
- Quand la compression/watermark termine, `_localVideoPath` change
- Cela provoque un **rebuild** du widget
- `AcademiaPlaybackView` est recréé avec la nouvelle URL
- `_init()` est appelé à nouveau
- Deuxième `initialize()` sur le fichier watermarké

**Impact :**
- Double initialisation du player
- Transition visuelle possible (flicker)

---

## ÉTAPE 4 : RAPPORT FINAL

### A. Chemin réel parcouru par la vidéo

```
Galerie → FilePicker → setState(_localVideoPath = original)
         → build() → AcademiaPlaybackView(original)
         → VideoPlayerController.initialize(original)
         → [ÉCRAN NOIR pendant initialize()]
         → [Première frame affichée si codec supporté]
         
[PARALLÈLE] → _compressAndWatermarkInBackground()
            → VideoCompress.compressVideo()
            → WatermarkService.addWatermark()
            → setState(_localVideoPath = watermarked)
            → rebuild → AcademiaPlaybackView(watermarked)
            → VideoPlayerController.initialize(watermarked)
            → [Deuxième écran noir possible]
```

---

### B. Trois opérations les plus coûteuses

| Opération | Durée estimée (TECNO LD7) | Impact sur UX |
|-----------|---------------------------|---------------|
| VideoCompress.compressVideo() | 5-30s | Background, non bloquant |
| WatermarkService.addWatermark() | 3-15s | Background, non bloquant |
| VideoPlayerController.initialize() | 0.5-3s | **BLOQUANT** - écran noir |

---

### C. Temps théorique maximal sur TECNO LD7

**Scénario pire (vidéo 200MB, codec H.264 1080p) :**
- `initialize()` sur fichier original : **2-3s** (écran noir)
- Compression : **20-30s** (background)
- Watermark : **10-15s** (background)
- `initialize()` sur fichier watermarké : **1-2s** (écran noir second)

**Total ressenti par utilisateur :** 3-5s d'écran noir initial

---

### D. Cause la plus probable du délai observé

**ROOT CAUSE :** `VideoPlayerController.initialize()` sur fichier local non optimisé

**Explication :**
1. L'utilisateur sélectionne une vidéo dans la galerie
2. Le chemin du fichier original est stocké dans `_localVideoPath`
3. La preview est immédiatement affichée avec ce fichier
4. `AcademiaPlaybackView._init()` est appelé
5. Pour les fichiers locaux, le code **force** l'utilisation de Flutter `video_player` (ligne 155)
6. `VideoPlayerController.initialize()` décode la première frame
7. Sur TECNO LD7, décodage d'un gros fichier (50-200MB) prend 2-3 secondes
8. Pendant ce temps, l'écran reste noir
9. Si le codec n'est pas supporté, `initialize()` échoue et l'écran reste noir définitivement

**Pourquoi la PlatformView native est désactivée pour les fichiers locaux :**
```dart
// Ligne 155 : if (_shouldUseNativeAndroid && !isLocalFileUri)
```
Le commentaire (ligne 153-154) indique :
> Exception: pour les previews locaux (file://), la PlatformView native peut crasher selon les devices.

Mais cette décision de sécurité a un coût : écran noir pendant l'initialisation Flutter.

---

### E. Modifications exactes à effectuer

#### MODIFICATION #1 : Utiliser PlatformView native pour les fichiers locaux

**Fichier :** `academia_playback_view.dart`  
**Ligne :** 155

**Avant :**
```dart
if (_shouldUseNativeAndroid && !isLocalFileUri) {
  debugPrint('[RUNTIME PLAYER] Using native Android view');
  setState(() { _initializing = false; _error = null; });
  return;
}
```

**Après :**
```dart
if (_shouldUseNativeAndroid) {
  debugPrint('[RUNTIME PLAYER] Using native Android view - url=${url.length > 60 ? url.substring(0, 60) : url}');
  setState(() { _initializing = false; _error = null; });
  return;
}
```

**Justification :**
- La PlatformView native utilise ExoPlayer qui gère mieux les gros fichiers
- ExoPlayer a un buffering progressif, pas d'écran noir complet
- Le risque de crash mentionné dans le commentaire doit être testé sur TECNO LD7
- Si crash survient, ajouter un try-catch avec fallback vers Flutter player

---

#### MODIFICATION #2 : Ajouter indicateur de chargement pendant initialize()

**Fichier :** `academia_playback_view.dart`  
**Lignes :** 166-170

**Avant :**
```dart
setState(() {
  _initializing = true;
  _error = null;
  _loggedFirstPlay = false;
});
```

**Après :**
```dart
setState(() {
  _initializing = true;
  _error = null;
  _loggedFirstPlay = false;
});
```

**Dans le build() (à ajouter) :**
```dart
if (_initializing) {
  return const Center(
    child: CircularProgressIndicator(),
  );
}
```

**Justification :**
- L'utilisateur voit qu'un chargement est en cours
- Réduit la perception d'un "écran noir bug"
- Meilleure UX même si le délai persiste

---

#### MODIFICATION #3 : Supprimer le code mort _compressAndSetVideo()

**Fichier :** `student_challenge_video_editor_screen.dart`  
**Lignes :** 515-668

**Action :** Supprimer la méthode `_compressAndSetVideo()` entièrement

**Justification :**
- Cette méthode n'est jamais appelée (grep confirme 0 appels)
- Contient un return prématuré qui empêche le setState
- Code mort qui ajoute de la confusion

---

#### MODIFICATION #4 : Optimiser le rebuild après compression

**Fichier :** `student_challenge_video_editor_screen.dart`  
**Lignes :** 755-762

**Avant :**
```dart
if (mounted) {
  setState(() {
    _isCompressing = false;
    _videoBytes = finalBytes;
    _localVideoPath = watermarkedPath;
    if (info.duration != null) _videoDurationMs = info.duration!.toInt();
  });
}
```

**Après :**
```dart
if (mounted) {
  setState(() {
    _isCompressing = false;
    _videoBytes = finalBytes;
    // Ne pas changer _localVideoPath immédiatement
    // Attendre que l'utilisateur clique sur "Publier" pour utiliser la version compressée
    if (info.duration != null) _videoDurationMs = info.duration!.toInt();
  });
}
```

**Justification :**
- Évite le rebuild et la deuxième initialisation
- La preview continue d'utiliser le fichier original
- La version compressée est utilisée uniquement pour l'upload
- Réduit le nombre d'écrans noirs

---

## CONCLUSION

**Cause principale :** `VideoPlayerController.initialize()` sur fichier local avec Flutter `video_player` au lieu de PlatformView native ExoPlayer.

**Solution prioritaire :** Activer PlatformView native pour les fichiers locaux (Modification #1).

**Solutions secondaires :** Ajouter indicateur de chargement (Modification #2) et éviter le rebuild inutile (Modification #4).

**Tests à effectuer sur TECNO LD7 :**
1. Vérifier que PlatformView native ne crash pas avec fichiers locaux
2. Mesurer le temps d'initialisation avec vs sans PlatformView
3. Confirmer que l'indicateur de chargement s'affiche correctement
