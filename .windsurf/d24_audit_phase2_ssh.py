#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""MISSION D.24 - PHASE 2+4+5 via SSH Kamatera + SQL Supabase"""
import requests, json, paramiko
from datetime import datetime

RENDER_ID  = "15d0b7ed-4124-4e47-93f0-a38d8ff92bcb"
MP4_FILE   = "90505511a06a4812afa6785033097289.mp4"
MP4_URL    = f"https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/whiteboard-renders/renders/{RENDER_ID}/{MP4_FILE}"

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}

KAMATERA = dict(hostname="185.167.97.144", username="root", password="Nexiomgroup@Academia0", timeout=20)

SEP = "=" * 70

def s(title): print(f"\n{SEP}\n{title}\n{SEP}")

def sql(label, q):
    s(f"SQL: {label}")
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                      json={"p_sql": q.strip().rstrip(";")}, timeout=30)
    print(f"HTTP:{r.status_code}")
    try:
        d = r.json(); print(json.dumps(d, ensure_ascii=False, indent=2)[:6000])
        return d
    except: print(r.text[:500]); return {}

def ssh(client, cmd, label=""):
    if label: s(f"SSH: {label}")
    _, o, e = client.exec_command(cmd, timeout=60)
    out = o.read().decode(errors='replace')
    err = e.read().decode(errors='replace')
    if out.strip(): print(out[:6000])
    if err.strip(): print(f"[STDERR] {err[:800]}")
    return out

print("=" * 70)
print(f"MISSION D.24 - AUDIT - {datetime.now().isoformat()}")
print(f"Target render_id: {RENDER_ID}")
print(f"Target file    : {MP4_FILE}")
print("=" * 70)

# ---------------------------------------------------------------
# PHASE 1 : RESULTATS SUPABASE DEJA CONNUS - COMPLEMENTAIRES
# ---------------------------------------------------------------
sql("Storyboard via whiteboard_projects (schema correct)",
    f"""
    SELECT left(wb.storyboard::text, 4000) as storyboard_preview
    FROM app.whiteboard_projects wb
    WHERE id = 'd5d0af4c-71f7-4a26-9d7b-48f9bf61ee84'
    """)

sql("Structure table whiteboard_renders (colonnes completes)",
    """
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='whiteboard_renders'
    ORDER BY ordinal_position
    """)

sql("whiteboard_fetch_queued_jobs - source SQL",
    "SELECT pg_get_functiondef(oid) as def FROM pg_proc WHERE proname='whiteboard_fetch_queued_jobs' LIMIT 1")

sql("whiteboard_mark_done - source SQL",
    "SELECT pg_get_functiondef(oid) as def FROM pg_proc WHERE proname='whiteboard_mark_done' LIMIT 1")

sql("whiteboard_get_render_status - source SQL",
    "SELECT pg_get_functiondef(oid) as def FROM pg_proc WHERE proname='whiteboard_get_render_status' LIMIT 1")

# ---------------------------------------------------------------
# PHASE 2 + 4 : SSH KAMATERA
# ---------------------------------------------------------------
s("CONNEXION SSH KAMATERA")
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(**KAMATERA)
print("SSH OK")

# Phase 2 : ffprobe complet
ssh(c, f"""
ffprobe -v quiet -print_format json -show_format -show_streams '{MP4_URL}' 2>&1
""", "PHASE 2 : ffprobe -show_format -show_streams")

ssh(c, f"""
ffprobe -v quiet -print_format json -show_frames -read_intervals '%+#20' '{MP4_URL}' 2>&1
""", "PHASE 2 : ffprobe -show_frames (20 premieres frames)")

# Phase 4 : environnement Kamatera
ssh(c, "ffmpeg -version 2>&1 | head -4", "PHASE 4 : FFmpeg version exacte")

ssh(c, """python3 -c "
import sys; print('Python:', sys.version.split()[0])
try: import PIL; print('Pillow:', PIL.__version__)
except: print('Pillow: ABSENT')
try: import httpx; print('httpx:', httpx.__version__)
except: print('httpx: ABSENT')
try: import paramiko; print('paramiko: OK')
except: print('paramiko: ABSENT')
" 2>&1""", "PHASE 4 : dependances Python")

ssh(c, "ps aux | grep -i whiteboard | grep -v grep | head -10",
    "PHASE 4 : processus worker actif")

ssh(c, "cat /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py 2>&1",
    "PHASE 4 : whiteboard_ffmpeg_assembler.py ACTUEL complet")

ssh(c, "cat /opt/whiteboard-worker/whiteboard_png_renderer.py 2>&1",
    "PHASE 4 : whiteboard_png_renderer.py ACTUEL complet")

ssh(c, "cat /opt/whiteboard-worker/whiteboard_upload_renderer.py 2>&1",
    "PHASE 4 : whiteboard_upload_renderer.py ACTUEL complet")

ssh(c, "cat /opt/whiteboard-worker/whiteboard_render_worker.py 2>&1",
    "PHASE 4 : whiteboard_render_worker.py ACTUEL complet")

ssh(c, "cat /etc/systemd/system/whiteboard-worker.service 2>/dev/null || echo 'no service file'",
    "PHASE 4 : whiteboard-worker.service")

ssh(c, """
journalctl -u whiteboard-worker --no-pager -n 150 2>/dev/null | head -150 || \
tail -150 /var/log/whiteboard-worker.log 2>/dev/null || echo 'pas de log journalctl'
""", "PHASE 4 : 150 derniers logs worker")

ssh(c, f"""
journalctl -u whiteboard-worker --no-pager 2>/dev/null | grep -i '{RENDER_ID[:8]}' | head -30 || \
echo 'aucun log pour ce render_id'
""", f"PHASE 4 : logs specifiques render {RENDER_ID[:8]}")

ssh(c, """
ls -la /opt/whiteboard-worker/
echo '---'
pip3 list 2>/dev/null | grep -iE 'pillow|httpx|paramiko|dotenv|requests'
""", "PHASE 4 : contenu /opt/whiteboard-worker + pip list")

c.close()
print("\n" + "=" * 70)
print("AUDIT D.24 - COLLECTE TERMINEE")
print("=" * 70)
