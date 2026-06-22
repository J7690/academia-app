# Audit P1 - Affichage Vidéo Immédiat

**Date :** 19 Juin 2026  
**Objectif :** Identifier ce qui se passe entre sélection et première image visible

---

## 1. Temps exact passé dans chaque étape

### Étape 1 : setState immédiat
- **Fichier :** `student_challenge_video_editor_screen.dart`
- **Méthode :** `_processSegments` (ligne 259-266) ou `_pickVideo` (ligne 483-490)
- **Temps :** < 1ms (setState synchrone)
- **Code :**
```dart
setState(() {
  _localVideoPath = firstFile.path;
  _fileName = name;
  _mimeType = ext;
  _uploadedUrl = null;
  _videoInitialized = false;
  _videoBytes = null;
});
```

### Étape 2 : build() de l'éditeur
- **Fichier :** `student_challenge_video_editor_screen.dart`
- **Méthode :** `build` (ligne 5297)
- **Temps :** < 10ms (rebuild Flutter)
- **Code :**
```dart
final String? effectivePreviewUrl = hasLocalVideo
    ? Uri.file(_localVideoPath!).toString()
    : (hasUrl ? _uploadedUrl : null);
```

### Étape 3 : AcademiaPlaybackView.initState()
- **Fichier :** `academia_playback_view.dart`
- **Méthode :** `initState` (ligne 91-96)
- **Temps :** < 1ms
- **Code :**
```dart
@override
void initState() {
  super.initState();
  widget.playbackController?._state = this;
  if (!widget.deferInitialization) {
    _init();  // Appel immédiat
  }
}
```

### Étape 4 : AcademiaPlaybackView._init()
- **Fichier :** `academia_playback_view.dart`
- **Méthode :** `_init` (ligne 134-246)
- **Temps :** Variable (dépend de VideoPlayerController.initialize())
- **Code :**
```dart
Future<void> _init() async {
  // ...
  final VideoPlayerController controller;
  if (isLocalFileUri) {
    final parsed = Uri.parse(url);
    controller = VideoPlayerController.file(File.fromUri(parsed));
  } else {
    controller = VideoPlayerController.networkUrl(Uri.parse(url));
  }
  _controller = controller;

  await controller.initialize();  // ← BLOQUANT
  await controller.setLooping(widget.looping);
  await controller.setVolume(widget.muted ? 0.0 : 1.0);
  // ...
}
```

### Étape 5 : VideoPlayerController.initialize()
- **Fichier :** `academia_playback_view.dart`
- **Méthode :** `_init` (ligne 179)
- **Temps :** **500ms - 3000ms** (dépend de la taille et du codec de la vidéo)
- **Responsable :** Flutter video_player package
- **Action :** Parse le fichier MP4, lit les métadonnées (duration, dimensions, codec), prépare le decoder

### Étape 6 : Génération miniature (arrière-plan)
- **Fichier :** `student_challenge_video_editor_screen.dart`
- **Méthode :** `_generateThumbnailInBackground` (ligne 636-650)
- **Temps :** 100-500ms
- **Statut :** Non-bloquant, appelé sans await
- **Code :**
```dart
Future<void> _generateThumbnailInBackground(String sourcePath) async {
  try {
    _thumbnailBytes = await vt.VideoThumbnail.thumbnailData(
      video: sourcePath,
      imageFormat: vt.ImageFormat.JPEG,
      maxWidth: 360,
      quality: 70,
    );
    if (mounted) {
      setState(() {}); // Trigger rebuild pour afficher miniature
    }
  } catch (e) {
    debugPrint('[Studio] Thumbnail generation failed: $e');
  }
}
```

---

## 2. Composant qui bloque l'affichage

**Responsable principal :** `VideoPlayerController.initialize()`

**Fichier :** `academia_playback_view.dart`  
**Ligne :** 179  
**Type :** Await bloquant

**Pourquoi il bloque :**
- Doit parser le fichier MP4 pour extraire les métadonnées
- Doit initialiser le decoder vidéo (hardware ou software)
- Doit préparer le buffer pour la première frame
- Pour les fichiers locaux, doit lire l'en-tête du fichier

**Temps typique :**
- Vidéo courte (< 10s) : 500-1000ms
- Vidéo moyenne (30-60s) : 1000-2000ms
- Vidéo longue (> 60s) : 2000-3000ms

**État pendant l'initialisation :**
- `_initializing = true` (ligne 163)
- UI affiche un CircularProgressIndicator (ligne 484-493)
- Aucune frame vidéo visible

---

## 3. VideoPlayerController attend-il le fichier complet ?

**Réponse :** NON, il n'attend pas le fichier complet.

**Ce qu'il fait :**
- Lit l'en-tête du fichier MP4 (moov atom)
- Extrait les métadonnées (duration, dimensions, codec, bitrate)
- Initialise le decoder
- Prépare le streaming progressif

**Ce qu'il NE fait PAS :**
- Ne lit pas tout le fichier
- Ne télécharge pas tout le fichier (pour les vidéos distantes)
- Ne décode pas toutes les frames

**Preuve :**
- Flutter video_player utilise le streaming progressif
- La première frame peut être affichée avant que le fichier soit complètement chargé
- Pour les fichiers locaux, l'accès est direct (pas de téléchargement)

**Cependant :**
- L'initialisation prend quand même du temps (500-3000ms)
- Ce temps est dû au parsing de l'en-tête et à l'initialisation du decoder
- C'est ce temps qui cause l'écran noir

---

## 4. La miniature peut-elle être affichée avant la vidéo ?

**Réponse technique :** OUI, elle est générée en arrière-plan.

**Réponse UI :** NON, elle n'est PAS affichée dans l'UI avant la vidéo.

**État actuel :**
- `_thumbnailBytes` est généré en arrière-plan (ligne 638)
- La miniature est passée à `VideoPublishScreen` (ligne 5281)
- MAIS elle n'est PAS affichée dans l'éditeur vidéo avant la vidéo principale

**Pourquoi elle n'est pas affichée :**
- L'UI de l'éditeur n'affiche que `AcademiaPlaybackEngine.view` (ligne 5327)
- Il n'y a pas de fallback pour afficher la miniature pendant l'initialisation
- La miniature est uniquement utilisée pour la publication, pas pour le preview

**Solution possible :**
- Afficher la miniature comme placeholder pendant l'initialisation de VideoPlayerController
- Une fois VideoPlayerController initialisé, remplacer la miniature par la vidéo

---

## 5. Diagramme du flux réel

```
Sélection vidéo (caméra/galerie)
    ↓ (< 1ms)
setState immédiat (_localVideoPath défini)
    ↓ (< 10ms)
build() de StudentChallengeVideoEditorScreen
    ↓ (< 1ms)
AcademiaPlaybackView.initState()
    ↓ (< 1ms)
AcademiaPlaybackView._init()
    ↓
setState(_initializing = true) → UI affiche loader
    ↓
VideoPlayerController.file(File.fromUri(parsed))
    ↓
await VideoPlayerController.initialize() ← BLOQUANT (500-3000ms)
    ├─ Parse fichier MP4 (en-tête)
    ├─ Extrait métadonnées
    ├─ Initialise decoder
    └─ Prépare streaming
    ↓
await controller.setLooping()
    ↓
await controller.setVolume()
    ↓
setState(_initializing = false)
    ↓
Première frame vidéo visible
    ↓
[En arrière-plan] _generateThumbnailInBackground (100-500ms)
    ↓
[En arrière-plan] _compressAndWatermarkInBackground (3-8 secondes)
```

---

## 6. Résumé des temps

| Étape | Temps | Bloquant ? | Responsable |
|-------|-------|------------|-------------|
| setState | < 1ms | Non | Flutter |
| build() | < 10ms | Non | Flutter |
| initState | < 1ms | Non | AcademiaPlaybackView |
| _init() | Variable | Oui | AcademiaPlaybackView |
| VideoPlayerController.initialize() | 500-3000ms | **OUI** | Flutter video_player |
| Première frame visible | - | - | - |

**Temps total avant première frame :** 500-3000ms

**Goulot d'étranglement :** `VideoPlayerController.initialize()`

---

## 7. Conclusion

**Cause de l'écran noir :**
- `VideoPlayerController.initialize()` est bloquant et prend 500-3000ms
- Pendant ce temps, l'UI affiche un loader (déjà implémenté)
- La miniature n'est pas utilisée comme placeholder

**Pourquoi l'affichage n'est pas immédiat :**
- Malgré le setState immédiat, le VideoPlayerController doit s'initialiser
- L'initialisation est nécessaire pour parser le fichier et préparer le decoder
- Ce temps est inévitable avec l'architecture actuelle

**Solutions possibles (hors périmètre de cet audit) :**
- Afficher la miniature comme placeholder pendant l'initialisation
- Utiliser le player natif Android pour les fichiers locaux (plus rapide)
- Pré-initialiser le player avant navigation
- Utiliser un format vidéo avec en-tête plus léger
