#!/usr/bin/env python3
"""D25 - Part 2: recuperer les donnees manquantes de la premiere execution"""
import sys, json, requests, paramiko
sys.stdout.reconfigure(encoding='utf-8')

RENDER_ID = "07356b0d-ff4c-4ce2-80a9-9e7ec5306367"
MP4_FNAME = "4b636e441c374687935eaecba55661ac.mp4"
MP4_URL   = f"https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/whiteboard-renders/renders/{RENDER_ID}/{MP4_FNAME}"
SUPABASE  = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY      = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}
KAMATERA  = dict(hostname="185.167.97.144", username="root", password="Nexiomgroup@Academia0", timeout=30)

def sql(query):
    r = requests.post(f"{SUPABASE}/rest/v1/rpc/admin_execute_sql", headers=H, json={"sql": query}, timeout=30)
    return r.json()

def ssh_run(c, cmd, timeout=120):
    _, o, e = c.exec_command(cmd, timeout=timeout)
    return o.read().decode(errors='replace'), e.read().decode(errors='replace')

# =============================================================
print("="*70)
print("D25-01 : SUPABASE - METADONNEES COMPLETES")
print("="*70)

q = f"""
SELECT
  rj.id AS render_id,
  rj.project_id,
  rj.status,
  rj.video_url,
  rj.created_at,
  rj.updated_at,
  EXTRACT(EPOCH FROM (rj.updated_at - rj.created_at))::int AS duree_traitement_s,
  wp.subject,
  wp.title AS project_title,
  rj.storyboard_json::text AS storyboard_raw
FROM whiteboard_render_jobs rj
LEFT JOIN whiteboard_projects wp ON wp.id = rj.project_id
WHERE rj.id = '{RENDER_ID}';
"""
res = sql(q)
rows = res.get('rows', [])
storyboard_json = None
nb_scenes = 0

if rows:
    r = rows[0]
    print(f"render_id        : {r.get('render_id')}")
    print(f"project_id       : {r.get('project_id')}")
    print(f"subject          : {r.get('subject')}")
    print(f"project_title    : {r.get('project_title')}")
    print(f"status           : {r.get('status')}")
    print(f"video_url        : {r.get('video_url')}")
    print(f"created_at       : {r.get('created_at')}")
    print(f"updated_at       : {r.get('updated_at')}")
    print(f"duree_traitement : {r.get('duree_traitement_s')} secondes")
    raw = r.get('storyboard_raw', '')
    if raw:
        try:
            storyboard_json = json.loads(raw)
            scenes = storyboard_json.get('scenes', [])
            nb_scenes = len(scenes)
            print(f"nb_scenes        : {nb_scenes}")
            print(f"theme            : {storyboard_json.get('theme','?')}")
            print(f"renderer         : {storyboard_json.get('renderer','?')}")
            print(f"duree_attendue   : {nb_scenes * 5}s ({nb_scenes} scenes x 5s)")
            for i, sc in enumerate(scenes):
                blocs = sc.get('blocks', [])
                print(f"  Scene {i+1}: '{sc.get('title','?')}' — {len(blocs)} bloc(s) — order={sc.get('order','?')}")
                for b in blocs[:3]:
                    print(f"    bloc type={b.get('type','?')} content='{str(b.get('content',''))[:60]}'")
        except Exception as ex:
            print(f"[ERREUR parse storyboard]: {ex}")
else:
    print("ERREUR: render_id non trouve")

print(f"\nURL MP4              : {MP4_URL}")
head = requests.head(MP4_URL, timeout=15)
file_size = int(head.headers.get('content-length', 0))
print(f"Taille (HEAD)        : {file_size} bytes ({file_size/1024:.1f} KB)")
print(f"Content-Type         : {head.headers.get('content-type','?')}")
print(f"HTTP HEAD status     : {head.status_code}")

# =============================================================
print("\n" + "="*70)
print("D25-02 : FFPROBE COMPLET (SSH sur MP4 deja telecharge)")
print("="*70)

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(**KAMATERA)

def ssh(cmd, maxout=10000):
    out, err = ssh_run(c, cmd)
    if out.strip(): print(out[:maxout])
    if err.strip() and 'deprecated' not in err.lower(): print(f"[ERR] {err[:500]}")
    return out

# ffprobe JSON complet
out, _ = ssh_run(c, f"ffprobe -v quiet -print_format json -show_streams -show_format /tmp/d25_target.mp4 2>/dev/null")
try:
    info = json.loads(out)
    fmt = info.get('format', {})
    streams = info.get('streams', [])
    video = [s for s in streams if s.get('codec_type') == 'video']
    audio = [s for s in streams if s.get('codec_type') == 'audio']

    print("\n--- CONTAINER ---")
    tags = fmt.get('tags', {})
    print(f"major_brand        : {tags.get('major_brand','?')}")
    print(f"compatible_brands  : {tags.get('compatible_brands','?')}")
    print(f"encoder (lavf)     : {tags.get('encoder','?')}")
    print(f"duration           : {fmt.get('duration','?')} s")
    print(f"size               : {fmt.get('size','?')} bytes")
    print(f"bit_rate           : {fmt.get('bit_rate','?')} bps")
    print(f"format_name        : {fmt.get('format_name','?')}")

    if video:
        v = video[0]
        vtags = v.get('tags', {})
        print("\n--- STREAM VIDEO ---")
        print(f"codec_name         : {v.get('codec_name','?')}")
        print(f"codec_tag_string   : {v.get('codec_tag_string','?')}")
        print(f"profile            : {v.get('profile','?')}")
        print(f"level              : {v.get('level','?')}")
        print(f"width x height     : {v.get('width','?')} x {v.get('height','?')}")
        print(f"coded_w x coded_h  : {v.get('coded_width','?')} x {v.get('coded_height','?')}")
        print(f"pix_fmt            : {v.get('pix_fmt','?')}")
        print(f"r_frame_rate       : {v.get('r_frame_rate','?')}")
        print(f"avg_frame_rate     : {v.get('avg_frame_rate','?')}")
        print(f"nb_frames          : {v.get('nb_frames','?')}")
        print(f"has_b_frames       : {v.get('has_b_frames','?')}")
        print(f"duration (stream)  : {v.get('duration','?')} s")
        print(f"duration_ts        : {v.get('duration_ts','?')}")
        print(f"time_base          : {v.get('time_base','?')}")
        print(f"color_space        : {v.get('color_space','NON DEFINI')}")
        print(f"color_transfer     : {v.get('color_transfer','NON DEFINI')}")
        print(f"color_primaries    : {v.get('color_primaries','NON DEFINI')}")
        print(f"color_range        : {v.get('color_range','NON DEFINI')}")
        print(f"chroma_location    : {v.get('chroma_location','?')}")
        print(f"field_order        : {v.get('field_order','?')}")
        print(f"encoder (libx264)  : {vtags.get('encoder','?')}")
        print(f"refs               : {v.get('refs','?')}")
        print(f"is_avc             : {v.get('is_avc','?')}")
        print(f"nal_length_size    : {v.get('nal_length_size','?')}")

        dur_reel = float(v.get('duration', 0))
        nb_frames_reel = int(v.get('nb_frames', 0))
        fps_reel = eval(v.get('avg_frame_rate','30/1'))

        print("\n--- D25-04: VALIDATION DUREE ---")
        print(f"ATTENDU :")
        print(f"  nb_scenes        : {nb_scenes}")
        print(f"  secondes/scene   : 5")
        print(f"  duree_totale     : {nb_scenes * 5}s")
        print(f"  nb_frames_attendu: {nb_scenes * 5 * int(fps_reel)}")
        print(f"REEL :")
        print(f"  duration         : {dur_reel:.3f}s")
        print(f"  nb_frames        : {nb_frames_reel}")
        print(f"  fps              : {fps_reel}")
        print(f"ECART :")
        ecart = dur_reel - (nb_scenes * 5) if nb_scenes > 0 else 0
        print(f"  duree_reel - attendu = {ecart:.3f}s")
        if nb_scenes > 0:
            scenes_detectees = dur_reel / 5
            print(f"  scenes_detectees_approx: {scenes_detectees:.1f}")

    print("\n--- STREAM AUDIO ---")
    if audio:
        a = audio[0]
        print(f"codec_audio        : {a.get('codec_name','?')}")
        print(f"sample_rate        : {a.get('sample_rate','?')}")
        print(f"channels           : {a.get('channels','?')}")
        print(f"duration           : {a.get('duration','?')}")
    else:
        print("AUCUNE PISTE AUDIO PRESENTE — 0 streams audio")

except json.JSONDecodeError as e:
    print(f"ERREUR parse ffprobe JSON: {e}")
    print(out[:2000])

# =============================================================
print("\n" + "="*70)
print("D25-03 : STRUCTURE MP4 (depuis fichier local C:\\tmp\\d25_audit.mp4)")
print("="*70)

try:
    with open(r"C:\tmp\d25_audit.mp4", "rb") as f:
        data = f.read()

    import hashlib
    print(f"MD5 local          : {hashlib.md5(data).hexdigest()}")
    print(f"Taille locale      : {len(data)} bytes")

    off, atoms = 0, []
    while off < len(data) - 8:
        sz = int.from_bytes(data[off:off+4], 'big')
        nm = data[off+4:off+8].decode('ascii', errors='?')
        atoms.append((nm, off, sz))
        off += sz
        if sz < 8 or off >= len(data): break

    print(f"\nATOMES TOP-LEVEL:")
    for nm, pos, sz in atoms:
        print(f"  [{nm}]  offset={pos}  taille={sz}")

    names = [a[0] for a in atoms]
    moov_idx = names.index('moov') if 'moov' in names else -1
    mdat_idx = names.index('mdat') if 'mdat' in names else -1
    print(f"\nORDRE             : {' > '.join(names)}")
    print(f"moov index        : {moov_idx}")
    print(f"mdat index        : {mdat_idx}")
    print(f"faststart actif   : {moov_idx < mdat_idx if moov_idx >= 0 and mdat_idx >= 0 else 'INDETERMINE'}")
    major = data[8:12].decode('ascii', errors='?')
    compat = data[16:28].decode('ascii', errors='?')
    print(f"major_brand       : {major}")
    print(f"compatible_brands : {compat}")
except Exception as ex:
    print(f"Fichier local non disponible: {ex}")

# =============================================================
print("\n" + "="*70)
print("D25-05 : TEST DECODAGE FFMPEG (lecture sans affichage)")
print("="*70)
out, err = ssh_run(c, "timeout 30 ffmpeg -v error -i /tmp/d25_target.mp4 -f null - 2>&1 | tail -15")
combined = (out + err).strip()
if combined:
    print(combined[:3000])
else:
    print("SUCCES: Aucune erreur de decodage detectee (stdout+stderr vides)")

# =============================================================
print("\n" + "="*70)
print("D25-06 : WORKER EN MEMOIRE - DETAILS")
print("="*70)
out, _ = ssh_run(c, "systemctl show whiteboard-worker -p MainPID,ActiveEnterTimestamp,ActiveState --value 2>/dev/null")
print(out.strip())
out, _ = ssh_run(c, """
PID=$(systemctl show whiteboard-worker -p MainPID --value 2>/dev/null | tr -d '\n')
echo "PID=$PID"
if [ -n "$PID" ] && [ "$PID" != "0" ]; then
    echo "Demarrage: $(ps -p $PID -o lstart= 2>/dev/null)"
    echo "Uptime: $(ps -p $PID -o etime= 2>/dev/null)"
fi
echo "Fichier assembler:"
stat /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py 2>/dev/null | grep -E 'File:|Modify:|Size:'
echo "MD5 assembler:"
md5sum /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py
echo "Header assembler:"
head -5 /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py
""")
print(out.strip())

out, _ = ssh_run(c, "ls -la /opt/whiteboard-worker/__pycache__/ 2>/dev/null || echo 'Pas de pycache'")
print("\nPYCACHE:")
print(out.strip())

# =============================================================
print("\n" + "="*70)
print("D25-07 : LOGS WORKER POUR CE RENDER")
print("="*70)
out, _ = ssh_run(c, f"journalctl -u whiteboard-worker --no-pager 2>/dev/null | grep -B1 -A6 '{RENDER_ID[:12]}'")
if out.strip():
    print(out[:5000])
else:
    print("Aucun log trouve pour ce render_id - cherche les renders recents:")
    out2, _ = ssh_run(c, "journalctl -u whiteboard-worker --no-pager --since '2026-06-29 07:00' 2>/dev/null | grep -E 'Processing|Assembling|Uploading|completed|error|ERROR' | head -30")
    print(out2[:3000])

# =============================================================
print("\n" + "="*70)
print("D25-07 : RESTART TIMESTAMP vs RENDER TIMESTAMP")
print("="*70)
out, _ = ssh_run(c, """
echo "=== Restart worker (v6) ==="
systemctl show whiteboard-worker -p ActiveEnterTimestamp --value
echo ""
echo "=== Derniers renders traites ==="
journalctl -u whiteboard-worker --no-pager --since '2026-06-29 06:00' 2>/dev/null | grep 'Processing job' | tail -10
""")
print(out.strip())

c.close()
print("\n\n=== COLLECTE D25 COMPLETE ===")
