"""
Mission D.26 — Collecte forensique Phase 2
- Récupère le dernier render via admin_execute_sql
- Télécharge le MP4 sur Kamatera
- Exécute ffprobe streams, format, packets, VUI, decode check
- Analyse TTS dans sources + logs
Lecture seule — aucune modification
"""
import subprocess, json, sys, os

KAMATERA_HOST = "185.167.97.144"
KAMATERA_USER = "root"
KAMATERA_PASS = "Nexiomgroup@Academia0"
SUPABASE_URL  = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SUPABASE_KEY  = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0OTY1NDA5NSwiZXhwIjoyMDY1MjMwMDk1fQ.3vTqFMsB3OXYoNV2FTKA0pxEEJlg3AJH6E-i_Ogyp74"

def ssh(cmd, timeout=120):
    import paramiko
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(KAMATERA_HOST, username=KAMATERA_USER, password=KAMATERA_PASS, timeout=20)
    _, stdout, stderr = client.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode(errors="replace")
    err = stderr.read().decode(errors="replace")
    client.close()
    return out, err

def supa_rpc(fn, payload):
    import urllib.request
    url = f"{SUPABASE_URL}/rest/v1/rpc/{fn}"
    data = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, method="POST", headers={
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
    })
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())

results = {}

# ─── STEP 1: Dernier render via admin_execute_sql ─────────────────────────────
print("=" * 60)
print("STEP 1 — Dernier render (admin_execute_sql)")
print("=" * 60)
try:
    resp = supa_rpc("admin_execute_sql", {
        "query": "SELECT id, project_id, status, video_url, duration_ms, created_at FROM app.whiteboard_renders WHERE status='done' AND video_url IS NOT NULL ORDER BY created_at DESC LIMIT 3"
    })
    print(json.dumps(resp, indent=2, ensure_ascii=False))
    results["supabase_renders"] = resp

    # Extraire le premier render
    if isinstance(resp, list) and resp:
        row = resp[0]
        video_url = row.get("video_url") or (row.get("result") and json.loads(row["result"])[0].get("video_url"))
    elif isinstance(resp, dict) and "result" in resp:
        parsed = json.loads(resp["result"])
        row = parsed[0] if parsed else {}
        video_url = row.get("video_url", "")
    else:
        video_url = ""
    print(f"\nvideo_url sélectionnée : {video_url}")
except Exception as e:
    print(f"ERREUR Supabase: {e}")
    # Fallback: utiliser le render connu de D25
    video_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/whiteboard-renders/renders/ad74ed9e-2133-4c79-9a84-29b33d9d8fb3/output.mp4"
    print(f"FALLBACK video_url: {video_url}")

# Tenter de récupérer la vraie URL depuis le bucket
try:
    resp2 = supa_rpc("admin_execute_sql", {
        "query": "SELECT id, video_url, duration_ms, created_at FROM app.whiteboard_renders WHERE video_url IS NOT NULL ORDER BY created_at DESC LIMIT 1"
    })
    print("\nRender unique:")
    print(json.dumps(resp2, indent=2, ensure_ascii=False))
    results["supabase_render_single"] = resp2
except Exception as e:
    print(f"Erreur render single: {e}")

# ─── STEP 2: Recherche URL réelle dans Supabase Storage ──────────────────────
print("\n" + "=" * 60)
print("STEP 2 — Recherche storage objects")
print("=" * 60)
try:
    resp3 = supa_rpc("admin_execute_sql", {
        "query": "SELECT name, metadata FROM storage.objects WHERE bucket_id='whiteboard-renders' ORDER BY created_at DESC LIMIT 5"
    })
    print(json.dumps(resp3, indent=2, ensure_ascii=False))
    results["storage_objects"] = resp3
except Exception as e:
    print(f"Erreur storage: {e}")

# ─── STEP 3: SSH — Tout le forensique sur Kamatera ───────────────────────────
print("\n" + "=" * 60)
print("STEP 3 — SSH Kamatera: download + ffprobe complet")
print("=" * 60)

# Construire l'URL publique correcte depuis le path storage
# Tenter de récupérer depuis Supabase d'abord
try:
    resp4 = supa_rpc("admin_execute_sql", {
        "query": """
SELECT 
  wr.id,
  wr.video_url,
  wr.duration_ms,
  wr.status,
  wr.created_at
FROM app.whiteboard_renders wr
WHERE wr.status = 'done'
ORDER BY wr.created_at DESC
LIMIT 1
"""
    })
    results["final_render"] = resp4
    print("Render final:", json.dumps(resp4, indent=2, ensure_ascii=False))
    # Extraire video_url
    if isinstance(resp4, list) and resp4:
        video_url = resp4[0].get("video_url", video_url)
    elif isinstance(resp4, dict):
        raw = resp4.get("result", "[]")
        parsed = json.loads(raw) if isinstance(raw, str) else raw
        if parsed:
            video_url = parsed[0].get("video_url", video_url)
except Exception as e:
    print(f"Erreur final render: {e}")

print(f"\n>>> VIDEO URL UTILISÉE: {video_url}")
results["video_url_used"] = video_url

# Script SSH complet
ssh_full = f"""#!/bin/bash
set -x
MP4_URL="{video_url}"
MP4=/tmp/d26_target.mp4

echo "=== DOWNLOAD MP4 ==="
curl -sL -o "$MP4" "$MP4_URL" 2>&1
FS=$(stat -c%s "$MP4" 2>/dev/null || echo 0)
echo "File size: $FS bytes"
if [ "$FS" -lt 1000 ]; then
    echo "ERROR: MP4 too small, download failed"
    echo "HTTP check:"
    curl -sI "$MP4_URL" | head -5
    exit 1
fi
md5sum "$MP4"

echo ""
echo "=== FFPROBE ALL STREAMS JSON ==="
ffprobe -v quiet -print_format json -show_streams "$MP4" 2>&1

echo ""
echo "=== FFPROBE FORMAT JSON ==="
ffprobe -v quiet -print_format json -show_format "$MP4" 2>&1

echo ""
echo "=== FFPROBE AUDIO ONLY ==="
ffprobe -v quiet -print_format json -show_streams -select_streams a "$MP4" 2>&1

echo ""
echo "=== FFPROBE VIDEO ONLY ==="
ffprobe -v quiet -print_format json -show_streams -select_streams v "$MP4" 2>&1

echo ""
echo "=== FFPROBE VERBOSE VUI ==="
ffprobe -v verbose "$MP4" 2>&1 | head -60

echo ""
echo "=== FFMPEG DECODE ERROR CHECK ==="
ffmpeg -v error -i "$MP4" -f null - 2>&1
echo "DECODE_EXIT=$?"

echo ""
echo "=== MP4 ATOMS ==="
python3 << 'PYEOF'
import sys
data = open('/tmp/d26_target.mp4','rb').read()
off = 0
print(f"Total bytes: {{len(data)}}")
depth = 0
containers = {{b'moov',b'trak',b'mdia',b'minf',b'stbl',b'edts',b'dinf',b'udta'}}
while off < len(data) - 8 and depth < 3:
    sz = int.from_bytes(data[off:off+4],'big')
    nm = data[off+4:off+8]
    try:
        name = nm.decode('ascii')
    except:
        name = '????'
    print(f"  [{{name}}] offset={{off}} size={{sz}}")
    if sz < 8 or off + sz > len(data):
        break
    if nm in containers:
        # one level deep
        sub_off = off + 8
        sub_end = off + sz
        while sub_off < sub_end - 8:
            sz2 = int.from_bytes(data[sub_off:sub_off+4],'big')
            nm2 = data[sub_off+4:sub_off+8].decode('ascii',errors='?')
            print(f"    [{{nm2}}] offset={{sub_off}} size={{sz2}}")
            if sz2 < 8: break
            sub_off += sz2
    off += sz
PYEOF

echo ""
echo "=== VIDEO PACKETS FIRST 50 ==="
ffprobe -v quiet -print_format json -show_packets -select_streams v -read_intervals "%+#50" "$MP4" 2>&1 | python3 << 'PYEOF'
import sys, json
try:
    d = json.load(sys.stdin)
    pkts = d.get('packets', [])
    print(f"Total video packets in sample: {{len(pkts)}}")
    if pkts:
        times = [float(p.get('pts_time', 0)) for p in pkts]
        errors = []
        for i in range(1, len(times)):
            if times[i] < times[i-1]:
                errors.append(f"REGRESSION pkt {{i}}: {{times[i-1]:.4f}} -> {{times[i]:.4f}}")
        print(f"PTS monotone: {{'YES' if not errors else 'NO'}}")
        for e in errors: print(f"  {e}")
        kf = [p for p in pkts if 'K' in p.get('flags','')]
        print(f"Keyframes: {{len(kf)}} / {{len(pkts)}}")
        if len(kf) > 1:
            ktimes = [float(p.get('pts_time',0)) for p in kf]
            gaps = [ktimes[i]-ktimes[i-1] for i in range(1, len(ktimes))]
            print(f"GOP avg: {{sum(gaps)/len(gaps):.3f}}s  min={{min(gaps):.3f}}s  max={{max(gaps):.3f}}s")
        # print first 10
        for p in pkts[:10]:
            print(f"  pkt pts={{p.get('pts_time','?'):8s}} dts={{p.get('dts_time','?'):8s}} dur={{p.get('duration_time','?'):6s}} flags={{p.get('flags','?')}}")
except Exception as ex:
    print(f"Parse error: {{ex}}")
PYEOF

echo ""
echo "=== AUDIO PACKETS FIRST 30 ==="
ffprobe -v quiet -print_format json -show_packets -select_streams a -read_intervals "%+#30" "$MP4" 2>&1 | python3 << 'PYEOF'
import sys, json
try:
    d = json.load(sys.stdin)
    pkts = d.get('packets', [])
    print(f"Total audio packets in sample: {{len(pkts)}}")
    for p in pkts[:10]:
        print(f"  pkt pts={{p.get('pts_time','?'):8s}} dur={{p.get('duration_time','?'):6s}} size={{p.get('size','?')}}")
except Exception as ex:
    print(f"Parse error: {{ex}}")
PYEOF

echo ""
echo "=== TTS GREP IN LOGS ==="
journalctl -u whiteboard-worker -n 1000 --no-pager 2>/dev/null | grep -iE "tts|gtts|piper|espeak|wav|narrat|audio|mp3|speech" | head -30 || echo "[NO TTS IN LOGS]"

echo ""
echo "=== TTS GREP IN SOURCES ==="
grep -rn "tts\\|gtts\\|piper\\|espeak\\|generate_tts\\|narrat\\|speech\\|audio_path\\|wav\\|mp3" /opt/whiteboard-worker/ 2>/dev/null || echo "[NO TTS IN SOURCES]"

echo ""
echo "=== TTS PACKAGES ==="
pip3 list 2>/dev/null | grep -iE "gtts|tts|piper|espeak|kokoro" || echo "[NO TTS PACKAGES]"
python3 -c "import gtts; print('gtts: INSTALLED')" 2>/dev/null || echo "gtts: NOT INSTALLED"
which espeak piper 2>/dev/null || echo "espeak/piper: NOT FOUND"

echo ""
echo "=== WORKER LOGS LAST 100 ==="
journalctl -u whiteboard-worker -n 100 --no-pager 2>/dev/null

echo ""
echo "=== WORKER FILES ==="
ls -la /opt/whiteboard-worker/
echo ""
md5sum /opt/whiteboard-worker/*.py 2>/dev/null
"""

print("Exécution SSH forensique complète...")
out, err = ssh(ssh_full, timeout=180)
print("STDOUT:")
print(out[:8000])
if err.strip():
    print("STDERR:", err[:2000])
results["ssh_forensic"] = {"out": out, "err": err}

# ─── SAVE ─────────────────────────────────────────────────────────────────────
out_path = r"C:\Users\fasop\AndroidStudioProjects\academia\.windsurf\d26_raw2.json"
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False, default=str)
print(f"\nSauvegardé : {out_path}")
print("COLLECTE D26 TERMINÉE")
