#!/usr/bin/env python3
"""
MISSION D.25 - AUDIT FORENSIQUE FINAL - LECTURE SEULE
Render ID: 07356b0d-ff4c-4ce2-80a9-9e7ec5306367
"""
import sys, json, struct, hashlib, requests, paramiko
sys.stdout.reconfigure(encoding='utf-8')

RENDER_ID = "07356b0d-ff4c-4ce2-80a9-9e7ec5306367"
MP4_FNAME = "4b636e441c374687935eaecba55661ac.mp4"
MP4_URL   = f"https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/whiteboard-renders/renders/{RENDER_ID}/{MP4_FNAME}"

SUPABASE  = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY      = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}
KAMATERA  = dict(hostname="185.167.97.144", username="root", password="Nexiomgroup@Academia0", timeout=30)

def sep(title):
    print(f"\n{'='*70}")
    print(f"  {title}")
    print('='*70)

def sql(query):
    r = requests.post(f"{SUPABASE}/rest/v1/rpc/admin_execute_sql", headers=H, json={"sql": query}, timeout=30)
    return r.json()

def ssh_run(c, cmd, timeout=120):
    _, o, e = c.exec_command(cmd, timeout=timeout)
    out = o.read().decode(errors='replace')
    err = e.read().decode(errors='replace')
    return out, err

# ============================================================
sep("D25-01 : IDENTIFICATION DU FICHIER REEL - SUPABASE")
# ============================================================

q1 = f"""
SELECT
  rj.id                                  AS render_id,
  rj.project_id,
  rj.status,
  rj.video_url,
  rj.created_at,
  rj.updated_at,
  EXTRACT(EPOCH FROM (rj.updated_at - rj.created_at))::int AS duree_traitement_s,
  wp.subject                              AS subject,
  wp.title                               AS project_title,
  rj.storyboard_json::text               AS storyboard_raw
FROM whiteboard_render_jobs rj
LEFT JOIN whiteboard_projects wp ON wp.id = rj.project_id
WHERE rj.id = '{RENDER_ID}';
"""
res = sql(q1)
rows = res.get('rows', [])
storyboard_json = None
if rows:
    r = rows[0]
    print(f"render_id         : {r.get('render_id')}")
    print(f"project_id        : {r.get('project_id')}")
    print(f"subject           : {r.get('subject')}")
    print(f"project_title     : {r.get('project_title')}")
    print(f"status            : {r.get('status')}")
    print(f"video_url         : {r.get('video_url')}")
    print(f"created_at        : {r.get('created_at')}")
    print(f"updated_at        : {r.get('updated_at')}")
    print(f"duree_traitement  : {r.get('duree_traitement_s')} secondes")
    raw = r.get('storyboard_raw', '')
    if raw:
        try:
            storyboard_json = json.loads(raw)
            scenes = storyboard_json.get('scenes', [])
            print(f"nb_scenes         : {len(scenes)}")
            print(f"theme             : {storyboard_json.get('theme','?')}")
            print(f"renderer          : {storyboard_json.get('renderer','?')}")
            duree_attendue = len(scenes) * 5
            print(f"duree_attendue    : {duree_attendue}s ({len(scenes)} scenes x 5s)")
            for i, sc in enumerate(scenes):
                print(f"  Scene {i+1}: '{sc.get('title','?')}' — {len(sc.get('blocks',[]))} blocs")
        except Exception as ex:
            print(f"[ERREUR parse storyboard]: {ex}")
else:
    print("ERREUR: render_id non trouvé dans Supabase")

# URL complète
print(f"\nURL Supabase MP4  : {MP4_URL}")

# Taille via HEAD
head = requests.head(MP4_URL, timeout=15)
file_size = int(head.headers.get('content-length', 0))
print(f"Taille fichier    : {file_size} bytes ({file_size/1024:.1f} KB)")
print(f"HTTP status HEAD  : {head.status_code}")

# ============================================================
sep("D25-02 + D25-03 + D25-04 : FFPROBE + STRUCTURE + DUREE")
# ============================================================

print(f"Telechargement du MP4 ({file_size} bytes)...")
resp = requests.get(MP4_URL, timeout=60)
print(f"HTTP GET: {resp.status_code}, taille reelle: {len(resp.content)} bytes")

mp4_data = None
if resp.status_code == 200:
    mp4_data = resp.content
    checksum_local = hashlib.md5(mp4_data).hexdigest()
    print(f"MD5 local         : {checksum_local}")

    # --- STRUCTURE ATOMS (D25-03) ---
    print("\n--- STRUCTURE MP4 (atoms) ---")
    off, atoms = 0, []
    while off < len(mp4_data) - 8:
        sz = int.from_bytes(mp4_data[off:off+4], 'big')
        nm = mp4_data[off+4:off+8].decode('ascii', errors='?')
        atoms.append((nm, off, sz))
        print(f"  [{nm}]  offset={off}  taille={sz}")
        if sz < 8: break
        off += sz
        if off >= len(mp4_data): break

    atom_names = [a[0] for a in atoms]
    has_ftyp = 'ftyp' in atom_names
    has_moov = 'moov' in atom_names
    has_mdat = 'mdat' in atom_names

    if has_moov and has_mdat:
        moov_before_mdat = atom_names.index('moov') < atom_names.index('mdat')
    else:
        moov_before_mdat = None

    print(f"\n  ftyp present      : {has_ftyp}")
    print(f"  moov present      : {has_moov}")
    print(f"  mdat present      : {has_mdat}")
    print(f"  ORDRE             : {' > '.join(atom_names)}")
    print(f"  moov AVANT mdat   : {moov_before_mdat}")
    print(f"  faststart actif   : {moov_before_mdat}")

    # bytes 8-11 du ftyp = major_brand
    if len(mp4_data) >= 12:
        major_brand = mp4_data[8:12].decode('ascii', errors='?')
        print(f"  major_brand       : {major_brand}")

    # Sauvegarder pour ffprobe SSH
    with open(r"C:\tmp\d25_audit.mp4", "wb") as f:
        f.write(mp4_data)
    print(f"\n  Sauvegarde locale : C:\\tmp\\d25_audit.mp4")
else:
    print(f"ERREUR telechargement: HTTP {resp.status_code}")

# ============================================================
sep("D25-02+D25-04+D25-05+D25-06+D25-07 : SSH KAMATERA")
# ============================================================

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(**KAMATERA)
print("SSH connecte OK")

def ssh(cmd, label=None, maxout=8000):
    if label:
        print(f"\n  [{label}]")
    out, err = ssh_run(c, cmd)
    if out.strip(): print(out[:maxout])
    if err.strip(): print(f"  [STDERR] {err[:800]}")
    return out

# -- D25-06: Worker en mémoire --
print("\n--- D25-06: WORKER EN MEMOIRE ---")
ssh("systemctl status whiteboard-worker --no-pager 2>/dev/null | head -20", "systemctl status")
ssh("ps aux | grep whiteboard | grep -v grep", "PID worker")
ssh("cat /proc/$(systemctl show whiteboard-worker -p MainPID --value)/cmdline 2>/dev/null | tr '\\0' ' '", "cmdline worker")

# Uptime du process
ssh("""
PID=$(systemctl show whiteboard-worker -p MainPID --value 2>/dev/null)
echo "PID: $PID"
if [ -n "$PID" ] && [ "$PID" != "0" ]; then
    echo "Demarrage: $(ps -p $PID -o lstart= 2>/dev/null)"
    echo "Uptime: $(ps -p $PID -o etime= 2>/dev/null)"
fi
""", "PID+uptime")

# Date de modification de l'assembler
ssh("stat /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py 2>/dev/null", "stat assembler")
ssh("ls -la /opt/whiteboard-worker/*.py 2>/dev/null", "liste scripts")

# Pycache
print("\n--- D25-06: PYCACHE ---")
ssh("ls -la /opt/whiteboard-worker/__pycache__/ 2>/dev/null || echo 'Pas de pycache'", "pycache")
ssh("python3 -c \"import marshal,struct; import dis; f=open('/opt/whiteboard-worker/__pycache__/whiteboard_ffmpeg_assembler.cpython-312.pyc','rb'); f.read(16); code=marshal.load(f); print('Constants:', [c for c in code.co_consts if isinstance(c,str) and 'colorspace' in c.lower()])\" 2>/dev/null || echo 'pyc non lisible ou Python version differente'", "inspection pyc")

# Checksum de l'assembler chargé
ssh("md5sum /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py 2>/dev/null", "md5 assembler sur disque")

# Version du script (grep commentaire de version)
ssh("head -10 /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py", "header assembler")

# Grep commande ffmpeg réelle dans le script
ssh("grep -n 'colorspace\\|colorprim\\|color_trc\\|color_primaries\\|x264-params\\|baseline\\|faststart\\|concat\\|smpte' /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py 2>/dev/null", "grep params critiques assembler")

# -- D25-07: Commande FFmpeg réelle pour ce render --
print("\n--- D25-07: COMMANDE FFMPEG REELLE ---")
ssh(f"journalctl -u whiteboard-worker --no-pager 2>/dev/null | grep -B2 -A5 '{RENDER_ID[:8]}' | head -60", "logs worker pour ce render")

# Vérifier si le render a été traité après le restart de v6
ssh(f"""
echo "Date restart worker:"
systemctl show whiteboard-worker -p ActiveEnterTimestamp --value 2>/dev/null
echo ""
echo "Render cree:"
""", "timing render vs restart")

# Logs worker: complet depuis 07:00
ssh("journalctl -u whiteboard-worker --no-pager --since '2026-06-29 07:00' 2>/dev/null | head -80", "logs complets depuis 07h")

# ffprobe via SSH sur le fichier téléchargé depuis Supabase
print("\n--- D25-02: FFPROBE COMPLET (SSH) ---")
ssh(f"""
curl -s -o /tmp/d25_target.mp4 '{MP4_URL}'
echo "TAILLE: $(stat -c%s /tmp/d25_target.mp4) bytes"
echo ""
echo "=== FFPROBE JSON ==="
ffprobe -v quiet -print_format json -show_streams -show_format /tmp/d25_target.mp4 2>/dev/null
""", "ffprobe complet SSH")

# D25-05: Test lecture locale (sans GUI, juste codec check)
print("\n--- D25-05: TEST LECTURE LOCALE ---")
ssh("""
echo "=== TEST FFPLAY (sans affichage, decodage seulement) ==="
timeout 10 ffplay -nodisp -autoexit /tmp/d25_target.mp4 2>&1 | tail -5 || echo "ffplay termine"

echo ""
echo "=== TEST FFMPEG DECODE COMPLET ==="
timeout 30 ffmpeg -i /tmp/d25_target.mp4 -f null - 2>&1 | tail -15
""", "test decode local")

# D25-07: Extraire la commande ffmpeg exacte du script en mémoire
print("\n--- D25-07: COMMANDE FFMPEG COMPLETE DU SCRIPT ---")
ssh("""
python3 -c "
import sys
sys.path.insert(0, '/opt/whiteboard-worker')
import inspect
import whiteboard_ffmpeg_assembler as asm
src = inspect.getsource(asm)
print(src)
" 2>/dev/null
""", "source assembler charge en memoire", maxout=12000)

# D25-09: Test ExoPlayer - vérifier si audio track absente est la cause
print("\n--- D25-09: ANALYSE PISTE AUDIO ---")
ssh("""
ffprobe -v quiet -print_format json -show_streams /tmp/d25_target.mp4 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
streams=d.get('streams',[])
audio=[s for s in streams if s.get('codec_type')=='audio']
video=[s for s in streams if s.get('codec_type')=='video']
print(f'Pistes video: {len(video)}')
print(f'Pistes audio: {len(audio)}')
if audio:
    a=audio[0]
    print(f'  codec audio: {a.get(\"codec_name\")}')
    print(f'  sample_rate: {a.get(\"sample_rate\")}')
    print(f'  channels   : {a.get(\"channels\")}')
    print(f'  duration   : {a.get(\"duration\")}')
else:
    print('  AUCUNE PISTE AUDIO PRESENTE')
"
""", "analyse audio streams")

# Vérifier si ExoPlayer peut tomber en erreur sur absence audio
ssh("""
echo "=== CHECK CODEC VIDEO DETAILS ==="
ffprobe -v error -show_streams /tmp/d25_target.mp4 2>/dev/null | grep -E 'color_|profile|level|has_b_frames|pix_fmt|width|height|duration|nb_frames|codec_name'
""", "details codec video")

# Verif bitstream VUI (Video Usability Information)
ssh("""
echo "=== ANALYSE VUI BITSTREAM ==="
ffprobe -v verbose /tmp/d25_target.mp4 2>&1 | grep -iE 'color|transfer|primaries|range|profile|level|vui|nal|sps|pps|smpte|bt709' | head -30
""", "analyse VUI bitstream")

c.close()
print("\n\nSSH ferme. Collecte terminee.")
print("Le rapport final D25-10 sera genere a partir de ces donnees.")
