# Rapport d'Audit - Pipeline Import Vidéo Challenge

**Date :** 19 Juin 2026  
**Objectif :** Audit des mécanismes actuels sans modification  
**Scope :** Affichage vidéo, bouton Suivant, upload, indicateur compression, audio feed

---

## 1. Problème : Écran noir après sélection de vidéo

### Observation
Après sélection d'une vidéo (caméra ou galerie), l'écran reste noir au lieu d'afficher la vidéo.

### Analyse technique

#### Fichier : `student_challenge_video_editor_screen.dart`

**Lignes 257-266 (_processSegments) :**
```dart
setState(() {
  _localVideoPath = firstFile.path;
  _fileName = name;
  _mimeType = ext;
  _uploadedUrl = null;
  _videoInitialized = false;
  _videoBytes = null; // Will be set after compression
});
```

**Lignes 483-490 (_pickVideo) :**
```dart
setState(() {
  _localVideoPath = filePath;
  _fileName = file.name;
  _mimeType = ext;
  _uploadedUrl = null;
  _videoInitialized = false;
  _videoBytes = null; // Will be set after compression
});
```

**Lignes 5277-5283 (build) :**
```dart
final bool hasUrl = _uploadedUrl != null && _uploadedUrl!.isNotEmpty;
final bool hasLocalVideo = _localVideoPath != null && _localVideoPath!.isNotEmpty;
final bool hasVideo = hasUrl || hasLocalVideo;

final String? effectivePreviewUrl = hasLocalVideo
    ? Uri.file(_localVideoPath!).toString()
    : (hasUrl ? _uploadedUrl : null);
```

**Lignes 5305-5315 (AcademiaPlaybackEngine.view) :**
```dart
child: AcademiaPlaybackEngine.view(
  url: previewUrl,
  preferFlutterPlayer: false,
  autoplay: isLocalPreview,
  looping: isLocalPreview,
  muted: false,
  showControls: false,
  fit: BoxFit.cover,
  playbackController: _previewPlaybackController,
),
```

#### Fichier : `academia_playback_view.dart`

**Lignes 145-159 (_init) :**
```dart
final uri = Uri.tryParse(url);
final isLocalFileUri = uri != null && uri.scheme.toLowerCase() == 'file';

// Sur Android, on utilise la PlatformView native qui a le filtre MediaTek.
// Pas besoin d'initialiser un VideoPlayerController.
// Exception: pour les previews locaux (file://), la PlatformView native peut
// crasher selon les devices. Dans ce cas on utilise video_player.
if (_shouldUseNativeAndroid && !isLocalFileUri) {
  debugPrint('[AcademiaPlaybackView] using native Android view url=$url');
  setState(() {
    _initializing = false;
    _error = null;
  });
  return;
}
```

**Lignes 161-179 (initialisation Flutter video_player pour fichiers locaux) :**
```dart
// --- Web / iOS: Flutter video_player ---
setState(() {
  _initializing = true;
  _error = null;
  _loggedFirstPlay = false;
});

try {
  debugPrint('[AcademiaPlaybackView] init url=$url');
  final VideoPlayerController controller;
  if (isLocalFileUri) {
    final parsed = Uri.parse(url);
    controller = VideoPlayerController.file(File.fromUri(parsed));
  } else {
    controller = VideoPlayerController.networkUrl(Uri.parse(url));
  }
  _controller = controller;

  await controller.initialize();
  await controller.setLooping(widget.looping);
  await controller.setVolume(widget.muted ? 0.0 : 1.0);
```

### Diagnostic

**Cause racine identifiée :**

1. **URL générée :** `Uri.file(_localVideoPath!)` génère une URL de type `file:///chemin/vers/video.mp4`

2. **Branchement conditionnel :** Dans `academia_playback_view.dart`, ligne 152, la condition `!isLocalFileUri` est vraie pour les fichiers locaux, donc le code utilise le Flutter `VideoPlayerController.file` au lieu du player natif Android.

3. **Initialisation asynchrone :** L'initialisation du `VideoPlayerController` (ligne 179) est asynchrone (`await controller.initialize()`). Pendant cette initialisation, l'état `_initializing` est true (ligne 163), mais il n'y a pas d'indicateur de chargement visible dans l'UI.

4. **Absence d'indicateur de chargement :** Le widget `AcademiaPlaybackView` n'affiche rien pendant `_initializing = true`, ce qui explique l'écran noir.

5. **Possible échec d'initialisation :** Si le fichier vidéo n'est pas accessible ou si le format n'est pas supporté, l'initialisation peut échouer silencieusement ou lever une exception non capturée.

**État actuel :**
- `_localVideoPath` est correctement défini après sélection
- L'URL `file://` est correctement générée
- Le player Flutter est correctement instancié pour les fichiers locaux
- **MAIS** l'initialisation asynchrone sans indicateur visuel cause l'écran noir

---

## 2. Problème : Bouton Suivant disponible mais message d'attente

### Observation
Le bouton "Suivant" est immédiatement disponible après sélection, mais lors du clic, un message indique de patienter car l'upload n'est pas terminé (peut prendre > 10 min pour une vidéo de 1 min).

### Analyse technique

#### Fichier : `student_challenge_video_editor_screen.dart`

**Lignes 5402-5405 (bouton Suivant) :**
```dart
GestureDetector(
  onTap: _localVideoPath == null
      ? null
      : _openPublishScreen,
```

**Lignes 5230-5246 (_openPublishScreen) :**
```dart
Future<void> _openPublishScreen() async {
  debugPrint('[Studio] _openPublishScreen: _uploadedUrl=$_uploadedUrl, _fileName=$_fileName, _videoBytes=${_videoBytes?.length}, _localVideoPath=$_localVideoPath');

  if ((_uploadedUrl == null || _uploadedUrl!.isEmpty) && !_isUploading) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Upload en cours...')),
    );
    await _uploadVideo();
    if (!mounted) return;
  }

  if (_uploadedUrl == null || _uploadedUrl!.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Upload non terminé. Réessaie dans quelques secondes.')),
    );
    return;
  }
```

**Lignes 744-753 (_uploadVideo) :**
```dart
Future<void> _uploadVideo() async {
  debugPrint('[Studio] ===== _uploadVideo START =====');
  debugPrint('[Studio] _isFreeVideo=$_isFreeVideo, _hasFreeVideoId=$_hasFreeVideoId, _fileName=$_fileName, bytesLen=${_videoBytes?.length}');
  if (_videoBytes == null || _fileName == null) {
    debugPrint('[Studio] ABORT: no video bytes or fileName');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sélectionne d\'abord une vidéo.')),
    );
    return;
  }
```

**Lignes 652-742 (_compressAndWatermarkInBackground) :**
```dart
Future<void> _compressAndWatermarkInBackground(String sourcePath, String originalName, DateTime t0) async {
  // ...
  setState(() => _isCompressing = true);
  
  // Compression
  final MediaInfo? info = await VideoCompress.compressVideo(...);
  
  // Watermark
  final watermarkedPath = await WatermarkService.addWatermark(info.path!);
  
  // Lecture des bytes
  final finalBytes = await finalFile.readAsBytes();
  
  setState(() {
    _isCompressing = false;
    _videoBytes = finalBytes;  // ← _videoBytes défini ici
    _localVideoPath = watermarkedPath;
  });
}
```

### Diagnostic

**Cause racine identifiée :**

1. **Dépendance circulaire :**
   - Le bouton "Suivant" dépend de `_localVideoPath` (disponible immédiatement)
   - `_openPublishScreen` lance `_uploadVideo()` si `_uploadedUrl` est null
   - `_uploadVideo()` nécessite `_videoBytes` (ligne 747)
   - `_videoBytes` n'est défini qu'après la compression dans `_compressAndWatermarkInBackground` (ligne 710)

2. **Race condition :**
   - Si l'utilisateur clique sur "Suivant" avant la fin de la compression :
     - `_videoBytes` est null
     - `_uploadVideo()` aborte avec le message "Sélectionne d'abord une vidéo"
     - L'utilisateur reçoit le message "Upload non terminé"

3. **Upload bloquant :**
   - `_uploadVideo()` est appelé avec `await` (ligne 5237), ce qui bloque la navigation
   - L'upload peut prendre plusieurs minutes pour une vidéo de 1 min
   - Pendant ce temps, l'utilisateur voit le message "Upload en cours..." mais ne peut rien faire

4. **Auto-upload non fonctionnel :**
   - Dans l'ancien pipeline, il y avait un auto-upload en arrière-plan (ligne 259 dans l'ancien code)
   - Dans le nouveau code, cet auto-upload a été supprimé
   - L'upload ne se fait que manuellement via le bouton "Suivant"

**État actuel :**
- Bouton "Suivant" disponible immédiatement (correct)
- MAIS clic sur "Suivant" déclenche un upload bloquant
- Upload échoue si compression pas terminée
- Pas d'auto-upload en arrière-plan

---

## 3. Problème : Indicateur de compression orange

### Observation
L'indicateur de compression orange est présent et visible.

### Analyse technique

#### Fichier : `student_challenge_video_editor_screen.dart`

**Lignes 5365-5400 (indicateur dans build) :**
```dart
// Compression indicator
if (_isCompressing)
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    margin: const EdgeInsets.only(right: 8),
    decoration: BoxDecoration(
      color: Colors.orange.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: Colors.orange,
        width: 1,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'Compression...',
          style: TextStyle(
            color: Colors.orange,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  ),
```

**Lignes 658-661 (activation dans _compressAndWatermarkInBackground) :**
```dart
// Show compression indicator
if (mounted) {
  setState(() => _isCompressing = true);
}
```

**Lignes 708-713 (désactivation) :**
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

### Diagnostic

**État actuel :**
- ✅ Indicateur correctement implémenté
- ✅ Activation au début de la compression
- ✅ Désactivation à la fin de la compression
- ✅ Affichage conditionnel basé sur `_isCompressing`
- ✅ Design visuel approprié (spinner orange + texte)

**Conclusion :** L'indicateur de compression fonctionne correctement. Aucun problème identifié.

---

## 4. Problème : Audio du feed persistant pendant compression

### Observation
L'audio du feed continue de jouer pendant que la compression se fait.

### Analyse technique

#### Fichier : `student_challenges_tab.dart`

**Lignes 1704-1740 (_openCreateVideoFromFeed) :**
```dart
Future<void> _openCreateVideoFromFeed(BuildContext context) async {
  if (!context.mounted) return;

  // Pause toutes les vidéos du feed avant de naviguer
  _pauseAllControllers();

  final segments = await Navigator.of(context).push<List<XFile>?>(
    MaterialPageRoute(
      builder: (_) => const ChallengeCameraCaptureScreen(),
    ),
  );

  if (!mounted) return;

  // Si l'utilisateur a capturé des segments, ouvrir le Studio avec les segments
  if (segments != null && segments.isNotEmpty) {
    final published = await Navigator.of(context).push<bool?>(
      MaterialPageRoute(
        builder: (_) => StudentChallengeVideoEditorScreen(
          videoType: 'free',
          initialMode: 'camera',
          initialSegments: segments,
        ),
      ),
    );
```

**Lignes 1765-1771 (_pauseAllControllers) :**
```dart
void _pauseAllControllers() {
  for (final entry in _controllers.entries) {
    if (entry.value.isAttached) {
      entry.value.pause();
    }
  }
}
```

**Lignes 1773-1782 (_muteAllControllers) :**
```dart
void _muteAllControllers() {
  for (final entry in _controllers.entries) {
    if (entry.value.isAttached) {
      // Note: AcademiaPlaybackController doesn't have a mute method
      // We rely on pause() which stops audio playback
      entry.value.pause();
    }
  }
}
```

#### Fichier : `challenge_camera_capture_screen.dart`

**Lignes 420-422 (_pickFromGallery) :**
```dart
if (picked != null && mounted) {
  Navigator.of(context).pop<List<XFile>>([picked]);
}
```

**Lignes 432-435 (_confirm) :**
```dart
void _confirm() {
  if (_segments.isEmpty) return;
  Navigator.of(context).pop<List<XFile>>(
    _segments.map((s) => s.file).toList(),
  );
}
```

### Diagnostic

**Cause racine identifiée :**

1. **Pause uniquement au départ :**
   - `_pauseAllControllers()` est appelé dans `_openCreateVideoFromFeed` (ligne 1708)
   - Cela pause les vidéos avant de naviguer vers `ChallengeCameraCaptureScreen`
   - MAIS cette pause ne s'applique qu'au moment de la navigation initiale

2. **Navigation en cascade :**
   - Flow : Feed → CameraCapture → VideoEditor
   - `_pauseAllControllers()` est appelé avant la première navigation (Feed → CameraCapture)
   - Lorsque `CameraCapture` navigue vers `VideoEditor` (via `Navigator.pop`), il n'y a PAS de nouvelle pause
   - Les contrôleurs du feed restent dans l'état où ils étaient après la première pause

3. **Absence de pause dans VideoEditor :**
   - `StudentChallengeVideoEditorScreen` n'appelle pas `_pauseAllControllers()` du feed
   - Le feed n'est pas accessible depuis le VideoEditor
   - Les contrôleurs du feed ne sont pas gérés pendant l'édition

4. **Méthode _muteAllControllers non utilisée :**
   - La méthode `_muteAllControllers` a été ajoutée mais n'est jamais appelée
   - Elle est identique à `_pauseAllControllers` (ne fait que pause)

5. **Problème de scope :**
   - `_controllers` est une variable privée de `_StudentChallengesTabState`
   - `StudentChallengeVideoEditorScreen` est un widget séparé
   - Il n'y a pas de mécanisme de communication entre les deux pour gérer l'audio

**État actuel :**
- `_pauseAllControllers()` appelé avant navigation vers CameraCapture
- MAIS pas de pause avant navigation vers VideoEditor
- Pas de mécanisme pour arrêter l'audio pendant l'édition
- `_muteAllControllers()` défini mais non utilisé

---

## 5. Résumé des problèmes identifiés

| # | Problème | Cause racine | Sévérité |
|---|----------|--------------|----------|
| 1 | Écran noir après sélection | Initialisation asynchrone de VideoPlayerController sans indicateur visuel | Haute |
| 2 | Bouton Suivant message d'attente | Dépendance à `_videoBytes` (disponible après compression) + upload bloquant | Haute |
| 3 | Indicateur compression orange | Fonctionne correctement | N/A |
| 4 | Audio feed persistant | Pause uniquement avant CameraCapture, pas avant VideoEditor | Haute |

---

## 6. État des variables clés

### Timeline des états après sélection de vidéo

| Moment | `_localVideoPath` | `_videoBytes` | `_isCompressing` | `_uploadedUrl` | Bouton Suivant |
|--------|------------------|---------------|------------------|----------------|----------------|
| Immédiatement après setState | ✅ Défini | ❌ null | ❌ false | ❌ null | ✅ Actif |
| Pendant compression | ✅ Défini | ❌ null | ✅ true | ❌ null | ✅ Actif |
| Après compression | ✅ Défini (watermarked) | ✅ Défini | ❌ false | ❌ null | ✅ Actif |
| Après upload | ✅ Défini | ✅ Défini | ❌ false | ✅ Défini | ✅ Actif |

### Problème de timing

- **T0 (sélection) :** `_localVideoPath` défini, bouton Suivant actif
- **T0 + clic Suivant :** `_videoBytes` encore null → upload échoue
- **T0 + 10s (fin compression) :** `_videoBytes` défini → upload possible
- **T0 + 10s + clic Suivant :** Upload lancé (bloquant)

---

## 7. Recommandations (sans modification)

### Pour le problème 1 (Écran noir)
- Ajouter un indicateur de chargement pendant `_initializing = true` dans `AcademiaPlaybackView`
- Gérer les erreurs d'initialisation avec un message utilisateur
- Vérifier que le fichier vidéo est accessible avant de tenter l'initialisation

### Pour le problème 2 (Bouton Suivant)
- Désactiver le bouton "Suivant" tant que `_videoBytes` est null
- Ou lancer l'upload en arrière-plan sans bloquer la navigation
- Ou afficher un indicateur de progression pendant l'upload

### Pour le problème 4 (Audio feed)
- Appeler `_pauseAllControllers()` avant chaque navigation
- Ou utiliser un mécanisme global de gestion de l'audio (AudioService)
- Ou muter explicitement le player natif Android

---

## 8. Conclusion

L'audit révèle que les modifications précédentes ont partiellement résolu les problèmes mais ont introduit de nouveaux problèmes :

1. **Affichage immédiat :** Implémenté mais l'écran noir persiste à cause de l'initialisation asynchrone
2. **Bouton Suivant :** Disponible immédiatement mais l'upload échoue si compression pas terminée
3. **Indicateur compression :** Fonctionne correctement
4. **Audio feed :** Partiellement résolu (pause avant CameraCapture) mais persiste pendant l'édition

Les problèmes sont liés à la gestion asynchrone des opérations et au manque de synchronisation entre les états de l'UI et les opérations en arrière-plan.
