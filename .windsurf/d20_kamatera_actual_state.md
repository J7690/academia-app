# D.20 – PHASE 4 : ÉTAT RÉEL KAMATERA

**Date** : 2026-06-28  
**Mission** : D.20 – Audit de conformité  
**Outils utilisés** : `audit_kamatera_full.py`, `d20_kamatera_whiteboard_audit.py`  
**Méthode** : SSH paramiko → root@185.167.97.144

---

## 1. IDENTIFICATION DU SERVEUR

| Attribut | Valeur |
|----------|--------|
| Hostname | `academia00` |
| IP | `185.167.97.144` |
| OS | Ubuntu Linux 6.8.0-117-generic (2026-05-05) |
| Accès | root |

---

## 2. SERVICES SYSTEMD ACTIFS

| Service | État | PID | Depuis |
|---------|------|-----|--------|
| `whiteboard-worker.service` | ✅ active (running) | 395272 | 2026-06-24 19:05:38 UTC |
| `bobodo-vocal.service` | ✅ active (running) | 166139 | 2026-06-14 13:23:57 UTC |
| `academia-compress.service` | ✅ active (running) | 304107 | 2026-06-20 18:59:51 UTC |
| `docker.service` | ✅ active (running) | — | — |
| `nginx.service` | ✅ active (running) | 388098 | — |
| `redis-server` | ✅ active (via port 6379) | 124968 | — |
| `containerd.service` | ✅ active (running) | — | — |

---

## 3. WHITEBOARD WORKER

### 3.1 Fichier systemd

**Chemin** : `/etc/systemd/system/whiteboard-worker.service`

```ini
[Unit]
Description=Whiteboard Render Worker Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/whiteboard-worker
ExecStart=/usr/bin/python3 /opt/whiteboard-worker/whiteboard_render_worker.py
Restart=always
RestartSec=5
LimitNOFILE=65536
StandardOutput=journal
StandardError=journal
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
```

### 3.2 Processus actif

```
root  395272  2.9%  /usr/bin/python3 /opt/whiteboard-worker/whiteboard_render_worker.py
```
**CPU** : ~2.9% (153 min CPU depuis Jun 24)  
**RAM** : 34.4M (peak 115.2M)

### 3.3 Fichiers /opt/whiteboard-worker/

```
total 836
-rw-r--r--  .env                       353 bytes  (Jun 23)
-rw-r--r--  whiteboard_ffmpeg_assembler.py  1976 bytes  (Jun 23)
-rw-r--r--  whiteboard_png_renderer.py      6526 bytes  (Jun 23)
-rw-r--r--  whiteboard_render_worker.py     6230 bytes  (Jun 23)
-rw-r--r--  whiteboard_upload_renderer.py   1872 bytes  (Jun 23)
-rw-r--r--  worker.log                    807664 bytes  (Jun 23)
drwxr-xr-x  __pycache__/
```

### 3.4 Variables d'environnement (.env masqué)

```
SUPABASE_URL=***
SUPABASE_SERVICE_KEY=***
WORKER_LOOP=***
WORKER_INTERVAL_SECONDS=***
WORKER_MAX_JOBS=***
```
Toutes les 5 variables attendues sont configurées.

---

## 4. LOGS DU WORKER (derniers 30)

```
Jun 28 09:01:57  INFO: HTTP Request: POST https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/whiteboard_fetch_queued_jobs "HTTP/1.1 200 OK"
Jun 28 09:01:57  INFO: [whiteboard_render_worker] Found 0 queued job(s)
Jun 28 09:01:59  INFO: HTTP Request: POST https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/whiteboard_fetch_queued_jobs "HTTP/1.1 200 OK"
Jun 28 09:01:59  INFO: [whiteboard_render_worker] Found 0 queued job(s)
Jun 28 09:02:01  INFO: HTTP Request: POST ...whiteboard_fetch_queued_jobs "HTTP/1.1 200 OK"
```

**→ Le worker poll activement `whiteboard_fetch_queued_jobs` toutes ~2 secondes.**  
**→ La RPC répond 200 OK avec 0 jobs (aucun job en attente).**  
**→ Le pipeline de rendu est opérationnel mais sans travail à traiter.**

---

## 5. PIPELINE PYTHON

### 5.1 whiteboard_render_worker.py

| Composant | État |
|-----------|------|
| Import `whiteboard_png_renderer` | ✅ présent localement |
| Import `whiteboard_ffmpeg_assembler` | ✅ présent localement |
| Import `whiteboard_upload_renderer` | ✅ présent localement |
| Boucle polling `whiteboard_fetch_queued_jobs` | ✅ active (prouvé par logs) |
| Appel `whiteboard_mark_processing` | ✅ dans le code |
| Appel `whiteboard_mark_done` | ✅ dans le code |
| Appel `whiteboard_mark_failed` | ✅ dans le code |
| `WHITEBOARD_BUCKET = "whiteboard-renders"` | ✅ configuré |
| `WHITEBOARD_TABLE = "whiteboard_renders"` | ✅ configuré |

### 5.2 whiteboard_ffmpeg_assembler.py

| Élément | État |
|---------|------|
| Utilise `ffmpeg` subprocess | ✅ présent |
| Pattern PNG : `scene_%03d.png` | ✅ présent |
| Output : `output.mp4` | ✅ présent |
| Vérification existence PNGs | ✅ présent |

### 5.3 whiteboard_upload_renderer.py

| Élément | État |
|---------|------|
| `WHITEBOARD_BUCKET = "whiteboard-renders"` | ✅ présent |
| Object key : `renders/{render_id}/{uuid}.mp4` | ✅ présent |
| URL construite : `{SUPABASE_URL}/storage/v1/object/public/{WHITEBOARD_BUCKET}/{object_key}` | ✅ présent |
| Upload via httpx async | ✅ présent |

---

## 6. FFMPEG

```
ffmpeg version 6.1.1-3ubuntu5
Copyright (c) 2000-2023 the FFmpeg developers
built with gcc 13 (Ubuntu 13.2.0-23ubuntu3)
```

**→ FFmpeg 6.1.1 installé et disponible dans PATH. H.264/AAC supportés.**

---

## 7. PYTHON ET DÉPENDANCES

| Package | Version |
|---------|---------|
| Python | 3.12.3 |
| httpx | 0.28.1 |
| pillow | 12.2.0 |
| requests | 2.31.0 |

**Absent** : `supabase` SDK Python (non requis, le worker utilise httpx direct)

---

## 8. RÉSEAU ET PORTS

| Port | Process | Rôle |
|------|---------|------|
| 8000 | `python` (PID 166139) | bobodo-vocal FastAPI |
| 8001 | `python3` (PID 304107) | academia-compress service |
| 80 | nginx | Reverse proxy |
| 22 | sshd | SSH |
| 6379 | redis-server | Redis (localhost only) |
| 7880/7881 | livekit-server (Docker) | LiveKit WebRTC |

**→ Aucun port dédié whiteboard-worker** (le worker est client HTTP sortant uniquement).

---

## 9. AUTRES SERVICES (hors scope whiteboard)

| Service | État | Rôle |
|---------|------|------|
| `bobodo-vocal` (port 8000) | ✅ Running | FastAPI Bobodo vocal |
| `academia-compress` (port 8001) | ✅ Running | Compression vidéo FFmpeg |
| `livekit-server` (Docker, ports 7880/7881) | ✅ Running | WebRTC LiveKit |

**Absents** :
- `voice_server` → SERVICE_NOT_FOUND
- Piper TTS → PIPER_NOT_IN_PATH
- `/root/voice_server/` → DIR_NOT_FOUND
- `/opt/voice_server/` → DIR_NOT_FOUND

---

## 10. RÉSUMÉ KAMATERA

| Composant | État réel |
|-----------|-----------|
| `whiteboard-worker.service` | ✅ active (running), enabled, depuis Jun 24 |
| Python worker (`whiteboard_render_worker.py`) | ✅ en exécution (PID 395272) |
| Polling `whiteboard_fetch_queued_jobs` | ✅ actif toutes ~2s |
| PNG renderer (`whiteboard_png_renderer.py`) | ✅ présent |
| FFmpeg assembler (`whiteboard_ffmpeg_assembler.py`) | ✅ présent |
| Upload renderer (`whiteboard_upload_renderer.py`) | ✅ présent |
| FFmpeg | ✅ version 6.1.1 |
| Variables .env | ✅ toutes configurées |
| Bucket cible `whiteboard-renders` | ✅ (défini dans code + confirmé Supabase) |
| Jobs en attente | ⚠️ 0 (aucun job créé) |

**→ Le pipeline Kamatera est entièrement opérationnel. Il attend des jobs qui n'arrivent jamais car le flux Flutter est bloqué avant la création d'un render job.**

---

**DOCUMENT CLÔTURÉ** – Audit Kamatera réalisé via SSH paramiko exclusivement.
