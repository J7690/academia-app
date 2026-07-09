#!/usr/bin/env python3
"""MISSION D31.2 — Phase 1 : traçage complet avant modification."""
import paramiko
import requests
import json
from pathlib import Path
import time

# ── SSH Kamatera ──
HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"
REMOTE_DIR = "/opt/whiteboard-worker"
REMOTE_FILES = [
    f"{REMOTE_DIR}/whiteboard_ffmpeg_assembler.py",
    f"{REMOTE_DIR}/whiteboard_render_worker.py",
]

# ── Supabase admin ──
SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
ADMIN_RPC = f"{SUPABASE_URL}/rest/v1/rpc/admin_execute_sql"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
ADMIN_HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}


def execute_sql(sql):
    sql = sql.strip().rstrip(';')
    for attempt in range(3):
        try:
            resp = requests.post(ADMIN_RPC, headers=ADMIN_HEADERS, json={"p_sql": sql}, timeout=60)
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            if attempt == 2:
                raise
            time.sleep(2)


def ssh_command(cmd):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS, timeout=20)
    stdin, stdout, stderr = ssh.exec_command(cmd)
    out = stdout.read().decode(errors='ignore')
    err = stderr.read().decode(errors='ignore')
    ssh.close()
    return out, err


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


# 1. Lire les fichiers actuels sur Kamatera
files_content = {}
for remote in REMOTE_FILES:
    files_content[Path(remote).name] = ssh_read_file(remote)

# 2. Récupérer un storyboard réel avec sujet dérivés
sql_project = """
SELECT id, subject, storyboard_json
FROM app.whiteboard_projects
WHERE subject ILIKE '%dériv%' AND storyboard_json IS NOT NULL
ORDER BY created_at DESC
LIMIT 1
"""
project_result = execute_sql(sql_project)
project_rows = project_result.get('rows', project_result.get('data', []))
project = project_rows[0] if project_rows else None

if project and isinstance(project, (list, tuple)):
    project_id, subject, storyboard_json = project
else:
    project_id, subject, storyboard_json = project['id'], project['subject'], project['storyboard_json']

if isinstance(storyboard_json, str):
    storyboard = json.loads(storyboard_json)
else:
    storyboard = storyboard_json

scenes = storyboard.get('scenes', [])
scene_durations = [s.get('duration_ms') for s in scenes]

# 3. État du worker
status_out, status_err = ssh_command("systemctl status whiteboard-worker --no-pager")

# 4. Générer le rapport de traçage
trace_report = f"""# D31_2_duration_trace.md

**Date :** {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}
**Mode :** LECTURE SEULE — avant modification
**Projet analysé :** `{project_id}`
**Sujet :** {subject}

---

## 1. Storyboard réel reçu par le worker

| Scène | Order | Titre | `duration_ms` |
|---|---|---|---|
"""
for i, scene in enumerate(scenes):
    trace_report += f"| {i+1} | {scene.get('order')} | {scene.get('title', '')[:40]} | {scene.get('duration_ms')} |\n"

trace_report += f"""
**Total `duration_ms` storyboard :** {sum(scene_durations)} ms ({sum(scene_durations)/1000:.1f} s)

**Valeurs uniques :** {sorted(set(scene_durations))}

---

## 2. Code qui transmet les scènes : Worker → Assembler

### `whiteboard_render_worker.py` (extrait actuel)

```python
{files_content['whiteboard_render_worker.py'].split('png_paths = render_storyboard_to_pngs')[1].split('mp4_path = assemble_pngs_to_mp4')[0]}
mp4_path = assemble_pngs_to_mp4(png_paths, temp_path)
```

### `whiteboard_ffmpeg_assembler.py` (extrait actuel)

```python
{files_content['whiteboard_ffmpeg_assembler.py'].split('SECONDS_PER_SCENE = 5')[0].split('def assemble_pngs_to_mp4')[0]}
SECONDS_PER_SCENE = 5

{files_content['whiteboard_ffmpeg_assembler.py'].split('SECONDS_PER_SCENE = 5')[1].split('with open(concat_file')[0]}
with open(concat_file, "w") as f:
    for p in png_paths:
        safe = str(p).replace("'", "'\\''")
        f.write(f"file '{{safe}}'\\n")
        f.write(f"duration {{SECONDS_PER_SCENE}}\\n")
```

---

## 3. Où `duration_ms` disparaît

| Étape | `duration_ms` présent ? | Utilisé ? | Preuve |
|---|---|---|---|
| Storyboard JSON | ✅ Oui | — | Voir tableau section 1 |
| `whiteboard_fetch_queued_jobs` | ✅ Oui (alias `storyboard`) | — | `SELECT wp.storyboard_json as storyboard` |
| `_process_single_job` | ✅ Oui dans `storyboard_json` | ❌ **Non lu** | `png_paths = render_storyboard_to_pngs(storyboard_json, temp_path)` |
| `assemble_pngs_to_mp4` | ❌ **Non reçu** | ❌ **Non utilisé** | Signature : `assemble_pngs_to_mp4(png_paths, output_dir)` |
| `concat.txt` | ❌ **Non reçu** | ❌ **Remplacé par 5** | `duration {{SECONDS_PER_SCENE}}` |
| `_mark_job_done` | ❌ **Faux** | ❌ **Faux** | `duration_ms = len(scenes) * 5000` |

---

## 4. État du worker avant modification

```
{status_out[:1500]}
```

**Erreurs éventuelles :**
```
{status_err[:500]}
```

---

**Conclusion :** `duration_ms` est généré par l'IA, stocké par Supabase, récupéré par le worker, mais **ignoré** dès l'appel à l'assembleur FFmpeg. L'assembleur utilise `SECONDS_PER_SCENE = 5` et `mark_done` remonte une durée fausse.
"""

outfile = Path("C:/Users/fasop/AndroidStudioProjects/academia/.windsurf/D31_2_duration_trace.md")
outfile.write_text(trace_report, encoding='utf-8')
print(f"Saved {outfile}")

# Sauvegarder les fichiers actuels comme backup
backup_dir = Path("C:/Users/fasop/AndroidStudioProjects/academia/.windsurf/kamatera_backup_d31_2")
backup_dir.mkdir(parents=True, exist_ok=True)
for name, content in files_content.items():
    (backup_dir / name).write_text(content, encoding='utf-8')
print(f"Backup saved in {backup_dir}")
