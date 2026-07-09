# D31_2_ffmpeg_changes.md

**Date :** 2026-06-30T18:07:00Z
**Fichiers modifiés :**
- `/opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py`
- `/opt/whiteboard-worker/whiteboard_render_worker.py`
**Backup :** `/opt/whiteboard-worker/backup_d31_2/*.20260630_172332`

---

## 1. Changements dans `whiteboard_ffmpeg_assembler.py`

### Suppression du hardcodage

```python
# AVANT
SECONDS_PER_SCENE = 5
FPS = 30

# APRÈS
FPS = 30
```

### Signature modifiée

```python
# AVANT
def assemble_pngs_to_mp4(png_paths: List[Path], output_dir: Path) -> Path:

# APRÈS
def assemble_pngs_to_mp4(png_paths: List[Path], output_dir: Path, durations_ms: Optional[List[int]] = None) -> Path:
```

### Durée par scène et durée totale

```python
# AVANT
with open(concat_file, "w") as f:
    for p in png_paths:
        safe = str(p).replace("'", "'\\''")
        f.write(f"file '{safe}'\n")
        f.write(f"duration {SECONDS_PER_SCENE}\n")
    last = str(png_paths[-1]).replace("'", "'\\''")
    f.write(f"file '{last}'\n")

# APRÈS
if durations_ms is None or len(durations_ms) != len(png_paths):
    durations_ms = [5000] * len(png_paths)
total_duration_s = sum(durations_ms) / 1000.0
with open(concat_file, "w") as f:
    for p, d in zip(png_paths, durations_ms):
        safe = str(p).replace("'", "'\\''")
        f.write(f"file '{safe}'\n")
        f.write(f"duration {d / 1000.0}\n")
```

**Conséquence :**
- `concat.txt` contient les durées réelles du storyboard (ex. `duration 7.0`).
- La dernière image n'est plus dupliquée (évite une durée supérieure de 1 scène).

### Forçage de la durée finale exacte

```python
# AVANT
        # Terminer quand la video se termine
        "-shortest",

# APRÈS
        # Terminer exactement a la duree totale du storyboard
        "-t", str(total_duration_s),
        "-shortest",
```

**Conséquence :** le MP4 est coupé exactement à la somme des `duration_ms` du storyboard.

---

## 2. Changements dans `whiteboard_render_worker.py`

### Extraction des durées

```python
# AJOUTÉ
storyboard = storyboard_json if isinstance(storyboard_json, dict) else {}
scenes = storyboard.get("scenes", [])
durations_ms = [s.get("duration_ms", 5000) for s in scenes]
if len(durations_ms) != len(png_paths):
    logger.warning(f"[whiteboard_render_worker] Duration mismatch: {len(durations_ms)} durations vs {len(png_paths)} PNGs; falling back to 5s per scene")
    durations_ms = None

# MODIFIÉ
mp4_path = assemble_pngs_to_mp4(png_paths, temp_path, durations_ms)
```

### Durée retournée à `mark_done`

```python
# AVANT
# Calculer la durée (estimation basée sur le nombre de scènes)
# Pour V1, on estime 5 secondes par scène
storyboard = storyboard_json if isinstance(storyboard_json, dict) else {}
scenes = storyboard.get("scenes", [])
duration_ms = len(scenes) * 5000

# APRÈS
# Calculer la durée totale à partir du storyboard
if durations_ms is not None:
    duration_ms = sum(durations_ms)
else:
    # Fallback legacy: estimate 5 seconds per scene
    duration_ms = len(scenes) * 5000
```

**Conséquence :** `whiteboard_mark_done` reçoit la somme réelle des `duration_ms` du storyboard.

---

## 3. Gestion des régressions

- **Fallback préservé** : si `durations_ms` est absent ou de taille incorrecte, l'ancien comportement 5s/scène est conservé.
- **API rétrocompatible** : `assemble_pngs_to_mp4` accepte toujours 2 arguments ; le 3ème est optionnel.
- **Aucun autre appelant** identifié dans le snapshot Kamatera.
- **Aucune autre URL / chemin modifié** : seul le pipeline Smart Whiteboard est touché.
