# Smart Whiteboard — Moteur Remotion (v2)

Moteur de rendu **animé** (niveau CapCut) piloté par le storyboard, exécuté sur
Kamatera. **Zéro crédit IA par vidéo** : c'est du calcul (Chromium + ffmpeg).
Remplace le diaporama d'images fixes (Pillow) par des scènes animées + voix off.

## Ce que ça produit
- Titre qui **s'écrit** (effet manuscrit), paragraphes en fondu/montée, **formules
  KaTeX** animées, corrections surlignées, transitions entre scènes.
- **Narration** (voix off) auto-hébergée — **Kokoro-82M** (Apache 2.0, voix FR, 0 crédit),
  repli Piper — + **sous-titres**.
- Durées **synchronisées sur la voix** (une scène ne coupe jamais la narration).
- Sortie MP4 **device-safe** : H.264 main/4.0, 720×1280, yuv420p, +faststart
  (même profil que le correctif v9 → lecture Android garantie).

## Structure
- `src/Root.tsx` — composition + durée calculée depuis le storyboard.
- `src/SmartWhiteboard.tsx` — enchaîne les scènes (durée = max storyboard / narration).
- `src/Scene.tsx`, `src/blocks.tsx` — scènes et blocs animés.
- `src/theme.ts` — thèmes `notebook` / `scientific`.
- `narrate.py` — narration TTS (Kokoro-FastAPI, repli Piper) → `public/narration/*.wav` + manifest.
- `render.mjs` — bundle + rendu + finalisation ffmpeg.
- `render_bridge.py` — point d'entrée appelé par le worker (opt-in `renderer_id='remotion'`).

## Dév local
```bash
npm ci
npm run dev           # Remotion Studio (prévisualisation live)
node render.mjs --storyboard src/sample_storyboard.json --out /tmp/test.mp4
```

## Intégration worker
Voir `render_bridge.py` : le worker bascule sur ce moteur quand
`whiteboard_projects.renderer_id == 'remotion'`, sinon garde le diaporama v9.
Déploiement VPS : `docs/WINDSURF_BRIEF_remotion_engine.md`.
