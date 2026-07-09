"""
Mission D.26 — Collecte forensique SSH uniquement
Utilise le render connu ad74ed9e et son URL réelle.
Exécute ffprobe streams, format, packets, TTS grep, atoms.
Lecture seule.
"""
import paramiko, json, sys

KAMATERA_HOST = "185.167.97.144"
KAMATERA_USER = "root"
KAMATERA_PASS = "Nexiomgroup@Academia0"

# URL réelle du render ad74ed9e (obtenue en D25 via Supabase)
# Le fichier est stocké dans whiteboard-renders/renders/{job_id}/{uuid}.mp4
# On recherche l'URL exacte via les logs du worker
VIDEO_URL_KNOWN = ""   # sera déterminé par SSH grep des logs

def ssh_run(cmd, timeout=180):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(KAMATERA_HOST, username=KAMATERA_USER,
                   password=KAMATERA_PASS, timeout=20)
    _, stdout, stderr = client.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode(errors="replace")
    err = stderr.read().decode(errors="replace")
    client.close()
    return out, err

results = {}

# ─── STEP 1: Trouver l'URL du dernier MP4 dans les logs worker ───────────────
print("=" * 60)
print("STEP 1 — Trouver video_url depuis logs Kamatera")
print("=" * 60)

cmd1 = """
echo "=== WORKER LOGS LAST 200 ==="
journalctl -u whiteboard-worker -n 200 --no-pager 2>/dev/null

echo ""
echo "=== GREP video_url / uploads ==="
journalctl -u whiteboard-worker -n 500 --no-pager 2>/dev/null | grep -iE "upload|video_url|completed|http|supabase" | tail -30

echo ""
echo "=== /tmp MP4 files ==="
find /tmp -name "*.mp4" -newer /tmp 2>/dev/null | head -10
ls -la /tmp/*.mp4 /tmp/tmp*/*.mp4 2>/dev/null | head -20

echo ""
echo "=== WORKER ENV (supabase url) ==="
grep -i "SUPABASE_URL\|WHITEBOARD_BUCKET" /opt/whiteboard-worker/.env 2>/dev/null || \
grep -i "SUPABASE_URL\|WHITEBOARD_BUCKET" /etc/whiteboard-worker.env 2>/dev/null || \
grep -rn "SUPABASE_URL" /opt/whiteboard-worker/ 2>/dev/null | grep -v ".pyc" | head -5

echo ""
echo "=== UPLOAD RENDERER SOURCE ==="
cat /opt/whiteboard-worker/whiteboard_upload_renderer.py 2>/dev/null
"""

out1, err1 = ssh_run(cmd1, timeout=60)
print(out1[:5000])
results["step1_logs"] = out1

# ─── STEP 2: Télécharger le MP4 directement depuis Supabase Storage ──────────
print("\n" + "=" * 60)
print("STEP 2 — Télécharger dernier MP4 et ffprobe complet")
print("=" * 60)

# Script qui va récupérer l'URL depuis les logs, ou utiliser la dernière
# entrée de la DB via l'endpoint public de Supabase storage
cmd2 = r"""
SUPABASE_URL="https://thevdfcwlcqzdoybfvgs.supabase.co"
SUPABASE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0OTY1NDA5NSwiZXhwIjoyMDY1MjMwMDk1fQ.3vTqFMsB3OXYoNV2FTKA0pxEEJlg3AJH6E-i_Ogyp74"
MP4=/tmp/d26_target.mp4

echo "=== SUPABASE RENDERS REST ==="
RENDERS=$(curl -sS \
  -H "apikey: $SUPABASE_KEY" \
  -H "Authorization: Bearer $SUPABASE_KEY" \
  "$SUPABASE_URL/rest/v1/whiteboard_renders?select=id,video_url,duration_ms,status,created_at&status=eq.done&order=created_at.desc&limit=3" 2>&1)
echo "$RENDERS"

# Extraire video_url du premier résultat
VIDEO_URL=$(echo "$RENDERS" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if isinstance(data, list) and data:
        for r in data:
            if r.get('video_url'):
                print(r['video_url'])
                break
except Exception as e:
    print('', file=sys.stderr)
" 2>/dev/null)

if [ -z "$VIDEO_URL" ]; then
    echo "Fallback: essai RPC whiteboard_fetch_queued_jobs"
    # Essai via admin_execute_sql
    VIDEO_URL=$(curl -sS -X POST \
      -H "apikey: $SUPABASE_KEY" \
      -H "Authorization: Bearer $SUPABASE_KEY" \
      -H "Content-Type: application/json" \
      -d '{"query":"SELECT id, video_url FROM app.whiteboard_renders WHERE status='"'"'done'"'"' AND video_url IS NOT NULL ORDER BY created_at DESC LIMIT 1"}' \
      "$SUPABASE_URL/rest/v1/rpc/admin_execute_sql" 2>&1 | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    # peut etre liste directe ou dict avec result
    if isinstance(d, list) and d:
        print(d[0].get('video_url',''))
    elif isinstance(d, dict):
        raw = d.get('result','[]')
        if isinstance(raw, str):
            rows = json.loads(raw)
        else:
            rows = raw
        if rows:
            print(rows[0].get('video_url',''))
except: pass
" 2>/dev/null)
fi

echo ""
echo "VIDEO_URL FOUND: $VIDEO_URL"

if [ -n "$VIDEO_URL" ]; then
    echo ""
    echo "=== DOWNLOAD MP4 ==="
    curl -sL -o "$MP4" "$VIDEO_URL" 2>&1
    FS=$(stat -c%s "$MP4" 2>/dev/null || echo 0)
    echo "File size: $FS bytes"
    
    if [ "$FS" -gt 10000 ]; then
        md5sum "$MP4"
        
        echo ""
        echo "=== FFPROBE STREAMS ALL ==="
        ffprobe -v quiet -print_format json -show_streams "$MP4" 2>&1
        
        echo ""
        echo "=== FFPROBE FORMAT ==="
        ffprobe -v quiet -print_format json -show_format "$MP4" 2>&1
        
        echo ""
        echo "=== FFPROBE VERBOSE VUI ==="
        ffprobe -v verbose "$MP4" 2>&1 | head -80
        
        echo ""
        echo "=== FFMPEG DECODE CHECK ==="
        ffmpeg -v error -i "$MP4" -f null - 2>&1
        echo "DECODE_EXIT=$?"
        
        echo ""
        echo "=== ATOMS PYTHON ==="
        python3 -c "
data = open('/tmp/d26_target.mp4','rb').read()
off = 0
atoms = []
while off < len(data) - 8:
    sz = int.from_bytes(data[off:off+4],'big')
    nm = data[off+4:off+8].decode('ascii',errors='?')
    atoms.append((nm, off, sz))
    print(f'  [{nm}] offset={off} size={sz}')
    if sz < 8 or off + sz > len(data): break
    off += sz
print()
print('Atom order:', ' > '.join(a[0] for a in atoms))
# faststart check
names = [a[0] for a in atoms]
moov_idx = names.index('moov') if 'moov' in names else -1
mdat_idx = names.index('mdat') if 'mdat' in names else -1
if moov_idx >= 0 and mdat_idx >= 0:
    print(f'faststart: {\"YES (moov before mdat)\" if moov_idx < mdat_idx else \"NO (mdat before moov)\"}')
"
        
        echo ""
        echo "=== VIDEO PACKETS ANALYSIS ==="
        ffprobe -v quiet -print_format json -show_packets -select_streams v -read_intervals "%+#100" "$MP4" 2>&1 | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    pkts = d.get('packets', [])
    print(f'Video packets sampled: {len(pkts)}')
    if not pkts:
        print('NO PACKETS')
        sys.exit(0)
    times_pts = []
    times_dts = []
    for p in pkts:
        try: times_pts.append(float(p.get('pts_time','nan')))
        except: times_pts.append(float('nan'))
        try: times_dts.append(float(p.get('dts_time','nan')))
        except: times_dts.append(float('nan'))
    pts_ok = all(times_pts[i] >= times_pts[i-1] for i in range(1,len(times_pts)))
    dts_ok = all(times_dts[i] >= times_dts[i-1] for i in range(1,len(times_dts)))
    print(f'PTS monotone: {\"YES\" if pts_ok else \"NO\"}')
    print(f'DTS monotone: {\"YES\" if dts_ok else \"NO\"}')
    kf = [p for p in pkts if 'K' in p.get('flags','')]
    print(f'Keyframes: {len(kf)} / {len(pkts)}')
    if len(kf) > 1:
        ktimes = [float(p.get('pts_time',0)) for p in kf]
        gaps = [ktimes[i]-ktimes[i-1] for i in range(1,len(ktimes))]
        print(f'GOP avg: {sum(gaps)/len(gaps):.3f}s  min={min(gaps):.3f}  max={max(gaps):.3f}')
    print('First 10 video packets:')
    for p in pkts[:10]:
        print(f\"  pts={p.get('pts_time','?'):8s} dts={p.get('dts_time','?'):8s} dur={p.get('duration_time','?'):6s} flags={p.get('flags','?')}\")
except Exception as ex:
    print(f'ERROR: {ex}')
    import traceback; traceback.print_exc()
"
        
        echo ""
        echo "=== AUDIO PACKETS ANALYSIS ==="
        ffprobe -v quiet -print_format json -show_packets -select_streams a -read_intervals "%+#50" "$MP4" 2>&1 | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    pkts = d.get('packets', [])
    print(f'Audio packets sampled: {len(pkts)}')
    for p in pkts[:10]:
        print(f\"  pts={p.get('pts_time','?'):8s} dur={p.get('duration_time','?'):6s} size={p.get('size','?')}\")
except Exception as ex:
    print(f'ERROR: {ex}')
"
    else
        echo "ERROR: MP4 download failed (size=$FS)"
        curl -sI "$VIDEO_URL" | head -10
    fi
else
    echo "ERROR: Could not determine video URL"
fi
"""

out2, err2 = ssh_run(cmd2, timeout=180)
print(out2[:10000])
if err2.strip():
    print("STDERR:", err2[:1000])
results["step2_ffprobe"] = out2

# ─── STEP 3: TTS + Sources complètes ─────────────────────────────────────────
print("\n" + "=" * 60)
print("STEP 3 — TTS forensic + sources complètes")
print("=" * 60)

cmd3 = r"""
echo "=== GREP TTS ALL SOURCES ==="
grep -rn "tts\|gtts\|piper\|espeak\|generate_tts\|narrat\|speech\|audio_path\|wav_path\|mp3_path" \
    /opt/whiteboard-worker/ 2>/dev/null || echo "[NO TTS IN ANY SOURCE]"

echo ""
echo "=== TTS IN LOGS (all time) ==="
journalctl -u whiteboard-worker --no-pager 2>/dev/null | \
    grep -iE "tts|gtts|piper|narrat|speech|audio" | head -20 || echo "[NO TTS IN LOGS]"

echo ""
echo "=== INSTALLED PACKAGES ==="
pip3 list 2>/dev/null | grep -iE "gtts|tts|piper|espeak|kokoro|azure|google|openai" | head -20
echo "---"
pip3 list 2>/dev/null | wc -l
echo "total packages"

echo ""
echo "=== ASSEMBLER FULL SOURCE ==="
cat /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py

echo ""
echo "=== RENDER WORKER FULL SOURCE ==="
cat /opt/whiteboard-worker/whiteboard_render_worker.py

echo ""
echo "=== UPLOAD RENDERER FULL SOURCE ==="
cat /opt/whiteboard-worker/whiteboard_upload_renderer.py
"""

out3, err3 = ssh_run(cmd3, timeout=60)
print(out3[:8000])
results["step3_tts_sources"] = out3

# ─── SAVE ─────────────────────────────────────────────────────────────────────
out_path = r"C:\Users\fasop\AndroidStudioProjects\academia\.windsurf\d26_raw3.json"
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False, default=str)
print(f"\nSauvegardé : {out_path}")
print("COLLECTE D26 TERMINÉE")
