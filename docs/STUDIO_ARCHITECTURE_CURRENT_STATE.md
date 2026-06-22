# ARCHITECTURE ACTUELLE DU PIPELINE VIDÉO - ÉTAT DES LIEUX

**Date :** 19 Juin 2026  
**Objectif :** Synthèse des audits Flutter, Supabase et Kamatera pour produire une vue d'ensemble factuelle de l'architecture actuelle

---

## 1. DIAGRAMME D'ARCHITECTURE

### 1.1 Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            FLUTTER APP (Client)                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ StudentChallengeVideoEditorScreen (Entry Point)                      │  │
│  │ - _pickVideo() → Import vidéo                                        │  │
│  │ - _compressAndWatermarkInBackground() → Compression locale           │  │
│  │ - _uploadVideo() → Upload Supabase                                   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ AcademiaPlaybackView (Playback)                                     │  │
│  │ - Android: ExoPlayer (native)                                       │  │
│  │ - iOS/Web: video_player (Flutter)                                  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ Services                                                            │  │
│  │ - VideoAssetUploadService (upload + transcoding trigger)            │  │
│  │ - VideoSegmentMergeService (merge segments)                         │  │
│  │ - WatermarkService (watermark FFmpeg - disabled)                    │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          SUPABASE CLOUD                                     │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ Storage                                                             │  │
│  │ - video-assets bucket (vidéos uploadées + renditions)                │  │
│  │ - challenge-media bucket (médias challenges - déprécié)             │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ PostgreSQL (schéma app)                                              │  │
│  │ - video_assets (métadonnées)                                        │  │
│  │ - video_sources (sources uploadées)                                 │  │
│  │ - video_renditions (renditions transcoded)                         │  │
│  │ - video_processing_jobs (jobs de traitement)                         │  │
│  │ - challenge_game_live_sessions (sessions live)                       │  │
│  │ - participations (participations challenges)                        │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ Edge Functions                                                      │  │
│  │ - transcode-video (création rendition "original")                   │  │
│  │ - transcode-multi-resolution (création jobs multi-résolution)       │  │
│  │ - merge-video-segments (fusion segments)                            │  │
│  │ - livekit-token (génération JWT LiveKit)                            │  │
│  │ - livekit-recording (enregistrement sessions)                       │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ RPCs                                                                │  │
│  │ - app_videoasset_create_upload_intent                               │  │
│  │ - app_videoasset_register_uploaded_source                           │  │
│  │ - app_videoasset_get_playback_manifest                              │  │
│  │ - app_videoasset_get_playback_for_direct_url                        │  │
│  │ - app_student_submit_challenge                                      │  │
│  │ - challenge_game_start_live                                         │  │
│  │ - challenge_game_end_live                                           │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        KAMATERA CLOUD (VPS)                                  │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ LiveKit Server (185.167.97.144:7880)                                 │  │
│  │ - Streaming vidéo/audio temps réel                                   │  │
│  │ - Egress (recording → Supabase Storage)                              │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ Redis (127.0.0.1:6379)                                               │  │
│  │ - Cache LiveKit (rooms, participants)                                │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ Nginx (185.167.97.144:80)                                            │  │
│  │ - Reverse proxy LiveKit                                              │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        DOCKER (Local)                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ academia-backend (python:3.11-slim)                                 │  │
│  │ - Port 8001                                                          │  │
│  │ - Proxy Supabase (/supabase/{path})                                 │  │
│  │ - Endpoints vidéo (/studio/video/render, /challenge/burn-overlays)  │  │
│  │ - FFmpeg installé                                                    │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ academia-videoasset-worker (python:3.11-slim)                       │  │
│  │ - Poll video_processing_jobs (status=queued)                        │  │
│  │ - Transcodage multi-résolution (main, 480p, 360p, 240p)             │  │
│  │ - Watermark TikTok-style                                            │  │
│  │ - Upload vers Supabase Storage                                      │  │
│  │ - FFmpeg installé                                                    │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        RAILWAY (Production - Indisponible)                  │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ academia-backend (https://academia-app-production.up.railway.app)   │  │
│  │ - Proxy Supabase                                                     │  │
│  │ - Endpoints vidéo lourds                                             │  │
│  │ - FFmpeg transcodage                                                │  │
│  │ - ⚠️ ACCÈS BLOQUÉ                                                    │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. RESPONSABILITÉS PAR COMPOSANT

### 2.1 Téléphone (Flutter)

| Tâche | Composant | Responsabilité | Statut |
|-------|-----------|----------------|--------|
| Import vidéo | StudentChallengeVideoEditorScreen._pickVideo() | Sélection depuis galerie | ✅ Actif |
| Compression locale | VideoCompress.compressVideo() | Compression avant upload | ✅ Actif |
| Watermark local | WatermarkService.addWatermark() | Watermark FFmpeg côté device | ❌ Désactivé |
| Upload vidéo | VideoAssetUploadService.uploadVideo() | Upload vers Supabase Storage | ✅ Actif |
| Playback vidéo | AcademiaPlaybackView | Playback ExoPlayer (Android) / video_player (iOS/Web) | ✅ Actif |
| Fusion segments | VideoSegmentMergeService.mergeSegments() | Upload segments + appel Edge Function | ✅ Actif |
| Preview édition | StudentChallengeVideoEditorScreen | Preview local avec overlays | ✅ Actif |

### 2.2 Supabase

| Tâche | Composant | Responsabilité | Statut |
|-------|-----------|----------------|--------|
| Stockage vidéo | Storage (video-assets bucket) | Stockage fichiers vidéo | ✅ Actif |
| Métadonnées vidéo | video_assets table | Métadonnées (status, owner, poster_url) | ✅ Actif |
| Sources vidéo | video_sources table | Sources uploadées (storage_path, mime_type) | ✅ Actif |
| Renditions vidéo | video_renditions table | Renditions transcoded (rendition_key, width, height) | ✅ Actif (original uniquement) |
| Jobs traitement | video_processing_jobs table | Jobs de transcodage (job_type, status, payload) | ⚠️ Créés mais non traités |
| Création rendition original | Edge Function transcode-video | Upsert rendition "original" + status ready | ✅ Actif |
| Création jobs multi-résolution | Edge Function transcode-multi-resolution | Insert jobs dans video_processing_jobs | ✅ Actif (fire-and-forget) |
| Fusion segments | Edge Function merge-video-segments | Fusion FFmpeg + upload | ✅ Actif |
| Playback manifest | RPC app_videoasset_get_playback_manifest | Récupère manifeste avec renditions | ✅ Actif |
| Upload intent | RPC app_videoasset_create_upload_intent | Crée intent d'upload | ✅ Actif |
| Register source | RPC app_videoasset_register_uploaded_source | Enregistre source uploadée | ✅ Actif |
| Soumission challenge | RPC app_student_submit_challenge | Soumet participation challenge | ✅ Actif |
| Token LiveKit | Edge Function livekit-token | Génération JWT LiveKit | ✅ Actif |
| Recording LiveKit | Edge Function livekit-recording | Enregistrement sessions | ✅ Actif |

### 2.3 Kamatera Cloud

| Tâche | Composant | Responsabilité | Statut |
|-------|-----------|----------------|--------|
| Streaming temps réel | LiveKit Server (185.167.97.144:7880) | Streaming vidéo/audio | ✅ Actif |
| Cache LiveKit | Redis (127.0.0.1:6379) | Cache rooms/participants | ✅ Actif |
| Reverse proxy | Nginx (185.167.97.144:80) | Proxy LiveKit | ✅ Actif |
| Recording | LiveKit Egress | Enregistrement → Supabase Storage | ✅ Actif |
| Encodage vidéo | - | Aucun composant d'encodage | ❌ Absent |

### 2.4 Docker (Local)

| Tâche | Composant | Responsabilité | Statut |
|-------|-----------|----------------|--------|
| Proxy Supabase | academia-backend | Proxy HTTP vers Supabase | ✅ Actif (local) |
| Transcodage vidéo | academia-backend (studio_video_renderer.py) | Transcodage FFmpeg | ✅ Prêt (local) |
| Watermark | academia-backend (_run_ffmpeg_export_watermarked) | Watermark TikTok-style | ✅ Prêt (local) |
| Poll jobs | academia-videoasset-worker | Poll video_processing_jobs | ✅ Prêt (local) |
| Transcodage multi-résolution | academia-videoasset-worker | Transcodage (main, 480p, 360p, 240p) | ✅ Prêt (local) |
| Upload renditions | academia-videoasset-worker | Upload vers Supabase Storage | ✅ Prêt (local) |

### 2.5 Railway (Production)

| Tâche | Composant | Responsabilité | Statut |
|-------|-----------|----------------|--------|
| Proxy Supabase | academia-backend (Railway) | Proxy HTTP vers Supabase | ❌ Indisponible |
| Transcodage vidéo | academia-backend (Railway) | Transcodage FFmpeg lourd | ❌ Indisponible |
| Poll jobs | academia-videoasset-worker (Railway) | Poll video_processing_jobs | ❌ Indisponible |
| Transcodage multi-résolution | academia-videoasset-worker (Railway) | Transcodage multi-résolution | ❌ Indisponible |

---

## 3. PIPELINE VIDÉO ACTUEL

### 3.1 Upload vidéo (Challenge)

```
1. Flutter: StudentChallengeVideoEditorScreen._pickVideo()
   ↓
2. Flutter: VideoCompress.compressVideo() (locale)
   ↓
3. Flutter: WatermarkService.addWatermark() (désactivé)
   ↓
4. Flutter: VideoAssetUploadService.uploadVideo()
   ↓
5. Supabase: RPC app_videoasset_create_upload_intent()
   ↓
6. Supabase: Upload vers Storage (video-assets bucket)
   ↓
7. Supabase: RPC app_videoasset_register_uploaded_source()
   ↓
8. Supabase: Edge Function transcode-video
   ↓
9. Supabase: Upsert rendition "original" dans video_renditions
   ↓
10. Supabase: Update video_assets.status = 'ready'
   ↓
11. Supabase: Edge Function transcode-multi-resolution (fire-and-forget)
   ↓
12. Supabase: Insert jobs dans video_processing_jobs (status=queued)
   ↓
13. [BLOQUÉ] Worker Docker/Railway non déployé → Jobs non traités
   ↓
14. Flutter: RPC app_student_submit_challenge()
   ↓
15. Supabase: Update participations.submission_url
```

### 3.2 Playback vidéo

```
1. Flutter: StudentChallengesProvider.fetchPlaybackForVideoAsset()
   ↓
2. Supabase: RPC app_videoasset_get_playback_manifest()
   ↓
3. Supabase: Query video_renditions (status=ready)
   ↓
4. Supabase: Return manifest avec renditions
   ↓
5. Flutter: AcademiaPlaybackView
   ↓
6. Android: ExoPlayer (native)
   iOS/Web: video_player (Flutter)
```

### 3.3 Fusion de segments

```
1. Flutter: VideoSegmentMergeService.mergeSegments()
   ↓
2. Flutter: Upload segments vers Storage (temp/segments)
   ↓
3. Supabase: Edge Function merge-video-segments
   ↓
4. Supabase: Fusion FFmpeg (Deno)
   ↓
5. Supabase: Upload résultat vers Storage
   ↓
6. Supabase: Return URL publique
```

### 3.4 LiveKit (Streaming temps réel)

```
1. Flutter: Edge Function livekit-token
   ↓
2. Supabase: RPC app_register_online_course_live_session_participant()
   ↓
3. Supabase: Return room_name, identity, role
   ↓
4. Supabase: Edge Function livekit-token → JWT
   ↓
5. Flutter: Connect to LiveKit ws://185.167.97.144:7880
   ↓
6. Kamatera: LiveKit Server streaming
   ↓
7. Kamatera: LiveKit Egress (recording)
   ↓
8. Supabase: Upload vers Storage
   ↓
9. Supabase: Update challenge_game_live_sessions.replay_video_asset_id
```

---

## 4. OBSERVATIONS CRITIQUES

### 4.1 Transcodage multi-résolution non fonctionnel

**Problème :** Les jobs de transcodage multi-résolution sont créés mais jamais traités.

**Cause :** Le worker `academia-videoasset-worker` n'est pas déployé en production (Railway indisponible) et n'est pas lancé en local.

**Preuve :** La table `video_processing_jobs` contient 4425 enregistrements (vérifié via RPC admin_execute_sql), ce qui confirme que les jobs sont créés mais restent en status "queued".

**Conséquence :** Seule la rendition "original" est disponible. Les renditions 720p, 480p, 240p ne sont jamais générées.

### 4.2 Watermark local désactivé

**Problème :** Le watermark côté device est désactivé (FFmpegKit désactivé).

**Cause :** Code commenté dans `WatermarkService.addWatermark()`.

**Conséquence :** Pas de watermark sur les vidéos uploadées depuis le téléphone.

### 4.3 Backend Railway indisponible

**Problème :** L'accès Railway est bloqué. Le backend `academia-backend` n'est pas accessible en production.

**Cause :** Accès Railway bloqué (raison non documentée).

**Conséquence :** Le proxy Supabase et les endpoints vidéo lourds ne sont pas disponibles en production.

### 4.4 Kamatera = LiveKit uniquement

**Problème :** Kamatera n'héberge que LiveKit. Il n'y a pas de composant d'encodage vidéo.

**Cause :** Architecture volontaire (LiveKit dédié sur Kamatera).

**Conséquence :** Le traitement vidéo doit se faire ailleurs (Docker local ou Railway).

### 4.5 Tables vidéo non documentées

**Problème :** Les tables vidéo (`video_assets`, `video_sources`, `video_renditions`, `video_processing_jobs`) ne sont pas dans les migrations SQL.

**Cause :** Tables créées manuellement ou via un outil non documenté.

**Conséquence :** Difficile de reproduire l'infrastructure.

---

## 5. ÉTAT DES LIEUX PAR COMPOSANT

### 5.1 Flutter

| Composant | État | Observations |
|-----------|------|--------------|
| Import vidéo | ✅ Fonctionnel | _pickVideo() utilise image_picker |
| Compression locale | ✅ Fonctionnel | VideoCompress.compressVideo() |
| Watermark local | ❌ Désactivé | FFmpegKit désactivé |
| Upload vidéo | ✅ Fonctionnel | VideoAssetUploadService.uploadVideo() |
| Playback vidéo | ✅ Fonctionnel | ExoPlayer (Android) / video_player (iOS/Web) |
| Fusion segments | ✅ Fonctionnel | VideoSegmentMergeService.mergeSegments() |
| Preview édition | ✅ Fonctionnel | Preview local avec overlays |

### 5.2 Supabase

| Composant | État | Observations |
|-----------|------|--------------|
| Storage video-assets | ✅ Fonctionnel | Bucket utilisé |
| Storage challenge-media | ❌ Déprécié | Bucket non utilisé |
| video_assets table | ✅ Fonctionnel | Table utilisée |
| video_sources table | ✅ Fonctionnel | Table utilisée |
| video_renditions table | ⚠️ Partiel | Seule rendition "original" créée |
| video_processing_jobs table | ⚠️ Partiel | Jobs créés mais non traités |
| transcode-video Edge Function | ✅ Fonctionnel | Création rendition "original" |
| transcode-multi-resolution Edge Function | ⚠️ Partiel | Jobs créés mais non traités |
| merge-video-segments Edge Function | ✅ Fonctionnel | Fusion segments |
| RPCs vidéo | ✅ Fonctionnel | RPCs utilisées |
| livekit-token Edge Function | ✅ Fonctionnel | Génération JWT |
| livekit-recording Edge Function | ✅ Fonctionnel | Enregistrement |

### 5.3 Kamatera

| Composant | État | Observations |
|-----------|------|--------------|
| LiveKit Server | ✅ Fonctionnel | Streaming temps réel |
| Redis | ✅ Fonctionnel | Cache LiveKit |
| Nginx | ✅ Fonctionnel | Reverse proxy |
| Encodage vidéo | ❌ Absent | Aucun composant d'encodage |

### 5.4 Docker (Local)

| Composant | État | Observations |
|-----------|------|--------------|
| academia-backend | ✅ Prêt | Proxy Supabase + endpoints vidéo |
| academia-videoasset-worker | ✅ Prêt | Poll jobs + transcodage |
| FFmpeg | ✅ Installé | Installé dans les conteneurs |

### 5.5 Railway (Production)

| Composant | État | Observations |
|-----------|------|--------------|
| academia-backend | ❌ Indisponible | Accès Railway bloqué |
| academia-videoasset-worker | ❌ Indisponible | Accès Railway bloqué |

---

## 6. RECOMMANDATIONS (NON IMPLÉMENTÉES)

**Note :** Ce document est un audit factuel. Aucune recommandation n'est fournie conformément à la directive de la mission.

---

## 7. CONCLUSION

L'architecture actuelle du pipeline vidéo Academia Studio est basée sur une approche hybride :

- **Flutter** gère l'import, la compression locale, l'upload et le playback
- **Supabase** gère le stockage, les métadonnées, le transcodage léger (rendition "original") et la fusion de segments
- **Kamatera** gère uniquement LiveKit pour le streaming temps réel
- **Docker (local)** est prêt pour le transcodage lourd mais n'est pas déployé en production
- **Railway** est indisponible, ce qui bloque le déploiement du backend lourd en production

Le pipeline fonctionne partiellement : l'upload, le playback et la fusion de segments sont opérationnels, mais le transcodage multi-résolution est bloqué par l'absence de worker en production.

---

**Statut :** ✅ PHASE D TERMINÉE
