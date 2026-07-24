# GO-LIVE moteur Remotion — commandes à exécuter (toi ou Windsurf)

Objectif : activer le moteur studio (cahier continu animé) sur le VPS Kamatera.
Tout est **opt-in** : si quelque chose manque, le rendu retombe sur vision/legacy (rien ne casse).
Remplace `<VPS>` par l'IP du serveur du worker whiteboard, et renseigne les secrets.

Pré-requis côté dépôt : le worker est déjà branché (`academia_bobodo_backend/whiteboard_render_worker.py`)
et l'app envoie déjà `engine:'remotion'` (à recompiler). Rien d'autre à coder.

---

## Étape 1 — Copier le moteur + le worker sur le VPS
```bash
# depuis ta machine, à la racine du dépôt academia/
rsync -a whiteboard_engine_remotion/ root@<VPS>:/opt/whiteboard-engine-remotion/
scp academia_bobodo_backend/whiteboard_render_worker.py root@<VPS>:/opt/whiteboard-worker/
```

## Étape 2 — Node + moteur Remotion + Chromium
```bash
ssh root@<VPS>
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs
cd /opt/whiteboard-engine-remotion
npm ci
npx remotion browser ensure
apt-get install -y libnss3 libatk-bridge2.0-0 libgtk-3-0 libasound2 fonts-liberation
# test moteur isolé (sans app) :
node render.mjs --storyboard src/sample_storyboard.json --out /tmp/pro.mp4
ffprobe -v error -select_streams v:0 -show_entries stream=profile,level,width,height -of default=nw=1 /tmp/pro.mp4
```
Attendu : un MP4 animé, `profile=Main level=40 720x1280`.

## Étape 3 — Voix off Kokoro (recommandé, sinon vidéo sans voix)
```bash
docker run -d --restart unless-stopped -p 8880:8880 --name kokoro-tts \
  ghcr.io/remsky/kokoro-fastapi-cpu:latest
```

## Étape 4 — Config du worker (variables d'environnement)
Le worker lit un `.env` dans son dossier. Ajoute :
```bash
cat >> /opt/whiteboard-worker/.env <<'EOF'
REMOTION_ENGINE_DIR=/opt/whiteboard-engine-remotion
KOKORO_URL=http://127.0.0.1:8880/v1/audio/speech
KOKORO_VOICE=ff_siwis
KOKORO_MODEL=kokoro
KOKORO_SPEED=0.95
# Optionnel (illustrations libres) : clé gratuite sur pexels.com/api
# PEXELS_API_KEY=xxxxx
# Optionnel (formules animées Manim, apres `pip install manim` + texlive) :
# MANIM_ENABLED=1
EOF
```

## Étape 5 — Redémarrer le worker + publier l'état
```bash
systemctl restart whiteboard-worker
systemctl status whiteboard-worker --no-pager | head -15
# balise de sante -> me permet de verifier a distance
cd /opt/whiteboard-engine-remotion
set -a; . /opt/whiteboard-worker/.env; set +a
python3 healthcheck.py
```

## Étape 6 — Test bout-en-bout
Option A (rapide, sans recompiler l'app) — forcer un projet existant sur Remotion :
```sql
-- Choisir un projet récent et le passer en remotion, puis créer un job de rendu.
update app.whiteboard_projects
   set storyboard_json = jsonb_set(storyboard_json, '{engine}', '"remotion"')
 where id = '<PROJECT_ID>';
select public.whiteboard_create_render_job('<PROJECT_ID>');
```
Puis vérifier le rendu :
```sql
select id, status, video_url, duration_ms
from app.whiteboard_renders order by created_at desc limit 3;
```

Option B (réel) — **recompiler l'app** (elle envoie déjà `engine:'remotion'`), générer un cours,
lancer le rendu depuis l'écran.

## Critères d'acceptation
- [ ] `node render.mjs ...` produit un MP4 animé (Main/4.0, 720x1280).
- [ ] `healthcheck.py` publie `ready_basic=true` (je le vois dans `app.whiteboard_engine_health`).
- [ ] Un job `engine=remotion` passe à `done` avec une vidéo **cahier continu animé**.
- [ ] Les projets sans `engine=remotion` continuent en vision/legacy (aucune régression).

## Rollback
- Retirer `engine:'remotion'` de l'app, ou vider `REMOTION_ENGINE_DIR` -> repli vision/legacy immédiat.
- `docker stop kokoro-tts` pour couper la voix Kokoro (repli sans voix).
