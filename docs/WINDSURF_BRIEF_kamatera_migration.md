# Brief Windsurf — Migration Railway → Kamatera + déploiement worker Whiteboard v9

Objectif : faire tourner **tout le traitement vidéo sur Kamatera** (Railway est retiré),
déployer le correctif du worker whiteboard, et consolider proprement en un seul
`docker-compose` sur le VPS. Exécute les tâches dans l'ordre. Ne committe jamais de secret.

---

## État déjà fait (NE PAS refaire — juste déployer)
Ces fichiers sont **déjà corrigés dans le dépôt** :
- `academia_bobodo_backend/whiteboard_ffmpeg_assembler.py` — v9 : profil `main`/level `4.0` (corrige `MediaCodecVideoRenderer error`) + encodage segment-par-segment à **durée exacte**.
- `academia_bobodo_backend/whiteboard_render_worker.py` — respecte `duration_ms` de chaque scène + durée totale réelle.
- `academia_app/lib/utils/url_normalizer.dart` — host proxy configurable `--dart-define=BACKEND_PROXY_HOST` (défaut `185.167.97.144:8001`), ancien host Railway gardé en *legacy*.
- `academia_bobodo_backend/main.py` — CORS Railway → `academiea.com`.
- `academia_bobodo_backend/requirements.txt` — ajout `Pillow` + `matplotlib` (rendu PNG + formules).
- `academia_bobodo_backend/Dockerfile` — commentaire PORT neutralisé.

Ta mission = **déployer** ces changements sur Kamatera + **consolider** + **décommissionner** l'existant Railway/legacy.

---

## Tâche 1 — Ajouter le worker whiteboard au `docker-compose.yml`
Dans `docker-compose.yml` (racine), ajouter un 3ᵉ service (même image que le backend) :

```yaml
  academia-whiteboard-worker:
    build:
      context: ./academia_bobodo_backend
      dockerfile: Dockerfile
    container_name: academia-whiteboard-worker
    env_file:
      - ./academia_bobodo_backend/.env
    environment:
      - WORKER_LOOP=1
      - WORKER_INTERVAL_SECONDS=2
      - WORKER_MAX_JOBS=1
    dns:
      - 1.1.1.1
      - 8.8.8.8
    command: ["python", "-u", "whiteboard_render_worker.py"]
    restart: unless-stopped
    volumes:
      - /tmp/academia_render:/tmp
```

Le worker lit `SUPABASE_URL` / `SUPABASE_SERVICE_KEY` depuis le `.env` (comme le backend).

## Tâche 2 — Vérifier les dépendances image
`requirements.txt` doit contenir `Pillow` et `matplotlib` (déjà ajoutés). Ne rien retirer.
ffmpeg est fourni par le `Dockerfile` (apt) — OK.

## Tâche 3 — Déployer sur le VPS Kamatera disponible
Cible : le VPS Kamatera actif (ex. `185.167.97.144`, héberge déjà LiveKit/Nginx).
Utilise les identifiants SSH Kamatera dont tu disposes.

```bash
ssh root@185.167.97.144
cd /opt && (git -C academia pull || git clone <REPO_URL> academia)
cd /opt/academia

# Secrets backend (ne pas committer) : SUPABASE_URL, SUPABASE_SERVICE_KEY,
# OPENROUTER_API_KEY, LIVEKIT_* , etc.
test -f academia_bobodo_backend/.env || nano academia_bobodo_backend/.env

docker compose up -d --build
docker compose ps
```

## Tâche 4 — Décommissionner l'ancien (éviter les doublons)
1. **Ancien worker whiteboard** en systemd dans `/opt` : il ferait double emploi avec le
   nouveau conteneur → deux pollers sur les mêmes jobs. Le désactiver :
   ```bash
   systemctl disable --now <nom_du_service_whiteboard>   # trouver via: systemctl list-units | grep -i whiteboard
   ```
2. **videoasset-worker / backend Railway** : plus rien à faire côté Railway (mort). Vérifier
   qu'aucune autre machine ne poll `app.video_processing_jobs` en parallèle.

## Tâche 5 — Exposer le backend + rebuild Flutter
- **Option A (immédiat)** : ouvrir le port `8001` → `http://185.167.97.144:8001`. C'est le
  défaut de `BACKEND_PROXY_HOST`, rien à changer côté Flutter.
- **Option B (propre, recommandé)** : ajouter un `location` Nginx (déjà installé sur le VPS)
  `api.academiea.com` → `127.0.0.1:8001` + certificat Let's Encrypt, puis builder le Flutter :
  ```bash
  flutter build apk --dart-define=BACKEND_PROXY_HOST=api.academiea.com
  ```

## Tâche 6 — Vérifications (bloquantes)
- [ ] `curl -f http://185.167.97.144:8001/debug/ffmpeg` → `ok:true`.
- [ ] `docker compose ps` : les 3 services `Up` (backend, videoasset-worker, whiteboard-worker).
- [ ] **Rendu whiteboard neuf** (généré APRÈS déploiement — les anciens restent illisibles) :
      `ffprobe` du MP4 → `profile=Main, level=40, 720x1280, yuv420p` ; durée = somme des
      `duration_ms` des scènes (pas un multiple de 5 s) ; `ffmpeg -v error -i x.mp4 -f null -` sans erreur ;
      lecture OK dans l'app (plus de `MediaCodecVideoRenderer error`).
- [ ] Un job `app.video_processing_jobs` en `queued` passe à `done`.
- [ ] `git grep -i railway` → uniquement de la doc historique, aucun host actif.
- [ ] Aucun trafic sortant vers `*.up.railway.app` dans les logs.

## Garde-fous
- Déployer `whiteboard_ffmpeg_assembler.py` **et** `whiteboard_render_worker.py` ensemble
  (la signature `assemble_pngs_to_mp4(..., durations=...)` a changé — un déploiement partiel
  recrée l'erreur `takes 2 positional arguments but 3 were given`).
- Un seul poller par type de job (désactiver l'ancien systemd whiteboard).
- Ne pas committer `.env` ni les clés Supabase/Kamatera.
- Ne pas remonter en 1080p sans re-tester la lecture sur un appareil d'entrée de gamme
  (si besoin HD : `TARGET_W/H=1080/1920`, `H264_PROFILE="high"`, `H264_LEVEL="4.1"`).

## Rollback
- Worker whiteboard : `docker compose stop academia-whiteboard-worker` puis réactiver
  l'ancien systemd, ou restaurer les `.bak`.
- Backend : `docker compose down` ; les données restent sur Supabase (aucune migration DB ici).
