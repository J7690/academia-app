"""
Mission D.26 — Collecte forensique complète
Phases 1, 2, 3, 4 : audio streams, packets, timestamps, logs TTS, source code
Lecture seule — aucune modification
"""
import subprocess
import json
import sys
import os
import tempfile
import urllib.request

# ─── CONFIG ───────────────────────────────────────────────────────────────────
KAMATERA_HOST = "185.167.97.144"
KAMATERA_USER = "root"
KAMATERA_PASS = "Nexiomgroup@Academia0"
SUPABASE_URL  = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SUPABASE_KEY  = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0OTY1NDA5NSwiZXhwIjoyMDY1MjMwMDk1fQ.3vTqFMsB3OXYoNV2FTKA0pxEEJlg3AJH6E-i_Ogyp74"

# ─── SSH HELPER ───────────────────────────────────────────────────────────────
def ssh(cmd, timeout=90):
    try:
        import paramiko
    except ImportError:
        return "[paramiko not available]"
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(KAMATERA_HOST, username=KAMATERA_USER, password=KAMATERA_PASS, timeout=20)
        _, stdout, stderr = client.exec_command(cmd, timeout=timeout)
        out = stdout.read().decode(errors="replace")
        err = stderr.read().decode(errors="replace")
        client.close()
        return out + err
    except Exception as e:
        return f"[SSH ERROR: {e}]"

# ─── SUPABASE HELPER ──────────────────────────────────────────────────────────
def supa_rpc(fn, payload):
    import urllib.request, json
    url = f"{SUPABASE_URL}/rest/v1/rpc/{fn}"
    data = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, method="POST", headers={
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read())
    except Exception as e:
        return {"error": str(e)}

def supa_get(path, params=""):
    import urllib.request, json
    url = f"{SUPABASE_URL}/rest/v1/{path}?{params}"
    req = urllib.request.Request(url, headers={
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
    })
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read())
    except Exception as e:
        return {"error": str(e)}

# ─── MAIN ─────────────────────────────────────────────────────────────────────
results = {}

print("=" * 60)
print("PHASE 1A — Récupération dernier render depuis Supabase")
print("=" * 60)

renders = supa_get(
    "whiteboard_renders",
    "select=id,project_id,status,video_url,duration_ms,created_at&order=created_at.desc&limit=3"
)
print(json.dumps(renders, indent=2, ensure_ascii=False))
results["latest_renders"] = renders

# Prendre le dernier render avec video_url
latest = None
if isinstance(renders, list):
    for r in renders:
        if r.get("video_url"):
            latest = r
            break

if latest:
    print(f"\nRender sélectionné : {latest['id']}")
    print(f"URL : {latest['video_url']}")
    results["selected_render"] = latest
else:
    print("ERREUR : aucun render avec video_url trouvé")
    results["selected_render"] = None

print("\n" + "=" * 60)
print("PHASE 1B — Téléchargement MP4 sur Kamatera + ffprobe complet")
print("=" * 60)

if latest and latest.get("video_url"):
    video_url = latest["video_url"]

    # Script SSH complet exécuté sur Kamatera
    ssh_script = f"""
set -e
cd /tmp
MP4_URL="{video_url}"
MP4_FILE="/tmp/d26_target.mp4"

echo "=== DOWNLOAD ==="
curl -sL -o "$MP4_FILE" "$MP4_URL"
echo "Downloaded: $(stat -c%s $MP4_FILE) bytes"

echo ""
echo "=== FFPROBE STREAMS JSON ==="
ffprobe -v quiet -print_format json -show_streams "$MP4_FILE" 2>/dev/null

echo ""
echo "=== FFPROBE FORMAT JSON ==="
ffprobe -v quiet -print_format json -show_format "$MP4_FILE" 2>/dev/null

echo ""
echo "=== FFPROBE AUDIO STREAMS ONLY ==="
ffprobe -v quiet -print_format json -show_streams -select_streams a "$MP4_FILE" 2>/dev/null

echo ""
echo "=== FFPROBE VIDEO STREAMS ONLY ==="
ffprobe -v quiet -print_format json -show_streams -select_streams v "$MP4_FILE" 2>/dev/null
"""
    out = ssh(ssh_script, timeout=120)
    print(out)
    results["phase1b_ffprobe"] = out

print("\n" + "=" * 60)
print("PHASE 1C — Analyse packets (PTS/DTS/keyframes) — ffprobe -show_packets")
print("=" * 60)

ssh_packets = """
MP4_FILE="/tmp/d26_target.mp4"
echo "=== FIRST 30 VIDEO PACKETS ==="
ffprobe -v quiet -print_format json -show_packets -select_streams v -read_intervals "%+#30" "$MP4_FILE" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
pkts = d.get('packets', [])
for i, p in enumerate(pkts):
    print(f\\"pkt {i:3d}: pts={p.get('pts_time','?'):10s} dts={p.get('dts_time','?'):10s} dur={p.get('duration_time','?'):8s} key={p.get('flags','?')}\\" )
print(f'Total packets in sample: {len(pkts)}')
"

echo ""
echo "=== FIRST 30 AUDIO PACKETS ==="
ffprobe -v quiet -print_format json -show_packets -select_streams a -read_intervals "%+#30" "$MP4_FILE" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
pkts = d.get('packets', [])
for i, p in enumerate(pkts):
    print(f\\"pkt {i:3d}: pts={p.get('pts_time','?'):10s} dts={p.get('dts_time','?'):10s} dur={p.get('duration_time','?'):8s} size={p.get('size','?')}\\" )
print(f'Total packets in sample: {len(pkts)}')
"

echo ""
echo "=== PTS MONOTONY CHECK (video, first 100 packets) ==="
ffprobe -v quiet -print_format json -show_packets -select_streams v -read_intervals "%+#100" "$MP4_FILE" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
pkts = d.get('packets', [])
times = [float(p.get('pts_time', 0)) for p in pkts]
errors = []
for i in range(1, len(times)):
    if times[i] < times[i-1]:
        errors.append(f'PTS regression at packet {i}: {times[i-1]:.4f} -> {times[i]:.4f}')
print(f'Packets checked: {len(times)}')
print(f'PTS monotone: {\"YES\" if not errors else \"NO\"}')
for e in errors:
    print(f'  ERROR: {e}')
keyframes = [p for p in pkts if 'K' in p.get('flags','')]
print(f'Keyframes in first 100: {len(keyframes)}')
if keyframes:
    kf_times = [float(p.get('pts_time', 0)) for p in keyframes]
    gaps = [kf_times[i]-kf_times[i-1] for i in range(1, len(kf_times))]
    if gaps:
        print(f'GOP size avg: {sum(gaps)/len(gaps):.3f}s')
"
"""
out_pkts = ssh(ssh_packets, timeout=120)
print(out_pkts)
results["phase3_packets"] = out_pkts

print("\n" + "=" * 60)
print("PHASE 1D — Recherche TTS dans logs, fichiers et code source")
print("=" * 60)

ssh_tts = """
echo "=== GREP TTS IN WORKER LOGS (last 500 lines) ==="
journalctl -u whiteboard-worker -n 500 --no-pager 2>/dev/null | grep -iE "tts|gtts|piper|espeak|wav|narrat|audio|mp3|generate_tts|speech" || echo "[AUCUN MATCH TTS DANS LES LOGS]"

echo ""
echo "=== GREP TTS IN WORKER SOURCE FILES ==="
grep -rn "tts\\|gtts\\|piper\\|espeak\\|generate_tts\\|narrat\\|speech\\|audio_path\\|wav\\|mp3" /opt/whiteboard-worker/ 2>/dev/null || echo "[AUCUN MATCH TTS DANS LES SOURCES]"

echo ""
echo "=== LIST ALL PYTHON FILES IN WORKER DIR ==="
ls -la /opt/whiteboard-worker/*.py 2>/dev/null

echo ""
echo "=== GREP FOR AUDIO IN ASSEMBLER ==="
grep -n "audio\\|aac\\|anullsrc\\|lavfi\\|c:a\\|b:a\\|-an\\|narrat" /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py 2>/dev/null

echo ""
echo "=== GREP FOR AUDIO IN RENDER WORKER ==="
grep -n "audio\\|tts\\|gtts\\|narrat\\|wav\\|mp3\\|aac\\|speech" /opt/whiteboard-worker/whiteboard_render_worker.py 2>/dev/null

echo ""
echo "=== CHECK FOR TTS PACKAGES ==="
pip3 show gtts piper-tts espeak kokoro TTS 2>/dev/null || echo "[gtts/piper not installed]"
python3 -c "import gtts; print('gtts OK')" 2>/dev/null || echo "gtts: NOT INSTALLED"
python3 -c "import TTS; print('TTS OK')" 2>/dev/null || echo "TTS: NOT INSTALLED"
which espeak 2>/dev/null || echo "espeak: NOT FOUND"
which piper 2>/dev/null || echo "piper: NOT FOUND"

echo ""
echo "=== FFMPEG AUDIO GENERATORS AVAILABLE ==="
ffmpeg -filters 2>/dev/null | grep -iE "anullsrc|sine|aevalsrc|lavfi" | head -20
"""
out_tts = ssh(ssh_tts, timeout=90)
print(out_tts)
results["phase1d_tts"] = out_tts

print("\n" + "=" * 60)
print("PHASE 1E — VUI verbose ffprobe (colorspace, levels, bitstream)")
print("=" * 60)

ssh_vui = """
MP4_FILE="/tmp/d26_target.mp4"

echo "=== FFPROBE VERBOSE (VUI headers) ==="
ffprobe -v verbose "$MP4_FILE" 2>&1 | head -80

echo ""
echo "=== ATOMS STRUCTURE ==="
python3 -c "
data = open('$MP4_FILE', 'rb').read()
off = 0
print('ATOM STRUCTURE:')
while off < len(data) - 8:
    sz = int.from_bytes(data[off:off+4], 'big')
    nm = data[off+4:off+8].decode('ascii', errors='?')
    print(f'  [{nm}] offset={off} size={sz}')
    if sz < 8 or sz > len(data): break
    off += sz
"

echo ""
echo "=== FFMPEG DECODE ERROR CHECK ==="
ffmpeg -v error -i "$MP4_FILE" -f null - 2>&1 | head -50
echo "exit_code=$?"

echo ""
echo "=== FILE SIZE + MD5 ==="
stat -c"%s bytes" "$MP4_FILE"
md5sum "$MP4_FILE"
"""
out_vui = ssh(ssh_vui, timeout=90)
print(out_vui)
results["phase1e_vui"] = out_vui

print("\n" + "=" * 60)
print("PHASE 2 — Grep ExoPlayer compatibility: concat.txt content")
print("=" * 60)

ssh_concat = """
echo "=== LAST GENERATED CONCAT.TXT (from /tmp) ==="
ls -lt /tmp/tmp*/concat.txt 2>/dev/null | head -5
LATEST_CONCAT=$(ls -t /tmp/tmp*/concat.txt 2>/dev/null | head -1)
if [ -n "$LATEST_CONCAT" ]; then
    cat "$LATEST_CONCAT"
    echo "lines: $(wc -l < $LATEST_CONCAT)"
else
    echo "[No concat.txt found in /tmp/tmp*]"
fi

echo ""
echo "=== FULL ASSEMBLER SOURCE (CURRENT ON DISK) ==="
cat /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py

echo ""
echo "=== FULL RENDER WORKER SOURCE ==="
cat /opt/whiteboard-worker/whiteboard_render_worker.py
"""
out_concat = ssh(ssh_concat, timeout=60)
print(out_concat)
results["phase2_sources"] = out_concat

print("\n" + "=" * 60)
print("SAUVEGARDE JSON")
print("=" * 60)

out_path = r"C:\Users\fasop\AndroidStudioProjects\academia\.windsurf\d26_raw_data.json"
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False, default=str)
print(f"Sauvegardé : {out_path}")
print("\nCOLLECTE TERMINÉE")
