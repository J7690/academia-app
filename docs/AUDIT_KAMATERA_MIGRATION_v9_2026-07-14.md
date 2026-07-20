# Audit Kamatera + déploiement Whiteboard v9 — Rapport avec preuves

**Date** : 14 juillet 2026  
**Contexte** : Brief « Migration Railway → Kamatera + déploiement worker Whiteboard v9 ».  
**Méthode** : audits SSH en lecture seule + tests de confirmation (aucune supposition).

---

## TL;DR — Recommandation

1. **FAIT & VALIDÉ** : le correctif **Whiteboard v9** est déployé sur le worker actif et
   vérifié de bout en bout (profil `Main` / level `4.0`, 720×1280 `yuv420p`, **durées exactes**,
   décodage OK, texte lisible).
2. **RECOMMANDATION (preuves à l'appui) : NE PAS exécuter la consolidation `docker compose`
   du brief sur ce VPS.** Elle casserait des services live et créerait des **doublons de
   pollers** — exactement le danger que le brief interdit. L'objectif réel du brief (« tout le
   traitement vidéo sur Kamatera + fix worker ») est **déjà atteint**.

---

## 1. Architecture réelle du VPS (preuves)

VPS `185.167.97.144` — Ubuntu 24.04, Docker 29.5.3 présent mais **un seul conteneur**
(`livekit-server`). Tout le reste tourne en **systemd**, pas en docker.

| Port / Unité | Rôle réel | Consommateur | Preuve |
|---|---|---|---|
| **8001** `academia-compress.service` | Serveur HTTP de **compression vidéo** (`POST /compress` : download → ffmpeg + watermark → upload Supabase). Clé service Supabase en dur. | Compression des vidéos | `head app.py`, `systemctl cat` |
| **8000** `bobodo-vocal.service` | FastAPI + **WebSocket `/ws`** (STT/TTS vocal) | **Flutter** `voice_provider.dart` → `ws://185.167.97.144:8000/ws` | `systemctl cat` + code Flutter |
| `video-worker.service` | `videoasset_worker.py` — poll `app.video_processing_jobs` via `SUPABASE_URL` | Pipeline vidéos Challenge | code L.99, `.env`, `systemctl cat` |
| `whiteboard-worker.service` | `whiteboard_render_worker.py` **v9** — poll `whiteboard_renders` | Smart Whiteboard | v9 confirmé + `is-active` |
| `livekit-server` (docker) | LiveKit | Sessions live | `docker ps` |

**Constats prouvés :**
- Le FastAPI `main.py` du dépôt (`academia_bobodo_backend/main.py`, 192 Ko) **n'est déployé
  nulle part** et **aucun consommateur ne l'appelle**. Le port 8001 est un service de
  compression indépendant, pas ce backend.
- Les ports **8000 et 8001 sont tous deux occupés par des services live**.
- **Aucun trafic Railway actif** : `grep -r railway /opt /root` ne renvoie que des fichiers de
  `site-packages` (docs `rich`, metadata `fastapi`). `url_normalizer.dart` ne fait que
  réécrire d'anciennes URLs stockées → Supabase (legacy inoffensif).

---

## 2. Pourquoi la consolidation `docker compose` du brief est inadaptée ICI

Le brief suppose une topologie (backend FastAPI + videoasset-worker + whiteboard-worker à
regrouper) qui **n'existe pas** sur ce VPS. Appliqué tel quel, `docker compose up -d --build` :

1. **Conflit de port** : `academia-backend` mappe `8001:8000` → **collision** avec
   `academia-compress.service` (8001) déjà live. Bind refusé, ou service de compression cassé.
2. **Doublon de poller vidéo** : `academia-videoasset-worker` pollerait
   `app.video_processing_jobs` **en parallèle** de `video-worker.service` déjà actif → deux
   pollers sur les mêmes jobs (le brief l'interdit explicitement).
3. **Doublon de poller whiteboard** : `academia-whiteboard-worker` doublonnerait le
   `whiteboard-worker.service` systemd déjà à jour v9.
4. **Backend inutile** : déploierait un FastAPI `main.py` qu'aucun client n'utilise, et
   risquerait le WS vocal (8000) dont dépend l'app.

**Bénéfice de la migration aujourd'hui : nul. Risque : élevé (coupure vocal/compression).**

---

## 3. Objectif du brief déjà atteint (preuves)

- **« Tout le traitement vidéo sur Kamatera »** :
  - `app.video_processing_jobs` : **207 jobs `done`** sur 30 jours, aucun bloqué.
  - `whiteboard_renders` : rendus produits sur Kamatera.
  - Railway : mort, aucune référence active.
- **« Déployer le correctif worker whiteboard v9 »** : fait (section 4).

---

## 4. Déploiement Whiteboard v9 — réalisé et vérifié

**Déployé** sur `/opt/whiteboard-worker` (les 3 fichiers ensemble, respect du garde-fou de
signature) puis `systemctl restart whiteboard-worker` :
- `whiteboard_ffmpeg_assembler.py` (v9 : `main`/`4.0`, encodage segment-par-segment à durée exacte)
- `whiteboard_render_worker.py` (respect `duration_ms` par scène + durée totale réelle)
- `whiteboard_png_renderer.py`

**Un seul poller** confirmé (`ps aux` : pid unique `whiteboard_render_worker.py`). Service `active`.

**Test de rendu neuf** (job `b0547110-…`, scènes 3s / 7s / 4s) :
```
codec_name=h264   profile=Main   level=40
width=720  height=1280  pix_fmt=yuv420p
duration=14.000000     # = 3+7+4 s, durées EXACTES respectées
ffmpeg -v error -i x.mp4 -f null -   -> DECODE_OK
```
- Frame extraite : titre + paragraphe word-wrappé, lisible, non tronqué
  (`.windsurf/logs/whiteboard_frame.png`).
- **Preuve du fix des durées** : le nouveau rendu = `duration_ms=14000` (exact), alors que les
  anciens rendus v8 étaient à 40000 / 15000 / 55000 ms (multiples de 5 s = l'ancien bug).

---

## 5. Modifications dépôt (non déployées sur VPS)

- `docker-compose.yml` : ajout du 3ᵉ service `academia-whiteboard-worker` (Tâche 1 du brief).
  **Conservé pour usage futur** (si un jour containerisation complète), mais **NON appliqué**
  sur ce VPS pour les raisons de la section 2.
- `whiteboard_ffmpeg_assembler.py`, `whiteboard_render_worker.py`, `requirements.txt`,
  `Dockerfile`, `main.py`, `url_normalizer.dart` : déjà corrigés dans le dépôt (v9).

> ⚠️ **Attention future** : si quelqu'un lance `docker compose up` sur ce VPS, il créera des
> doublons de pollers + conflit de port. Ne le faire qu'après avoir migré/arrêté les services
> systemd correspondants (voir section 6).

---

## 6. Si une vraie consolidation docker est souhaitée plus tard (plan sûr)

1. Copier `/opt/*/.env` → `academia_bobodo_backend/.env` (SUPABASE_URL, SUPABASE_SERVICE_KEY, …).
2. Choisir des ports libres pour le backend (ex. `8002:8000`) OU d'abord décommissionner
   `academia-compress.service` (8001) et rebrancher la compression sur le nouveau backend.
3. **Avant** `docker compose up`, arrêter les pollers systemd doublons :
   `systemctl disable --now video-worker whiteboard-worker`.
4. Préserver le vocal : soit conteneuriser `bobodo-vocal`, soit garder son systemd et NE PAS
   binder 8000 côté docker.
5. `docker compose up -d --build` puis vérifier `docker compose ps` + endpoints.

---

## 7. Vérifications du brief — état

- [x] `docker compose ps` 3 services Up → **N/A** : consolidation non appliquée (justifié).
- [x] **Rendu whiteboard neuf** `profile=Main, level=40, 720x1280, yuv420p` + **durée exacte** + `DECODE_OK` + lisible → **OK**.
- [x] Job whiteboard `queued` → `done` → **OK** (`b0547110`).
- [x] `video_processing_jobs` : 207 `done`, pipeline sain sur Kamatera → **OK**.
- [x] `git grep railway` → doc/legacy uniquement, aucun host actif → **OK**.
- [x] Aucun trafic sortant `*.up.railway.app` → **OK** (aucune conf active).

---

## Artefacts

- `.windsurf/inspect_kamatera_state.py` — inspection topologie VPS
- `.windsurf/inspect_kamatera_backend.py` — inspection backends 8000/8001
- `.windsurf/audit_kamatera_services.py` + `.windsurf/logs/audit_kamatera_services.txt` — audit services
- `.windsurf/confirm_pipelines_health.py` — santé pipelines Supabase
- `.windsurf/deploy_v1_worker_update.py` — déploiement v9
- `.windsurf/test_whiteboard_v1_render.py` — test rendu (durées 3/7/4 s)
- `.windsurf/verify_rendered_mp4.py` — ffprobe/ffmpeg + frame
- `.windsurf/logs/whiteboard_frame.png` — frame de contrôle
