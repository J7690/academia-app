"""D26 — Récupère clé complète + URL MP4 + ffprobe complet"""
import paramiko, json, re

H, U, P = "185.167.97.144", "root", "Nexiomgroup@Academia0"

def run(cmd, t=120):
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(H, username=U, password=P, timeout=20)
    _, o, e = c.exec_command(cmd, timeout=t)
    out = o.read().decode(errors="replace")
    err = e.read().decode(errors="replace")
    c.close()
    return out, err

# 1. Clé complète + listing dossier ad74ed9e + SQL via Python
cmd = r"""
python3 << 'EOF'
import os, json, re
from dotenv import load_dotenv
load_dotenv('/opt/whiteboard-worker/.env')

KEY = os.getenv('SUPABASE_SERVICE_KEY','')
SB  = os.getenv('SUPABASE_URL','https://thevdfcwlcqzdoybfvgs.supabase.co')
print(f"KEY_LEN={len(KEY)}")
print(f"KEY_PREFIX={KEY[:40]}")
print(f"SB={SB}")

import urllib.request

# List storage folder ad74ed9e
headers = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}
body = json.dumps({"prefix": "renders/ad74ed9e-2133-4c79-9a84-29b33d9d8fb3/", "limit": 10}).encode()
req = urllib.request.Request(f"{SB}/storage/v1/object/list/whiteboard-renders",
                              data=body, method="POST", headers=headers)
try:
    with urllib.request.urlopen(req, timeout=20) as r:
        data = json.loads(r.read())
    print("FOLDER_LIST:", json.dumps(data))
    if isinstance(data, list):
        for item in data:
            nm = item.get('name','')
            if nm.endswith('.mp4'):
                url = f"{SB}/storage/v1/object/public/whiteboard-renders/renders/ad74ed9e-2133-4c79-9a84-29b33d9d8fb3/{nm}"
                print(f"MP4_URL={url}")
except Exception as ex:
    print(f"FOLDER_ERR={ex}")

# Also query renders table via RPC
rpc_payload = json.dumps({"p_limit": 5}).encode()
rpc_req = urllib.request.Request(f"{SB}/rest/v1/rpc/whiteboard_fetch_queued_jobs",
                                  data=rpc_payload, method="POST", headers=headers)
try:
    with urllib.request.urlopen(rpc_req, timeout=10) as r:
        print("RPC_QUEUED:", r.read().decode()[:200])
except Exception as ex:
    print(f"RPC_ERR={ex}")

# Try whiteboard_get_render_status
for rid in ['ad74ed9e-2133-4c79-9a84-29b33d9d8fb3', 'fd9e3969-be64-45a9-8e95-00606ac51446']:
    pl = json.dumps({"p_render_id": rid}).encode()
    rr = urllib.request.Request(f"{SB}/rest/v1/rpc/whiteboard_get_render_status",
                                 data=pl, method="POST", headers={**headers,"Content-Type":"application/json"})
    try:
        with urllib.request.urlopen(rr, timeout=10) as r:
            resp = json.loads(r.read())
        print(f"STATUS_{rid[:8]}={json.dumps(resp)[:300]}")
    except Exception as ex:
        print(f"STATUS_ERR_{rid[:8]}={ex}")

EOF
"""
out, err = run(cmd, 60)
print(out)
if err.strip():
    print("ERR:", err[:500])

# Extract URL
url_match = re.search(r"MP4_URL=(\S+)", out)
pub_url = url_match.group(1).strip() if url_match else ""

# Also check status responses for video_url
status_urls = re.findall(r'"video_url"\s*:\s*"([^"]+)"', out)
if status_urls:
    pub_url = status_urls[0]
    print(f"URL from status: {pub_url}")

print(f"\n>>> PUB URL: {pub_url}")

# 2. Télécharger + ffprobe complet si URL trouvée
if pub_url:
    print("\n=== DOWNLOAD + FFPROBE ===")
    cmd2 = f"""
URL="{pub_url}"
MP4=/tmp/d26_final.mp4
curl -sL -o "$MP4" "$URL"
FS=$(stat -c%s "$MP4" 2>/dev/null || echo 0)
echo "SIZE: $FS"
if [ "$FS" -gt 10000 ]; then
  md5sum "$MP4"
  echo "=== STREAMS ==="
  ffprobe -v quiet -print_format json -show_streams "$MP4" 2>&1
  echo "=== FORMAT ==="
  ffprobe -v quiet -print_format json -show_format "$MP4" 2>&1
  echo "=== VUI ==="
  ffprobe -v verbose "$MP4" 2>&1 | head -70
  echo "=== DECODE ==="
  ffmpeg -v error -i "$MP4" -f null - 2>&1; echo "EXIT=$?"
  echo "=== ATOMS ==="
  python3 -c "
d=open('/tmp/d26_final.mp4','rb').read()
o,ns=0,[]
while o<len(d)-8:
  sz=int.from_bytes(d[o:o+4],'big')
  nm=d[o+4:o+8].decode('ascii',errors='?')
  ns.append(nm); print(f'  [{nm}] off={o} sz={sz}')
  if sz<8 or o+sz>len(d): break
  o+=sz
mi=ns.index('moov') if 'moov' in ns else -1
di=ns.index('mdat') if 'mdat' in ns else -1
print('Atom order: '+' > '.join(ns))
print(f'faststart (moov<mdat): {mi>=0 and di>=0 and mi<di}')
"
  echo "=== VIDEO PACKETS ==="
  ffprobe -v quiet -print_format json -show_packets -select_streams v -read_intervals "%+#80" "$MP4" 2>&1 | python3 -c "
import sys,json
d=json.load(sys.stdin)
pk=d.get('packets',[])
print(f'Video pkts sampled={len(pk)}')
if pk:
  t=[float(p.get('pts_time',0)) for p in pk]
  ok=all(t[i]>=t[i-1] for i in range(1,len(t)))
  print(f'PTS monotone={ok}')
  kf=[p for p in pk if 'K' in p.get('flags','')]
  print(f'Keyframes={len(kf)}/{len(pk)}')
  if len(kf)>1:
    kt=[float(p.get('pts_time',0)) for p in kf]
    g=[kt[i]-kt[i-1] for i in range(1,len(kt))]
    print(f'GOP avg={sum(g)/len(g):.3f}s min={min(g):.3f} max={max(g):.3f}')
  for p in pk[:10]:
    print(f\\\"  pts={p.get('pts_time','?'):8} dts={p.get('dts_time','?'):8} dur={p.get('duration_time','?'):6} flags={p.get('flags','?')}\\\")
"
  echo "=== AUDIO PACKETS ==="
  ffprobe -v quiet -print_format json -show_packets -select_streams a -read_intervals "%+#50" "$MP4" 2>&1 | python3 -c "
import sys,json
d=json.load(sys.stdin)
pk=d.get('packets',[])
print(f'Audio pkts sampled={len(pk)}')
for p in pk[:10]:
  print(f\\\"  pts={p.get('pts_time','?'):8} dur={p.get('duration_time','?'):6} sz={p.get('size','?')}\\\")
"
else
  echo "DOWNLOAD FAILED size=$FS"
  curl -sI "$URL" 2>&1 | head -8
fi
"""
    o2, e2 = run(cmd2, 150)
    print(o2[:10000])
    if e2.strip():
        print("ERR2:", e2[:300])

    # Save all
    with open(r"C:\Users\fasop\AndroidStudioProjects\academia\.windsurf\d26_final3.json",
              "w", encoding="utf-8") as f:
        json.dump({"url": pub_url, "step1": out, "ffprobe": o2}, f,
                  indent=2, ensure_ascii=False, default=str)
    print("\nSaved d26_final3.json")
else:
    # Lister tous les dossiers renders/ pour trouver le plus récent
    print("\nNo URL found — listing all render folders")
    cmd3 = r"""
python3 -c "
import os, json, urllib.request
from dotenv import load_dotenv
load_dotenv('/opt/whiteboard-worker/.env')
KEY = os.getenv('SUPABASE_SERVICE_KEY','')
SB  = os.getenv('SUPABASE_URL','')
headers = {'apikey': KEY, 'Authorization': f'Bearer {KEY}', 'Content-Type': 'application/json'}
# List all top-level folders
for folder in ['renders/fd9e3969-be64-45a9-8e95-00606ac51446/',
               'renders/ad74ed9e-2133-4c79-9a84-29b33d9d8fb3/',
               'renders/d9109f2d-73c7-45fa-b532-7a366f96bdb01/']:
    body = json.dumps({'prefix': folder, 'limit': 5}).encode()
    req = urllib.request.Request(f'{SB}/storage/v1/object/list/whiteboard-renders',
                                  data=body, method='POST', headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            d = json.loads(r.read())
        print(f'{folder}: {json.dumps(d)[:300]}')
    except Exception as ex:
        print(f'{folder}: ERR {ex}')
"
"""
    o3, _ = run(cmd3, 60)
    print(o3[:4000])
    with open(r"C:\Users\fasop\AndroidStudioProjects\academia\.windsurf\d26_final3.json",
              "w", encoding="utf-8") as f:
        json.dump({"step1": out, "folders": o3}, f, indent=2, ensure_ascii=False, default=str)
    print("Saved d26_final3.json")
