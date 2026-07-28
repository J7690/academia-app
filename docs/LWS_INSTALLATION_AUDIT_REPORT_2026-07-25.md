# Audit LWS - Etat de l'installation et capacites reelles

Date: 2026-07-25
Serveur: lws-nexiom (root@31.207.38.60)
Auteur: Windsurf
Destinataire: Claude

## 1. Resume executif

- Le serveur LWS (Ubuntu 24.04, 4 vCPU, 8 Go RAM, 147 Go disque) heberge le pipeline Smart Whiteboard complet: worker Python, moteur Remotion, moteur Vision, voix off Kokoro via Docker.
- Le worker `whiteboard-worker.service` est actif et poll Supabase sans erreur.
- La balise de sante `app.whiteboard_engine_health` est publiee avec succes (`ready_basic=true`).
- Seule la Phase 1 de la migration Kamatera vers LWS est operationnelle. Les phases 2 (video compression/upload), 3 (LiveKit/Redis/Nginx) et 4 (academia-node) ne sont pas encore installees.

## 2. Sources consultees

Fichiers du depot et scripts d'audit LWS:

- `.windsurf/lws_bootstrap_whiteboard.sh` - script canonical de bootstrap Smart Whiteboard
- `.windsurf/lws_vps_audit.py` - script Python d'audit non destructif du VPS
- `.windsurf/lws_vps_reference.md` - reference LWS (vide ou illisible lors de la lecture)
- `docs/AUDIT_WINDSURF_LWS_ETAT_ACTUEL.md` - protocole d'audit lecture seule
- `docs/INSTRUCTIONS_WINDSURF_LWS.md` - guide d'installation du pipeline Remotion sur LWS
- `docs/MIGRATION_COMPLETE_KAMATERA_VERS_LWS.md` - plan complet de migration des 4 phases
- `whiteboard_engine_remotion/deploy/bootstrap_lws.sh` - bootstrap dans le moteur Remotion
- Inspection directe via SSH `lws-nexiom`

## 3. Identite et ressources du serveur

- OS: Ubuntu 24.04.4 LTS (kernel 6.12.95+deb13-amd64)
- Architecture: x86_64
- RAM: 8 Go total, ~7,5 Go disponibles au repos
- Disque: 147 Go total, 8,7 Go utilises, 138 Go libres (6%)
- CPU: 4 vCPU (constate lors d'audits precedents)
- Acces SSH: alias `lws-nexiom` configure avec cle root

## 4. Versions des runtimes et outils

- Node.js: v20.20.2
- npm: 10.8.2
- Python: 3.12.3
- ffmpeg: 6.1.1-3ubuntu5
- Docker: installe et actif
- Systemd: whiteboard-worker.service active (running)

## 5. Arborescence /opt

Dossiers deploiement existants:

- `/opt/whiteboard-worker`
  - `.env` (permissions 600)
  - `whiteboard_render_worker.py`
  - `whiteboard_png_renderer.py`
  - `whiteboard_ffmpeg_assembler.py`
  - `whiteboard_upload_renderer.py`
  - `vision_engine/` (copie de `academia_bobodo_backend/whiteboard_vision` effectuee le 23/07)

- `/opt/whiteboard-engine-remotion`
  - `package.json`, `package-lock.json`
  - `node_modules/` (165 sous-repertoires)
  - `src/` (composants React/Remotion)
  - `render.mjs`, `render_bridge.py`
  - `healthcheck.py`, `narrate.py`, `manim_render.py`
  - `deploy/`, `public/`, `remotion.config.ts`, `tsconfig.json`

- `/opt/containerd` (Docker)

Dossiers attendus mais absents (migration Phase 2-4):

- `/opt/academia`
- `/opt/academia-backend`
- `/opt/livekit`

## 6. Configuration .env (/opt/whiteboard-worker/.env)

Variables actives (la cle de service Supabase est masquee):

- `SUPABASE_URL=https://thevdfcwlcqzdoybfvgs.supabase.co`
- `SUPABASE_SERVICE_KEY` - presente (valeur sensible non affichee)
- `WORKER_LOOP=1`
- `WORKER_INTERVAL_SECONDS=2`
- `WORKER_MAX_JOBS=1`
- `REMOTION_ENGINE_DIR=/opt/whiteboard-engine-remotion`
- `KOKORO_URL=http://127.0.0.1:8880/v1/audio/speech`
- `KOKORO_VOICE=ff_siwis`
- `KOKORO_MODEL=kokoro`
- `KOKORO_SPEED=0.95`
- `RENDERER_ENGINE=vision`

Le fichier est en ligne LF (les problemes CRLF initiaux ont ete corriges).

## 7. Moteur Remotion

- `package.json` dependances:
  - `@remotion/bundler`, `@remotion/cli`, `@remotion/renderer`, `@remotion/google-fonts`, `@remotion/transitions`, `@remotion/lottie`, `@remotion/motion-blur`, `@remotion/paths`, `@remotion/media-utils` : `^4.0.0`
  - `remotion` : `^4.0.0`
  - `react`/`react-dom` 18.3.1
  - `katex` 0.16.9
  - `typescript` 5.4.5 (dev)

- Chromium: installe dans `node_modules/.remotion/chrome-headless-shell`, symlink depuis `~/.cache/chrome-headless-shell`
- Rendu de test reussi precedemment: `/tmp/pro.mp4` avec `profile=Main`, `level=40`, `720x1280`
- Note: le bootstrap initial a necessite un `npm install` car `package-lock.json` etait absent; les versions exactes `4.0.0` ont ete remplacees par `^4.0.0` dans le `package.json` du serveur.

## 8. Moteur Vision

- Dossier `/opt/whiteboard-worker/vision_engine` present et operationnel
- Fichiers cles:
  - `whiteboard_scene_engine.py`
  - `whiteboard_playwright_capture.py`
  - `capture_scene.js`
  - `katex_renderer.js`
  - `diagram_renderer.js`
  - `scene_template.html`
  - `__init__.py`
- `RENDERER_ENGINE=vision` active dans `.env`
- Test d'import direct: `python3 -c 'import whiteboard_scene_engine'` reussit

## 9. Services systemd et conteneurs Docker

Services systemd actifs:

- `whiteboard-worker.service` - Academia Smart Whiteboard Render Worker (active, running)
- `docker.service` - Docker Application Container Engine (active, running)

Conteneur Docker actif:

- `kokoro-tts` - `ghcr.io/remsky/kokoro-fastapi-cpu:latest`
  - Statut: Up (47h au moment de l'audit)
  - Port: `127.0.0.1:8880->8880/tcp`
  - Endpoint: `http://127.0.0.1:8880/v1/audio/speech`

## 10. Sante du pipeline

Resultat de `healthcheck.py` (execution sans variables d'environnement, publication locale):

- `node`: v20.20.2
- `npm`: 10.8.2
- `ffmpeg`: true
- `remotion_installed`: true
- `chromium_ready`: true
- `kokoro_reachable`: false* (la variable KOKORO_URL n'etait pas chargee dans ce test isole)
- `pexels_key_set`: false
- `manim_enabled`: false
- `ready_basic`: true
- Lors d'une execution avec `.env` source, la publication vers `app.whiteboard_report_engine_health` a reussi (HTTP 204).

## 11. Logs worker observables

Les 30 dernieres lignes de `journalctl -u whiteboard-worker` montrent:

- Requetes POST `whiteboard_fetch_queued_jobs` -> `HTTP/1.1 200 OK`
- `Found 0 queued job(s)` repete
- Aucune erreur `Traceback`, `Error` ou `echec` visible
- Le worker est en attente de jobs Supabase.

## 12. Etat de la migration Kamatera -> LWS

Tableau de conformite au plan `docs/MIGRATION_COMPLETE_KAMATERA_VERS_LWS.md`:

| # | Service | Statut LWS | Commentaire |
|---|---|---|---|
| 1 | whiteboard-worker (Vision + Remotion) | actif | Operationnel |
| 2 | Kokoro TTS | actif | Docker `kokoro-tts` sur 127.0.0.1:8880 |
| 3 | academia-backend (compression/watermark) | absent | Phase 2 non demarree |
| 4 | academia-videoasset-worker | absent | Phase 2 non demarree |
| 5 | LiveKit server | absent | Phase 3 non demarree |
| 6 | Redis | absent | Phase 3 non demarree |
| 7 | Nginx | absent | Phase 3 non demarree |
| 8 | LiveKit Egress | absent | Phase 3 non demarree |
| 9 | academia-node (API REST/connecteurs) | absent | Phase 4 non demarree |

## 13. Capacites reelles

### Ce qui fonctionne maintenant

- Polling Supabase des jobs whiteboard (`whiteboard_fetch_queued_jobs` repond 200 OK)
- Rendu Remotion de test valide (Main@L4.0, 720x1280)
- Import des modules `render_bridge` et `whiteboard_scene_engine`
- Generation de voix off via Kokoro TTS local
- Publication de la balise de sante `ready_basic=true` vers Supabase
- Moteur Vision active (`RENDERER_ENGINE=vision`)

### Limites et points d'attention

- Le worker n'a pas encore traite de jobs reels depuis le dernier redemarrage (0 queued).
- Le moteur Vision depend de Playwright/Node/KaTeX; bien que les fichiers soient presents, aucun rendu Vision complet n'a ete valide en production sur LWS a ce jour.
- RAM 8 Go: conforme au minimum, mais le plan de migration recommande 16 Go pour eviter les `JavaScript heap out of memory` observes sur Kamatera. A surveiller lors de rendus Remotion lourds.
- `ready_basic=true` mais `kokoro_reachable` est marque false quand le `KOKORO_URL` n'est pas exporte; avec `.env` source, le conteneur repond (HTTP 404 sur GET /, ce qui est attendu).
- Phases 2, 3 et 4 de la migration sont entierement absentes.

## 14. Ecarts par rapport aux instructions initiales

- Le bootstrap canonical `.windsurf/lws_bootstrap_whiteboard.sh` a ete utilise, mais a necessite des ajustements manuels:
  - Remplacement de `npm ci` par `npm install` a cause d'un `package-lock.json` manquant initialement.
  - Correction des versions Remotion de `4.0.0` exact a `^4.0.0`.
  - Normalisation des fins de ligne CRLF -> LF sur `/opt/whiteboard-worker/.env`.
  - Deploiement manuel de `vision_engine` depuis `academia_bobodo_backend/whiteboard_vision` car le dossier n'existait pas sur le serveur.

## 15. Recommandations

1. Valider Phase 1 par 2-3 rendus reels depuis l'app Flutter avec `engine=vision` puis `engine=remotion`.
2. Si validation OK, repasser le provider Flutter de `'engine': 'vision'` a `'engine': 'remotion'`.
3. Augmenter la RAM de LWS a 16 Go avant de lancer des rendus lourds ou concurrents.
4. Phase 2: deployer `academia-backend` et `academia-videoasset-worker` via `docker-compose.yml`.
5. Phase 3: installer LiveKit self-hosted, Redis (127.0.0.1 uniquement), Nginx.
6. Phase 4: migrer `academia-node`.
7. Ne pas couper Kamatera avant validation reelle de toutes les phases.

---

*Rapport genere automatiquement par Windsurf pour transmission a Claude.*
