# Audit P2 - Validation du Flux Réel Flutter

**Date :** 19 Juin 2026  
**Objectif :** Prouver ou réfuter que l'écran d'édition est indépendant de la compression et du watermark

---

## 1. Code complet des méthodes

### _processSegments()

```dart
Future<void> _processSegments(List<XFile> segments) async {
  final t0 = DateTime.now();
  debugPrint('[TIMING] T0 - Segments reçus de caméra: ${t0.toIso8601String()}');

  setState(() {
    _capturedSegments = segments;
  });

  if (segments.length == 1) {
    // Single segment → show immediately, compress in background
    try {
      final firstFile = segments.first;
      final name = firstFile.name.isNotEmpty ? firstFile.name : 'video.mp4';

      debugPrint('[Studio] Showing video immediately: ${firstFile.path}');
      
      // Show video immediately without compression/watermark
      final ext = name.contains('.') ? name.split('.').last : 'mp4';
      setState(() {
        _localVideoPath = firstFile.path;
        _fileName = name;
        _mimeType = ext;
        _uploadedUrl = null;
        _videoInitialized = false;
        _videoBytes = null; // Will be set after compression
      });

      // Generate thumbnail in background (non-blocking)
      _generateThumbnailInBackground(firstFile.path);

      // Compress and watermark in background (non-blocking)
      _compressAndWatermarkInBackground(firstFile.path, name, t0);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors du traitement de la vidéo capturée.'),
        ),
      );
    }
  } else {
    // Multiple segments, show merge dialog
    await _showMergeSegmentsDialog(segments);
  }
}
```

**Fichier :** `student_challenge_video_editor_screen.dart`  
**Lignes :** 241-285

---

### _pickVideo()

```dart
Future<void> _pickVideo() async {
  final t0 = DateTime.now();
  debugPrint('[TIMING] T0 - Vidéo sélectionnée: ${t0.toIso8601String()}');

  final result = await FilePicker.platform.pickFiles(
    allowMultiple: false,
    withData: true,
    type: FileType.custom,
    allowedExtensions: const ['mp4', 'mov', 'webm', 'mkv'],
  );

  if (result == null || result.files.isEmpty) {
    return;
  }

  final file = result.files.first;
  final filePath = file.path;
  if (filePath == null || filePath.isEmpty) {
    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Impossible de lire la vidéo sélectionnée.')),
      );
      return;
    }
    // Web or no path — skip compression, use raw bytes.
    setState(() {
      _videoBytes = bytes;
      _fileName = file.name;
      _mimeType = file.extension;
      _uploadedUrl = null;
      _videoInitialized = false;
    });
    if (!mounted) return;
    return;
  }

  // Show video immediately without compression/watermark
  final ext = file.name.contains('.') ? file.name.split('.').last : 'mp4';
  setState(() {
    _localVideoPath = filePath;
    _fileName = file.name;
    _mimeType = ext;
    _uploadedUrl = null;
    _videoInitialized = false;
    _videoBytes = null; // Will be set after compression
  });

  // Generate thumbnail in background (non-blocking)
  _generateThumbnailInBackground(filePath);

  // Compress and watermark in background (non-blocking)
  _compressAndWatermarkInBackground(filePath, file.name, t0);
}
```

**Fichier :** `student_challenge_video_editor_screen.dart`  
**Lignes :** 442-497

---

### _compressAndWatermarkInBackground()

```dart
Future<void> _compressAndWatermarkInBackground(String sourcePath, String originalName, DateTime t0) async {
  if (!mounted) return;

  final ext = originalName.contains('.') ? originalName.split('.').last : 'mp4';

  // Show compression indicator
  if (mounted) {
    setState(() => _isCompressing = true);
  }

  final t1 = DateTime.now();
  debugPrint('[TIMING] T1 - Début compression (background): ${t1.toIso8601String()} (ΔT1-T0: ${t1.difference(t0).inMilliseconds}ms)');

  try {
    // Detect video orientation for compression preset
    final orientation = VideoOrientationService.detectFromDimensions(1920, 1080);
    
    // Use orientation-aware compression preset
    final VideoQuality quality;
    if (_hdUpload) {
      quality = VideoQuality.Res1920x1080Quality;
    } else {
      quality = VideoQuality.MediumQuality;
    }
    
    final MediaInfo? info = await VideoCompress.compressVideo(
      sourcePath,
      quality: quality,
      deleteOrigin: false,
      includeAudio: true,
    );

    final t2 = DateTime.now();
    debugPrint('[TIMING] T2 - Fin compression (background): ${t2.toIso8601String()} (ΔT2-T1: ${t2.difference(t1).inMilliseconds}ms)');

    if (!mounted) return;

    if (info != null && info.path != null) {
      final originalSize = await File(sourcePath).length();

      // Add Academia watermark
      debugPrint('[Studio] Adding Academia watermark (background)...');
      final watermarkedPath = await WatermarkService.addWatermark(info.path!);
      if (!mounted) return;

      final finalFile = File(watermarkedPath);
      final finalBytes = await finalFile.readAsBytes();
      final compressedSize = finalBytes.length;
      debugPrint(
        '[Studio] Compression+Watermark (background): ${(originalSize / 1024 / 1024).toStringAsFixed(1)} MB → '
        '${(compressedSize / 1024 / 1024).toStringAsFixed(1)} MB '
        '(${(100 - compressedSize * 100 / originalSize).toStringAsFixed(0)}% réduit)',
      );

      if (mounted) {
        setState(() {
          _isCompressing = false;
          _videoBytes = finalBytes;
          _localVideoPath = watermarkedPath;
          if (info.duration != null) _videoDurationMs = info.duration!.toInt();
        });
      }
    } else {
      debugPrint('[Studio] Compression returned null, watermarking original (background)...');
      final watermarkedPath = await WatermarkService.addWatermark(sourcePath);
      if (!mounted) return;
      final bytes = await File(watermarkedPath).readAsBytes();
      if (mounted) {
        setState(() {
          _isCompressing = false;
          _videoBytes = bytes;
          _localVideoPath = watermarkedPath;
        });
      }
    }
  } catch (e) {
    debugPrint('[Studio] Compression error (background): $e — watermarking original...');
    if (!mounted) return;
    final watermarkedPath = await WatermarkService.addWatermark(sourcePath);
    if (!mounted) return;
    final bytes = await File(watermarkedPath).readAsBytes();
    if (mounted) {
      setState(() {
        _isCompressing = false;
        _videoBytes = bytes;
        _localVideoPath = watermarkedPath;
      });
    }
  }
}
```

**Fichier :** `student_challenge_video_editor_screen.dart`  
**Lignes :** 652-742

---

### build()

```dart
@override
Widget build(BuildContext context) {
  final bool hasUrl = _uploadedUrl != null && _uploadedUrl!.isNotEmpty;
  final bool hasLocalVideo = _localVideoPath != null && _localVideoPath!.isNotEmpty;
  final bool hasVideo = hasUrl || hasLocalVideo;

  final String? effectivePreviewUrl = hasLocalVideo
      ? Uri.file(_localVideoPath!).toString()
      : (hasUrl ? _uploadedUrl : null);

  final bool isLocalPreview = (effectivePreviewUrl ?? '').startsWith('file://');

  // Mode studio plein écran TikTok/CapCut : vidéo en fond, barre d'outils
  // horizontale en bas, bouton "Suivant" en haut à droite.
  if (hasVideo) {
    if (effectivePreviewUrl == null || effectivePreviewUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    final String previewUrl = effectivePreviewUrl;
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Vidéo plein écran + overlays ──
          Positioned.fill(
            child: Stack(
              children: [
                Positioned.fill(
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
                ),
                // ... overlays ...
              ],
            ),
          ),
          // ... top bar with compression indicator ...
        ],
      ),
    );
  }
  // ... else case ...
}
```

**Fichier :** `student_challenge_video_editor_screen.dart`  
**Lignes :** 5296-5395 (extrait)

---

## 2. Variables utilisées par build() pour afficher la vidéo

| Variable | Utilisation dans build() | Dépend de la compression ? | Dépend du watermark ? |
|----------|-------------------------|---------------------------|----------------------|
| `_localVideoPath` | Ligne 5299, 5302-5303 | NON | NON |
| `_uploadedUrl` | Ligne 5298, 5304 | NON | NON |
| `_isCompressing` | Ligne 5387 (indicateur UI) | OUI (défini dans _compressAndWatermarkInBackground) | NON |
| `_previewPlaybackController` | Ligne 5335 | NON | NON |
| `_zones` | Ligne 5346 | NON | NON |
| `_selectedZoneIndex` | Ligne 5347 | NON | NON |
| `_hdUpload` | Utilisé indirectement dans _compressAndWatermarkInBackground | NON | NON |

**Variables NON utilisées pour l'affichage vidéo :**
- `_videoBytes` : NON utilisé dans build() pour l'affichage
- `_thumbnailBytes` : NON utilisé dans build() pour l'affichage
- `_videoDurationMs` : NON utilisé dans build() pour l'affichage
- `_fileName` : NON utilisé dans build() pour l'affichage
- `_mimeType` : NON utilisé dans build() pour l'affichage

---

## 3. Dépendances des variables

### _localVideoPath

**Où définie :**
- `_processSegments()` ligne 260
- `_pickVideo()` ligne 484
- `_compressAndWatermarkInBackground()` ligne 711, 724, 738

**À quel moment :**
- Immédiatement après sélection (lignes 260, 484)
- Après compression + watermark (lignes 711, 724, 738)

**Dépend de la compression :**
- NON pour l'initialisation (lignes 260, 484)
- OUI pour la mise à jour finale (lignes 711, 724, 738)

**Dépend du watermark :**
- NON pour l'initialisation (lignes 260, 484)
- OUI pour la mise à jour finale (lignes 711, 724, 738)

**Conclusion :** `_localVideoPath` est défini IMMÉDIATEMENT après sélection, indépendamment de la compression et du watermark. Il est mis à jour plus tard avec le fichier compressé + watermark, mais cela n'affecte PAS l'affichage initial.

---

### _uploadedUrl

**Où définie :**
- `_processSegments()` ligne 263 (défini à null)
- `_pickVideo()` ligne 487 (défini à null)
- `_uploadVideo()` (défini après upload réussi)

**À quel moment :**
- Immédiatement après sélection (défini à null)
- Après upload réussi

**Dépend de la compression :**
- NON

**Dépend du watermark :**
- NON

**Conclusion :** `_uploadedUrl` n'est PAS utilisé pour l'affichage local. Il est utilisé uniquement pour les vidéos distantes (après upload).

---

### _isCompressing

**Où définie :**
- `_compressAndWatermarkInBackground()` ligne 660 (défini à true)
- `_compressAndWatermarkInBackground()` ligne 709, 722, 736 (défini à false)

**À quel moment :**
- Au début de la compression (ligne 660)
- À la fin de la compression (lignes 709, 722, 736)

**Dépend de la compression :**
- OUI

**Dépend du watermark :**
- NON

**Conclusion :** `_isCompressing` est utilisé uniquement pour l'indicateur UI (ligne 5387). Il n'affecte PAS l'affichage vidéo.

---

### _videoBytes

**Où définie :**
- `_processSegments()` ligne 265 (défini à null)
- `_pickVideo()` ligne 489 (défini à null)
- `_compressAndWatermarkInBackground()` ligne 710, 723, 737

**À quel moment :**
- Immédiatement après sélection (défini à null)
- Après compression + watermark (lignes 710, 723, 737)

**Dépend de la compression :**
- OUI

**Dépend du watermark :**
- OUI

**Conclusion :** `_videoBytes` est utilisé UNIQUEMENT pour l'upload, PAS pour l'affichage vidéo dans build().

---

## 4. Réponse question 3 : La vidéo est-elle affichée à partir de ?

**Réponse :** A. `_localVideoPath`

**Preuve :**
```dart
// build() ligne 5299
final bool hasLocalVideo = _localVideoPath != null && _localVideoPath!.isNotEmpty;

// build() ligne 5302-5303
final String? effectivePreviewUrl = hasLocalVideo
    ? Uri.file(_localVideoPath!).toString()
    : (hasUrl ? _uploadedUrl : null);

// build() ligne 5327-5328
child: AcademiaPlaybackEngine.view(
  url: previewUrl,  // ← effectivePreviewUrl dérivé de _localVideoPath
```

**Conclusion :** La vidéo visible dans l'éditeur est affichée à partir de `_localVideoPath`, PAS de `_videoBytes`.

---

## 5. Réponse question 4 : Si la compression échoue totalement

### La vidéo reste-t-elle visible ?

**Réponse :** OUI

**Preuve :**
- `_localVideoPath` est défini immédiatement après sélection (ligne 260 ou 484)
- `build()` utilise `_localVideoPath` pour l'affichage (ligne 5302-5303)
- Même si la compression échoue, `_localVideoPath` reste défini avec le chemin du fichier brut
- Le catch block dans `_compressAndWatermarkInBackground()` (ligne 728) définit quand même `_localVideoPath` avec le fichier watermarké (ligne 738)

**Conclusion :** La vidéo reste visible car elle est affichée à partir du fichier brut, pas du fichier compressé.

---

### Le bouton Suivant reste-t-il fonctionnel ?

**Réponse :** OUI

**Preuve :**
- Le bouton "Suivant" dépend de `_localVideoPath` (ligne 5403 dans l'ancien code, maintenant modifié)
- `_localVideoPath` est défini immédiatement après sélection
- `_uploadVideo()` a un fallback sur `_localVideoPath` si `_videoBytes` est null (lignes 753-766)

**Conclusion :** Le bouton "Suivant" reste fonctionnel car `_uploadVideo()` peut lire le fichier brut directement.

---

### L'éditeur reste-t-il utilisable ?

**Réponse :** OUI

**Preuve :**
- L'éditeur dépend de `_localVideoPath` pour l'affichage
- Les overlays (_zones, _selectedZoneIndex) sont indépendants de la compression
- Les contrôles de lecture (_previewPlaybackController) sont indépendants de la compression

**Conclusion :** L'éditeur reste pleinement utilisable car toutes les fonctionnalités dépendent de `_localVideoPath`, pas de la compression.

---

## 6. Diagramme réel du flux

```
Sélection vidéo (caméra/galerie)
    ↓
_processSegments() ou _pickVideo()
    ↓
setState IMMÉDIAT (lignes 259-266 ou 483-490)
    ├─ _localVideoPath = firstFile.path  ← DÉFINI IMMÉDIATEMENT
    ├─ _fileName = name
    ├─ _mimeType = ext
    ├─ _uploadedUrl = null
    ├─ _videoInitialized = false
    └─ _videoBytes = null
    ↓
build() appelé (rebuild Flutter)
    ↓
hasLocalVideo = true (car _localVideoPath != null)
    ↓
effectivePreviewUrl = Uri.file(_localVideoPath!)
    ↓
AcademiaPlaybackEngine.view(url: effectivePreviewUrl)
    ↓
Widget affiché
    ↓
AcademiaPlaybackView.initState()
    ↓
_init()
    ↓
VideoPlayerController.initialize() (500-3000ms)
    ↓
Première frame visible
    ↓
[En arrière-plan] _generateThumbnailInBackground (appelé ligne 269 ou 493)
    ↓
[En arrière-plan] _compressAndWatermarkInBackground (appelé ligne 272 ou 496)
    ↓
_isCompressing = true (ligne 660)
    ↓
VideoCompress.compressVideo() (3-8 secondes)
    ↓
WatermarkService.addWatermark()
    ↓
setState (lignes 708-713, 721-725, 735-739)
    ├─ _isCompressing = false
    ├─ _videoBytes = finalBytes  ← DÉFINI APRÈS COMPRESSION
    └─ _localVideoPath = watermarkedPath  ← MIS À JOUR APRÈS WATERMARK
```

---

## 7. Conclusion

**L'écran d'édition est-il indépendant de la compression et du watermark ?**

**Réponse :** OUI, pour l'affichage initial

**Preuves :**
1. `_localVideoPath` est défini immédiatement après sélection (avant compression)
2. `build()` utilise `_localVideoPath` pour l'affichage (pas `_videoBytes`)
3. La compression et le watermark sont en arrière-plan (non-bloquants)
4. Si la compression échoue, la vidéo reste visible (fichier brut)
5. Si la compression échoue, le bouton "Suivant" reste fonctionnel (fallback sur fichier brut)
6. Si la compression échoue, l'éditeur reste utilisable

**Ce qui dépend de la compression :**
- `_videoBytes` (utilisé uniquement pour l'upload)
- `_isCompressing` (utilisé uniquement pour l'indicateur UI)
- La mise à jour finale de `_localVideoPath` (avec le fichier compressé + watermark)

**Ce qui NE dépend PAS de la compression :**
- L'affichage vidéo initial (utilise `_localVideoPath` brut)
- La fonctionnalité de l'éditeur
- La disponibilité du bouton "Suivant"

**Conclusion :** L'écran d'édition est indépendant de la compression et du watermark pour l'affichage initial et la fonctionnalité de base. La compression et le watermark sont des optimisations pour l'upload, pas des prérequis pour l'édition.
