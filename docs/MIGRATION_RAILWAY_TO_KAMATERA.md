# Migration Railway → Kamatera Cloud

Railway est retiré du dispositif. Ce document liste ce qui en dépendait et comment
tout basculer sur Kamatera. Le worker **whiteboard** parle directement à Supabase et
**n'est pas concerné**.

## 1. Ce qui était sur Railway
- **`academia-backend`** (FastAPI, `academia_bobodo_backend/`) — proxy Supabase + endpoints vidéo lourds (`/studio/video/render`, `/challenge/burn-overlays`, `/challenge/generate-thumbnail`, `/supabase/*`).
- **`academia-videoasset-worker`** (`videoasset_worker.py`) — transcodage multi-résolution + watermark (poll `app.video_processing_jobs`).

URL Railway (morte) : `https://academia-app-production.up.railway.app`.

## 2. Modifications de code déjà appliquées (dans le dépôt)
- `academia_app/lib/utils/url_normalizer.dart` — host proxy **configurable** via
  `--dart-define=BACKEND_PROXY_HOST=...`, défaut `185.167.97.144:8001`. L'ancien host
  Railway est conservé en *legacy* pour que les URLs déjà stockées en base restent normalisées.
- `academia_bobodo_backend/main.py` — CORS : origines Railway → `https://academiea.com` (+ www).
- `academia_bobodo_backend/Dockerfile` — commentaire PORT neutralisé (plus de mention Railway).

> Si tu exposes le backend derrière un domaine + TLS (recommandé), builde le Flutter avec
> `--dart-define=BACKEND_PROXY_HOST=api.academiea.com` au lieu de l'IP:port.

## 3. Déploiement sur Kamatera (à exécuter — hors sandbox)
Cible : **le VPS Kamatera disponible** (ex. `185.167.97.144`, qui héberge déjà LiveKit/Nginx).
Le `docker-compose.yml` (racine du dépôt) lance backend + videoasset-worker.

```bash
ssh root@185.167.97.144
# 1. Récupérer le code (git clone/pull du dépôt sur le VPS)
cd /opt && git clone <REPO_URL> academia || (cd /opt/academia && git pull)
cd /opt/academia

# 2. Renseigner les secrets backend (NE PAS committer)
#    academia_bobodo_backend/.env : SUPABASE_URL, SUPABASE_SERVICE_KEY, OPENROUTER_API_KEY, etc.
nano academia_bobodo_backend/.env

# 3. Construire et lancer (ffmpeg est dans l'image)
docker compose up -d --build

# 4. Vérifier
docker compose ps
curl -f http://localhost:8001/debug/ffmpeg        # doit renvoyer ok:true
docker compose logs --tail=40 academia-videoasset-worker
```

### Exposition du backend
- **Option A (immédiat)** : port `8001` ouvert sur l'IP → `http://185.167.97.144:8001`
  (c'est le défaut de `BACKEND_PROXY_HOST`). HTTP non chiffré : ok mobile, risque
  mixed-content sur le web.
- **Option B (propre)** : ajouter un `location` Nginx (déjà présent sur le VPS) qui
  proxy `api.academiea.com` → `127.0.0.1:8001` + certificat Let's Encrypt. Puis builder
  le Flutter avec `--dart-define=BACKEND_PROXY_HOST=api.academiea.com`.

## 4. Worker whiteboard (rappel)
`whiteboard_render_worker.py` tourne déjà sur Kamatera `/opt` et parle direct à Supabase.
Il n'utilise pas Railway. (Voir `DEVIN_BRIEF_deploy_whiteboard_v9.md` pour son correctif en cours.)
Option de consolidation : l'ajouter comme 3ᵉ service du `docker-compose.yml` — mais alors
**désactiver l'ancien service systemd `/opt`** pour éviter deux pollers concurrents sur les mêmes jobs.

## 5. Vérifs finales
- [ ] `http://<VPS>:8001/debug/ffmpeg` → `ok:true`.
- [ ] Un job `app.video_processing_jobs` en `queued` passe à `done` (worker actif).
- [ ] L'app (buildée avec le bon `BACKEND_PROXY_HOST`) lit les médias sans erreur.
- [ ] Aucune requête ne part plus vers `*.up.railway.app` (grep logs).
- [ ] `git grep -i railway` ne renvoie plus que de la documentation historique.
