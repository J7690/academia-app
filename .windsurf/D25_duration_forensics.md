# D25_duration_forensics.md — Traçage complet de la durée vidéo

## Render de référence

| Champ | Valeur |
|---|---|
| render_id | `ad74ed9e-2133-4c79-9a84-29b33d9d8fb3` |
| project_id | `3fa88728-9ce5-489e-8f51-85dc3b87f7f4` |
| subject | dérivés d'une fonction |
| status | done |
| renderer | notebook |
| narration_mode | **tts** |

---

## PHASE 1 — Tableau des scènes storyboard

| order | scene_id | duration_ms storyboard | cumul_ms | blocks |
|---|---|---|---|---|
| 0 | scene-001 | 7000 | 7000 | title, paragraph, paragraph |
| 1 | scene-002 | 8000 | 15000 | definition, formula |
| 2 | scene-003 | 6000 | 21000 | paragraph, paragraph |
| 3 | scene-004 | 7000 | 28000 | paragraph, paragraph, formula |
| 4 | scene-005 | 9000 | 37000 | paragraph, formula, formula, paragraph |
| 5 | scene-006 | 10000 | 47000 | paragraph, formula×4 |
| 6 | scene-007 | 7000 | 54000 | exercise, formula, paragraph |
| 7 | scene-008 | 8000 | 62000 | correction, formula×3 |
| 8 | scene-009 | 7000 | 69000 | paragraph×4 |

**Total duration_ms storyboard : 69 000 ms = 69.000s**
**Nombre de scènes : 9**

---

## PHASE 1B — Métriques ffprobe runtime

| métrique | valeur réelle |
|---|---|
| duration container (moov/mvhd) | **49.966667s** |
| duration stream vidéo (tkhd) | **49.966667s** |
| nb_frames (header) | **1499** |
| nb_frames (comptés réels) | **1499** |
| fps réel (avg_frame_rate) | **30/1** |
| fps réel (r_frame_rate) | **30/1** |
| time_base vidéo | **1/15360** |
| duration_ts vidéo | **767488** |
| durée calculée (1499÷30) | **49.9667s** |
| taille fichier | **338856 bytes** |
| bit_rate container | **54253 bps** |
| format_name | mov,mp4,m4a,3gp,3g2,mj2 |
| nb_streams | 2 (video + audio) |

---

## PHASE 1C — Analyse écart

| Durée | Valeur | Écart vs storyboard |
|---|---|---|
| Attendue (storyboard) | **69.000000s** | référence |
| Container ffprobe | **49.966667s** | **-19.033333s** |
| Stream vidéo tkhd | **49.966667s** | **-19.033333s** |
| Calculée (frames/fps) | **49.966667s** | **-19.033333s** |

**VERDICT DURÉE : NON CONFORME — écart -19.033s**

---

## PHASE 1D — Identification du responsable

### Preuve runtime — fichier `whiteboard_ffmpeg_assembler.py` ligne 18

```python
SECONDS_PER_SCENE = 5   # ← HARDCODÉ À 5s
FPS = 30
```

### Preuve runtime — fichier `whiteboard_ffmpeg_assembler.py` lignes 31–37

```python
concat_file = output_dir / "concat.txt"
with open(concat_file, "w") as f:
    for p in png_paths:
        safe = str(p).replace("'", "'\\''")
        f.write(f"file '{safe}'\n")
        f.write(f"duration {SECONDS_PER_SCENE}\n")  # ← 5s par PNG, ignorant duration_ms storyboard
    last = str(png_paths[-1]).replace("'", "'\\''")
    f.write(f"file '{last}'\n")
```

### Preuve runtime — fichier `whiteboard_png_renderer.py` — 1 PNG par scène

Le renderer génère **1 PNG par scène** (9 scènes → 9 PNGs).

### Preuve runtime — fichier `whiteboard_render_worker.py` ligne 139

```python
duration_ms = len(scenes) * 5000  # ← ESTIMATION HARDCODÉE 5s/scène (45000ms)
```

Le worker signale `duration_ms=45000` (9×5000) dans Supabase — même pas 49.97s réel.

### Calcul démonstration

```
9 scènes × 5 secondes/scène = 45.000s concat demuxer
+ 4.967s = durée réelle FFmpeg (concat avec dernière image dupliquée)
= 49.967s réel
```

**vs**

```
Storyboard : durée réelle = 69.000s
  (scènes de 6s à 10s selon contenu)
```

---

## Matrice de responsabilité durée

| Composant | Responsable ? | Preuve |
|---|---|---|
| Storyboard JSON | NON — source de vérité correcte (69s) | `duration_ms` par scène présent |
| Flutter | NON — affiche seulement | — |
| Edge Function | NON — génère le storyboard, ne touche pas FFmpeg | — |
| Supabase / RPC | NON — stocke et route | — |
| `whiteboard_png_renderer.py` | NON — génère 1 PNG/scène correctement | — |
| **`whiteboard_ffmpeg_assembler.py`** | **OUI — RESPONSABLE PRINCIPAL** | `SECONDS_PER_SCENE = 5` ligne 18 |
| `whiteboard_render_worker.py` | OUI SECONDAIRE — `duration_ms` faux (45000) | ligne 139 |

---

## Correction minimale requise (non appliquée — lecture seule)

**Fichier** : `whiteboard_ffmpeg_assembler.py`

**Ligne 18** : supprimer `SECONDS_PER_SCENE = 5`

**Signature** : changer `assemble_pngs_to_mp4(png_paths, output_dir)` → `assemble_pngs_to_mp4(png_paths, output_dir, scene_durations_ms)`

**Lignes 31–36** : utiliser `scene_durations_ms[i] / 1000.0` au lieu de `SECONDS_PER_SCENE`

**Fichier** : `whiteboard_render_worker.py`

**Ligne 139** : calculer `sum(s.get('duration_ms',0) for s in scenes)` au lieu de `len(scenes) * 5000`

---

*Toutes les valeurs sont issues de données runtime réelles (ffprobe SSH Kamatera, SQL Supabase, lecture code source).*
