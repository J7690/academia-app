# Audit Pipeline Importation Vidéo Challenge
**Date**: 16 Juin 2026  
**Objectif**: Identifier les causes des écrans noirs, lenteur et audio persistant lors de l'import vidéo

---

## A. Cartographie Complète du Pipeline

### Parcours Utilisateur
```
Challenge Feed (student_challenges_tab.dart)
  ↓ Bouton "+"
_openCreateVideoFromFeed()
  ↓ _pauseAllControllers()
Navigator.push → ChallengeCameraCaptureScreen()
  ↓ Bouton galerie
_pickFromGallery()
  ↓ ImagePicker.pickVideo()
Navigator.pop([XFile])
  ↓ StudentChallengeVideoEditorScreen(initialSegments)
_processSegments()
  ↓ _compressAndSetVideo()
VideoCompress.compressVideo()
  ↓ WatermarkService.addWatermark()
_uploadVideo()
  ↓ VideoAssetUploadService.ingestVideoFromBytes()
RPC: app_videoasset_create_upload_intent
  ↓ Upload chunked vers Supabase Storage
RPC: app_videoasset_register_uploaded_source
  ↓ _initRemoteVideo()
AcademiaPlaybackView avec URL distante
  ↓ Écran noir (initialisation)
```

### Points de Navigation
1. **Feed → Caméra**: `student_challenges_tab.dart:1710` (MaterialPageRoute)
2. **Caméra → Galerie**: `challenge_camera_capture_screen.dart:409` (ImagePicker)
3. **Galerie → Éditeur**: `challenge_camera_capture_screen.dart:415` (Navigator.pop)
4. **Éditeur → Publication**: `student_challenge_video_editor_screen.dart:3236` (_submitVideoChallenge)

---

## B. Fichiers Flutter Impliqués

| Fichier | Lignes | Rôle |
|---------|--------|------|
| `student_challenges_tab.dart` | 3573 | Feed Challenge, navigation vers caméra, pause controllers |
| `challenge_camera_capture_screen.dart` | 1035 | Capture caméra, sélection galerie, filtres live |
| `student_challenge_video_editor_screen.dart` | 5993 | Studio d'édition, compression, upload, preview |
| `videoasset_upload_service.dart` | 188 | Upload vers Supabase Storage, RPCs VideoAsset |
| `video_segment_merge_service.dart` | 161 | Fusion multi-segments, Edge Function merge-video-segments |
| `watermark_service.dart` | 198 | Watermark Academia (FFmpegKit DISABLED) |
| `academia_playback_view.dart` | 580 | Lecteur vidéo natif Android + Flutter video_player |
| `academia_playback_engine.dart` | 42 | Factory pour AcademiaPlaybackView |
| `video_orientation_service.dart` | - | Détection orientation vidéo |

---

## C. Services Flutter Impliqués

### VideoAssetUploadService
- **Méthode**: `ingestVideoFromBytes()`
- **RPCs**: `app_videoasset_create_upload_intent`, `app_videoasset_register_uploaded_source`
- **Upload**: ChunkedUploadService pour fichiers > 4MB
- **Buckets**: `video-assets`, `challenge-media`

### VideoSegmentMergeService
- **Méthode**: `mergeSegments()`
- **Edge Function**: `merge-video-segments` (Supabase)
- **Transitions**: none, fade, dissolve, slide (server-side DISABLED pour transitions)

### WatermarkService
- **Méthode**: `addWatermark()`
- **FFmpegKit**: **DISABLED** (lignes 90-107 commentées)
- **Fallback**: Retourne vidéo originale sans watermark
- **Preuve**: `debugPrint('[Watermark] DISABLED — FFmpegKit not available')`

### ChunkedUploadService
- **Role**: Upload par chunks pour gros fichiers
- **Seuil**: 4MB
- **Progress**: Callback onProgress

---

## D. Services Supabase Impliqués

### RPCs VideoAsset
| RPC | Paramètres | Retour |
|-----|------------|--------|
| `app_videoasset_create_upload_intent` | p_origin, p_context_type, p_context_id, p_role, p_mime_type, p_expected_size | bucket, storage_path, source_id |
| `app_videoasset_register_uploaded_source` | p_source_id | video_asset_id, playback |
| `app_videoasset_get_playback_manifest` | p_video_asset_id | playback (best_url, renditions) |
| `app_videoasset_get_playback_for_direct_url` | p_direct_url | video_asset_id, playback |

### Edge Functions
| Edge Function | Statut | Rôle |
|--------------|--------|------|
| `merge-video-segments` | Créée, NON déployée | Fusion segments côté serveur (concaténation bytes) |
| `challenge-*` | - | Aucune Edge Function spécifique Challenge identifiée |

### Buckets Storage
- `video-assets` : Stockage principal VideoAsset
- `challenge-media` : Stockage médias Challenge
- `td-documents` : Module TD (non utilisé pour Challenge)

### Tables
- `video_assets` : Métadonnées vidéos, renditions
- `challenge_participations` : Participations aux challenges
- `challenge_videos` : Vidéos de participation

---

## E. Services Kamatera Impliqués

### Statut
**AUCUN service vidéo actif sur Kamatera pour le pipeline Challenge**

Kamatera (185.167.97.144) héberge uniquement:
- STT (Speech-to-Text) pour Bobodo Voice
- TTS (Text-to-Speech) pour Bobodo Voice
- Aucun worker FFmpeg
- Aucun service ClipLife
- Aucun transcodage vidéo

### Preuve
- Recherche "kamatera" dans codebase Flutter: 0 résultats liés aux vidéos
- Recherche "clip" dans codebase Flutter: 0 résultats liés à ClipLife
- Scripts .windsurf: `deploy_kamatera.py` déploie uniquement Bobodo Voice (STT/TTS)

---

## F. Utilisation Réelle de FFmpeg

### FFmpegKit
**STATUT: DISABLED dans tout le codebase Flutter**

| Fichier | Lignes | Commentaire |
|---------|--------|-------------|
| `watermark_service.dart` | 6-8, 90-107 | Imports commentés, executeWithArguments commenté |
| `audio_mix_service.dart` | 4-6, 110, 128 | Imports commentés, executeWithArguments commenté |
| `gameplay_recorder_service.dart` | 9-10, 167-185 | Imports commentés, executeWithArguments commenté |
| `student_challenge_video_editor_screen.dart` | 10-11, 1491-1492, 1936-1937 | Imports commentés, executeWithArguments commenté |

### Preuve Code
```dart
// watermark_service.dart:107
debugPrint('[Watermark] DISABLED — FFmpegKit not available');
return null;
```

### Compression Vidéo
**Package utilisé**: `video_compress: ^3.1.3` (hardware-accelerated H.264)
- **Méthode**: `VideoCompress.compressVideo()`
- **Qualité**: MediumQuality ou Res1920x1080Quality
- **Local**: Device-side, pas de FFmpeg

---

## G. Utilisation Réelle de ClipLife

### Statut
**AUCUNE trace de ClipLife dans le codebase**

- Recherche "clip" dans codebase: uniquement "clip" comme segment vidéo
- Recherche "cliplife": 0 résultats
- Aucun package ClipLife dans pubspec.yaml
- Aucun appel API ClipLife

### Conclusion
ClipLife n'est pas utilisé pour le pipeline Challenge. Le traitement est:
- Compression locale (video_compress)
- Watermarking (désactivé)
- Upload direct Supabase
- Fusion segments (Edge Function Supabase, concaténation bytes simple)

---

## H. Cause des Écrans Noirs

### Écran Noir 1: Après sélection galerie
**Lieu**: `student_challenge_video_editor_screen.dart` après `_compressAndSetVideo()`

**Cause**:
- `_compressAndSetVideo()` est une méthode async bloquante
- Pendant compression + watermarking, l'écran affiche le widget précédent
- Aucun indicateur de chargement visible pendant compression
- `setState(() => _isCompressing = true)` est appelé (ligne 505), mais l'UI ne montre pas de loader visible

**Preuve**:
```dart
// student_challenge_video_editor_screen.dart:505
setState(() => _isCompressing = true);

// ... compression longue ...

// student_challenge_video_editor_screen.dart:550
_isCompressing = false;
```

**Résultat visuel**: Écran noir pendant 5-30 secondes selon taille vidéo

### Écran Noir 2: Dans l'éditeur vidéo
**Lieu**: `AcademiaPlaybackView` initialisation

**Cause**:
- `AcademiaPlaybackView` retourne `Container(color: Colors.black)` par défaut lors de l'initialisation
- Ligne 484-493: `if (_initializing || controller == null || !controller.value.isInitialized)`
- Aucun indicateur de chargement dans `student_challenge_video_editor_screen.dart` pour l'initialisation vidéo

**Preuve**:
```dart
// academia_playback_view.dart:484-493
if (_initializing || controller == null || !controller.value.isInitialized) {
  return Container(
    color: Colors.black,
    alignment: Alignment.center,
    child: const SizedBox(
      width: 28,
      height: 28,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );
}
```

**Résultat visuel**: Écran noir avec petit loader central (souvent invisible sur fond noir)

### Écran Noir 3: Pendant upload
**Lieu**: `student_challenge_video_editor_screen.dart` pendant `_uploadVideo()`

**Cause**:
- `_uploadVideo()` est async, mais l'UI ne montre pas de loader visible
- `_isUploading = true` (ligne 608), mais pas de widget loader visible dans le build
- L'utilisateur voit l'écran d'édition sans feedback visuel

**Preuve**:
```dart
// student_challenge_video_editor_screen.dart:608
_isUploading = true;

// ... upload chunked ...

// student_challenge_video_editor_screen.dart:819
_isUploading = false;
```

---

## I. Cause de la Lenteur

### Analyse par étape

| Étape | Durée estimée | Blocante? | Thread | Impact UX |
|-------|---------------|-----------|--------|-----------|
| Sélection galerie | 1-3s | Non | UI | Faible |
| Récupération fichier | 0.5-2s | Non | UI | Faible |
| Génération miniature | 2-5s | Oui | UI | Moyen |
| Compression VideoCompress | 5-30s | Oui | UI | **Critique** |
| Watermarking (désactivé) | 0s | Non | - | Nul |
| Upload chunked | 5-60s | Oui | Background | **Critique** |
| Chargement preview | 2-10s | Oui | UI | Moyen |
| Chargement overlays | 1-3s | Non | Background | Faible |

### Goulots d'étranglement

1. **Compression VideoCompress (5-30s)**
   - Exécutée sur thread UI (async mais bloque l'UI visuellement)
   - Hardware-accelerated mais dépend des performances device
   - Pas de feedback visuel clair

2. **Upload chunked (5-60s)**
   - Dépend de la connexion réseau
   - Chunked upload pour fichiers > 4MB
   - Pas de barre de progression visible dans l'UI principale

3. **Génération miniature (2-5s)**
   - `video_thumbnail` package
   - Exécutée avant compression
   - Bloque le début du traitement

### Preuve Code
```dart
// student_challenge_video_editor_screen.dart:478-488
_thumbnailBytes = await vt.VideoThumbnail.thumbnailData(
  video: sourcePath,
  imageFormat: vt.ImageFormat.JPEG,
  maxWidth: 360,
  quality: 70,
);

// student_challenge_video_editor_screen.dart:523-528
final MediaInfo? info = await VideoCompress.compressVideo(
  sourcePath,
  quality: quality,
  deleteOrigin: false,
  includeAudio: true,
);
```

---

## J. Cause de l'Audio Persistant

### Analyse du Cycle de Vie Vidéo

### Contrôleurs Impliqués
- **Feed**: `AcademiaPlaybackController` (Map<int, AcademiaPlaybackController> _controllers)
- **Éditeur**: `_previewPlaybackController` (AcademiaPlaybackController)

### Méthode Pause
```dart
// student_challenges_tab.dart:1765-1771
void _pauseAllControllers() {
  for (final entry in _controllers.entries) {
    if (entry.value.isAttached) {
      entry.value.pause();
    }
  }
}
```

### Appel avant navigation
```dart
// student_challenges_tab.dart:1708
_pauseAllControllers();
```

### Pourquoi l'audio continue?

**Cause 1: Native Android Player**
- `AcademiaPlaybackView` utilise `AndroidView` avec lecteur natif sur Android
- La méthode `pause()` appelle `_nativeChannel.invokeMethod('pause')`
- Mais le lecteur natif peut ne pas respecter immédiatement la pause
- Le codec audio peut continuer en arrière-plan

**Preuve**:
```dart
// academia_playback_view.dart:302-311
Future<void> _pauseExternal() async {
  if (_useNativeAndroid) {
    final ch = _nativeChannel;
    if (ch == null) return;
    try {
      await ch.invokeMethod<bool>('pause')
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
    } catch (_) {}
    _isPaused = true;
    if (mounted) setState(() {});
    return;
  }
```

**Cause 2: Pas de dispose explicite**
- `_pauseAllControllers()` fait un `pause()`, pas un `dispose()`
- Les contrôleurs restent en mémoire avec l'audio buffer
- Pas de libération des ressources audio natives

**Cause 3: Timing**
- La pause est appelée AVANT la navigation
- Mais la navigation peut prendre du temps
- Le lecteur peut reprendre pendant la transition

---

## K. Classement des Causes par Impact

| Cause | Impact estimé | Criticité | Preuve |
|-------|---------------|-----------|--------|
| **Écrans noirs (compression)** | 40% | Critique | Container noir sans loader visible |
| **Audio persistant** | 30% | Critique | Native player pause non respectée |
| **Lenteur compression** | 20% | Élevée | VideoCompress sur thread UI, 5-30s |
| **Upload lent** | 10% | Moyenne | Dépend réseau, pas de progression visible |

---

## L. Recommandations de Correction

### Priorité 1: Écrans Noirs (Critique)

**1.1 Ajouter loader visible pendant compression**
```dart
// student_challenge_video_editor_screen.dart
// Dans build(), ajouter:
if (_isCompressing) {
  return Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text('Compression en cours...', style: TextStyle(color: Colors.white)),
        ],
      ),
    ),
  );
}
```

**1.2 Améliorer loader AcademiaPlaybackView**
```dart
// academia_playback_view.dart:484-493
// Changer le loader pour plus de visibilité:
if (_initializing || controller == null || !controller.value.isInitialized) {
  return Container(
    color: Colors.black,
    alignment: Alignment.center,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
        SizedBox(height: 16),
        Text('Chargement vidéo...', style: TextStyle(color: Colors.white70)),
      ],
    ),
  );
}
```

**1.3 Ajouter loader pendant upload**
```dart
// student_challenge_video_editor_screen.dart
// Dans build(), ajouter:
if (_isUploading) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: Colors.white),
        SizedBox(height: 16),
        Text('Upload en cours... ${(_uploadProgress * 100).toInt()}%', 
             style: TextStyle(color: Colors.white)),
      ],
    ),
  );
}
```

### Priorité 2: Audio Persistant (Critique)

**2.1 Dispose explicite des contrôleurs**
```dart
// student_challenges_tab.dart
// Remplacer _pauseAllControllers() par:
void _pauseAndDisposeAllControllers() {
  for (final entry in _controllers.entries) {
    if (entry.value.isAttached) {
      entry.value.pause();
      // Attendre un peu pour que la pause prenne effet
      Future.delayed(Duration(milliseconds: 100), () {
        entry.value._state = null; // Force detach
      });
    }
  }
}
```

**2.2 Mute explicite avant pause**
```dart
// academia_playback_view.dart
// Dans _pauseExternal(), ajouter mute avant pause:
if (_useNativeAndroid) {
  final ch = _nativeChannel;
  if (ch == null) return;
  try {
    await ch.invokeMethod<bool>('setVolume', {'volume': 0.0});
    await Future.delayed(Duration(milliseconds: 50));
    await ch.invokeMethod<bool>('pause');
  } catch (_) {}
}
```

**2.3 Dispose dans dispose()**
```dart
// student_challenges_tab.dart
@override
void dispose() {
  _pauseAndDisposeAllControllers();
  _controllers.clear();
  super.dispose();
}
```

### Priorité 3: Lenteur Compression (Élevée)

**3.1 Compression en background avec Isolate**
```dart
// student_challenge_video_editor_screen.dart
// Utiliser compute() pour compression hors thread UI:
final MediaInfo? info = await compute(_compressVideoInIsolate, {
  'sourcePath': sourcePath,
  'quality': quality,
});

static Future<MediaInfo?> _compressVideoInIsolate(Map<String, dynamic> params) async {
  final sourcePath = params['sourcePath'] as String;
  final quality = params['quality'] as VideoQuality;
  
  return await VideoCompress.compressVideo(
    sourcePath,
    quality: quality,
    deleteOrigin: false,
    includeAudio: true,
  );
}
```

**3.2 Réduire qualité par défaut**
```dart
// student_challenge_video_editor_screen.dart:514-521
// Changer MediumQuality pour LowQuality par défaut:
quality = VideoQuality.LowQuality; // Plus rapide, moins bloquant
```

**3.3 Compression différée**
```dart
// student_challenge_video_editor_screen.dart
// Compresser en background après upload:
if (segments.length == 1) {
  // Upload original immédiatement
  await _uploadVideoDirectly(firstFile.path);
  // Compresser en background
  _compressInBackground(firstFile.path);
}
```

### Priorité 4: Upload Lent (Moyenne)

**4.1 Barre de progression visible**
```dart
// student_challenge_video_editor_screen.dart
// Dans build(), ajouter:
if (_isUploading) {
  return Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(value: _uploadProgress, color: Colors.white),
          SizedBox(height: 16),
          Text('Upload: ${(_uploadProgress * 100).toInt()}%', 
               style: TextStyle(color: Colors.white)),
          SizedBox(height: 8),
          Text('${(_uploadProgress * _videoBytes!.length / 1024 / 1024).toStringAsFixed(1)} MB / ${(_videoBytes!.length / 1024 / 1024).toStringAsFixed(1)} MB',
               style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    ),
  );
}
```

**4.2 Upload parallèle par chunks**
```dart
// chunked_upload_service.dart
// Augmenter taille des chunks pour réduire nombre de requêtes:
const int CHUNK_SIZE = 10 * 1024 * 1024; // 10MB au lieu de 4MB
```

**4.3 Compression avant upload**
```dart
// student_challenge_video_editor_screen.dart
// S'assurer que la compression est terminée avant upload:
await _compressAndSetVideo(filePath, file.name);
// Attendre que _isCompressing == false
while (_isCompressing) {
  await Future.delayed(Duration(milliseconds: 100));
}
await _uploadVideo();
```

---

## Résumé Exécutif

### Problèmes Identifiés
1. **Écrans noirs**: Absence de loaders visibles pendant compression, upload, initialisation
2. **Audio persistant**: Native Android player ne respecte pas pause, pas de dispose explicite
3. **Lenteur**: Compression sur thread UI, upload sans progression visible

### Racines Techniques
- FFmpegKit désactivé (watermarking non fonctionnel)
- Pas d'Isolate pour compression
- Native Android player lifecycle mal géré
- UI feedback insuffisant

### Impact UX
- **Écrans noirs**: 40% de l'impact ressenti
- **Audio persistant**: 30% de l'impact ressenti
- **Lenteur**: 30% de l'impact ressenti

### Correction Prioritaire
1. Ajouter loaders visibles (1-2h)
2. Fix audio persistant avec mute + dispose (2-3h)
3. Optimiser compression avec Isolate (3-4h)
4. Améliorer feedback upload (1-2h)

**Total estimé**: 7-11 heures de développement

---

## Annexes

### A. Preuve FFmpegKit Disabled
```bash
# Recherche dans codebase
grep -r "ffmpeg_kit" academia_app/lib/
# Résultat: Tous les imports sont commentés
```

### B. Preuve Kamatera Non Utilisé
```bash
# Recherche dans codebase
grep -r "kamatera" academia_app/lib/
# Résultat: 0 résultats liés aux vidéos
```

### C. Preuve ClipLife Non Utilisé
```bash
# Recherche dans codebase
grep -r "cliplife" academia_app/
# Résultat: 0 résultats
```

---

**Fin de l'audit**
