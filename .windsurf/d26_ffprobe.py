"""D26 — ffprobe complet du MP4 ad74ed9e sur Kamatera"""
import paramiko, json

H, U, P = "185.167.97.144", "root", "Nexiomgroup@Academia0"
URL = "https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/whiteboard-renders/renders/ad74ed9e-2133-4c79-9a84-29b33d9d8fb3/30258deac6114b89a2fdfc309d3ea9bc.mp4"

def run(cmd, t=180):
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(H, username=U, password=P, timeout=20)
    _, o, e = c.exec_command(cmd, timeout=t)
    out = o.read().decode(errors="replace")
    err = e.read().decode(errors="replace")
    c.close()
    return out, err

# Create a script file on remote then execute
script = r'''#!/bin/bash
set -e
URL="''' + URL + r'''"
MP4=/tmp/d26_final.mp4

echo "=== DOWNLOAD ==="
curl -sL -o "$MP4" "$URL"
FS=$(stat -c%s "$MP4" 2>/dev/null || echo 0)
echo "SIZE: $FS bytes"
md5sum "$MP4"

if [ "$FS" -lt 10000 ]; then
  echo "ERROR: File too small"
  curl -sI "$URL" | head -5
  exit 1
fi

echo ""
echo "=== FFPROBE STREAMS JSON ==="
ffprobe -v quiet -print_format json -show_streams "$MP4"

echo ""
echo "=== FFPROBE FORMAT JSON ==="
ffprobe -v quiet -print_format json -show_format "$MP4"

echo ""
echo "=== FFPROBE VERBOSE (VUI) ==="
ffprobe -v verbose "$MP4" 2>&1 | head -70

echo ""
echo "=== FFMPEG DECODE CHECK ==="
ffmpeg -v error -i "$MP4" -f null - 2>&1
echo "DECODE_EXIT_CODE=$?"

echo ""
echo "=== MP4 ATOMS ==="
python3 << 'PYEOF'
data = open('/tmp/d26_final.mp4', 'rb').read()
off = 0
names = []
while off < len(data) - 8:
    sz = int.from_bytes(data[off:off+4], 'big')
    nm = data[off+4:off+8].decode('ascii', errors='?')
    names.append(nm)
    print(f"  [{nm}] offset={off} size={sz}")
    if sz < 8 or off + sz > len(data):
        break
    off += sz
print(f"\nAtom order: {' > '.join(names)}")
mi = names.index('moov') if 'moov' in names else -1
di = names.index('mdat') if 'mdat' in names else -1
print(f"faststart (moov before mdat): {mi >= 0 and di >= 0 and mi < di}")
PYEOF

echo ""
echo "=== VIDEO PACKETS FIRST 80 ==="
ffprobe -v quiet -print_format json -show_packets -select_streams v -read_intervals "%+#80" "$MP4" | python3 << 'PYEOF'
import sys, json
d = json.load(sys.stdin)
pk = d.get('packets', [])
print(f"Video packets sampled: {len(pk)}")
if pk:
    t = [float(p.get('pts_time', 0)) for p in pk]
    ok = all(t[i] >= t[i-1] for i in range(1, len(t)))
    print(f"PTS monotone: {ok}")
    dt = [float(p.get('dts_time', 0)) for p in pk]
    dts_ok = all(dt[i] >= dt[i-1] for i in range(1, len(dt)))
    print(f"DTS monotone: {dts_ok}")
    kf = [p for p in pk if 'K' in p.get('flags', '')]
    print(f"Keyframes: {len(kf)} / {len(pk)}")
    if len(kf) > 1:
        kt = [float(p.get('pts_time', 0)) for p in kf]
        g = [kt[i] - kt[i-1] for i in range(1, len(kt))]
        print(f"GOP avg={sum(g)/len(g):.3f}s min={min(g):.3f} max={max(g):.3f}")
    print("First 10 video packets:")
    for p in pk[:10]:
        print(f"  pts={p.get('pts_time','?'):>8} dts={p.get('dts_time','?'):>8} dur={p.get('duration_time','?'):>6} flags={p.get('flags','?')}")
PYEOF

echo ""
echo "=== AUDIO PACKETS FIRST 50 ==="
ffprobe -v quiet -print_format json -show_packets -select_streams a -read_intervals "%+#50" "$MP4" | python3 << 'PYEOF'
import sys, json
d = json.load(sys.stdin)
pk = d.get('packets', [])
print(f"Audio packets sampled: {len(pk)}")
if pk:
    t = [float(p.get('pts_time', 0)) for p in pk]
    ok = all(t[i] >= t[i-1] for i in range(1, len(t)))
    print(f"Audio PTS monotone: {ok}")
    print("First 10 audio packets:")
    for p in pk[:10]:
        print(f"  pts={p.get('pts_time','?'):>8} dur={p.get('duration_time','?'):>6} size={p.get('size','?')}")
    # Check silence: if all sizes are similar and small
    sizes = [int(p.get('size', 0)) for p in pk]
    avg_sz = sum(sizes) / len(sizes) if sizes else 0
    print(f"  avg_packet_size={avg_sz:.0f} bytes")
    print(f"  all_same_size={len(set(sizes)) <= 3}")
PYEOF

echo ""
echo "=== TOTAL PACKET COUNT ==="
VPKTS=$(ffprobe -v quiet -count_packets -show_entries stream=nb_read_packets -select_streams v "$MP4" 2>&1 | grep nb_read)
APKTS=$(ffprobe -v quiet -count_packets -show_entries stream=nb_read_packets -select_streams a "$MP4" 2>&1 | grep nb_read)
echo "VIDEO: $VPKTS"
echo "AUDIO: $APKTS"

echo ""
echo "DONE"
'''

# Upload script + execute
print("Uploading and executing script on Kamatera...")
o_up, _ = run("cat > /tmp/d26_script.sh << 'SCRIPTEOF'\n" + script + "\nSCRIPTEOF\nchmod +x /tmp/d26_script.sh && bash /tmp/d26_script.sh", 180)

print(o_up)

# Save
with open(r"C:\Users\fasop\AndroidStudioProjects\academia\.windsurf\d26_ffprobe_out.txt", "w", encoding="utf-8") as f:
    f.write(o_up)
print("\nSaved d26_ffprobe_out.txt")
