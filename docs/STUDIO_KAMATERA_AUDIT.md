# AUDIT KAMATERA CLOUD - PIPELINE VIDÉO

**Date :** 19 Juin 2026  
**Objectif :** Cartographier l'infrastructure réelle utilisée par Academia

---

## 1. MACHINES VIRTUELLES

### 1.1 Serveur LiveKit (vérifié via SSH)

| Paramètre | Valeur |
|-----------|--------|
| **IP** | 185.167.97.144 |
| **WebSocket** | ws://185.167.97.144:7880 |
| **HTTP API** | http://185.167.97.144:7880 |
| **Redis** | 127.0.0.1:6379 (local) |
| **Nginx** | http://185.167.97.144 |
| **API Key** | `APIKeylrmgQYJgiEZa` |
| **Installé le** | 2026-06-07 |
| **Capacité** | ~50 participants simultanés par room, ~10 rooms simultanées |
| **Bande passante** | 100 Mbps (Kamatera standard) |
| **Mode d'exécution** | Conteneur Docker (livekit-server:latest) |
| **Uptime conteneur** | 12 jours |

### 1.2 Services hébergés sur Kamatera

| Service | Port | Rôle | Statut |
|---------|------|------|--------|
| LiveKit Server | 7880 | Streaming vidéo/audio en temps réel | ✅ Actif |
| Redis | 6379 | Cache LiveKit | ✅ Actif |
| Nginx | 80 | Reverse proxy | ✅ Actif |

### 1.3 Caractéristiques système (vérifié via SSH)

| Paramètre | Valeur |
|-----------|--------|
| **OS** | Ubuntu 24.04.4 LTS |
| **RAM totale** | 9.7 Go |
| **RAM utilisée** | 1.6 Go |
| **RAM disponible** | 8.2 Go |
| **CPU** | 4 coeurs |
| **Disque total** | 30 Go |
| **Disque utilisé** | 17 Go (58%) |
| **Disque disponible** | 12 Go |
| **FFmpeg** | 6.1.1-3ubuntu5 (installé) |
| **Docker** | 29.5.3 (installé) |
| **Conteneurs Docker** | 1 (livekit-server) |

---

## 2. DOCKER

### 2.1 Docker Compose (local)

**Fichier :** `docker-compose.yml`

**Services :**

| Service | Image | Ports | Rôle | Statut |
|---------|-------|-------|------|--------|
| academia-backend | python:3.11-slim | 8001:8000 | Backend FastAPI (proxy Supabase, endpoints vidéo) | Local |
| academia-videoasset-worker | python:3.11-slim | - | Worker de traitement vidéo (poll video_processing_jobs) | Local |

### 2.2 Dockerfile

**Fichier :** `academia_bobodo_backend/Dockerfile`

**Base image :** `python:3.11-slim`

**Dépendances système :**
- ffmpeg (installé via apt-get)

**Dépendances Python :**
- fastapi
- httpx
- python-dotenv
- livekit

**Commande :** `uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}`

### 2.3 Volumes

| Volume | Chemin hôte | Chemin conteneur | Rôle |
|--------|-------------|------------------|------|
| /tmp/academia_render | /tmp/academia_render | /tmp | Traitement vidéo temporaire |
| ./assets/images | /assets/images:ro | /assets/images | Logo watermark |

---

## 3. RÉSEAUX

### 3.1 Architecture réseau

```
┌─────────────────────────────────────────────────────────────┐
│ Flutter App (Mobile/Web/Desktop)                            │
└──────────┬──────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────┐     ┌────────────────────────────────┐
│ Supabase Cloud       │     │ Kamatera VPS (LiveKit)         │
│ ─ Auth               │     │ ─ LiveKit Server :7880         │
│ ─ PostgreSQL         │     │ ─ Redis :6379                  │
│ ─ Edge Functions     │◄───►│ ─ Nginx :80                    │
│ ─ Storage            │     │ ─ Egress (recording → S3)      │
│ ─ Realtime           │     └────────────────────────────────┘
└──────────────────────┘
```

### 3.2 Flow connexion LiveKit

1. Client → Supabase Edge Function `livekit-token` → JWT
2. Client → LiveKit ws://185.167.97.144:7880 avec JWT
3. LiveKit Egress → Supabase Storage (replay_url)

---

## 4. SERVICES EXPOSÉS

### 4.1 Services Kamatera

| Service | URL | Rôle | Statut |
|---------|-----|------|--------|
| LiveKit WebSocket | ws://185.167.97.144:7880 | Streaming temps réel | ✅ Exposé |
| LiveKit HTTP API | http://185.167.97.144:7880 | API LiveKit | ✅ Exposé |
| Nginx | http://185.167.97.144 | Reverse proxy | ✅ Exposé |
| LiveKit Dashboard | http://185.167.97.144:7880 | Monitoring | ✅ Exposé |

### 4.2 Services Docker (local)

| Service | Port | Rôle | Statut |
|---------|------|------|--------|
| academia-backend | 8001 | Backend FastAPI | Local |
| academia-videoasset-worker | - | Worker vidéo | Local |

### 4.3 Services Railway (production)

| Service | URL | Rôle | Statut |
|---------|-----|------|--------|
| academia-backend | https://academia-app-production.up.railway.app | Backend FastAPI (proxy Supabase, endpoints vidéo) | ⚠️ Indisponible (accès Railway bloqué) |

---

## 5. CONTENEURS DÉTAILLÉS

### 5.1 academia-backend

| Paramètre | Valeur |
|-----------|--------|
| **Nom** | academia-backend |
| **Image** | python:3.11-slim |
| **Ports** | 8001:8000 (local) |
| **Commande** | uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000} |
| **Healthcheck** | curl -f http://localhost:8000/debug/ffmpeg |
| **Restart** | unless-stopped |
| **Volumes** | /tmp/academia_render:/tmp |
| **Rôle** | Proxy Supabase, endpoints vidéo, endpoints IA, endpoints LiveKit |

**Endpoints vidéo :**
- `/debug/ffmpeg` - Diagnostic FFmpeg
- `/supabase/{full_path:path}` - Proxy Supabase
- `/studio/video/render` - Rendu vidéo
- `/challenge/burn-overlays` - Burn overlays
- `/challenge/generate-thumbnail` - Génération thumbnail

### 5.2 academia-videoasset-worker

| Paramètre | Valeur |
|-----------|--------|
| **Nom** | academia-videoasset-worker |
| **Image** | python:3.11-slim |
| **Commande** | python -u videoasset_worker.py |
| **Restart** | unless-stopped |
| **Volumes** | /tmp/academia_render:/tmp, ./assets/images:/assets/images:ro |
| **Rôle** | Worker de traitement vidéo (poll video_processing_jobs) |

**Configuration :**
- `WORKER_LOOP=1` - Mode boucle infinie
- `WORKER_INTERVAL_SECONDS=2` - Intervalle de polling
- `WORKER_MAX_JOBS=3` - Jobs max par itération
- `SUPABASE_PROXY_URL=http://academia-backend:8000` - Proxy via backend
- `WATERMARK_LOGO_PATH=/assets/images/academia.png` - Logo watermark

**Jobs supportés :**
- `generate_hls` / `generate_mp4` - Transcodage multi-résolution
- `export_watermarked` - Watermark TikTok-style

---

## 6. LIVEKIT

### 6.1 Configuration

| Paramètre | Valeur |
|-----------|--------|
| **Host** | 185.167.97.144 |
| **Port** | 7880 |
| **API Key** | APIKeylrmgQYJgiEZa |
| **API Secret** | uXu7tiObNgaLkYA3VydinjsKRzPJjL8SNWC9pRx8 |
| **WebSocket** | ws://185.167.97.144:7880 |
| **HTTP** | http://185.167.97.144:7880 |

### 6.2 Edge Functions LiveKit

| Edge Function | Rôle | Statut |
|---------------|------|--------|
| `livekit-token` | Génération JWT LiveKit | ✅ Déployé |
| `livekit-recording` | Enregistrement sessions | ✅ Déployé |

### 6.3 Recording

**Mécanisme :** LiveKit Egress

**Destination :** Supabase Storage

**Table :** `challenge_game_live_sessions.replay_video_asset_id`

---

## 7. REDIS

| Paramètre | Valeur |
|-----------|--------|
| **Host** | 127.0.0.1 |
| **Port** | 6379 |
| **Rôle** | Cache LiveKit (rooms, participants) |
| **Statut** | Local au VPS Kamatera |

---

## 8. POSTGRESQL

**Localisation :** Supabase Cloud (pas sur Kamatera)

**Rôle :** Base de données principale

**Schéma app :**
- video_assets
- video_sources
- video_renditions
- video_processing_jobs
- challenge_game_live_sessions
- participations

---

## 9. NGINX

| Paramètre | Valeur |
|-----------|--------|
| **Host** | 185.167.97.144 |
| **Port** | 80 |
| **Rôle** | Reverse proxy pour LiveKit |
| **Status endpoint** | http://185.167.97.144/status |

---

## 10. FFMPEG

### 10.1 Installation (vérifié via SSH)

**Localisation :** Installé sur le VPS Kamatera (/usr/bin/ffmpeg)

**Version :** 6.1.1-3ubuntu5

**Installation :** Via apt-get (Ubuntu 24.04.4 LTS)

**Note :** FFmpeg est installé sur Kamatera mais n'est PAS utilisé pour l'encodage vidéo. Le transcodage vidéo se fait soit localement (Docker) soit sur Railway (indisponible).

### 10.2 Utilisation

**Backend (academia-backend) :**
- `/debug/ffmpeg` - Diagnostic
- Transcodage via `studio_video_renderer.py`
- Watermark via `_run_ffmpeg_export_watermarked`
- Transcodage multi-résolution (480p, 360p, 240p)

**Worker (academia-videoasset-worker) :**
- Poll `video_processing_jobs`
- Transcodage multi-résolution (main, 480p, 360p, 240p)
- Watermark TikTok-style
- Upload vers Supabase Storage

### 10.3 Profils de transcodage

| Profil | Résolution | Bitrate | Codec |
|--------|------------|---------|-------|
| mp4_main | 720p | - | libx264 |
| mp4_480p | 480p | 800k | libx264 |
| mp4_360p | 360p | - | libx264 |
| mp4_240p | 240p | 400k | libx264 |

---

## 11. WORKERS

### 11.1 academia-videoasset-worker

**Fichier :** `academia_bobodo_backend/videoasset_worker.py`

**Mode :** Boucle infinie (WORKER_LOOP=1)

**Intervalle :** 2 secondes

**Jobs max :** 3 par itération

**Mécanisme :**
1. Poll `video_processing_jobs` (status=queued)
2. Marque job comme running
3. Télécharge source depuis Supabase Storage
4. Exécute FFmpeg (transcodage ou watermark)
5. Upload renditions vers Supabase Storage
6. Met à jour `video_renditions`
7. Marque job comme done

**Jobs supportés :**
- `generate_hls` / `generate_mp4` - Transcodage multi-résolution
- `export_watermarked` - Watermark TikTok-style

---

## 12. PIPES MÉDIA

### 12.1 Pipeline vidéo actuel

```
Flutter → Supabase Storage → Edge Function transcode-video → Rendition "original"
                                                        ↓
                                             Edge Function transcode-multi-resolution
                                                        ↓
                                             video_processing_jobs (queued)
                                                        ↓
                                             Worker Docker (poll)
                                                        ↓
                                             FFmpeg transcodage
                                                        ↓
                                             Upload Supabase Storage
                                                        ↓
                                             video_renditions (ready)
```

### 12.2 Pipeline LiveKit

```
Flutter → Edge Function livekit-token → JWT
              ↓
         LiveKit ws://185.167.97.144:7880
              ↓
         Streaming temps réel
              ↓
         LiveKit Egress
              ↓
         Supabase Storage
              ↓
         challenge_game_live_sessions.replay_video_asset_id
```

---

## 13. OBSERVATIONS CRITIQUES

### 13.1 Kamatera = LiveKit uniquement (vérifié via SSH)

**Observation :** Kamatera n'héberge que LiveKit (conteneur Docker), Redis et Nginx. Il n'y a pas de composant d'encodage vidéo actif.

**Preuve :** 
- Seul 1 conteneur Docker tourne : livekit-server
- FFmpeg est installé mais non utilisé pour l'encodage vidéo
- Aucun service de transcodage vidéo n'est actif

**Conséquence :** Le transcodage vidéo se fait soit localement (Docker), soit sur Railway (backend), mais pas sur Kamatera.

### 13.2 Backend Railway indisponible

**Observation :** L'accès Railway est bloqué. Le backend `academia-backend` est déployé sur Railway mais inaccessible.

**Conséquence :** Le proxy Supabase et les endpoints vidéo lourds ne sont pas disponibles en production. Seule la version locale Docker fonctionne.

### 13.3 Worker Docker local

**Observation :** Le worker `academia-videoasset-worker` est configuré pour tourner en local via Docker Compose.

**Conséquence :** Le traitement vidéo multi-résolution ne fonctionne que si le Docker Compose est lancé localement. En production, les jobs restent en status "queued" sans être traités.

### 13.4 FFmpeg présent mais sous-utilisé

**Observation :** FFmpeg est installé dans les conteneurs Docker, mais le transcodage multi-résolution n'est pas activé en production.

**Conséquence :** Seule la rendition "original" est créée par l'Edge Function Supabase. Les renditions 720p, 480p, 240p ne sont jamais générées.

### 13.5 Pas d'architecture de traitement vidéo sur Kamatera

**Observation :** Il n'y a pas de service d'encodage vidéo sur Kamatera. Le VPS Kamatera est dédié à LiveKit uniquement.

**Conséquence :** Le traitement vidéo doit se faire ailleurs (Docker local ou Railway).

---

## 14. COMPOSANTS D'ENCODAGE VIDÉO

### 14.1 Existant

| Composant | Localisation | Rôle | Statut |
|-----------|-------------|------|--------|
| FFmpeg | Docker academia-backend | Transcodage, watermark | ✅ Installé |
| FFmpeg | Docker academia-videoasset-worker | Transcodage multi-résolution | ✅ Installé |
| studio_video_renderer.py | academia_bobodo_backend | Fonctions FFmpeg | ✅ Prêt |
| videoasset_worker.py | academia_bobodo_backend | Worker polling | ✅ Prêt |

### 14.2 Non déployé en production

| Composant | Raison | Statut |
|-----------|--------|--------|
| academia-backend (Railway) | Accès Railway bloqué | ❌ Indisponible |
| academia-videoasset-worker (Railway) | Accès Railway bloqué | ❌ Indisponible |
| Transcodage multi-résolution | Worker non déployé | ❌ Non fonctionnel |

---

## 15. ARCHITECTURE DE TRAITEMENT VIDÉO

### 15.1 Actuelle

**Local (Docker) :**
- Flutter → Supabase Storage → Edge Function transcode-video → Rendition "original"
- video_processing_jobs (queued) → Worker Docker (non lancé) → Jobs non traités

**Production (Railway) :**
- Flutter → Supabase Storage → Edge Function transcode-video → Rendition "original"
- video_processing_jobs (queued) → Worker Railway (indisponible) → Jobs non traités

### 15.2 Prévue (quand Railway revient)

**Production (Railway) :**
- Flutter → Supabase Storage → Edge Function transcode-video → Rendition "original"
- video_processing_jobs (queued) → Worker Railway → FFmpeg transcodage → Renditions multi-résolution

---

**Statut :** ✅ PHASE C TERMINÉE
