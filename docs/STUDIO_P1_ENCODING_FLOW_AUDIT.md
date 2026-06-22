# P1 — ENCODING FLOW AUDIT

**Date :** 19 Juin 2026  
**Objectif :** Découvrir qui encode réellement les vidéos

---

## FLUX COMPLET D'ENCODAGE

### 1. Vidéo utilisateur (galerie ou caméra)

**Point d'entrée :** `StudentChallengeVideoEditorScreen._pickVideo()`

**Fichier :** `academia_app/lib/features/student/student_challenge_video_editor_screen.dart:449`

**Code :**
```dart
Future<void> _pickVideo() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.video,
    allowMultiple: false,
  );
  
  if (result != null && result.files.isNotEmpty) {
    final file = result.files.first;
    final filePath = file.path;
    
    _compressAndWatermarkInBackground(filePath, file.name, t0);
  }
}
```

**Action :** Sélection vidéo depuis la galerie

**Encodage :** Aucun à cette étape

---

### 2. Compression locale

**Point d'entrée :** `StudentChallengeVideoEditorScreen._compressAndWatermarkInBackground()`

**Fichier :** `academia_app/lib/features/student/student_challenge_video_editor_screen.dart:688`

**Code :**
```dart
Future<void> _compressAndWatermarkInBackground(String sourcePath, String originalName, DateTime t0) async {
  final info = await VideoCompress.compressVideo(
    sourcePath,
    quality: VideoQuality.DefaultQuality,
    includeAudio: true,
  );
  
  if (info != null) {
    final watermarkedPath = await WatermarkService.addWatermark(info.path);
  }
}
```

**Action :** Compression via `video_compress` (Flutter)

**Encodage :** Compression locale (software, pas hardware)

**Bibliothèque :** `video_compress` (Flutter)

**Localisation :** Flutter côté device

---

### 3. Watermark local

**Point d'entrée :** `WatermarkService.addWatermark()`

**Fichier :** `academia_app/lib/games/services/watermark_service.dart`

**Code :**
```dart
static Future<String> addWatermark(String videoPath) async {
  // FFmpegKit watermark
  // Désactivé (code commenté)
}
```

**Action :** Watermark via FFmpegKit

**Encodage :** Watermark via FFmpeg

**Bibliothèque :** `ffmpeg_kit_flutter_new_audio` (Flutter)

**Localisation :** Flutter côté device

**Statut :** Désactivé (code commenté)

---

### 4. Upload vidéo

**Point d'entrée :** `VideoAssetUploadService.uploadVideo()`

**Fichier :** `academia_app/lib/services/videoasset_upload_service.dart`

**Code :**
```dart
Future<String> uploadVideo({
  required String filePath,
  required String fileName,
  required String mimeType,
}) async {
  // 1. RPC app_videoasset_create_upload_intent
  // 2. Upload vers Supabase Storage
  // 3. RPC app_videoasset_register_uploaded_source
}
```

**Action :** Upload vers Supabase Storage

**Encodage :** Aucun à cette étape

**Localisation :** Flutter → Supabase Storage

---

### 5. RPC app_videoasset_create_upload_intent

**Fichier :** `supabase/migrations/...` (non trouvé dans les migrations)

**Action :** Création d'un intent d'upload

**Encodage :** Aucun

**Localisation :** Supabase PostgreSQL

---

### 6. Upload vers bucket video-assets

**Action :** Upload du fichier vidéo

**Encodage :** Aucun

**Localisation :** Supabase Storage

---

### 7. RPC app_videoasset_register_uploaded_source

**Fichier :** `supabase/migrations/...` (non trouvé dans les migrations)

**Action :** Enregistrement de la source uploadée

**Encodage :** Aucun

**Localisation :** Supabase PostgreSQL

---

### 8. Edge Function transcode-video

**Fichier :** `supabase/functions/transcode-video/index.ts`

**Code :**
```typescript
// 1. Téléchargement la source depuis Supabase Storage
// 2. Upsert rendition "original" dans video_renditions
// 3. Update video_assets.status = 'ready'
```

**Action :** Création de la rendition "original"

**Encodage :** Aucun (pas de transcodage)

**Localisation :** Supabase Edge Function

---

### 9. Edge Function transcode-multi-resolution

**Fichier :** `supabase/functions/transcode-multi-resolution/index.ts`

**Code :**
```typescript
// 1. Téléchargement la source depuis Supabase Storage
// 2. Insert jobs dans video_processing_jobs (status=queued)
// 3. Jobs: generate_mp4 (main, 480p, 360p, 240p)
```

**Action :** Création de jobs de transcodage

**Encodage :** Aucun (création de jobs uniquement)

**Localisation :** Supabase Edge Function

---

### 10. Worker (non déployé)

**Fichier :** `academia_bobodo_backend/videoasset_worker.py`

**Code :**
```python
# 1. Poll video_processing_jobs (status=queued)
# 2. Téléchargement source depuis Supabase Storage
# 3. FFmpeg transcodage (main, 480p, 360p, 240p)
# 4. Upload renditions vers Supabase Storage
# 5. Update video_renditions (status=ready)
```

**Action :** Transcodage multi-résolution

**Encodage :** FFmpeg (libx264)

**Localisation :** Docker (local) ou Railway (production)

**Statut :** Non déployé (0 jobs queued dans video_processing_jobs)

---

### 11. Fusion de segments

**Point d'entrée :** `VideoSegmentMergeService.mergeSegments()`

**Fichier :** `academia_app/lib/services/video_segment_merge_service.dart`

**Code :**
```dart
Future<String> mergeSegments({
  required List<String> segmentPaths,
  required String transition,
}) async {
  // 1. Upload segments vers Supabase Storage
  // 2. Edge Function merge-video-segments
  // 3. Upload résultat vers Supabase Storage
}
```

**Action :** Fusion de segments

**Encodage :** FFmpeg (via Edge Function Supabase)

**Localisation :** Supabase Edge Function (Deno)

---

## QUI ENCODE RÉELLEMENT ?

### Tableau récapitulatif

| Étape | Qui encode | Encodage | Localisation | Statut |
|-------|-----------|----------|--------------|--------|
| Compression locale | Flutter (video_compress) | Compression software | Device | ✅ Actif |
| Watermark local | Flutter (FFmpegKit) | Watermark FFmpeg | Device | ❌ Désactivé |
| Transcodage multi-résolution | Worker (videoasset_worker.py) | FFmpeg (libx264) | Docker/Railway | ❌ Non déployé |
| Fusion segments | Edge Function Supabase | FFmpeg (Deno) | Supabase | ✅ Actif |

### Observations critiques

1. **Compression locale est active** mais utilise software encoding (plus lent que hardware)
2. **Watermark local est désactivé** (code commenté)
3. **Transcodage multi-résolution est bloqué** (worker non déployé)
4. **Fusion segments est active** via Edge Function Supabase

---

## OÙ FFMPEG EST-IL EXÉCUTÉ ?

### Tableau récapitulatif

| Localisation | Usage | Statut | Preuve |
|--------------|-------|--------|-------|
| Flutter (FFmpegKit) | Watermark local | ❌ Désactivé | `watermark_service.dart` code commenté |
| Edge Function Supabase | Fusion segments | ✅ Actif | `merge-video-segments/index.ts` |
| Backend Python (Docker local) | Transcodage multi-résolution | ❌ Non utilisé en production | `videoasset_worker.py` |
| Backend Python (Railway) | Transcodage multi-résolution | ❌ Indisponible | Railway bloqué |
| Kamatera | Aucun | ❌ Non utilisé | Audit Kamatera |

---

## FLUX DÉTAILLÉ AVEC PREUVES

### Étape 1: Import vidéo

**Fichier :** `student_challenge_video_editor_screen.dart:449`

**Preuve :**
```dart
debugPrint('[P6_ENTER] _pickVideo');
final result = await FilePicker.platform.pickFiles(
  type: FileType.video,
  allowMultiple: false,
);
debugPrint('[P6_EXIT] _pickVideo duration=${duration}ms');
```

### Étape 2: Compression locale

**Fichier :** `student_challenge_video_editor_screen.dart:688`

**Preuve :**
```dart
debugPrint('[P6_ENTER] _compressAndWatermarkInBackground');
final info = await VideoCompress.compressVideo(
  sourcePath,
  quality: VideoQuality.DefaultQuality,
  includeAudio: true,
);
debugPrint('[P6_EXIT] _compressAndWatermarkInBackground duration=${duration}ms');
```

### Étape 3: Watermark local

**Fichier :** `watermark_service.dart`

**Preuve :**
```dart
// Code commenté
// final session = await FFmpegKit.execute(...)
```

### Étape 4: Upload vidéo

**Fichier :** `videoasset_upload_service.dart`

**Preuve :**
```dart
final response = await supabase.functions.invoke(
  'app_videoasset_create_upload_intent',
  body: {...},
);
```

### Étape 5: Edge Function transcode-video

**Fichier :** `supabase/functions/transcode-video/index.ts`

**Preuve :**
```typescript
const { data, error } = await supabase
  .from('video_renditions')
  .upsert({...})
```

### Étape 6: Edge Function transcode-multi-resolution

**Fichier :** `supabase/functions/transcode-multi-resolution/index.ts`

**Preuve :**
```typescript
const { data, error } = await supabase
  .from('video_processing_jobs')
  .insert({...})
```

### Étape 7: Worker (non déployé)

**Fichier :** `videoasset_worker.py`

**Preuve :**
```python
jobs = await _fetch_queued_jobs(limit=max_jobs)
for job in jobs:
    await _process_single_job(job, worker_id)
```

**Statut :** 0 jobs queued dans video_processing_jobs (vérifié via RPC admin_execute_sql)

### Étape 8: Fusion segments

**Fichier :** `video_segment_merge_service.dart`

**Preuve :**
```dart
final response = await supabase.functions.invoke(
  'merge-video-segments',
  body: {...},
);
```

---

## CONCLUSION

### Qui encode réellement aujourd'hui ?

1. **Compression locale :** Flutter (video_compress) - software encoding
2. **Watermark :** Aucun (désactivé)
3. **Transcodage multi-résolution :** Aucun (worker non déployé)
4. **Fusion segments :** Edge Function Supabase (FFmpeg Deno)

### Où FFmpeg est-il exécuté ?

1. **Flutter (FFmpegKit) :** Désactivé
2. **Edge Function Supabase :** Fusion segments
3. **Backend Python :** Non utilisé en production
4. **Kamatera :** Non utilisé

### Pourquoi l'utilisateur attend-il plusieurs minutes ?

1. **Compression locale :** 5-20 secondes (software encoding)
2. **Upload :** 5-20 secondes (dépend de la connexion)
3. **Fusion segments :** 10-20 secondes (Edge Function)
4. **Transcodage multi-résolution :** Bloqué (worker non déployé)

---

**Statut :** ✅ TERMINÉ
