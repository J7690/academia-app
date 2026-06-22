# AUDIT SUPABASE - PIPELINE VIDÉO

**Date :** 19 Juin 2026  
**Objectif :** Cartographier tous les composants backend liés au Studio vidéo

---

## 1. TABLES

### 1.1 Tables identifiées (schéma app)

Les tables suivantes existent dans la base de données (vérifié via RPC admin_execute_sql) mais **non trouvées dans les migrations SQL**. Elles ont été créées manuellement ou via un outil non documenté.

| Table | Schéma | Rôle | Statut |
|-------|--------|------|--------|
| `video_assets` | app | Métadonnées des vidéos (status, owner, poster_url) | Utilisée |
| `video_sources` | app | Sources des vidéos (storage_bucket, storage_path, mime_type, file_size_bytes) | Utilisée |
| `video_renditions` | app | Renditions transcoded (rendition_key, kind, width, height, bitrate_kbps, codec, status) | Utilisée |
| `video_processing_jobs` | app | Jobs de traitement vidéo (job_type, status, payload) | Utilisée |

### 1.2 Tables liées aux challenges

| Table | Schéma | Rôle | Statut |
|-------|--------|------|--------|
| `challenge_game_live_sessions` | app | Sessions live gaming avec replay_video_asset_id | Utilisée |
| `participations` | app | Participations aux challenges (submission_url, submission_text) | Utilisée |

### 1.3 Structure des tables vidéo (d'après le code)

#### video_assets (vérifié - 235 enregistrements)
```sql
-- Colonnes réelles (vérifié via RPC admin_execute_sql)
- id: UUID (PK)
- owner_user_id: UUID
- origin: TEXT
- status: TEXT
- canonical_type: TEXT
- duration_ms: INTEGER
- width: INTEGER
- height: INTEGER
- rotation: INTEGER
- has_audio: BOOLEAN
- checksum_sha256: TEXT
- content_warning_flags: JSONB
- deleted_at: TIMESTAMPTZ
- created_at: TIMESTAMPTZ
- updated_at: TIMESTAMPTZ
```

#### video_sources (vérifié - 150 enregistrements)
```sql
-- Colonnes réelles (vérifié via RPC admin_execute_sql)
- id: UUID (PK)
- video_asset_id: UUID (FK)
- storage_bucket: TEXT
- storage_path: TEXT
- mime_type: TEXT
- file_size_bytes: BIGINT
- ingest_profile: TEXT
- created_at: TIMESTAMPTZ
- ingested_at: TIMESTAMPTZ
- validation_report: JSONB
```

#### video_renditions (vérifié - 378 enregistrements)
```sql
-- Colonnes réelles (vérifié via RPC admin_execute_sql)
- id: UUID (PK)
- video_asset_id: UUID (FK)
- rendition_key: TEXT (original, mp4_720p, mp4_480p, mp4_240p)
- kind: TEXT (mp4)
- width: INTEGER
- height: INTEGER
- bitrate_kbps: INTEGER
- fps: INTEGER
- codec: TEXT (h264)
- storage_bucket: TEXT
- storage_path: TEXT
- public_url_hint: TEXT
- status: TEXT (ready, pending)
- error: TEXT
- created_at: TIMESTAMPTZ
```

#### video_processing_jobs (vérifié - 4425 enregistrements)
```sql
-- Colonnes réelles (vérifié via RPC admin_execute_sql)
- id: UUID (PK)
- video_asset_id: UUID (FK)
- job_type: TEXT (transcode_resolution)
- status: TEXT (queued, processing, completed, failed)
- attempts: INTEGER
- locked_at: TIMESTAMPTZ
- locked_by: TEXT
- payload: JSONB (source_url, source_bucket, source_path, output_bucket, output_path, rendition_id, rendition_key, target_height, target_bitrate, ffmpeg_args)
- error: TEXT
- created_at: TIMESTAMPTZ
- updated_at: TIMESTAMPTZ
```

---

## 2. BUCKETS STORAGE

| Bucket | Rôle | Statut |
|--------|------|--------|
| `video-assets` | Stockage des vidéos uploadées et renditions | Utilisé |
| `challenge-media` | Stockage des médias des challenges | Utilisé |

### 2.1 Structure du bucket video-assets

```
video-assets/
├── temp/
│   └── segments/
│       └── {timestamp}/
│           ├── segment_000_{timestamp}.mp4
│           ├── segment_001_{timestamp}.mp4
│           └── ...
├── renditions/
│   └── {video_asset_id}/
│       ├── original.mp4
│       ├── mp4_720p.mp4
│       ├── mp4_480p.mp4
│       └── mp4_240p.mp4
└── {origin}/{context_type}/{context_id}/
    └── {filename}
```

---

## 3. RPCs

### 3.1 RPCs vidéo utilisées

| RPC | Rôle | Paramètres | Utilisé par |
|-----|------|------------|-------------|
| `app_videoasset_create_upload_intent` | Crée un intent d'upload vidéo | p_origin, p_context_type, p_context_id, p_role, p_mime_type, p_expected_size | VideoAssetUploadService |
| `app_videoasset_register_uploaded_source` | Enregistre la source uploadée | p_source_id, p_checksum_sha256, p_width, p_height, p_duration_ms, p_has_audio, p_validation_report | VideoAssetUploadService |
| `app_videoasset_get_playback_manifest` | Récupère le manifeste de playback | p_video_asset_id | StudentChallengesProvider, student_home_tab |
| `app_videoasset_get_playback_for_direct_url` | Récupère le playback pour une URL directe | p_direct_url | Multiple providers |

### 3.2 RPCs challenges

| RPC | Rôle | Paramètres | Utilisé par |
|-----|------|------------|-------------|
| `app_student_submit_challenge` | Soumet une participation challenge | p_participation_id, p_submission_text, p_submission_url | StudentChallengesProvider |

### 3.3 RPCs live gaming

| RPC | Rôle | Paramètres | Utilisé par |
|-----|------|------------|-------------|
| `challenge_game_start_live` | Démarre une session live gaming | p_game_type, p_mode | - |
| `challenge_game_end_live` | Termine une session live gaming | p_session_id, p_score_final, p_replay_video_asset_id | - |
| `challenge_game_list_live` | Liste les sessions live en cours | - | - |

---

## 4. EDGE FUNCTIONS

### 4.1 Edge Functions vidéo

| Edge Function | Rôle | Déclenché par | Statut |
|---------------|------|---------------|--------|
| `transcode-video` | Crée la rendition "original" et marque l'asset comme ready | VideoAssetUploadService.triggerTranscode() | Utilisé |
| `transcode-multi-resolution` | Crée les jobs de transcodage multi-résolution (720p, 480p, 240p) | VideoAssetUploadService._triggerMultiResolution() | Utilisé (fire-and-forget) |
| `merge-video-segments` | Fusionne plusieurs segments vidéo avec transitions | VideoSegmentMergeService.mergeSegments() | Utilisé |
| `assemble-video-chunks` | Assemble des chunks vidéo (non utilisé dans le flux actuel) | - | Inutilisé |

### 4.2 Détail de transcode-video

**Fichier :** `supabase/functions/transcode-video/index.ts`

**Responsabilités :**
1. Fetch le video_asset et sa source primaire
2. Construit l'URL publique depuis Storage
3. Upsert une rendition "original" dans video_renditions
4. Met à jour le status du video_asset à 'ready'
5. Optionnellement set poster_url

**Paramètres :**
```typescript
{
  video_asset_id: string,
  poster_url?: string
}
```

**Réponse :**
```typescript
{
  success: true,
  video_asset_id: string,
  playback: {
    best_url: string,
    poster_url: string | null,
    renditions: [{ label: 'original', url: string, mime_type: string }]
  }
}
```

### 4.3 Détail de transcode-multi-resolution

**Fichier :** `supabase/functions/transcode-multi-resolution/index.ts`

**Responsabilités :**
1. Fetch la source vidéo
2. Vérifie quelles renditions existent déjà
3. Pour chaque résolution manquante (720p, 480p, 240p) :
   - Insère une rendition entry en status 'pending'
   - Insère un job dans video_processing_jobs
4. Le worker VPS doit poller video_processing_jobs pour exécuter FFmpeg

**Paramètres :**
```typescript
{
  video_asset_id: string
}
```

**Réponse :**
```typescript
{
  success: true,
  video_asset_id: string,
  jobs_created: number,
  jobs: [{ rendition_key: string, rendition_id: string, status: 'queued' }]
}
```

**Profils de résolution :**
```typescript
[
  { key: 'mp4_720p', height: 720, bitrate: '1500k', bitrateKbps: 1500 },
  { key: 'mp4_480p', height: 480, bitrate: '800k', bitrateKbps: 800 },
  { key: 'mp4_240p', height: 240, bitrate: '400k', bitrateKbps: 400 }
]
```

**VPS IP :** 185.167.97.144 (déduit de LIVEKIT_URL)

### 4.4 Détail de merge-video-segments

**Fichier :** `supabase/functions/merge-video-segments/index.ts`

**Responsabilités :**
1. Fusionne plusieurs segments vidéo avec transitions
2. Supporte : none, fade, dissolve, slide
3. Upload le résultat vers Storage
4. Retourne l'URL publique

**Paramètres :**
```typescript
{
  segment_paths: string[],
  bucket: string,
  output_path: string,
  transition: string,
  transition_duration_ms: number
}
```

---

## 5. TRIGGERS

Aucun trigger identifié pour le pipeline vidéo dans les migrations.

---

## 6. POLICIES

Les policies RLS sont appliquées sur les tables mais non documentées dans les migrations. Les tables vidéo utilisent probablement :
- `service_role` pour les Edge Functions
- `authenticated` pour les utilisateurs

---

## 7. CRON JOBS

Aucun cron job identifié pour le pipeline vidéo dans les migrations.

---

## 8. QUEUES

**Queue vidéo :** `video_processing_jobs`

**Mécanisme :**
- Les jobs sont insérés par `transcode-multi-resolution`
- Un worker VPS doit poller cette table pour exécuter FFmpeg
- Statuts : queued, processing, completed, failed

**Payload du job :**
```json
{
  "source_url": "https://...",
  "source_bucket": "video-assets",
  "source_path": "...",
  "output_bucket": "video-assets",
  "output_path": "renditions/{video_asset_id}/{rendition_key}.mp4",
  "rendition_id": "...",
  "rendition_key": "mp4_720p",
  "target_height": 720,
  "target_bitrate": "1500k",
  "ffmpeg_args": "-vf \"scale=-2:720\" -c:v libx264 -preset fast -b:v 1500k -c:a aac -b:a 128k -movflags +faststart"
}
```

---

## 9. PIPELINE VIDÉO SUPPORTÉ PAR SUPABASE

### 9.1 Upload vidéo

1. **Flutter** appelle `app_videoasset_create_upload_intent`
2. **RPC** crée un entry dans `video_sources` avec status 'pending'
3. **Flutter** upload le fichier vers Storage (direct ou chunké)
4. **Flutter** appelle `app_videoasset_register_uploaded_source`
5. **RPC** met à jour `video_sources` avec les métadonnées

### 9.2 Transcodage

1. **Flutter** appelle Edge Function `transcode-video`
2. **Edge Function** :
   - Fetch `video_asset` et `video_source`
   - Construit l'URL publique
   - Upsert rendition "original" dans `video_renditions`
   - Met à jour `video_asset.status` à 'ready'
3. **Flutter** appelle Edge Function `transcode-multi-resolution` (fire-and-forget)
4. **Edge Function** :
   - Vérifie les renditions existantes
   - Insère renditions manquantes en status 'pending'
   - Insère jobs dans `video_processing_jobs`
5. **Worker VPS** (non identifié dans le code) :
   - Poll `video_processing_jobs`
   - Exécute FFmpeg
   - Upload les renditions vers Storage
   - Met à jour `video_renditions` status à 'ready'

### 9.3 Fusion de segments

1. **Flutter** upload les segments vers Storage (temp/segments)
2. **Flutter** appelle Edge Function `merge-video-segments`
3. **Edge Function** :
   - Fusionne les segments avec FFmpeg
   - Upload le résultat vers Storage
   - Retourne l'URL publique

### 9.4 Playback

1. **Flutter** appelle `app_videoasset_get_playback_manifest` ou `app_videoasset_get_playback_for_direct_url`
2. **RPC** retourne le manifeste avec toutes les renditions
3. **Flutter** utilise la meilleure URL pour le playback

---

## 10. OBSERVATIONS CRITIQUES

### 10.1 Tables non documentées
- Les tables vidéo (`video_assets`, `video_sources`, `video_renditions`, `video_processing_jobs`) ne sont pas dans les migrations
- Elles existent probablement dans la base de données mais sans fichier de migration
- Cela rend difficile la reproduction de l'infrastructure

### 10.2 Worker VPS manquant
- Le code prévoit un worker VPS qui poll `video_processing_jobs`
- Ce worker n'est pas identifié dans le code Flutter
- Les jobs de transcodage multi-résolution ne sont jamais exécutés
- Seule la rendition "original" est créée

### 10.3 Transcodage partiel
- Seule la rendition "original" est créée par `transcode-video`
- Les renditions 720p, 480p, 240p sont en attente d'un worker qui n'existe pas
- Le pipeline multi-résolution est incomplet

### 10.4 FFmpeg non exécuté
- L'Edge Function `transcode-multi-resolution` ne fait que créer des jobs
- FFmpeg n'est jamais exécuté par Supabase
- Le transcodage réel doit se faire sur un VPS externe

### 10.5 Merge de segments
- La fusion de segments utilise une Edge Function
- FFmpeg est exécuté côté Supabase (Deno)
- Peut impacter les performances pour les vidéos longues

---

## 11. COMPOSANTS UTILISÉS

### 11.1 Utilisés activement

| Composant | Rôle | Statut |
|-----------|------|--------|
| `video_assets` | Métadonnées vidéos | ✅ Utilisé |
| `video_sources` | Sources vidéos | ✅ Utilisé |
| `video_renditions` | Renditions (original uniquement) | ✅ Utilisé |
| `video_processing_jobs` | Jobs de transcodage (créés mais non exécutés) | ⚠️ Partiel |
| `transcode-video` | Création rendition original | ✅ Utilisé |
| `transcode-multi-resolution` | Création jobs multi-résolution | ⚠️ Partiel |
| `merge-video-segments` | Fusion segments | ✅ Utilisé |
| `video-assets` bucket | Stockage vidéos | ✅ Utilisé |

### 11.2 Inutilisés

| Composant | Rôle | Statut |
|-----------|------|--------|
| `assemble-video-chunks` | Assemblage chunks | ❌ Inutilisé |
| `challenge-media` bucket | Stockage médias challenges | ❌ Inutilisé (déprécié) |

### 11.3 Partiellement connectés

| Composant | Rôle | Problème |
|-----------|------|----------|
| `video_processing_jobs` | Jobs de transcodage | Worker VPS manquant |
| `transcode-multi-resolution` | Multi-résolution | Jobs créés mais non exécutés |

---

**Statut :** ✅ PHASE B TERMINÉE
