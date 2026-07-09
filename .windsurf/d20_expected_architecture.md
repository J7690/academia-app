# D.20 – PHASE 1 : ARCHITECTURE ATTENDUE (DOCUMENTATION OFFICIELLE)

**Date** : 2026-06-28  
**Mission** : D.20 – Audit de conformité  
**Sources** : ACADEMIA_TECHNICAL_CONSTITUTION.md, ACADEMIA_ARCHITECTURE_DECISIONS.md, SMART_WHITEBOARD_DATA_CONTRACT.md, ACADEMIA_ENGINEERING_LOGBOOK.md, PHASE_D6_SUMMARY.md, MISSION_D9_AUDIT_WHITEBOARD_RPC_REPORT.md

---

## 1. FLUTTER – ARCHITECTURE ATTENDUE

### 1.1 Écrans

| Écran | Route | Rôle |
|-------|-------|------|
| `SmartWhiteboardInputScreen` | `/smart-whiteboard-input` | Saisie sujet, renderer, thème, narration → déclenche createProject + generateStoryboard |
| `SmartWhiteboardStoryboardEditorScreen` | `/smart-whiteboard-editor` | Édition du storyboard généré (scènes, blocs) |
| `SmartWhiteboardPreviewScreen` | `/smart-whiteboard-preview` | Prévisualisation MP4 rendu |
| `SmartWhiteboardProjectsListScreen` | `/smart-whiteboard-projects` | Liste des projets existants |

### 1.2 Provider

| Classe | Fichier | Rôle |
|--------|---------|------|
| `SmartWhiteboardProvider` | `providers/smart_whiteboard_provider.dart` | Orchestrateur central. États : idle → creating → generating → editing → rendering → done → error |

**Méthodes attendues** :
- `createProject(subject, rendererId, themeId, narrationMode)` → appelle `SmartWhiteboardService.createProject()`
- `generateStoryboard()` → appelle Edge Function `whiteboard-generate-storyboard`
- `updateProject(...)` → appelle `SmartWhiteboardService.updateProject()`
- `loadProjects()` → appelle `SmartWhiteboardService.listProjects()`
- `deleteProject(projectId)` → appelle `SmartWhiteboardService.deleteProject()`
- `createRenderJob()` → appelle `SmartWhiteboardRenderService.createRenderJob()`
- `pollRenderStatus(renderId)` → appelle `SmartWhiteboardRenderService.getRenderStatus()`

### 1.3 Services

| Classe | Fichier | RPCs appelées |
|--------|---------|---------------|
| `SmartWhiteboardService` | `services/smart_whiteboard_service.dart` | `whiteboard_create_project`, `whiteboard_get_project`, `whiteboard_update_project`, `whiteboard_list_projects`, `whiteboard_delete_project` |
| `SmartWhiteboardRenderService` | `services/smart_whiteboard_render_service.dart` | `whiteboard_create_render_job`, `whiteboard_get_render_status` |
| `SmartWhiteboardNarrationService` | `services/smart_whiteboard_narration_service.dart` | Service narration TTS (optionnel) |

### 1.4 Modèles

| Classe | Champs clés |
|--------|-------------|
| `Storyboard` | version, created_at, created_by, subject, renderer, theme, narration_mode, export_settings, scenes[] |
| `Scene` | id, order, title, duration_ms, transition, blocks[] |
| `Block` | id, type, content, order, visible, animation, position, style |
| `ExportSettings` | format, resolution (width/height), frame_rate, video_codec, audio_codec |
| `RenderJob` | id, project_id, status, video_url, duration_ms, error_message |

### 1.5 Navigation

**Flux utilisateur attendu** :
```
ChallengesTab → bouton + → SmartWhiteboardInputScreen
  → createProject() [RPC]
  → generateStoryboard() [Edge Function]
  → Navigation → SmartWhiteboardStoryboardEditorScreen
    → createRenderJob() [RPC]
    → pollRenderStatus() [RPC polling]
    → Navigation → SmartWhiteboardPreviewScreen
```

### 1.6 Appels RPC Flutter

| RPC | Paramètres | Retour attendu |
|-----|------------|----------------|
| `whiteboard_create_project` | p_student_id, p_subject, p_renderer_id, p_theme_id, p_narration_mode, p_storyboard_json | `{success: bool, project_id: uuid}` |
| `whiteboard_get_project` | p_project_id | `{success: bool, project: {...}}` |
| `whiteboard_update_project` | p_project_id, p_subject, p_status, ... | `{success: bool}` |
| `whiteboard_list_projects` | p_status | `{success: bool, projects: [...]}` |
| `whiteboard_delete_project` | p_project_id | `{success: bool}` |
| `whiteboard_create_render_job` | p_project_id | `{success: bool, render_id: uuid}` |
| `whiteboard_get_render_status` | p_render_id | `{success: bool, status: string, video_url: string?}` |

### 1.7 Appel Edge Function Flutter

| Edge Function | Input | Output succès | Output erreur |
|---------------|-------|---------------|---------------|
| `whiteboard-generate-storyboard` | `{mode, subject, content, renderer, theme, narration_mode}` | `{success: true, storyboard_json: {...}}` | `{error: string}` |

---

## 2. SUPABASE – ARCHITECTURE ATTENDUE

### 2.1 Schéma

- **Schéma `app`** pour les tables (isolation des données métier)
- **Schéma `public`** pour les RPCs (accessibles via PostgREST)

### 2.2 Tables

| Table | Schéma | Colonnes clés |
|-------|--------|---------------|
| `whiteboard_projects` | app | id (uuid PK), student_id (FK→students), subject (text), status (text), renderer_id (text), theme_id (text), narration_mode (text), storyboard_json (jsonb), created_at, updated_at |
| `whiteboard_renders` | app | id (uuid PK), project_id (FK→whiteboard_projects), status (text: queued/processing/done/failed), video_url (text?), duration_ms (int?), error_message (text?), started_at, completed_at, created_at |
| `whiteboard_ai_generations` | app | id (uuid PK), project_id (FK), model (text), tokens_input (int), tokens_output (int), cost_usd (float), created_at |

### 2.3 RPCs Flutter (schéma public)

| RPC | Schéma | Signature |
|-----|--------|-----------|
| `whiteboard_create_project` | public | (p_student_id uuid, p_subject text, p_renderer_id text, p_theme_id text, p_narration_mode text, p_storyboard_json jsonb) RETURNS jsonb |
| `whiteboard_get_project` | public | (p_project_id uuid) RETURNS jsonb |
| `whiteboard_update_project` | public | (p_project_id uuid, p_subject text, p_status text, ...) RETURNS jsonb |
| `whiteboard_list_projects` | public | (p_status text) RETURNS jsonb |
| `whiteboard_delete_project` | public | (p_project_id uuid) RETURNS jsonb |
| `whiteboard_create_render_job` | public | (p_project_id uuid) RETURNS jsonb |
| `whiteboard_get_render_status` | public | (p_render_id uuid) RETURNS jsonb |

### 2.4 RPCs Worker (schéma public)

| RPC | Schéma | Signature |
|-----|--------|-----------|
| `whiteboard_fetch_queued_jobs` | public | (p_limit integer DEFAULT 5) RETURNS TABLE(id uuid, storyboard jsonb, created_at timestamptz) |
| `whiteboard_mark_processing` | public | (p_job_id uuid) RETURNS void |
| `whiteboard_mark_done` | public | (p_job_id uuid, p_video_url text, p_duration_ms integer) RETURNS void |
| `whiteboard_mark_failed` | public | (p_job_id uuid, p_error_message text) RETURNS void |
| `whiteboard_get_any_student_id` | public | () RETURNS uuid |

### 2.5 Edge Functions

| Fonction | Trigger | Rôle |
|---------|---------|------|
| `whiteboard-generate-storyboard` | Appel Flutter (Supabase.functions.invoke) | Appelle OpenRouter → génère storyboard JSON → sauvegarde en base |

### 2.6 Buckets Storage

| Bucket | Public | Rôle |
|--------|--------|------|
| `whiteboard-renders` | Non | Stocke les MP4 rendus par le worker |
| `whiteboard-narrations` | Non | Stocke les narrations audio TTS |

### 2.7 RLS

- Attendu : policies RLS sur `whiteboard_projects` et `whiteboard_renders` permettant à chaque étudiant d'accéder uniquement à ses propres données.

### 2.8 Triggers

- Attendu : trigger `updated_at` sur `whiteboard_projects`.

---

## 3. KAMATERA – ARCHITECTURE ATTENDUE

### 3.1 Worker

| Composant | Chemin attendu | Rôle |
|-----------|---------------|------|
| Worker principal | `/opt/whiteboard-worker/whiteboard_render_worker.py` | Poll `whiteboard_fetch_queued_jobs` → traitement → mark_done/failed |
| PNG Renderer | `/opt/whiteboard-worker/whiteboard_png_renderer.py` | Convertit storyboard JSON en frames PNG |
| FFmpeg Assembler | `/opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py` | Assemble PNGs → MP4 |
| Upload Renderer | `/opt/whiteboard-worker/whiteboard_upload_renderer.py` | Upload MP4 → Supabase Storage bucket `whiteboard-renders` |

### 3.2 Service systemd

| Service | Fichier | État attendu |
|---------|---------|--------------|
| `whiteboard-worker.service` | `/etc/systemd/system/whiteboard-worker.service` | active (running), enabled |

### 3.3 Pipeline de rendu attendu

```
whiteboard_fetch_queued_jobs (RPC poll toutes 2s)
  → whiteboard_mark_processing (RPC)
  → whiteboard_png_renderer.py (storyboard → PNGs)
  → whiteboard_ffmpeg_assembler.py (PNGs → MP4)
  → whiteboard_upload_renderer.py (MP4 → Storage whiteboard-renders)
  → whiteboard_mark_done(video_url) (RPC)
```

### 3.4 Variables d'environnement

| Variable | Valeur attendue |
|----------|----------------|
| SUPABASE_URL | https://thevdfcwlcqzdoybfvgs.supabase.co |
| SUPABASE_SERVICE_KEY | JWT service_role |
| WORKER_LOOP | true |
| WORKER_INTERVAL_SECONDS | 2 |
| WORKER_MAX_JOBS | 1 |

### 3.5 FFmpeg

- Attendu : FFmpeg installé sur le système (`/usr/bin/ffmpeg`)
- Version : compatible H.264/AAC

### 3.6 Autres services actifs (hors scope whiteboard)

| Service | Rôle |
|---------|------|
| `bobodo-vocal.service` | Serveur Bobodo vocal (port 8000) |
| `academia-compress.service` | Service compression vidéo (port 8001) |
| `livekit-server` (Docker) | Serveur LiveKit (ports 7880/7881) |
| nginx | Reverse proxy (port 80) |
| redis-server | Cache (port 6379) |

---

## 4. FLUX GLOBAL ATTENDU

```
[Flutter Student] 
  → SmartWhiteboardInputScreen 
  → SmartWhiteboardProvider.createProject() 
  → RPC whiteboard_create_project 
  → app.whiteboard_projects (INSERT)
  → SmartWhiteboardProvider.generateStoryboard()
  → Edge Function whiteboard-generate-storyboard
    → OpenRouter API (LLM)
    → storyboard JSON validé
    → Retour Flutter
  → SmartWhiteboardStoryboardEditorScreen
  → SmartWhiteboardProvider.createRenderJob()
  → RPC whiteboard_create_render_job
  → app.whiteboard_renders (INSERT, status=queued)
  
[Kamatera Worker]
  → poll whiteboard_fetch_queued_jobs (toutes 2s)
  → whiteboard_mark_processing
  → render PNG frames
  → assemble MP4 (FFmpeg)
  → upload Storage whiteboard-renders
  → whiteboard_mark_done(video_url)
  
[Flutter Student]
  → poll whiteboard_get_render_status
  → SmartWhiteboardPreviewScreen (affiche MP4)
```

---

**DOCUMENT CLÔTURÉ** : Architecture attendue définie à partir de la documentation officielle. Prêt pour comparaison avec l'état réel.
