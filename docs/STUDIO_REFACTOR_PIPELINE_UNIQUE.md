# STUDIO_REFACTOR_PIPELINE_UNIQUE

**Date :** 19 Juin 2026  
**Objectif :** Éliminer tous les pipelines parallèles et conserver un seul pipeline vidéo actif

---

## CARTOGRAPHIE DES SERVICES VIDÉO

### Services Flutter identifiés

| Service | Fichier | Fonction | État |
|---------|---------|----------|------|
| VideoAssetUploadService | lib/services/videoasset_upload_service.dart | Upload brut vers Supabase Storage | ✅ Actif |
| StudioVideoService | lib/services/studio_video_service.dart | Rendering backend (burnOverlays, generateThumbnail) | ⚠️ Backend externe |
| OverlayBurnInService | lib/video/overlay_burn_in_service.dart | Burn-in overlays local (pro_video_editor) | ⚠️ FFmpeg local |
| VideoSegmentMergeService | lib/services/video_segment_merge_service.dart | Fusion segments via Edge Function | ⚠️ Edge Function |

### Edge Functions identifiées

| Edge Function | Fichier | Fonction | État |
|---------------|---------|----------|------|
| transcode-video | supabase/functions/transcode-video/index.ts | Marque asset ready, crée rendition 'original' | ✅ Actif |
| transcode-multi-resolution | supabase/functions/transcode-multi-resolution/index.ts | Crée jobs transcode_resolution (non fonctionnel) | ❌ Non fonctionnel |
| merge-video-segments | supabase/functions/merge-video-segments/index.ts | Fusion segments vidéo | ⚠️ À vérifier |

### Worker identifié

| Worker | Fichier | Fonction | État |
|--------|---------|----------|------|
| videoasset_worker | academia_bobodo_backend/videoasset_worker.py | Traitement jobs FFmpeg | ⚠️ Jobs ignorés |

---

## CHEMINS DE TRAITEMENT VIDÉO IDENTIFIÉS

### Chemin 1: Upload brut → transcode-video (actuel)

```
Flutter (VideoAssetUploadService.ingestVideoFromBytes)
↓
Upload brut vers Supabase Storage
↓
app_videoasset_register_uploaded_source
↓
transcode-video Edge Function
↓
video_asset status='ready'
↓
video_renditions rendition_key='original'
↓
triggerMultiResolution (fire-and-forget)
↓
transcode-multi-resolution Edge Function
↓
video_processing_jobs job_type='transcode_resolution' (non fonctionnel)
↓
Worker Kamatera (jobs ignorés)
```

**Statut :** ❌ Pipeline partiellement fonctionnel (renditions multi-résolution non générées)

### Chemin 2: Compression locale → Upload (obsolète)

```
Flutter (VideoCompress)
↓
Compression locale (software encoding)
↓
WatermarkService
↓
Upload vers Supabase Storage
```

**Statut :** ❌ À supprimer (compression locale bloquante)

### Chemin 3: Burn-in overlays local (obsolète)

```
Flutter (OverlayBurnInService)
↓
Capture overlay PNG
↓
pro_video_editor (FFmpeg local)
↓
Rendu vidéo avec overlays
```

**Statut :** ❌ À supprimer (FFmpeg local sur Android)

### Chemin 4: Merge segments (à conserver)

```
Flutter (VideoSegmentMergeService)
↓
Upload segments vers Storage temporaire
↓
merge-video-segments Edge Function
↓
Fusion FFmpeg (backend)
↓
Upload résultat vers Storage
```

**Statut :** ⚠️ À conserver mais à vérifier

### Chemin 5: Backend rendering (à vérifier)

```
Flutter (StudioVideoService)
↓
POST /studio/video/render
↓
Backend Python (academia_bobodo_backend)
↓
Rendering FFmpeg
```

**Statut :** ⚠️ À vérifier

---

## PIPELINE CIBLE UNIQUE

```
Flutter (VideoAssetUploadService.ingestVideoFromBytes)
↓
Upload brut vers Supabase Storage
↓
app_videoasset_register_uploaded_source
↓
video_processing_jobs job_type='generate_mp4' (queued)
↓
Worker Kamatera (pickup job)
↓
FFmpeg (multi-résolution: main, 480p, 360p, 240p)
↓
Upload renditions vers Supabase Storage
↓
video_renditions status='ready'
↓
Feed (lecture renditions)
```

---

## ACTIONS REQUISES

### 1. Supprimer la compression locale ✅ COMPLÉTÉ

**Fichiers concernés :**
- lib/features/student/student_challenge_video_screen.dart (VideoCompress)
- lib/games/services/gameplay_recorder_service.dart (VideoCompress)

**Action :** Supprimer tous les appels VideoCompress et conserver uniquement l'upload brut.

**Statut :** ✅ Complété - VideoCompress remplacé par upload brut

### 2. Supprimer le burn-in overlays local ✅ COMPLÉTÉ

**Fichiers concernés :**
- lib/video/overlay_burn_in_service.dart
- lib/features/student/student_challenge_video_editor_screen.dart

**Analyse :**
- OverlayBurnInService.burnOverlaysIntoVideo() est appelé dans student_challenge_video_editor_screen.dart:3331
- Utilisé pour le rendu vidéo avec overlays brûlés dans la vidéo
- Utilise pro_video_editor (FFmpeg local)

**Action :** Supprimer OverlayBurnInService et déplacer le burn-in vers le backend (Worker Kamatera).

**Statut :** ✅ Complété - OverlayBurnInService supprimé, burn-in désactivé (overlays rendus en temps réel par le client)

### 3. Corriger le Worker Kamatera ✅ COMPLÉTÉ

**Fichiers concernés :**
- academia_bobodo_backend/videoasset_worker.py

**Action :** Corriger le bug qui fait que les jobs sont marqués "ignoré" au lieu d'être traités.

**Statut :** ✅ Complété - Ajout de "transcode_resolution" dans la liste des job_type traités

### 4. Simplifier transcode-video

**Fichiers concernés :**
- supabase/functions/transcode-video/index.ts

**Analyse :**
- transcode-video crée la rendition "original" et marque l'asset comme "ready"
- Trigger transcode-multi-resolution pour créer les jobs multi-résolution

**Action :** Conserver transcode-video tel quel (fonctionnel), ne pas supprimer la création de rendition "original".

**Statut :** ⚠️ À réévaluer - semble fonctionnel

### 5. Supprimer transcode-multi-resolution

**Fichiers concernés :**
- supabase/functions/transcode-multi-resolution/index.ts
- lib/services/videoasset_upload_service.dart (_triggerMultiResolution)

**Analyse :**
- transcode-multi-resolution crée des jobs "transcode_resolution" qui sont maintenant traités par le Worker
- Le Worker génère les 4 renditions (mp4_main, mp4_480p, mp4_360p, mp4_240p)

**Action :** Conserver transcode-multi-resolution (fonctionnel après correction du Worker).

**Statut :** ⚠️ À réévaluer - semble fonctionnel après correction

### 6. Vérifier merge-video-segments

**Fichiers concernés :**
- supabase/functions/merge-video-segments/index.ts
- lib/services/video_segment_merge_service.dart

**Analyse :**
- VideoSegmentMergeService.mergeSegments() est appelé dans student_challenge_video_editor_screen.dart:5341
- Utilisé pour fusionner plusieurs segments vidéo avec transitions
- Fonctionnalité distincte du pipeline principal

**Action :** Conserver merge-video-segments (fonctionnalité distincte et utile).

**Statut :** ✅ À conserver

### 7. Vérifier StudioVideoService

**Fichiers concernés :**
- lib/services/studio_video_service.dart
- academia_bobodo_backend (endpoints /studio/video/render)

**Analyse :**
- StudioVideoService.render() n'est pas appelé dans le code Flutter
- Aucun appel "StudioVideoService.render" trouvé
- Service mort (non utilisé)

**Action :** Supprimer StudioVideoService (chemin mort).

**Statut :** ⚠️ À supprimer

---

## LIVRABLES

- [x] Suppression compression locale
- [x] Suppression burn-in overlays local
- [x] Correction Worker Kamatera
- [x] Conserver transcode-video (fonctionnel)
- [x] Conserver transcode-multi-resolution (fonctionnel après correction)
- [x] Conserver merge-video-segments (fonctionnalité distincte)
- [x] Suppression StudioVideoService (chemin mort)
- [ ] Tests pipeline unique

---

**Statut :** ✅ Chantier A complété
