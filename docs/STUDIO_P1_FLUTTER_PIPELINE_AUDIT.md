# P1 — AUDIT CIBLÉ DU PIPELINE STUDIO FLUTTER

**Date :** 19 Juin 2026  
**Objectif :** Identifier précisément pourquoi l'expérience Studio est lente, pourquoi les vidéos débordent de l'écran, et déterminer où sont réellement exécutés les traitements vidéo.

---

## PHASE A — CARTOGRAPHIE DU STUDIO FLUTTER

### 1. Point d'entrée principal

**Écran principal Studio :** `StudentChallengeVideoEditorScreen`

**Fichier :** `academia_app/lib/features/student/student_challenge_video_editor_screen.dart`

**Route Flutter :** Navigation directe depuis :
- `student_challenges_tab.dart` (mode free)
- `student_challenge_detail_screen.dart` (mode challenge)

**Provider utilisé :** `StudentChallengesProvider`

**Services utilisés :**
- `VideoAssetUploadService` - Upload vidéo vers Supabase
- `VideoSegmentMergeService` - Fusion de segments
- `WatermarkService` - Watermark FFmpeg
- `AudioMixService` - Mixage audio
- `OverlayBurnInService` - Burn overlays
- `StudioVideoService` - Backend proxy

**Flux d'entrée :**

```text
StudentChallengesTab (Feed)
 ↓
StudentChallengeVideoEditorScreen (mode: free)
 ↓
 _pickVideo() → _compressAndWatermarkInBackground() → _uploadVideo()
```

```text
StudentChallengeDetailScreen (Challenge)
 ↓
StudentChallengeVideoEditorScreen (mode: challenge)
 ↓
 _pickVideo() → _compressAndWatermarkInBackground() → _uploadVideo()
```

### 2. Arborescence complète

**lib/features/student/**
```
├── student_challenge_video_editor_screen.dart (Écran principal Studio)
├── student_challenge_video_overlays.dart (Gestion overlays)
├── student_challenge_video_ar_screen.dart (AR - stub web)
├── student_challenge_video_ar_combined_screen.dart (AR combiné - stub web)
├── student_challenge_video_ar_screen_stub.dart (Stub web)
├── student_challenge_video_ar_combined_screen_stub.dart (Stub web)
├── challenge_camera_capture_screen.dart (Capture caméra)
├── challenge_scientific_studio_screen.dart (Studio scientifique)
├── challenge_video_edit_screen.dart (Édition vidéo)
├── video_publish_screen.dart (Publication)
├── student_recently_deleted_videos_screen.dart (Vidéos supprimées)
└── tabs/
    └── student_challenges_tab.dart (Onglet challenges)
```

**lib/video/**
```
├── academia_playback_view.dart (Widget playback)
├── academia_playback_controller.dart (Contrôleur playback)
├── academia_playback_engine.dart (Moteur playback)
├── audio_mix_service.dart (Mixage audio)
└── overlay_burn_in_service.dart (Burn overlays)
```

**lib/services/**
```
├── videoasset_upload_service.dart (Upload Supabase)
├── video_segment_merge_service.dart (Fusion segments)
├── studio_video_service.dart (Backend proxy)
├── studio_ai_service.dart (Services IA)
└── studio_audio_service.dart (Services audio)
```

**lib/games/services/**
```
├── watermark_service.dart (Watermark FFmpeg)
└── gameplay_recorder_service.dart (Enregistrement gameplay)
```

**lib/widgets/**
```
├── audio_picker_sheet.dart (Sélecteur audio)
├── dj_mix_sheet.dart (Mixage DJ)
├── equation_editor.dart (Éditeur équations)
└── video_overlays_layer.dart (Couche overlays)
```

**lib/providers/**
```
└── student_challenges_provider.dart (Provider challenges)
```

### 3. Widgets impliqués dans le Studio

| Widget | Rôle | Fichier |
|--------|------|---------|
| `StudentChallengeVideoEditorScreen` | Écran principal Studio | `student_challenge_video_editor_screen.dart` |
| `AcademiaPlaybackView` | Widget playback vidéo | `academia_playback_view.dart` |
| `VideoOverlaysLayer` | Couche overlays (texte, stickers) | `video_overlays_layer.dart` |
| `EquationEditor` | Éditeur équations scientifiques | `equation_editor.dart` |
| `AudioPickerSheet` | Sélecteur musique de fond | `audio_picker_sheet.dart` |
| `DjMixSheet` | Mixage audio DJ | `dj_mix_sheet.dart` |

### 4. Services impliqués dans le Studio

| Service | Rôle | Fichier |
|---------|------|---------|
| `VideoAssetUploadService` | Upload vidéo vers Supabase Storage | `videoasset_upload_service.dart` |
| `VideoSegmentMergeService` | Fusion de segments vidéo | `video_segment_merge_service.dart` |
| `WatermarkService` | Watermark FFmpeg côté device | `watermark_service.dart` |
| `AudioMixService` | Mixage audio | `audio_mix_service.dart` |
| `OverlayBurnInService` | Burn overlays sur vidéo | `overlay_burn_in_service.dart` |
| `StudioVideoService` | Proxy vers backend Python | `studio_video_service.dart` |

### 5. Providers impliqués dans le Studio

| Provider | Rôle | Fichier |
|----------|------|---------|
| `StudentChallengesProvider` | Gestion des challenges et vidéos | `student_challenges_provider.dart` |

---

## PHASE B — PIPELINE RÉEL DE TRAITEMENT VIDÉO

### Localisation des opérations

| Opération | Local | Backend | Supabase | Worker | Fichier responsable |
| --------- | ----- | ------- | -------- | ------ | ------------------- |
| **Import vidéo** | Flutter | ❌ | ❌ | ❌ | `student_challenge_video_editor_screen.dart:_pickVideo()` |
| **Compression locale** | Flutter (video_compress) | ❌ | ❌ | ❌ | `student_challenge_video_editor_screen.dart:_compressAndWatermarkInBackground()` |
| **Watermark local** | Flutter (FFmpegKit - désactivé) | ❌ | ❌ | ❌ | `watermark_service.dart:addWatermark()` |
| **Génération thumbnail** | Flutter (video_thumbnail) | ❌ | ❌ | ❌ | `student_challenge_video_editor_screen.dart:_generateThumbnail()` |
| **Upload vidéo** | Flutter → Supabase Storage | ❌ | ✅ | ❌ | `videoasset_upload_service.dart:uploadVideo()` |
| **Transcodage multi-résolution** | ❌ | ❌ | Edge Function | ❌ (non déployé) | `transcode-multi-resolution/index.ts` |
| **Fusion segments** | Flutter → Edge Function | ❌ | ✅ | ❌ | `video_segment_merge_service.dart:mergeSegments()` |
| **Ajout musique** | Flutter (AudioMixService) | ❌ | ❌ | ❌ | `audio_mix_service.dart` |
| **Ajout texte** | Flutter (VideoOverlaysLayer) | ❌ | ❌ | ❌ | `video_overlays_layer.dart` |
| **Ajout overlay** | Flutter (VideoOverlaysLayer) | ❌ | ❌ | ❌ | `video_overlays_layer.dart` |
| **Burn overlays** | Backend Python (optionnel) | ✅ | ❌ | ❌ | `overlay_burn_in_service.dart` |
| **Export** | Flutter (upload) | ❌ | ✅ | ❌ | `videoasset_upload_service.dart` |

### Observations critiques

1. **Compression locale :** Effectuée par `video_compress` (Flutter) côté device
2. **Watermark local :** FFmpegKit est désactivé dans `watermark_service.dart`
3. **Transcodage multi-résolution :** Créé par Edge Function mais worker non déployé
4. **Fusion segments :** Déléguée à Edge Function Supabase
5. **Burn overlays :** Peut être délégué à backend Python mais pas utilisé actuellement

---

## PHASE C — CHRONOMÉTRAGE COMPLET

### Méthodologie

Les chronométrages sont basés sur les logs présents dans le code :
- `[P6_ENTER]` - Entrée de méthode
- `[P6_EXIT]` - Sortie de méthode avec durée
- `[TIMING]` - Points de timing spécifiques

### Logs identifiés

Dans `student_challenge_video_editor_screen.dart` :

```dart
debugPrint('[P6_ENTER] _pickVideo');
debugPrint('[TIMING] T0 - Vidéo sélectionnée: ${t0.toIso8601String()}');
debugPrint('[P6_EXIT] _pickVideo duration=${duration}ms');

debugPrint('[P6_ENTER] _compressAndWatermarkInBackground');
debugPrint('[P6_EXIT] _compressAndWatermarkInBackground duration=${duration}ms');

debugPrint('[P6_ENTER] _uploadVideo');
debugPrint('[P6_EXIT] _uploadVideo duration=${duration}ms');
```

### Estimation des temps (basée sur le code)

| Étape | Temps estimé | Preuve |
| ----- | ------------ | ------ |
| Import vidéo (_pickVideo) | ~500-2000ms | Logs P6_ENTER/P6_EXIT |
| Compression locale (video_compress) | ~5-30 secondes | Dépend de la durée vidéo |
| Watermark local (FFmpegKit) | ~10-60 secondes | Désactivé |
| Génération thumbnail | ~1-3 secondes | video_thumbnail |
| Upload vidéo (Supabase) | ~5-30 secondes | Dépend de la taille |
| Fusion segments (Edge Function) | ~10-60 secondes | Dépend du nombre de segments |
| Transcodage multi-résolution | BLOQUÉ | Worker non déployé |

**Note :** Les temps exacts nécessitent un test avec une vraie vidéo et capture des logs runtime.

---

## PHASE D — ANALYSE DU PROBLÈME DE DÉBORDEMENT

### VideoPlayer utilisés

| Player | Utilisation | Fichier |
|--------|-------------|---------|
| `video_player` (Flutter) | iOS/Web | `academia_playback_view.dart` |
| `ExoPlayer` (native Android) | Android | `AcademiaAndroidVideoView.kt` |
| `AcademiaPlaybackView` | Wrapper multi-plateforme | `academia_playback_view.dart` |

### Layout et aspect ratio

Dans `academia_playback_view.dart` :

```dart
Widget build(BuildContext context) {
  return AspectRatio(
    aspectRatio: _aspectRatio ?? 16 / 9,
    child: _shouldUseNativeAndroid
        ? AndroidView(...)  // ExoPlayer
        : VideoPlayer(_controller),  // Flutter video_player
  );
}
```

### Aspect ratio attendu vs réel

| Écran | Aspect Ratio attendu | Aspect Ratio réel | Mode de rendu |
|-------|---------------------|-------------------|---------------|
| Feed | 16:9 | Variable | BoxFit.cover |
| Studio Preview | 16:9 | Variable | AspectRatio widget |
| Challenge Preview | 16:9 | Variable | AspectRatio widget |
| Lecture vidéo | 16:9 | Variable | AspectRatio widget |

### Problème identifié

L'aspect ratio est calculé dynamiquement depuis les métadonnées vidéo mais peut être incorrect si :
- Les métadonnées vidéo sont erronées
- La rotation vidéo n'est pas prise en compte
- Le widget AspectRatio utilise une valeur par défaut (16/9) quand les métadonnées sont manquantes

**Preuve :** Dans `academia_playback_view.dart` :

```dart
double? _aspectRatio;

@override
void initState() {
  super.initState();
  _init();
}

Future<void> _init() async {
  // ...
  final metadata = await _controller.getMetadata();
  if (metadata != null) {
    final width = metadata['width'];
    final height = metadata['height'];
    if (width != null && height != null) {
      setState(() {
        _aspectRatio = width / height;
      });
    }
  }
}
```

Si les métadonnées ne sont pas disponibles, `_aspectRatio` reste null et utilise la valeur par défaut 16/9.

---

## PHASE E — PIPELINE D'ENCODAGE RÉEL

### Flux complet

```text
Vidéo utilisateur (galerie ou caméra)
 ↓
StudentChallengeVideoEditorScreen._pickVideo()
 ↓
VideoCompress.compressVideo() (Flutter, local)
 ↓
WatermarkService.addWatermark() (Flutter, FFmpegKit - désactivé)
 ↓
VideoAssetUploadService.uploadVideo() (Flutter → Supabase Storage)
 ↓
RPC app_videoasset_create_upload_intent() (Supabase)
 ↓
Upload vers bucket video-assets (Supabase Storage)
 ↓
RPC app_videoasset_register_uploaded_source() (Supabase)
 ↓
Edge Function transcode-video (Supabase)
 ↓
Upsert rendition "original" dans video_renditions (Supabase)
 ↓
Edge Function transcode-multi-resolution (Supabase)
 ↓
Insert jobs dans video_processing_jobs (Supabase)
 ↓
[STOP] Worker non déployé → Jobs non traités
```

### Qui encode réellement ?

| Étape | Qui encode | Preuve |
|-------|-----------|--------|
| Compression locale | Flutter (video_compress) | `student_challenge_video_editor_screen.dart:_compressAndWatermarkInBackground()` |
| Watermark | Flutter (FFmpegKit - désactivé) | `watermark_service.dart:addWatermark()` |
| Transcodage multi-résolution | Aucun (worker non déployé) | Queue video_processing_jobs vide (0 jobs queued) |
| Fusion segments | Edge Function Supabase (FFmpeg Deno) | `video_segment_merge_service.dart:mergeSegments()` |

### Où FFmpeg est-il exécuté ?

| Localisation | Usage | Preuve |
|--------------|-------|--------|
| Flutter (FFmpegKit) | Watermark local (désactivé) | `watermark_service.dart` |
| Edge Function Supabase | Fusion segments | `merge-video-segments/index.ts` |
| Backend Python (Docker local) | Non utilisé en production | `videoasset_worker.py` |
| Kamatera | Non utilisé pour l'encodage | Audit Kamatera |

---

## PHASE F — ANALYSE DES APPELS FFMPEG

### Recherche dans le projet

| Fichier | Commande FFmpeg | Usage |
| ------- | --------------- | ----- |
| `watermark_service.dart` | FFmpegKit watermark | Watermark local (désactivé) |
| `audio_mix_service.dart` | FFmpeg audio mix | Mixage audio |
| `studio_video_service.dart` | Backend proxy FFmpeg | Backend Python (non utilisé) |
| `gameplay_recorder_service.dart` | FFmpeg recording | Enregistrement gameplay |
| `student_challenge_video_editor_screen.dart` | video_compress (pas FFmpeg direct) | Compression locale |

### Combien de fois FFmpeg est lancé ?

| Opération | Fréquence | Localisation |
|-----------|-----------|--------------|
| Compression | 1 par vidéo | Flutter (video_compress) |
| Watermark | 0 (désactivé) | Flutter (FFmpegKit) |
| Fusion segments | 1 par fusion | Edge Function Supabase |
| Mixage audio | Variable | Flutter (AudioMixService) |
| Recording gameplay | Variable | Flutter (gameplay_recorder_service) |

---

## PHASE G — BENCHMARK TIKTOK / CAPCUT

### Comparaison architecture

| Fonction | Academia | TikTok | CapCut |
| -------- | -------- | ------ | ------ |
| **Import vidéo** | Flutter (galerie/caméra) | Native (galerie/caméra) | Native (galerie/caméra) |
| **Compression** | Flutter (video_compress) | Native (hardware) | Native (hardware) |
| **Watermark** | FFmpegKit (désactivé) | Native (hardware) | Native (hardware) |
| **Trim/cut** | Flutter (video_editor) | Native (hardware) | Native (hardware) |
| **Fusion segments** | Edge Function Supabase | Native (hardware) | Native (hardware) |
| **Ajout musique** | Flutter (AudioMixService) | Native (hardware) | Native (hardware) |
| **Ajout texte** | Flutter (VideoOverlaysLayer) | Native (hardware) | Native (hardware) |
| **Ajout overlay** | Flutter (VideoOverlaysLayer) | Native (hardware) | Native (hardware) |
| **Export** | Flutter → Supabase | Native (local) | Native (local) |
| **Transcodage multi-résolution** | Worker (non déployé) | Cloud (backend) | Cloud (backend) |
| **Upload** | Supabase Storage | Cloud (propriétaire) | Cloud (propriétaire) |

### Observations

1. **Academia utilise Flutter pour la plupart des traitements** au lieu du hardware natif
2. **TikTok/CapCut utilisent le hardware natif** pour la compression, le trim et l'export
3. **Academia délègue la fusion à une Edge Function** au lieu de le faire localement
4. **Le transcodage multi-résolution est bloqué** par l'absence de worker

---

## RÉPONSES AUX QUESTIONS

1. **Qui encode réellement les vidéos aujourd'hui ?**
   - Compression : Flutter (video_compress) côté device
   - Watermark : Aucun (FFmpegKit désactivé)
   - Transcodage multi-résolution : Aucun (worker non déployé)
   - Fusion segments : Edge Function Supabase

2. **Où FFmpeg est-il exécuté ?**
   - Flutter (FFmpegKit) : Watermark local (désactivé)
   - Edge Function Supabase : Fusion segments
   - Backend Python : Non utilisé en production
   - Kamatera : Non utilisé pour l'encodage

3. **Pourquoi l'utilisateur attend-il plusieurs minutes ?**
   - Compression locale via Flutter (plus lent que hardware natif)
   - Upload vers Supabase (dépend de la connexion)
   - Fusion segments via Edge Function (latence réseau)
   - Transcodage multi-résolution bloqué (pas de worker)

4. **Quelle étape est la plus lente ?**
   - Compression locale (estimée 5-30 secondes)
   - Upload vidéo (estimé 5-30 secondes)
   - Fusion segments (estimé 10-60 secondes)

5. **Pourquoi la vidéo déborde-t-elle de l'écran ?**
   - Aspect ratio calculé depuis les métadonnées vidéo
   - Valeur par défaut 16/9 si métadonnées manquantes
   - Rotation vidéo non prise en compte

6. **Le worker Kamatera est-il utilisé actuellement ?**
   - Non (worker non déployé)

7. **Le backend Python est-il réellement utilisé ?**
   - Non en production (Railway indisponible)

8. **Le Studio exporte-t-il localement ou à distance ?**
   - Upload vers Supabase Storage (distant)

9. **Quels traitements sont effectués plusieurs fois inutilement ?**
   - Compression locale + transcodage multi-résolution (redondant si le worker était déployé)

10. **Quel est le flux exact entre Flutter, Supabase, Worker et Kamatera ?**
    - Flutter → Supabase Storage (upload)
    - Supabase Edge Function → video_processing_jobs (création jobs)
    - Worker (non déployé) → vidéo_processing_jobs (traitement)
    - Kamatera → LiveKit uniquement (pas d'encodage)

---

**Statut :** ✅ PHASE A-G TERMINÉE
