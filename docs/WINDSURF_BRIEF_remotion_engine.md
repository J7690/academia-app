# Brief Windsurf — Déploiement du moteur Remotion (Smart Whiteboard v2)

Objectif : faire passer Smart Whiteboard du **diaporama fixe** au **moteur animé Remotion**
(niveau CapCut) + **narration TTS auto-hébergée**, sur Kamatera, **zéro crédit IA par vidéo**.
Déploiement **opt-in** : le pipeline v9 (diaporama) reste le défaut ; on bascule projet par
projet via `whiteboard_projects.renderer_id = 'remotion'`. On ne casse rien.

Le code du moteur est déjà dans le dépôt : `whiteboard_engine_remotion/`.

---

## Où déployer
Sur le VPS qui exécute le worker whiteboard (service `whiteboard-worker`, `/opt/whiteboard-worker`).
Vérifier les ressources avant (Remotion+Chromium = gourmand) :
```bash
nproc && free -h && df -h /
```
Cible confortable : ≥ 2 vCPU libres et ≥ 2 Go RAM libres pendant un rendu. Si le VPS LiveKit
est trop chargé, déployer le moteur sur un VPS Kamatera dédié au rendu.

## Tâche 1 — Node + moteur Remotion
```bash
# Node 18+ (LTS)
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs
node -v

# Copier le moteur sur le VPS (scp/rsync du dossier, ou git)
rsync -a whiteboard_engine_remotion/ root@<VPS>:/opt/whiteboard-engine-remotion/

cd /opt/whiteboard-engine-remotion
npm ci   # installe aussi les paquets d'effets : @remotion/transitions, /lottie,
         # /motion-blur, /paths, /media-utils (déjà déclarés dans package.json)
# Chromium headless pour Remotion + libs système
npx remotion browser ensure
apt-get install -y libnss3 libatk-bridge2.0-0 libgtk-3-0 libasound2 fonts-liberation
```

## Tâche 2 — Kokoro-82M (TTS français haut de gamme, 0 crédit)
On remplace Piper par **Kokoro-82M** (Apache 2.0, 54 voix dont le français, ~6× temps
réel sur CPU) via **Kokoro-FastAPI** (API compatible OpenAI). Le plus simple = Docker :
```bash
# Image CPU (ou -gpu si le VPS a un GPU) — expose une API OpenAI-compatible sur :8880
docker run -d --restart unless-stopped -p 8880:8880 \
  --name kokoro-tts ghcr.io/remsky/kokoro-fastapi-cpu:latest

# Test (voix française ff_siwis) :
curl -s http://127.0.0.1:8880/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{"model":"kokoro","input":"Bonjour, ceci est un test.","voice":"ff_siwis","response_format":"wav"}' \
  -o /tmp/tts.wav
ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 /tmp/tts.wav
```
Variables pour le worker/bridge :
```bash
export KOKORO_URL=http://127.0.0.1:8880/v1/audio/speech
export KOKORO_VOICE=ff_siwis
export KOKORO_MODEL=kokoro
```
> `narrate.py` bascule automatiquement : **Kokoro** d'abord, **Piper** en repli si
> `PIPER_BIN`/`PIPER_MODEL` sont définis, sinon **vidéo sans voix** (dégradation douce).
> Vérifie la liste des voix FR disponibles de l'image et ajuste `KOKORO_VOICE` si besoin.

## Tâche 3 — Test du moteur, isolé
```bash
cd /opt/whiteboard-engine-remotion
# a) sans narration
node render.mjs --storyboard src/sample_storyboard.json --out /tmp/wb_noaudio.mp4
# b) avec narration
python3 narrate.py --storyboard src/sample_storyboard.json --public ./public --out /tmp/narr.json
node render.mjs --storyboard src/sample_storyboard.json --narration /tmp/narr.json --out /tmp/wb.mp4

# Vérifs
ffprobe -v error -select_streams v:0 -show_entries stream=profile,level,width,height,pix_fmt -of default=nw=1 /tmp/wb.mp4
#   ATTENDU : profile=Main, level=40, 720x1280, yuv420p
ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 /tmp/wb.mp4   # >= somme des narrations
ffmpeg -v error -i /tmp/wb.mp4 -f null - && echo DECODE_OK
```
Ouvrir `/tmp/wb.mp4` : titre qui s'écrit, blocs animés, formule KaTeX, sous-titres, voix off.

## Tâche 4 — Brancher le worker (opt-in)
Dans `academia_bobodo_backend/whiteboard_render_worker.py`, autour de l'assemblage :
```python
import os, sys
sys.path.insert(0, os.environ.get("REMOTION_ENGINE_DIR", "/opt/whiteboard-engine-remotion"))

# ... dans _process_single_job, après récupération du storyboard et du projet :
renderer = (storyboard_json or {}).get("renderer_id") or job.get("renderer_id")
if renderer == "remotion":
    from render_bridge import render_storyboard_remotion
    mp4_path = render_storyboard_remotion(storyboard_json, temp_path)
    duration_ms = None  # laisser le mark_done recalculer, ou ffprobe la durée réelle
else:
    png_paths = render_storyboard_to_pngs(storyboard_json, temp_path)
    # ... (chemin v9 existant, inchangé)
```
> Assure-toi que le worker connaît `renderer_id` : soit via la RPC `whiteboard_fetch_queued_jobs`
> (l'ajouter au payload), soit en lisant `app.whiteboard_projects.renderer_id` par `project_id`.
> Exporter dans l'unité systemd du worker : `REMOTION_ENGINE_DIR`, `KOKORO_URL`,
> `KOKORO_VOICE`, `KOKORO_MODEL` (et éventuellement `PIPER_BIN`/`PIPER_MODEL` en repli).

## Tâche 5 — Rollout progressif
```sql
-- Basculer UN projet de test sur le nouveau moteur :
update app.whiteboard_projects set renderer_id = 'remotion' where id = '<PROJECT_ID_TEST>';
```
Générer un rendu depuis l'app → vérifier la vidéo animée + narration. Élargir ensuite.

## Critères d'acceptation
- [ ] `/tmp/wb.mp4` : `profile=Main, level=40, 720x1280, yuv420p`, `DECODE_OK`.
- [ ] Vidéo **animée** (écriture du titre, fondus, formule animée) — plus un diaporama.
- [ ] **Voix off** présente + sous-titres, durée vidéo ≥ durée narration.
- [ ] Le chemin v9 (diaporama) marche toujours pour les projets `renderer_id != 'remotion'`.
- [ ] Un seul worker whiteboard actif (pas de doublon).

## Garde-fous
- **Opt-in strict** : ne pas mettre `remotion` par défaut tant que le POC n'est pas validé sur appareil.
- Surveiller CPU/RAM pendant un rendu (Chromium). Fixer `REMOTION_RENDER_TIMEOUT` si besoin.
- Ne pas committer les binaires Piper/modèles ni aucun secret.
- Fallback : si Node/Chromium/Piper indisponible, le job doit échouer proprement (status `failed`)
  sans bloquer le worker — pas de crash de la boucle de polling.

## Rollback
`update app.whiteboard_projects set renderer_id = 'notebook' where renderer_id = 'remotion';`
→ retour immédiat au diaporama v9. Le moteur Remotion reste installé, inactif.
