# D31_2_duration_trace.md

**Date :** 2026-06-30T17:17:23Z
**Mode :** LECTURE SEULE — avant modification
**Projet analysé :** `3993bb85-1818-407b-810e-4bcfe1b983fa`
**Sujet :** dérivés d'une fonction

---

## 1. Storyboard réel reçu par le worker

| Scène | Order | Titre | `duration_ms` |
|---|---|---|---|
| 1 | 0 | Introduction aux Dérivées | 7000 |
| 2 | 1 | Qu'est-ce qu'une dérivée ? | 8000 |
| 3 | 2 | Définition Formelle | 10000 |
| 4 | 3 | Exemples de Dérivées Simples | 9000 |
| 5 | 4 | Application Concrète | 8000 |
| 6 | 5 | Exercice d'Application | 7000 |
| 7 | 6 | Correction de l'Exercice | 9000 |
| 8 | 7 | Conclusion | 6000 |

**Total `duration_ms` storyboard :** 64000 ms (64.0 s)

**Valeurs uniques :** [6000, 7000, 8000, 9000, 10000]

---

## 2. Code qui transmet les scènes : Worker → Assembler

### `whiteboard_render_worker.py` (extrait actuel)

```python
(storyboard_json, temp_path)
            
            # Assembler les PNGs en MP4
            logger.info(f"[whiteboard_render_worker] Assembling MP4 for job {job_id}")
            
mp4_path = assemble_pngs_to_mp4(png_paths, temp_path)
```

### `whiteboard_ffmpeg_assembler.py` (extrait actuel)

```python
"""
Whiteboard FFmpeg Assembler - v7 CORRECTION D.25
P1: Ajout piste audio silencieuse pour compatibilite ExoPlayer Android
    OMX Qualcomm echoue sur MP4 video-only avec format_supported=YES
    Solution: -f lavfi -i anullsrc + -c:a aac -b:a 64k -shortest

Toutes corrections precedentes maintenues:
  v6: colorspace sRGB->BT709 (plus de smpte170m)
  v5: BT709 metadata, Baseline 3.1, no B-frames
  C1: concat demuxer duree explicite
  C2: faststart (moov avant mdat)
  C3: Baseline profile
"""
from pathlib import Path
from typing import List
import subprocess


SECONDS_PER_SCENE = 5


FPS = 30


def assemble_pngs_to_mp4(png_paths: List[Path], output_dir: Path) -> Path:
    if not png_paths:
        raise ValueError("No PNGs provided")
    for p in png_paths:
        if not p.exists():
            raise FileNotFoundError(f"PNG not found: {p}")

    # C1: concat demuxer avec duree explicite par scene
    concat_file = output_dir / "concat.txt"
    
with open(concat_file, "w") as f:
    for p in png_paths:
        safe = str(p).replace("'", "'\''")
        f.write(f"file '{safe}'\n")
        f.write(f"duration {SECONDS_PER_SCENE}\n")
```

---

## 3. Où `duration_ms` disparaît

| Étape | `duration_ms` présent ? | Utilisé ? | Preuve |
|---|---|---|---|
| Storyboard JSON | ✅ Oui | — | Voir tableau section 1 |
| `whiteboard_fetch_queued_jobs` | ✅ Oui (alias `storyboard`) | — | `SELECT wp.storyboard_json as storyboard` |
| `_process_single_job` | ✅ Oui dans `storyboard_json` | ❌ **Non lu** | `png_paths = render_storyboard_to_pngs(storyboard_json, temp_path)` |
| `assemble_pngs_to_mp4` | ❌ **Non reçu** | ❌ **Non utilisé** | Signature : `assemble_pngs_to_mp4(png_paths, output_dir)` |
| `concat.txt` | ❌ **Non reçu** | ❌ **Remplacé par 5** | `duration {SECONDS_PER_SCENE}` |
| `_mark_job_done` | ❌ **Faux** | ❌ **Faux** | `duration_ms = len(scenes) * 5000` |

---

## 4. État du worker avant modification

```
● whiteboard-worker.service - Whiteboard Render Worker Service
     Loaded: loaded (/etc/systemd/system/whiteboard-worker.service; enabled; preset: enabled)
     Active: active (running) since Mon 2026-06-29 09:15:20 UTC; 1 day 8h ago
   Main PID: 490198 (python3)
      Tasks: 2 (limit: 11864)
     Memory: 35.4M (peak: 474.0M)
        CPU: 1h 1min 29.759s
     CGroup: /system.slice/whiteboard-worker.service
             └─490198 /usr/bin/python3 /opt/whiteboard-worker/whiteboard_render_worker.py

Jun 30 17:17:13 academia00 python3[490198]: INFO:httpx:HTTP Request: POST https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/whiteboard_fetch_queued_jobs "HTTP/1.1 200 OK"
Jun 30 17:17:13 academia00 python3[490198]: INFO:whiteboard_render_worker:[whiteboard_render_worker] Found 0 queued job(s)
Jun 30 17:17:15 academia00 python3[490198]: INFO:httpx:HTTP Request: POST https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/whiteboard_fetch_queued_jobs "HTTP/1.1 200 OK"
Jun 30 17:17:15 academia00 python3[490198]: INFO:whiteboard_render_worker:[whiteboard_render_worker] Found 0 queued job(s)
Jun 30 17:17:18 academia00 python3[490198]: INFO:httpx:HTTP Request: POST https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/whiteboard_fetch_queued_jobs "HTTP/1.1 200 OK"
Jun 30 17:17:18 academia00 python3[490198]: INFO:whiteboard_render_worker:[whiteboard_render_worker] Found 0 queued job(s)
Jun 30 17:17:20 academia00 python3[490198]: INFO:httpx:HTTP Request: POST https://thevdfcwlcqzdoybfvgs.supa
```

**Erreurs éventuelles :**
```

```

---

**Conclusion :** `duration_ms` est généré par l'IA, stocké par Supabase, récupéré par le worker, mais **ignoré** dès l'appel à l'assembleur FFmpeg. L'assembleur utilise `SECONDS_PER_SCENE = 5` et `mark_done` remonte une durée fausse.
