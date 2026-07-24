# Smart Whiteboard Studio — Qui exécute quoi (toutes les vagues)

Ce document sépare **ce que Claude a réellement fait** de **ce que tu/Windsurf devez
exécuter** (parce que Claude n'a **pas** accès au VPS Kamatera ni les ressources pour
lancer npm/Chromium/Manim). Objectif : que **rien ne soit supposé fait** alors qu'il ne
l'est pas.

---

## 1. La symbiose — comment ça marche (et c'est automatique)

Le flux, de la saisie de l'étudiant à la vidéo :

```
Étudiant saisit un sujet
   │
   ▼
App → Edge Function "whiteboard-generate-storyboard"  ✅ DÉPLOYÉE (v32)
   │   L'IA produit un storyboard v2 : narration par scène, transition,
   │   blocs list/image (requête), + champ "engine"
   ▼
Projet stocké (app.whiteboard_projects.storyboard_json)
   │
   ▼
Worker whiteboard lit le job :
   • storyboard.engine == "remotion"  → render_bridge.py (moteur ANIMÉ)
        → résout images (Pexels) + formules animées (Manim) + narration (Kokoro)
        → rendu Remotion + ffmpeg → MP4 animé stylé
   • sinon                            → diaporama v9 (inchangé)
```

**Le contrat de schéma** relie les deux bouts : le prompt du générateur (déployé) et le
moteur (`src/types.ts`) parlent le **même langage** (types de blocs, `narration`,
`transition`, `engine`). Donc **dès que le moteur tourne sur le VPS et que `engine="remotion"`
est demandé, la génération IA alimente automatiquement tous les effets** — sans intervention
manuelle par vidéo. Tant que ces deux conditions ne sont pas remplies, l'app reste sur le
diaporama v9 (sécurité, rien ne casse).

---

## 2. Ce qui est RÉELLEMENT fait par Claude (vérifiable)

| Élément | État | Où |
|---|---|---|
| Correctif lecture + durées (v9) | ✅ déployé (par Windsurf) | `/opt/whiteboard-worker` |
| Générateur IA v2 (narration, transition, list/image, engine) | ✅ **déployé (v32)** | Edge Function Supabase |
| Moteur Remotion (scènes, blocs, thèmes) | ✅ code | `whiteboard_engine_remotion/` |
| Effets (transitions, Ken Burns, glow, ligne par ligne, image, liste) | ✅ code | idem |
| Narration Kokoro (repli Piper) | ✅ code | `narrate.py` |
| Résolution images Pexels + pont worker | ✅ code | `render_bridge.py` |
| Formules animées Manim (Vague 3) | ✅ code | `manim_render.py` + moteur |
| Docs/briefs | ✅ | `docs/` |

> Claude **peut** déployer des Edge Functions Supabase (fait). Claude **ne peut pas**
> accéder au VPS Kamatera (SSH), lancer npm/Chromium/Manim, ni créer de comptes tiers.

---

## 3. Ce que TOI / Windsurf devez exécuter (Claude n'a pas l'accès/les ressources)

### Vague 1 — Moteur de base (obligatoire)
Sur le VPS (SSH — Claude n'y a pas accès) :
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs
rsync -a whiteboard_engine_remotion/ root@<VPS>:/opt/whiteboard-engine-remotion/
cd /opt/whiteboard-engine-remotion && npm ci        # installe AUSSI les paquets d'effets
npx remotion browser ensure                          # Chromium (téléchargement, ~heavy)
apt-get install -y libnss3 libatk-bridge2.0-0 libgtk-3-0 libasound2 fonts-liberation
node render.mjs --storyboard src/sample_storyboard.json --out /tmp/test.mp4   # test
```
_Pourquoi pas Claude :_ pas d'accès SSH ; Chromium/rendu = ressources indisponibles ici.

### Vague 1 — Narration Kokoro (voix off)
```bash
docker run -d --restart unless-stopped -p 8880:8880 --name kokoro-tts \
  ghcr.io/remsky/kokoro-fastapi-cpu:latest
# exporter pour le worker : KOKORO_URL, KOKORO_VOICE=ff_siwis, KOKORO_MODEL=kokoro
```
_Pourquoi pas Claude :_ pas de Docker ni d'accès VPS.

### Vague 2 — Assets images (Pexels, gratuit)
1. Créer un compte gratuit sur pexels.com/api → obtenir une **clé API**.
2. Exporter `PEXELS_API_KEY=<clé>` dans le service worker.
_Pourquoi pas Claude :_ ne peut pas créer de compte ni détenir ta clé. **Sans clé, les
blocs image sont simplement ignorés (dégradation douce), le reste marche.**

### Vague 3 — Formules animées Manim
```bash
pip install manim
apt-get install -y texlive texlive-latex-extra dvisvgm
# activer : export MANIM_ENABLED=1  dans le service worker
```
_Pourquoi pas Claude :_ install lourde + rendu = VPS. **Sans Manim, les formules restent
en KaTeX (statique lisible), rien ne casse.**

### Intégration worker (toutes vagues) — édition + redémarrage
Dans `academia_bobodo_backend/whiteboard_render_worker.py`, brancher le moteur animé :
```python
import os, sys
sys.path.insert(0, os.environ.get("REMOTION_ENGINE_DIR", "/opt/whiteboard-engine-remotion"))
engine = (storyboard_json or {}).get("engine")
if engine == "remotion":
    from render_bridge import render_storyboard_remotion
    mp4_path = render_storyboard_remotion(storyboard_json, temp_path)
else:
    # ... chemin diaporama v9 inchangé
```
Exporter dans l'unité systemd du worker : `REMOTION_ENGINE_DIR`, `KOKORO_URL`,
`KOKORO_VOICE`, `KOKORO_MODEL`, `PEXELS_API_KEY` (Vague 2), `MANIM_ENABLED=1` (Vague 3).
Puis `systemctl restart whiteboard-worker`.

### Activation côté app (déclencheur de la symbiose)
Le générateur met `engine="slideshow"` par défaut. Pour utiliser le studio animé, l'app
doit envoyer **`engine: "remotion"`** dans l'appel à `whiteboard-generate-storyboard`
(ex. via un interrupteur « Studio animé »). Alternative : basculer le défaut côté serveur
une fois le POC validé.
_Décision à prendre : interrupteur utilisateur, ou défaut global ?_

---

## 3bis. Balise de santé — pour que Claude vérifie l'installation à distance

Claude n'a **pas** d'accès SSH au VPS ni à l'API Kamatera (réseau bloqué, testé). Pour
permettre une vérification à distance, une **balise** publie l'état des outils dans Supabase.
Côté Supabase, c'est **déjà en place** (table `app.whiteboard_engine_health` + RPC
`app.whiteboard_report_engine_health`, déployés par Claude).

À exécuter sur le VPS (après installation) — puis en cron, ex. toutes les 10 min :
```bash
cd /opt/whiteboard-engine-remotion
SUPABASE_URL=$SUPABASE_URL SUPABASE_SERVICE_KEY=$SUPABASE_SERVICE_KEY \
KOKORO_URL=$KOKORO_URL PEXELS_API_KEY=$PEXELS_API_KEY MANIM_ENABLED=$MANIM_ENABLED \
python3 healthcheck.py
```
Ça sonde Node, Chromium, ffmpeg, Remotion, Kokoro, Pexels, Manim et publie le résultat.
Ensuite Claude (ou toi) interroge : `select host, components, updated_at from app.whiteboard_engine_health;`
→ Claude peut alors **confirmer lui-même** ce qui est réellement installé et fonctionnel.

## 4. Vérifications — pour ne rien supposer
1. **Génération IA** : lancer une génération, ouvrir `storyboard_json` → il doit contenir
   `narration` (par scène), `transition`, et `engine`. (Sinon, le générateur n'est pas actif.)
2. **Rendu animé** : projet avec `engine="remotion"` → le MP4 doit être **animé** (titre qui
   s'écrit, transitions, voix off), `ffprobe` = `Main/level 40, 720x1280`.
3. **Assets** : avec `PEXELS_API_KEY`, un bloc image affiche une vraie illustration (Ken Burns).
4. **Manim** : avec `MANIM_ENABLED=1`, une formule s'écrit (clip animé) au lieu du KaTeX statique.

---

## 5. Ce qui reste explicitement NON fait (aucune hypothèse)
- Le moteur Remotion **n'a jamais été exécuté** (Claude ne peut pas) — à valider sur VPS (Vague 1).
- **Pexels** inactif tant que la clé n'est pas posée → images ignorées (dégradation douce).
- **Manim** inactif tant que non installé → formules en KaTeX (dégradation douce).
- **La symbiose ne s'active** que lorsque l'app envoie `engine="remotion"` (ou défaut changé).
- Le branchement du worker (section « Intégration worker ») **doit être appliqué** — sans lui,
  même un projet `engine="remotion"` repasse par le diaporama v9.
