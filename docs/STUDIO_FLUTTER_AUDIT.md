# AUDIT FLUTTER STUDIO - PIPELINE VIDÉO

**Date :** 19 Juin 2026  
**Objectif :** Cartographier intégralement le pipeline vidéo côté Flutter

---

## 1. POINT D'ENTRÉE DU STUDIO

### Écran principal
**Fichier :** `lib/features/student/student_challenge_video_editor_screen.dart`

**Classe :** `StudentChallengeVideoEditorScreen`

**Constructeur :**
```dart
const StudentChallengeVideoEditorScreen({
  super.key,
  this.challengeId,
  this.participationId,
  this.initialMode,
  this.asAdditionalVideo = false,
  this.videoType = 'challenge',
  this.freeVideoId,
  this.initialSegments,
});
```

**Paramètres d'entrée :**
- `challengeId` : ID du challenge (optionnel)
- `participationId` : ID de la participation (optionnel)
- `initialMode` : Mode initial ('gallery', 'camera', etc.)
- `videoType` : Type de vidéo ('challenge' ou 'free')
- `freeVideoId` : ID de vidéo libre (optionnel)
- `initialSegments` : Segments vidéo déjà capturés (optionnel)

**Méthode d'initialisation :** `_handleInitialCaptureMode(String mode)`

---

## 2. FLUX COMPLET DU PIPELINE

### 2.1 Import vidéo

#### 2.1.1 Depuis la galerie
**Méthode :** `_pickVideo()`
**Fichier :** `lib/features/student/student_challenge_video_editor_screen.dart` (ligne 449)

**Étapes :**
1. Appel de `FilePicker.platform.pickFiles()` pour sélectionner un fichier
2. Lecture des bytes du fichier
3. Mise à jour de `_localVideoPath` avec le chemin du fichier
4. Appel de `_generateThumbnailInBackground()` pour générer la miniature
5. Appel de `_compressAndWatermarkInBackground()` pour compression et watermark en arrière-plan

#### 2.1.2 Depuis la caméra
**Méthode :** `_openCameraCaptureFlow()`
**Fichier :** `lib/features/student/student_challenge_video_editor_screen.dart` (ligne 294)

**Étapes :**
1. Navigation vers `ChallengeCameraCaptureScreen`
2. Récupération des segments capturés (`List<XFile>`)
3. Appel de `_processSegments()` pour traiter les segments

#### 2.1.3 Segments déjà capturés
**Méthode :** `_processSegments(List<XFile> segments)`
**Fichier :** `lib/features/student/student_challenge_video_editor_screen.dart` (ligne 242)

**Étapes :**
1. Mise à jour de `_capturedSegments`
2. Si 1 segment : affichage immédiat, compression en arrière-plan
3. Si plusieurs segments : affichage du dialogue de fusion

---

### 2.2 Prévisualisation

**Composant :** `AcademiaPlaybackEngine.view()`
**Fichier :** `lib/video/academia_playback_engine.dart`

**Paramètres :**
```dart
AcademiaPlaybackEngine.view(
  url: previewUrl,
  preferFlutterPlayer: false,
  autoplay: isLocalPreview,
  looping: isLocalPreview,
  muted: false,
  showControls: false,
  fit: BoxFit.cover,
  playbackController: _previewPlaybackController,
)
```

**Logique de prévisualisation :**
- Si `_localVideoPath` existe : URL locale (`file://`)
- Sinon si `_uploadedUrl` existe : URL distante
- `preferFlutterPlayer: false` force l'utilisation du player natif Android

**Player natif :** `AcademiaAndroidVideoView`
**Fichier :** `android/app/src/main/kotlin/com/academia/nexiomgroup/app/AcademiaAndroidVideoView.kt`

**Player Flutter fallback :** `video_player`
**Fichier :** `lib/video/academia_playback_view.dart`

---

### 2.3 Compression

**Méthode :** `_compressAndWatermarkInBackground()`
**Fichier :** `lib/features/student/student_challenge_video_editor_screen.dart` (ligne 688)

**Qui lance la compression :**
- `_pickVideo()` après sélection de vidéo depuis galerie
- `_processSegments()` après capture caméra (1 segment)

**Quand elle démarre :**
- Immédiatement après sélection/capture (non-bloquant)
- Exécution en arrière-plan (`Future`)

**Librairie utilisée :** `video_compress`
**Version :** `^3.1.3`

**Étapes de compression :**
1. Détection de l'orientation vidéo
2. Sélection de la qualité (HD ou Medium selon `_hdUpload`)
3. Appel de `VideoCompress.compressVideo()`
4. Validation du résultat
5. Appel de `WatermarkService.addWatermark()`
6. Validation du fichier watermarké (existe, taille > 0)
7. Mise à jour de `_localVideoPath` avec le chemin compressé
8. Mise à jour de `_videoBytes` avec les bytes compressés

**Est-elle bloquante :** Non (exécution en arrière-plan)

**Où elle s'exécute :** Sur le téléphone (Flutter/Dart)

---

### 2.4 Watermark

**Service :** `WatermarkService`
**Fichier :** `lib/games/services/watermark_service.dart`

**Méthode :** `addWatermark(String inputPath)`

**Librairie utilisée :** `ffmpeg_kit_flutter_new_audio`
**Version :** `^2.0.0`
**Statut :** Désactivé (commenté dans le code)

**Comportement actuel :**
- FFmpegKit est désactivé
- La méthode retourne simplement `inputPath` (pas de watermark réel)
- 3 niveaux de fallback définis mais non exécutés

---

### 2.5 Édition

#### 2.5.1 Overlays
**Service :** `OverlayBurnInService`
**Fichier :** `lib/video/overlay_burn_in_service.dart`

**Composant UI :** `_TimedStudioOverlaysLayer`
**Fichier :** `lib/widgets/video_overlays_layer.dart`

**Types d'overlays :**
- Texte
- Équations mathématiques
- AR 3D (si activé)
- Zones draggable

#### 2.5.2 Audio
**Service :** `AudioMixService`
**Fichier :** `lib/video/audio_mix_service.dart`

**Composant UI :** `AudioPickerSheet`, `DJMixSheet`

**Librairie utilisée :** `ffmpeg_kit_flutter_new_audio`
**Statut :** Non utilisé dans le flux actuel (commenté)

#### 2.5.3 Fusion de segments
**Service :** `VideoSegmentMergeService`
**Fichier :** `lib/services/video_segment_merge_service.dart`

**Méthode :** `mergeSegments()`

**Transitions supportées :**
- none (aucune)
- fade (fondu)
- dissolve (dissolution)
- slide (glissement)

**Implémentation :**
- Upload des segments vers Supabase Storage (bucket `video-assets`)
- Appel Edge Function `merge-video-segments`
- Récupération de l'URL fusionnée
- Cleanup des fichiers temporaires

---

### 2.6 Export

**Méthode :** `_uploadVideo()`
**Fichier :** `lib/features/student/student_challenge_video_editor_screen.dart` (ligne 882)

**Service :** `VideoAssetUploadService`
**Fichier :** `lib/services/videoasset_upload_service.dart`

**Étapes :**
1. Appel de `VideoAssetUploadService.ingestVideoFromBytes()`
2. Appel RPC `app_videoasset_create_upload_intent`
3. Upload chunké (si > 4MB) via `ChunkedUploadService`
4. Appel RPC `app_videoasset_register_uploaded_source`
5. Appel Edge Function `transcode-video`
6. Appel Edge Function `transcode-multi-resolution` (fire-and-forget)

---

### 2.7 Publication

**Méthode :** `_submitChallenge()`
**Fichier :** `lib/features/student/student_challenge_video_editor_screen.dart`

**Provider :** `StudentChallengesProvider`
**Fichier :** `lib/providers/student_challenges_provider.dart`

**RPC :** `app_student_submit_challenge`

**Paramètres :**
- `participation_id`
- `submission_text` (optionnel)
- `submission_url` (optionnel)

---

## 3. COMPOSANTS IMPLIQUÉS

### 3.1 Services vidéo

| Service | Fichier | Rôle |
|---------|---------|------|
| `VideoAssetUploadService` | `lib/services/videoasset_upload_service.dart` | Upload vidéo vers Supabase Storage |
| `StudioVideoService` | `lib/services/studio_video_service.dart` | Appel backend Docker pour burn overlays |
| `VideoSegmentMergeService` | `lib/services/video_segment_merge_service.dart` | Fusion de segments avec transitions |
| `WatermarkService` | `lib/games/services/watermark_service.dart` | Watermark TikTok-style (désactivé) |
| `AudioMixService` | `lib/video/audio_mix_service.dart` | Mixage audio (non utilisé) |
| `OverlayBurnInService` | `lib/video/overlay_burn_in_service.dart` | Burn overlays sur vidéo |
| `VideoOrientationService` | `lib/services/video_orientation_service.dart` | Détection orientation vidéo |
| `ChunkedUploadService` | `lib/services/chunked_upload_service.dart` | Upload chunké pour gros fichiers |

### 3.2 Providers

| Provider | Fichier | Rôle |
|----------|---------|------|
| `StudentChallengesProvider` | `lib/providers/student_challenges_provider.dart` | Gestion challenges et participations |

### 3.3 Controllers

| Controller | Fichier | Rôle |
|------------|---------|------|
| `AcademiaPlaybackController` | `lib/video/academia_playback_engine.dart` | Contrôle playback vidéo |

### 3.4 Widgets

| Widget | Fichier | Rôle |
|--------|---------|------|
| `StudentChallengeVideoEditorScreen` | `lib/features/student/student_challenge_video_editor_screen.dart` | Écran principal Studio |
| `AcademiaPlaybackView` | `lib/video/academia_playback_view.dart` | Vue playback vidéo |
| `AcademiaPlaybackEngine` | `lib/video/academia_playback_engine.dart` | Facade pour playback |
| `_TimedStudioOverlaysLayer` | `lib/widgets/video_overlays_layer.dart` | Layer overlays |
| `_DraggableZonesLayer` | `lib/widgets/video_overlays_layer.dart` | Layer zones draggable |
| `AudioPickerSheet` | `lib/widgets/audio_picker_sheet.dart` | Sélection audio |
| `DJMixSheet` | `lib/widgets/dj_mix_sheet.dart` | Mixage audio |
| `EquationEditor` | `lib/widgets/equation_editor.dart` | Éditeur équations |

### 3.5 Repositories

Aucun repository spécifique pour le Studio. Les données sont gérées via :
- Supabase RPC
- Supabase Storage
- Edge Functions

---

## 4. LIBRAIRIES VIDÉO UTILISÉES

| Librairie | Version | Rôle exact | Point d'appel | Fichier | Classe | Méthode |
|-----------|---------|------------|---------------|---------|--------|---------|
| `video_compress` | `^3.1.3` | Compression vidéo locale | `_compressAndWatermarkInBackground()` | `student_challenge_video_editor_screen.dart` | `VideoCompress` | `compressVideo()` |
| `ffmpeg_kit_flutter_new_audio` | `^2.0.0` | Watermark et audio mix | `WatermarkService.addWatermark()` | `watermark_service.dart` | `FFmpegKit` | `executeWithArguments()` (désactivé) |
| `video_player` | `^2.10.1` | Playback vidéo Flutter (fallback) | `AcademiaPlaybackView._init()` | `academia_playback_view.dart` | `VideoPlayerController` | `initialize()` |
| `camera` | `^0.11.0` | Capture vidéo caméra | `ChallengeCameraCaptureScreen` | `challenge_camera_capture_screen.dart` | `CameraController` | `startVideoRecording()` |
| `video_thumbnail` | `^0.5.6` | Génération miniature | `_generateThumbnailInBackground()` | `student_challenge_video_editor_screen.dart` | `VideoThumbnail` | `thumbnailData()` |
| `easy_video_editor` | `^0.1.3` | Édition vidéo (non utilisé) | - | - | - | - |
| `pro_video_editor` | `^1.6.1` | Édition vidéo avancée (non utilisé) | - | - | - | - |
| `cached_video_player_plus` | `^4.1.0` | Cache vidéo (non utilisé) | - | - | - | - |
| `tiktoklikescroller` | `^0.2.8` | Scroll TikTok-style (feed) | `student_challenges_tab.dart` | `TikTokLikescroller` | - | - |

### 4.1 ExoPlayer (Native Android)

| Librairie | Version | Rôle exact | Point d'appel | Fichier | Classe | Méthode |
|-----------|---------|------------|---------------|---------|--------|---------|
| `androidx.media3` | - | Playback natif Android | `AcademiaPlaybackView.build()` | `AcademiaAndroidVideoView.kt` | `ExoPlayer` | `setMediaItem()` |

**Fichier :** `android/app/src/main/kotlin/com/academia/nexiomgroup/app/AcademiaAndroidVideoView.kt`

**Configuration :**
- `DefaultDataSource.Factory` pour gérer file://, content://, http/https
- `CacheDataSource` pour cache disque (200 MB)
- `DefaultRenderersFactory` avec codec selector safe (skip MediaTek)
- `DefaultLoadControl` avec buffer agressif (TikTok-style)

---

## 5. QUI LANCE LA COMPRESSION ET QUAND

### 5.1 Qui lance la compression

**Méthode :** `_compressAndWatermarkInBackground()`
**Appelée par :**
1. `_pickVideo()` - après sélection de vidéo depuis galerie
2. `_processSegments()` - après capture caméra (1 segment)

### 5.2 Quand elle démarre

**Immédiatement après :**
- Sélection de fichier depuis galerie
- Capture caméra (1 segment)

**Non-bloquant :** Exécution en arrière-plan via `Future`

### 5.3 Quand elle se termine

**Après :**
- Compression réussie ou échouée
- Watermark appliqué (ou fallback vers source)
- Validation fichier (existe, taille > 0)
- Mise à jour de `_localVideoPath` et `_videoBytes`

### 5.4 Est-elle bloquante

**Non** - Exécution en arrière-plan, UI reste responsive

### 5.5 Où elle s'exécute

**Sur le téléphone** - Flutter/Dart avec librairie native `video_compress`

### 5.6 Est-elle exécutée sur un service distant

**Non** - Compression locale uniquement

---

## 6. DIAGRAMME DÉTAILLÉ DU PIPELINE ACTUEL

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           UTILISATEUR                                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
            ┌───────▼────────┐              ┌───────▼────────┐
            │  GALERIE       │              │  CAMÉRA        │
            └───────┬────────┘              └───────┬────────┘
                    │                               │
            ┌───────▼───────────────────────────────▼────────┐
            │  StudentChallengeVideoEditorScreen           │
            │  (_pickVideo ou _processSegments)             │
            └───────┬───────────────────────────────┬────────┘
                    │                               │
            ┌───────▼────────┐              ┌───────▼────────┐
            │  Affichage      │              │  Fusion         │
            │  immédiat      │              │  segments       │
            │  (preview)     │              │  (si >1)        │
            └───────┬────────┘              └───────┬────────┘
                    │                               │
            ┌───────▼───────────────────────────────▼────────┐
            │  _compressAndWatermarkInBackground            │
            │  (arrière-plan, non-bloquant)                 │
            └───────┬───────────────────────────────┬────────┘
                    │                               │
            ┌───────▼────────┐              ┌───────▼────────┐
            │  VideoCompress │              │  Watermark      │
            │  (local)       │              │  (désactivé)    │
            └───────┬────────┘              └───────┬────────┘
                    │                               │
            ┌───────▼───────────────────────────────▼────────┐
            │  Validation (fichier existe, taille > 0)       │
            └───────┬───────────────────────────────┬────────┘
                    │                               │
            ┌───────▼────────┐              ┌───────▼────────┐
            │  Update state  │              │  Fallback       │
            │  (_localVideo  │              │  vers source    │
            │  Path)         │              │                 │
            └───────┬────────┘              └───────┬────────┘
                    │                               │
            ┌───────▼───────────────────────────────▼────────┐
            │  AcademiaPlaybackEngine.view (preview)         │
            │  - Android: ExoPlayer (natif)                  │
            │  - iOS/Web: video_player (fallback)             │
            └───────┬───────────────────────────────┬────────┘
                    │                               │
            ┌───────▼────────┐              ┌───────▼────────┐
            │  Édition        │              │  Publication    │
            │  (overlays,     │              │  (_submit)      │
            │  audio, AR)     │              │                 │
            └───────┬────────┘              └───────┬────────┘
                    │                               │
            ┌───────▼───────────────────────────────▼────────┐
            │  _uploadVideo                                   │
            │  VideoAssetUploadService.ingestVideoFromBytes  │
            └───────┬───────────────────────────────┬────────┘
                    │                               │
            ┌───────▼────────┐              ┌───────▼────────┐
            │  RPC create    │              │  Upload chunké │
            │  upload intent │              │  (>4MB)         │
            └───────┬────────┘              └───────┬────────┘
                    │                               │
            ┌───────▼───────────────────────────────▼────────┐
            │  RPC register uploaded source                 │
            └───────┬───────────────────────────────┬────────┘
                    │                               │
            ┌───────▼────────┐              ┌───────▼────────┐
            │  Edge Function  │              │  Edge Function  │
            │  transcode-video│              │  transcode-multi │
            │  (original)     │              │  (720p,480p,240p)│
            └───────┬────────┘              └───────┬────────┘
                    │                               │
            ┌───────▼───────────────────────────────▼────────┐
            │  RPC submitChallenge                           │
            │  StudentChallengesProvider.submitChallenge      │
            └───────┬───────────────────────────────┬────────┘
                    │                               │
            ┌───────▼────────┐              ┌───────▼────────┐
            │  Supabase DB   │              │  Supabase      │
            │  (participations│              │  Storage       │
            │  ,videos)       │              │  (video-assets) │
            └────────────────┘              └────────────────┘
```

---

## 7. OBSERVATIONS CRITIQUES

### 7.1 Watermark désactivé
- FFmpegKit est présent mais désactivé dans le code
- Le watermark ne fonctionne pas réellement
- La méthode retourne simplement le fichier source

### 7.2 Compression locale uniquement
- Pas de service distant pour la compression
- Tout se passe sur le téléphone
- Peut impacter les performances sur les appareils bas de gamme

### 7.3 Audio mix non utilisé
- `AudioMixService` existe mais n'est pas intégré dans le flux
- FFmpegKit pour audio est désactivé

### 7.4 Éditeurs vidéo non utilisés
- `easy_video_editor` et `pro_video_editor` sont dans pubspec.yaml mais non utilisés
- L'édition se fait via overlays et fusion de segments uniquement

### 7.5 Transcodage backend
- Le transcodage se fait via Edge Functions Supabase
- Pas de service d'encodage sur Kamatera identifié dans le code Flutter

---

**Statut :** ✅ PHASE A TERMINÉE
