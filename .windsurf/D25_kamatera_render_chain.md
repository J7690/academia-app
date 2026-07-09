# D25_kamatera_render_chain.md — Traçage complet de la chaîne Kamatera

## Environnement runtime

| Composant | Version |
|---|---|
| OS | Ubuntu (linux, Kamatera VM 185.167.97.144) |
| Python | 3.12.3 |
| Pillow | 12.2.0 |
| FFmpeg | 6.1.1-3ubuntu5 |
| Service | systemd `whiteboard-worker` |

### Checksums des fichiers actifs

| Fichier | MD5 | Taille | Modifié |
|---|---|---|---|
| `whiteboard_ffmpeg_assembler.py` | `1aef5f207a1491f2e0b2855ce63d4f59` | 3416 bytes | Jun 29 09:15 |
| `whiteboard_png_renderer.py` | `62a604fdabbe7f065f0ca5acb76195b0` | 6526 bytes | Jun 23 18:44 |
| `whiteboard_render_worker.py` | `96274c246a4ba3e3cb4f2dc076707b20` | 6230 bytes | Jun 23 18:31 |
| `whiteboard_upload_renderer.py` | `547a0d66ad175c9d8f100566166e928f` | 1872 bytes | Jun 23 18:31 |

---

## Chaîne complète de rendu

```
STORYBOARD JSON (Supabase)
  ↓ RPC whiteboard_fetch_queued_jobs
  ↓ Champ: {id, storyboard, created_at}
  
whiteboard_render_worker.py — _fetch_queued_jobs()
  URL: /rest/v1/rpc/whiteboard_fetch_queued_jobs
  Payload: {"p_limit": 1}
  ↓ job["storyboard"] = storyboard_json
  
whiteboard_render_worker.py — _process_single_job()
  1. _mark_job_processing(job_id)
     → RPC whiteboard_mark_processing
  2. tempfile.TemporaryDirectory() → /tmp/tmpXXXXXX/
  
  ↓ Step A: render_storyboard_to_pngs(storyboard_json, temp_path)
  
whiteboard_png_renderer.py — render_storyboard_to_pngs()
  - Lit scenes = storyboard_json.get("scenes", [])
  - Pour chaque scène → 1 PNG (1080×1920)
  - Thème "notebook" → fond blanc, texte noir
  - Ignore duration_ms des scènes (toutes égales)
  - Retourne: List[Path] → [scene_0.png ... scene_8.png]
  
  ↓ 9 PNGs générés (1 par scène, indépendants de duration_ms)
  
  ↓ Step B: assemble_pngs_to_mp4(png_paths, temp_path)
  
whiteboard_ffmpeg_assembler.py — assemble_pngs_to_mp4()
  - SECONDS_PER_SCENE = 5  ← hardcodé, ignore duration_ms
  - Génère /tmp/tmpXXXX/concat.txt:
      file '/tmp/.../scene_0.png'
      duration 5              ← 5s fixe, pas 7s storyboard
      file '/tmp/.../scene_1.png'
      duration 5              ← 5s fixe, pas 8s storyboard
      ... (×9 scènes)
      file '/tmp/.../scene_8.png'  ← dernière image sans duration
  
  - Commande FFmpeg réelle:
      ffmpeg -y
        -f concat -safe 0 -i concat.txt
        -f lavfi -i anullsrc=r=44100:cl=stereo
        -vf scale=1080:1920...,colorspace=all=bt709:iall=bt709:itrc=srgb,format=yuv420p
        -c:v libx264 -profile:v baseline -level:v 3.1
        -pix_fmt yuv420p -r 30 -g 60 -preset fast -crf 28
        -colorspace bt709 -color_primaries bt709 -color_trc bt709 -color_range tv
        -x264-params colorprim=bt709:transfer=bt709:colormatrix=bt709:fullrange=0
        -c:a aac -b:a 64k -ar 44100 -ac 2
        -shortest
        -movflags +faststart
        /tmp/tmpXXXX/output.mp4
  
  ↓ MP4 produit: 9×5s = 45s concat + 1 frame dupliée = 49.967s
                 (au lieu de 69s attendu)
  
  ↓ Step C: upload_mp4_to_storage(mp4_path, job_id)
  
whiteboard_upload_renderer.py — upload_mp4_to_storage()
  - Storage path: whiteboard-renders/renders/{job_id}/{uuid}.mp4
  - Upload HTTP PUT vers Supabase Storage
  - Retourne: URL publique
  
  ↓ Step D: _mark_job_done(job_id, video_url, duration_ms)
  
whiteboard_render_worker.py ligne 139:
  duration_ms = len(scenes) * 5000  ← 9×5000 = 45000ms (faux)
  → RPC whiteboard_mark_done({p_job_id, p_video_url, p_duration_ms: 45000})
  
RÉSULTAT SUPABASE:
  status = "done"
  video_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/..."
  duration_ms = 45000  ← faux (réel = 49967ms, attendu = 69000ms)
```

---

## Logs runtime (extrait render ad74ed9e)

```
Jun 29 09:35:03  Processing job ad74ed9e-2133-4c79-9a84-29b33d9d8fb3
Jun 29 09:35:03  Assembling MP4 for job ad74ed9e-2133-4c79-9a84-29b33d9d8fb3
Jun 29 09:35:16  Uploading MP4 for job ad74ed9e-2133-4c79-9a84-29b33d9d8fb3
Jun 29 09:35:17  Job ad74ed9e-2133-4c79-9a84-29b33d9d8fb3 completed successfully
```

**Durée traitement total : 14 secondes** (09:35:03 → 09:35:17)

---

## Points de défaillance identifiés dans la chaîne

| Étape | Composant | Défaut | Impact |
|---|---|---|---|
| B | `whiteboard_ffmpeg_assembler.py` L.18 | `SECONDS_PER_SCENE=5` ignore `duration_ms` | Durée -19s |
| B | `whiteboard_ffmpeg_assembler.py` | Pas de paramètre `scene_durations_ms` | Durées scènes ignorées |
| A→B | `whiteboard_render_worker.py` | Pas d'appel TTS avant assemblage | Voix absente |
| D | `whiteboard_render_worker.py` L.139 | `len(scenes)*5000` au lieu de `sum(duration_ms)` | duration_ms Supabase faux |

---

*Toutes les preuves sont issues de lectures de fichiers SSH runtime et logs systemd.*
