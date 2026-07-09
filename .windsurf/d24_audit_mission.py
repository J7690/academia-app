#!/usr/bin/env python3
"""
MISSION D.24 – AUDIT DE CONFORMITÉ DU RENDU VIDÉO SMART WHITEBOARD
Lecture seule. Aucune modification.
"""
import requests, json, struct, paramiko
from datetime import datetime

RENDER_ID = "15d0b7ed-4124-4e47-93f0-a38d8ff92bcb"
MP4_FILENAME = "90505511a06a4812afa6785033097289.mp4"
MP4_URL = f"https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/whiteboard-renders/renders/{RENDER_ID}/{MP4_FILENAME}"

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}

KAMATERA_HOST = "185.167.97.144"
KAMATERA_USER = "root"
KAMATERA_PWD  = "Nexiomgroup@Academia0"

SEP = "=" * 70

def sec(title):
    print(f"\n{SEP}\n  {title}\n{SEP}")

def admin_sql(label, sql):
    sec(f"SQL: {label}")
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                      json={"p_sql": sql.strip().rstrip(";")}, timeout=30)
    print(f"HTTP:{r.status_code}")
    try:
        data = r.json()
        print(json.dumps(data, ensure_ascii=False, indent=2)[:6000])
        return data
    except:
        print(r.text[:500])
        return {}

def ssh_run(client, cmd, label=""):
    if label:
        sec(f"SSH: {label}")
    _, stdout, stderr = client.exec_command(cmd, timeout=60)
    out = stdout.read().decode(errors='replace')
    err = stderr.read().decode(errors='replace')
    if out.strip():
        print(out[:5000])
    if err.strip():
        print(f"STDERR: {err[:1000]}")
    return out

print(f"\n{'#'*70}")
print(f"  MISSION D.24 – AUDIT CONFORMITÉ RENDU VIDÉO SMART WHITEBOARD")
print(f"  {datetime.now().isoformat()}")
print(f"  render_id : {RENDER_ID}")
print(f"  fichier   : {MP4_FILENAME}")
print(f"{'#'*70}")

# ==============================================================
# PHASE 1 – RETROUVER LE JOB SUPABASE
# ==============================================================
sec("PHASE 1 – JOB SUPABASE")

admin_sql("Render job 15d0b7ed complet",
    f"""
    SELECT id, project_id, status, progress, video_url, error_message,
           created_at, updated_at, duration_ms
    FROM app.whiteboard_renders
    WHERE id = '{RENDER_ID}'
    """)

admin_sql("Projet associé",
    f"""
    SELECT wp.id, wp.subject, wp.renderer_id, wp.theme_id, wp.narration_mode,
           wp.status, wp.created_at
    FROM app.whiteboard_projects wp
    INNER JOIN app.whiteboard_renders wr ON wr.project_id = wp.id
    WHERE wr.id = '{RENDER_ID}'
    """)

admin_sql("Storyboard du projet (truncated)",
    f"""
    SELECT left(ws.content::text, 3000) as storyboard_preview,
           jsonb_array_length(ws.content->'scenes') as nb_scenes
    FROM app.whiteboard_storyboards ws
    INNER JOIN app.whiteboard_renders wr ON wr.project_id = ws.project_id
    WHERE wr.id = '{RENDER_ID}'
    ORDER BY ws.created_at DESC LIMIT 1
    """)

admin_sql("Tous les renders récents (5 derniers)",
    """
    SELECT id, status, video_url, duration_ms, created_at, updated_at
    FROM app.whiteboard_renders
    ORDER BY created_at DESC LIMIT 5
    """)

# ==============================================================
# PHASE 1b – TÉLÉCHARGER LE MP4 ET ANALYSER SA STRUCTURE
# ==============================================================
sec("PHASE 1b – TÉLÉCHARGEMENT ET ANALYSE STRUCTURE MP4")
print(f"URL: {MP4_URL}")
r = requests.get(MP4_URL, timeout=30)
print(f"HTTP status: {r.status_code}")
print(f"Content-Type: {r.headers.get('content-type')}")
print(f"Content-Length header: {r.headers.get('content-length')}")
print(f"Taille réelle téléchargée: {len(r.content)} bytes")

mp4_data = r.content
mp4_local = "C:/Users/fasop/AndroidStudioProjects/academia/.windsurf/audit_d24_target.mp4"
with open(mp4_local, "wb") as f:
    f.write(mp4_data)
print(f"Sauvegardé: {mp4_local}")

# Structure atoms MP4
print("\n--- Atoms MP4 ---")
offset = 0
atoms_ordered = []
while offset < len(mp4_data) - 8:
    sz = struct.unpack('>I', mp4_data[offset:offset+4])[0]
    nm = mp4_data[offset+4:offset+8].decode('ascii', errors='?')
    atoms_ordered.append((offset, nm, sz))
    print(f"  offset={offset:8d}  name={nm}  size={sz}")
    if sz == 0 or sz < 8:
        break
    offset += sz
    if offset >= len(mp4_data):
        break

# moov avant mdat ?
names = [a[1] for a in atoms_ordered]
moov_idx = names.index('moov') if 'moov' in names else -1
mdat_idx = names.index('mdat') if 'mdat' in names else -1
print(f"\nmoov index: {moov_idx}, mdat index: {mdat_idx}")
print(f"moov AVANT mdat: {moov_idx < mdat_idx if moov_idx >= 0 and mdat_idx >= 0 else 'N/A'}")

# mvhd - durée
mvhd_pos = mp4_data.find(b'mvhd')
if mvhd_pos >= 0:
    version = mp4_data[mvhd_pos + 4]
    if version == 0:
        ts = struct.unpack('>I', mp4_data[mvhd_pos+12:mvhd_pos+16])[0]
        dur = struct.unpack('>I', mp4_data[mvhd_pos+16:mvhd_pos+20])[0]
    else:
        ts = struct.unpack('>I', mp4_data[mvhd_pos+16:mvhd_pos+20])[0]
        dur = struct.unpack('>Q', mp4_data[mvhd_pos+20:mvhd_pos+28])[0]
    print(f"\nmvhd: version={version}, timescale={ts}, duration={dur}")
    if ts > 0:
        print(f"  → durée calculée: {dur/ts:.4f}s ({dur/ts/60:.2f} min)")
    else:
        print("  → timescale=0 : durée INVALIDE")

# ==============================================================
# PHASE 2 + 4 – KAMATERA : ffprobe, worker, logs
# ==============================================================
sec("PHASE 2+4 – CONNEXION KAMATERA")
client_ssh = paramiko.SSHClient()
client_ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client_ssh.connect(KAMATERA_HOST, username=KAMATERA_USER, password=KAMATERA_PWD, timeout=20)
print("Connexion SSH établie")

# ffprobe complet sur le fichier local Kamatera ou via URL
ssh_run(client_ssh, f"""
ffprobe -v quiet \
  -print_format json \
  -show_format \
  -show_streams \
  '{MP4_URL}' 2>&1
""", "ffprobe -show_format -show_streams sur le MP4 cible")

# ffprobe frames (limité aux 10 premières)
ssh_run(client_ssh, f"""
ffprobe -v quiet \
  -print_format json \
  -show_frames \
  -read_intervals "%+#10" \
  '{MP4_URL}' 2>&1
""", "ffprobe -show_frames (10 premières frames)")

# Version FFmpeg exacte
ssh_run(client_ssh, "ffmpeg -version 2>&1 | head -3", "FFmpeg version exacte")

# Python + Pillow + dépendances
ssh_run(client_ssh, """
python3 -c "
import sys
print('Python:', sys.version)
try:
    import PIL; print('Pillow:', PIL.__version__)
except: print('Pillow: NON INSTALLÉ')
try:
    import httpx; print('httpx:', httpx.__version__)
except: print('httpx: NON INSTALLÉ')
try:
    import paramiko; print('paramiko:', paramiko.__version__)
except: print('paramiko: NON INSTALLÉ')
try:
    import dotenv; print('dotenv: OK')
except: print('dotenv: NON INSTALLÉ')
" 2>&1
""", "Versions Python + dépendances")

# Worker en cours d'exécution
ssh_run(client_ssh, "ps aux | grep -i whiteboard | grep -v grep", "Processus worker actif")

# Lire whiteboard_ffmpeg_assembler.py ACTUEL (version déployée)
ssh_run(client_ssh, "cat /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py", "whiteboard_ffmpeg_assembler.py ACTUEL")

# Lire whiteboard_png_renderer.py ACTUEL
ssh_run(client_ssh, "cat /opt/whiteboard-worker/whiteboard_png_renderer.py 2>&1 | head -80", "whiteboard_png_renderer.py (80 premières lignes)")

# Lire whiteboard_upload_renderer.py
ssh_run(client_ssh, "cat /opt/whiteboard-worker/whiteboard_upload_renderer.py 2>&1", "whiteboard_upload_renderer.py")

# Logs du worker pour le render cible
ssh_run(client_ssh, f"""
journalctl -u whiteboard-worker --no-pager -n 200 2>/dev/null | grep -A5 -B5 '{RENDER_ID[:8]}' || \
grep -r '{RENDER_ID[:8]}' /var/log/ 2>/dev/null | head -30 || \
echo 'Aucun log journalctl avec ce render_id'
""", f"Logs pour render {RENDER_ID[:8]}")

# Logs récents du worker (100 dernières lignes)
ssh_run(client_ssh, """
journalctl -u whiteboard-worker --no-pager -n 100 2>/dev/null || \
tail -100 /var/log/whiteboard-worker.log 2>/dev/null || \
echo 'journalctl non disponible'
""", "100 dernières lignes logs worker")

# Fichiers temporaires encore présents
ssh_run(client_ssh, f"""
find /tmp -name '*{RENDER_ID[:8]}*' 2>/dev/null
find /tmp -name '*.png' -newer /tmp 2>/dev/null | head -10
find /tmp -name '*.mp4' -newer /tmp 2>/dev/null | head -10
echo '--- /tmp contents ---'
ls -la /tmp/ | head -20
""", "Fichiers temporaires PNG/MP4")

# Variables d'environnement du worker
ssh_run(client_ssh, """
cat /opt/whiteboard-worker/.env 2>/dev/null | sed 's/=.*/=***REDACTED***/g' || echo '.env non trouvé'
cat /etc/systemd/system/whiteboard-worker.service 2>/dev/null || echo 'service file non trouvé'
""", "Variables env + service systemd")

# Lire le whiteboard_render_worker.py complet
ssh_run(client_ssh, "cat /opt/whiteboard-worker/whiteboard_render_worker.py", "whiteboard_render_worker.py complet")

client_ssh.close()

# ==============================================================
# PHASE 5 – MÉMOIRE ARCHITECTURALE (fichiers projet)
# ==============================================================
sec("PHASE 5 – MÉMOIRE ARCHITECTURALE")

admin_sql("Définition SQL whiteboard_create_render_job",
    "SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'whiteboard_create_render_job' LIMIT 1")

admin_sql("Définition SQL whiteboard_mark_done",
    "SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'whiteboard_mark_done' LIMIT 1")

admin_sql("Définition SQL whiteboard_fetch_queued_jobs",
    "SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'whiteboard_fetch_queued_jobs' LIMIT 1")

admin_sql("Structure table whiteboard_renders",
    """
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='whiteboard_renders'
    ORDER BY ordinal_position
    """)

print(f"\n{'#'*70}")
print("  AUDIT D.24 TERMINÉ - Données collectées pour rapport final")
print(f"{'#'*70}")
