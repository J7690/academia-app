"""D26 — Récupère la vraie clé Supabase depuis .env Kamatera, puis l'URL du MP4"""
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

results = {}

# 1. Lire le .env complet
print("=== .ENV ===")
o, _ = run("cat /opt/whiteboard-worker/.env", 10)
print(o)
results["env"] = o

# Parser la clé réelle
key_match = re.search(r"SUPABASE_SERVICE_KEY=(\S+)", o.replace("\n", " ").replace("\r", ""))
sb_match   = re.search(r"SUPABASE_URL=(\S+)", o.replace("\n", " ").replace("\r", ""))
real_key = key_match.group(1).strip() if key_match else ""
real_sb  = sb_match.group(1).strip()  if sb_match  else "https://thevdfcwlcqzdoybfvgs.supabase.co"
print(f"REAL KEY (first 40): {real_key[:40]}...")
print(f"REAL SB: {real_sb}")
results["real_key_prefix"] = real_key[:40]

# 2. Utiliser la vraie clé pour lister le storage
print("\n=== STORAGE LIST ===")
cmd_list = (
    f'KEY="{real_key}"\n'
    f'SB="{real_sb}"\n'
    'curl -sS \\\n'
    '  -H "apikey: $KEY" \\\n'
    '  -H "Authorization: Bearer $KEY" \\\n'
    '  "$SB/storage/v1/object/list/whiteboard-renders" \\\n'
    '  -X POST -H "Content-Type: application/json" \\\n'
    '  -d \'{"prefix":"renders/","limit":10,"sortBy":{"column":"created_at","order":"desc"}}\' 2>&1\n'
)
o2, e2 = run(cmd_list, 30)
print(o2[:3000])
results["storage_list"] = o2

# Extraire les noms de fichiers MP4
mp4_paths = re.findall(r'"name"\s*:\s*"(renders/[^"]+\.mp4)"', o2)
print("MP4 paths:", mp4_paths)

# 3. Via admin_execute_sql avec la vraie clé
print("\n=== SQL video_url ===")
import urllib.request, urllib.error
sql_payload = json.dumps({
    "query": "SELECT id, video_url, duration_ms, created_at FROM app.whiteboard_renders WHERE status='done' AND video_url IS NOT NULL ORDER BY created_at DESC LIMIT 3"
}).encode()
req = urllib.request.Request(
    f"{real_sb}/rest/v1/rpc/admin_execute_sql",
    data=sql_payload,
    method="POST",
    headers={
        "apikey": real_key,
        "Authorization": f"Bearer {real_key}",
        "Content-Type": "application/json",
    }
)
try:
    with urllib.request.urlopen(req, timeout=20) as r:
        body = r.read().decode()
    print(body[:2000])
    results["sql_result"] = body
    data = json.loads(body)
    # Extraire video_url
    if isinstance(data, list) and data:
        for row in data:
            if row.get("video_url"):
                pub_url = row["video_url"]
                break
    elif isinstance(data, dict) and "result" in data:
        rows = json.loads(data["result"]) if isinstance(data["result"], str) else data["result"]
        pub_url = rows[0].get("video_url", "") if rows else ""
    else:
        pub_url = ""
    print(f"\nPUB URL: {pub_url}")
    results["pub_url"] = pub_url
except Exception as ex:
    print(f"SQL error: {ex}")
    pub_url = ""
    results["pub_url"] = ""

# 4. Si on a l'URL: télécharger + ffprobe complet
if not pub_url and mp4_paths:
    pub_url = f"{real_sb}/storage/v1/object/public/whiteboard-renders/{mp4_paths[0]}"
    results["pub_url"] = pub_url
    print(f"URL from storage list: {pub_url}")

if pub_url:
    print(f"\n=== DOWNLOAD + FFPROBE: {pub_url[:80]} ===")
    cmd_fp = (
        f'URL="{pub_url}"\n'
        'MP4=/tmp/d26_final.mp4\n'
        'curl -sL -o "$MP4" "$URL" 2>&1\n'
        'FS=$(stat -c%s "$MP4" 2>/dev/null || echo 0)\n'
        'echo "SIZE: $FS bytes"\n'
        'if [ "$FS" -gt 10000 ]; then\n'
        '  md5sum "$MP4"\n'
        '  echo "=== STREAMS JSON ==="\n'
        '  ffprobe -v quiet -print_format json -show_streams "$MP4" 2>&1\n'
        '  echo "=== FORMAT JSON ==="\n'
        '  ffprobe -v quiet -print_format json -show_format "$MP4" 2>&1\n'
        '  echo "=== VUI VERBOSE ==="\n'
        '  ffprobe -v verbose "$MP4" 2>&1 | head -80\n'
        '  echo "=== DECODE CHECK ==="\n'
        '  ffmpeg -v error -i "$MP4" -f null - 2>&1; echo "EXIT=$?"\n'
        '  echo "=== ATOMS ==="\n'
        "  python3 -c \"\n"
        "d=open('/tmp/d26_final.mp4','rb').read()\n"
        "o=0\n"
        "ns=[]\n"
        "while o<len(d)-8:\n"
        "  sz=int.from_bytes(d[o:o+4],'big')\n"
        "  nm=d[o+4:o+8].decode('ascii',errors='?')\n"
        "  ns.append(nm)\n"
        "  print(f'  [{nm}] off={o} sz={sz}')\n"
        "  if sz<8 or o+sz>len(d):break\n"
        "  o+=sz\n"
        "mi=ns.index('moov') if 'moov' in ns else -1\n"
        "di=ns.index('mdat') if 'mdat' in ns else -1\n"
        "print(f'faststart: {mi<di}')\n"
        "\"\n"
        '  echo "=== VIDEO PACKETS ==="\n'
        "  ffprobe -v quiet -print_format json -show_packets -select_streams v -read_intervals '%+#80' \"$MP4\" 2>&1 | python3 -c \"\n"
        "import sys,json as J\n"
        "d=J.load(sys.stdin)\n"
        "pk=d.get('packets',[])\n"
        "print(f'Video pkts={len(pk)}')\n"
        "if pk:\n"
        "  t=[float(p.get('pts_time',0)) for p in pk]\n"
        "  ok=all(t[i]>=t[i-1] for i in range(1,len(t)))\n"
        "  print(f'PTS mono={ok}')\n"
        "  kf=[p for p in pk if 'K' in p.get('flags','')]\n"
        "  print(f'Keyframes={len(kf)}')\n"
        "  if len(kf)>1:\n"
        "    kt=[float(p.get('pts_time',0)) for p in kf]\n"
        "    g=[kt[i]-kt[i-1] for i in range(1,len(kt))]\n"
        "    print(f'GOP avg={sum(g)/len(g):.3f}s')\n"
        "  [print(f\\\"  pts={p.get('pts_time','?'):8} flags={p.get('flags','?')}\\\") for p in pk[:8]]\n"
        "\"\n"
        '  echo "=== AUDIO PACKETS ==="\n'
        "  ffprobe -v quiet -print_format json -show_packets -select_streams a -read_intervals '%+#50' \"$MP4\" 2>&1 | python3 -c \"\n"
        "import sys,json as J\n"
        "d=J.load(sys.stdin)\n"
        "pk=d.get('packets',[])\n"
        "print(f'Audio pkts={len(pk)}')\n"
        "[print(f\\\"  pts={p.get('pts_time','?'):8} dur={p.get('duration_time','?'):6} sz={p.get('size','?')}\\\") for p in pk[:8]]\n"
        "\"\n"
        'else\n'
        '  echo "DOWNLOAD FAILED"\n'
        '  curl -sI "$URL" | head -8\n'
        'fi\n'
    )
    o3, e3 = run(cmd_fp, 120)
    print(o3[:8000])
    if e3.strip():
        print("STDERR:", e3[:500])
    results["ffprobe_full"] = o3

# Save
with open(r"C:\Users\fasop\AndroidStudioProjects\academia\.windsurf\d26_final2.json", "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False, default=str)
print("\nSaved d26_final2.json")
