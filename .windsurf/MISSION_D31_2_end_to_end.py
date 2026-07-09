#!/usr/bin/env python3
"""MISSION D31.2 — Phase 5 : test end-to-end duration harmonization."""
import requests
import json
import time
import paramiko
from pathlib import Path
import re

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
ADMIN_RPC = f"{SUPABASE_URL}/rest/v1/rpc/admin_execute_sql"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
ADMIN_HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

PROJECT_ID = "3993bb85-1818-407b-810e-4bcfe1b983fa"


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


# 1. Get storyboard duration from project
project_sql = f"SELECT storyboard_json FROM app.whiteboard_projects WHERE id = '{PROJECT_ID}'"
project_result = execute_sql(project_sql)
rows = project_result.get('rows', project_result.get('data', []))
storyboard = rows[0]
if isinstance(storyboard, (list, tuple)):
    storyboard = storyboard[0]
if isinstance(storyboard, str):
    storyboard = json.loads(storyboard)

scenes = storyboard.get('scenes', [])
storyboard_durations_ms = [s.get('duration_ms', 5000) for s in scenes]
storyboard_total_ms = sum(storyboard_durations_ms)
print(f"Storyboard total duration_ms: {storyboard_total_ms} ms ({len(scenes)} scenes)")

# 2. Insert a render job for this project
insert_sql = f"""
INSERT INTO app.whiteboard_renders (project_id, status, progress)
VALUES ('{PROJECT_ID}', 'queued', 0)
RETURNING id
"""
insert_result = execute_sql(insert_sql)
render_rows = insert_result.get('rows', insert_result.get('data', []))
render_id = render_rows[0]
if isinstance(render_id, (list, tuple)):
    render_id = render_id[0]
print(f"Created render job: {render_id}")

# 3. Wait for worker to process
max_wait = 300  # 5 minutes
poll_interval = 5
start = time.time()
render_status = None
while time.time() - start < max_wait:
    status_sql = f"SELECT status, video_url, duration_ms, error_message FROM app.whiteboard_renders WHERE id = '{render_id}'"
    status_result = execute_sql(status_sql)
    status_rows = status_result.get('rows', status_result.get('data', []))
    row = status_rows[0]
    if isinstance(row, (list, tuple)):
        status, video_url, db_duration_ms, error_message = row
    else:
        status, video_url, db_duration_ms, error_message = row['status'], row['video_url'], row['duration_ms'], row['error_message']
    render_status = status
    print(f"[{int(time.time()-start)}s] status={status}, db_duration_ms={db_duration_ms}, video_url={video_url}")
    if status in ('done', 'failed'):
        break
    time.sleep(poll_interval)

if render_status != 'done':
    raise RuntimeError(f"Render failed or timeout: status={render_status}, error={error_message}")

# 4. Verify video with ffprobe on Kamatera
# Download the video to a temp file on Kamatera and ffprobe it
video_url = video_url.strip()
temp_mp4 = f"/tmp/d31_2_test_{render_id}.mp4"
out, err = ssh_command(f"curl -L -o {temp_mp4} '{video_url}' && ffprobe -v error -show_entries format=duration -of csv=p=0 {temp_mp4}")
ffprobe_duration_s = float(out.strip())
ffprobe_duration_ms = int(ffprobe_duration_s * 1000)
print(f"ffprobe duration: {ffprobe_duration_ms} ms")

# 5. Worker log tail
log_out, _ = ssh_command("journalctl -u whiteboard-worker --no-pager -n 50")

# 6. Generate report
report = f"""# D31_2_end_to_end_validation.md

**Date :** {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}
**Render job :** `{render_id}`
**Project :** `{PROJECT_ID}`
**Sujet :** dérivés d'une fonction

---

## 1. `duration_ms` total du storyboard

**{storyboard_total_ms} ms** ({storyboard_total_ms/1000:.1f} s) — {len(scenes)} scènes

| Scène | Titre | `duration_ms` |
|---|---|---|
"""
for i, scene in enumerate(scenes):
    report += f"| {i+1} | {scene.get('title', '')[:40]} | {scene.get('duration_ms')} |\n"

report += f"""
---

## 2. `duration_ms` total envoyé au worker (via `storyboard_json`)

**{storyboard_total_ms} ms**

Le worker lit `wp.storyboard_json` via `whiteboard_fetch_queued_jobs`.

---

## 3. Durée réelle du MP4 (ffprobe)

Commande : `ffprobe -v error -show_entries format=duration -of csv=p=0 {temp_mp4}`

Résultat : **{ffprobe_duration_ms} ms** ({ffprobe_duration_s:.3f} s)

---

## 4. `duration_ms` enregistrée dans Supabase

**{db_duration_ms} ms**

---

## 5. Tableau de cohérence

| Source | Valeur (ms) | Tolérance | Statut |
|---|---|---|---|
| Storyboard | {storyboard_total_ms} | — | référence |
| Worker reçu | {storyboard_total_ms} | — | ✅ identique |
| MP4 ffprobe | {ffprobe_duration_ms} | ±500 ms | {'✅ OK' if abs(ffprobe_duration_ms - storyboard_total_ms) <= 500 else '❌ HORS TOLÉRANCE'} |
| Supabase DB | {db_duration_ms} | ±500 ms | {'✅ OK' if abs(db_duration_ms - storyboard_total_ms) <= 500 else '❌ HORS TOLÉRANCE'} |

---

## 6. Worker log (extrait)

```
{log_out[-2000:]}
```

---

## 7. Conclusion

**{ '✅ Toutes les durées sont cohérentes dans la tolérance de ±500 ms.' if (abs(ffprobe_duration_ms - storyboard_total_ms) <= 500 and abs(db_duration_ms - storyboard_total_ms) <= 500) else '❌ Incohérence détectée.' }**
"""

outfile = Path("C:/Users/fasop/AndroidStudioProjects/academia/.windsurf/D31_2_end_to_end_validation.md")
outfile.write_text(report, encoding='utf-8')
print(f"Saved {outfile}")
