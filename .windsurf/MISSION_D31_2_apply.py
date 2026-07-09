#!/usr/bin/env python3
"""MISSION D31.2 — Phases 2 & 3 : correction minimale sur Kamatera."""
import paramiko
from pathlib import Path
import time

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"
REMOTE_DIR = "/opt/whiteboard-worker"
REMOTE_FILES = {
    "whiteboard_ffmpeg_assembler.py": f"{REMOTE_DIR}/whiteboard_ffmpeg_assembler.py",
    "whiteboard_render_worker.py": f"{REMOTE_DIR}/whiteboard_render_worker.py",
}


def ssh_read_file(remote_path):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS, timeout=20)
    sftp = ssh.open_sftp()
    with sftp.file(remote_path, 'r') as f:
        content = f.read().decode('utf-8')
    sftp.close()
    ssh.close()
    return content


def ssh_write_file(remote_path, content):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS, timeout=20)
    sftp = ssh.open_sftp()
    with sftp.file(remote_path, 'w') as f:
        f.write(content.encode('utf-8'))
    sftp.close()
    ssh.close()


def ssh_command(cmd):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS, timeout=20)
    stdin, stdout, stderr = ssh.exec_command(cmd)
    out = stdout.read().decode(errors='ignore')
    err = stderr.read().decode(errors='ignore')
    ssh.close()
    return out, err


# ── Backup timestamped on remote ──
timestamp = time.strftime('%Y%m%d_%H%M%S', time.gmtime())
backup_cmd = f"mkdir -p {REMOTE_DIR}/backup_d31_2 && cp {REMOTE_DIR}/whiteboard_ffmpeg_assembler.py {REMOTE_DIR}/backup_d31_2/whiteboard_ffmpeg_assembler.py.{timestamp} && cp {REMOTE_DIR}/whiteboard_render_worker.py {REMOTE_DIR}/backup_d31_2/whiteboard_render_worker.py.{timestamp}"
out, err = ssh_command(backup_cmd)
print(f"Backup result: out={out.strip()}, err={err.strip()}")

# ── Read current files ──
assembler = ssh_read_file(REMOTE_FILES["whiteboard_ffmpeg_assembler.py"])
worker = ssh_read_file(REMOTE_FILES["whiteboard_render_worker.py"])

# ── Modify assembler ──
# Make typing import include Optional
new_assembler = assembler.replace(
    "from typing import List",
    "from typing import List, Optional"
)
# Replace signature and body
new_assembler = new_assembler.replace(
    "SECONDS_PER_SCENE = 5\nFPS = 30\n\n\ndef assemble_pngs_to_mp4(png_paths: List[Path], output_dir: Path) -> Path:",
    "FPS = 30\n\n\ndef assemble_pngs_to_mp4(png_paths: List[Path], output_dir: Path, durations_ms: Optional[List[int]] = None) -> Path:")

new_assembler = new_assembler.replace(
    "    # C1: concat demuxer avec duree explicite par scene\n    concat_file = output_dir / \"concat.txt\"\n    with open(concat_file, \"w\") as f:\n        for p in png_paths:\n            safe = str(p).replace(\"'\", \"'\\\\\\''\")\n            f.write(f\"file '{safe}'\\n\")\n            f.write(f\"duration {SECONDS_PER_SCENE}\\n\")\n        last = str(png_paths[-1]).replace(\"'\", \"'\\\\\\''\")\n        f.write(f\"file '{last}'\\n\")",
    "    # C1: concat demuxer avec duree explicite par scene\n    concat_file = output_dir / \"concat.txt\"\n    # Fallback: if no durations provided or mismatch, use 5s per scene (legacy behavior)\n    if durations_ms is None or len(durations_ms) != len(png_paths):\n        durations_ms = [5000] * len(png_paths)\n    with open(concat_file, \"w\") as f:\n        for p, d in zip(png_paths, durations_ms):\n            safe = str(p).replace(\"'\", \"'\\\\\\''\")\n            f.write(f\"file '{safe}'\\n\")\n            f.write(f\"duration {d / 1000.0}\\n\")\n        last = str(png_paths[-1]).replace(\"'\", \"'\\\\\\''\")\n        f.write(f\"file '{last}'\\n\")"
)

# ── Modify worker ──
# Add durations_ms extraction and pass to assembler
new_worker = worker.replace(
    "            # Assembler les PNGs en MP4\n            logger.info(f\"[whiteboard_render_worker] Assembling MP4 for job {job_id}\")\n            mp4_path = assemble_pngs_to_mp4(png_paths, temp_path)\n",
    "            # Extract scene durations from storyboard\n            storyboard = storyboard_json if isinstance(storyboard_json, dict) else {}\n            scenes = storyboard.get(\"scenes\", [])\n            durations_ms = [s.get(\"duration_ms\", 5000) for s in scenes]\n            if len(durations_ms) != len(png_paths):\n                logger.warning(f\"[whiteboard_render_worker] Duration mismatch: {len(durations_ms)} durations vs {len(png_paths)} PNGs; falling back to 5s per scene\")\n                durations_ms = None\n            \n            # Assembler les PNGs en MP4\n            logger.info(f\"[whiteboard_render_worker] Assembling MP4 for job {job_id}\")\n            mp4_path = assemble_pngs_to_mp4(png_paths, temp_path, durations_ms)\n"
)

# Replace duration calculation for mark_done
new_worker = new_worker.replace(
    "            # Calculer la durée (estimation basée sur le nombre de scènes)\n            # Pour V1, on estime 5 secondes par scène\n            storyboard = storyboard_json if isinstance(storyboard_json, dict) else {}\n            scenes = storyboard.get(\"scenes\", [])\n            duration_ms = len(scenes) * 5000",
    "            # Calculer la durée totale à partir du storyboard\n            if durations_ms is not None:\n                duration_ms = sum(durations_ms)\n            else:\n                # Fallback legacy: estimate 5 seconds per scene\n                duration_ms = len(scenes) * 5000"
)

# ── Write files ──
ssh_write_file(REMOTE_FILES["whiteboard_ffmpeg_assembler.py"], new_assembler)
ssh_write_file(REMOTE_FILES["whiteboard_render_worker.py"], new_worker)
print("Modified files written to Kamatera")

# ── Verify diff ──
diff_cmd = f"diff -u {REMOTE_DIR}/backup_d31_2/whiteboard_ffmpeg_assembler.py.{timestamp} {REMOTE_DIR}/whiteboard_ffmpeg_assembler.py && diff -u {REMOTE_DIR}/backup_d31_2/whiteboard_render_worker.py.{timestamp} {REMOTE_DIR}/whiteboard_render_worker.py"
out, err = ssh_command(diff_cmd)
print("Diff output:")
print(out)
print("Diff errors:")
print(err)

# ── Save local copy of changes ──
local_dir = Path("C:/Users/fasop/AndroidStudioProjects/academia/.windsurf/kamatera_snapshot_d31_2")
local_dir.mkdir(parents=True, exist_ok=True)
(local_dir / "whiteboard_ffmpeg_assembler.py").write_text(new_assembler, encoding='utf-8')
(local_dir / "whiteboard_render_worker.py").write_text(new_worker, encoding='utf-8')
print(f"Saved modified snapshots to {local_dir}")

# ── Generate changes report ──
changes_report = f"""# D31_2_ffmpeg_changes.md

**Date :** {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}
**Fichiers modifiés :**
- `{REMOTE_DIR}/whiteboard_ffmpeg_assembler.py`
- `{REMOTE_DIR}/whiteboard_render_worker.py`
**Backup :** `{REMOTE_DIR}/backup_d31_2/*.{timestamp}`

---

## 1. Changements dans `whiteboard_ffmpeg_assembler.py`

### Signature modifiée

```python
# AVANT
def assemble_pngs_to_mp4(png_paths: List[Path], output_dir: Path) -> Path:

# APRÈS
def assemble_pngs_to_mp4(png_paths: List[Path], output_dir: Path, durations_ms: Optional[List[int]] = None) -> Path:
```

### Durée par scène

```python
# AVANT
SECONDS_PER_SCENE = 5
...
for p in png_paths:
    f.write(f"duration {{SECONDS_PER_SCENE}}\\n")

# APRÈS
if durations_ms is None or len(durations_ms) != len(png_paths):
    durations_ms = [5000] * len(png_paths)
for p, d in zip(png_paths, durations_ms):
    f.write(f"duration {{d / 1000.0}}\\n")
```

**Conséquence :** `concat.txt` contient maintenant les durées réelles du storyboard (ex. `duration 7.0`) au lieu de `duration 5`.

---

## 2. Changements dans `whiteboard_render_worker.py`

### Extraction des durées

```python
# AJOUTÉ
storyboard = storyboard_json if isinstance(storyboard_json, dict) else {{}}
scenes = storyboard.get("scenes", [])
durations_ms = [s.get("duration_ms", 5000) for s in scenes]
if len(durations_ms) != len(png_paths):
    durations_ms = None

# MODIFIÉ
mp4_path = assemble_pngs_to_mp4(png_paths, temp_path, durations_ms)
```

### Durée retournée à `mark_done`

```python
# AVANT
duration_ms = len(scenes) * 5000

# APRÈS
if durations_ms is not None:
    duration_ms = sum(durations_ms)
else:
    duration_ms = len(scenes) * 5000
```

**Conséquence :** `whiteboard_mark_done` reçoit la somme réelle des `duration_ms` du storyboard.

---

## 3. Gestion des régressions

- **Fallback préservé** : si `durations_ms` est absent ou de taille incorrecte, l'ancien comportement 5s/scène est conservé.
- **API rétrocompatible** : `assemble_pngs_to_mp4` accepte toujours 2 arguments ; le 3ème est optionnel.
- **Aucun autre appelant** identifié dans le snapshot Kamatera.
"""

changes_file = Path("C:/Users/fasop/AndroidStudioProjects/academia/.windsurf/D31_2_ffmpeg_changes.md")
changes_file.write_text(changes_report, encoding='utf-8')
print(f"Saved {changes_file}")
