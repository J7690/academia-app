"""D26 — SSH final : URL réelle + ffprobe complet"""
import paramiko, json

H, U, P = "185.167.97.144", "root", "Nexiomgroup@Academia0"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0OTY1NDA5NSwiZXhwIjoyMDY1MjMwMDk1fQ.3vTqFMsB3OXYoNV2FTKA0pxEEJlg3AJH6E-i_Ogyp74"
SB  = "https://thevdfcwlcqzdoybfvgs.supabase.co"

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

# 1. Storage list + upload source + .env
print(">>> STORAGE + SOURCES")
cmd_a = (
    "SB=" + SB + "\n"
    "KEY=" + KEY + "\n"
    'echo "=== STORAGE LIST (renders/) ==="\n'
    'curl -sS -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \\\n'
    '  "$SB/storage/v1/object/list/whiteboard-renders" \\\n'
    '  -X POST -H "Content-Type: application/json" \\\n'
    '  -d \'{"prefix":"renders/","limit":10,"sortBy":{"column":"created_at","order":"desc"}}\' 2>&1\n'
    'echo ""\n'
    'echo "=== UPLOAD RENDERER ==="\n'
    'cat /opt/whiteboard-worker/whiteboard_upload_renderer.py\n'
    'echo ""\n'
    'echo "=== ENV FILE ==="\n'
    'cat /opt/whiteboard-worker/.env 2>/dev/null || echo "[no .env]"\n'
    'echo ""\n'
    'echo "=== LAST LOGS ==="\n'
    'journalctl -u whiteboard-worker -n 300 --no-pager 2>/dev/null | grep -iE "complet|upload|Processing|done|error" | tail -30\n'
)
o, e = run(cmd_a, 60)
print(o[:6000])
results["a_storage_sources"] = o

# Extraire folder UUID du storage list
import re
folder_match = re.findall(r'"name"\s*:\s*"(renders/[^"]+)"', o)
print("Folders found:", folder_match[:5])

# 2. Construire URLs candidates + télécharger
print("\n>>> DOWNLOAD + FFPROBE")
# On sait que le render_id = ad74ed9e-2133-4c79-9a84-29b33d9d8fb3
# L'upload renderer génère: renders/{render_id}/{uuid4}.mp4
# Chercher dans le storage
cmd_b = (
    "SB=" + SB + "\n"
    "KEY=" + KEY + "\n"
    'echo "=== STORAGE LIST renders/ad74ed9e ==="\n'
    'curl -sS -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \\\n'
    '  "$SB/storage/v1/object/list/whiteboard-renders" \\\n'
    '  -X POST -H "Content-Type: application/json" \\\n'
    '  -d \'{"prefix":"renders/ad74ed9e","limit":5}\' 2>&1\n'
    'echo ""\n'
    # Lister tous les sous-dossiers renders/
    'echo "=== STORAGE renders/ ALL SUBFOLDERS ==="\n'
    'curl -sS -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \\\n'
    '  "$SB/storage/v1/object/list/whiteboard-renders" \\\n'
    '  -X POST -H "Content-Type: application/json" \\\n'
    '  -d \'{"prefix":"renders","limit":20,"sortBy":{"column":"created_at","order":"desc"}}\' 2>&1\n'
)
o2, e2 = run(cmd_b, 60)
print(o2[:4000])
results["b_storage_list"] = o2

# Extraire le path complet du MP4
paths = re.findall(r'"name"\s*:\s*"([^"]+\.mp4)"', o2)
print("MP4 paths found:", paths)

# Fallback: construire URL depuis le dernier render_id connu
# et tenter de lister son contenu
render_id = "ad74ed9e-2133-4c79-9a84-29b33d9d8fb3"

cmd_c = (
    "SB=" + SB + "\n"
    "KEY=" + KEY + "\n"
    f'RID={render_id}\n'
    f'echo "=== LIST renders/$RID/ ==="\n'
    'curl -sS -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \\\n'
    '  "$SB/storage/v1/object/list/whiteboard-renders" \\\n'
    '  -X POST -H "Content-Type: application/json" \\\n'
    f'  -d \'{{"prefix":"renders/{render_id}/","limit":5}}\' 2>&1\n'
)
o3, e3 = run(cmd_c, 30)
print(o3[:2000])
results["c_render_list"] = o3

# Extraire le filename MP4
mp4_names = re.findall(r'"name"\s*:\s*"([a-f0-9]{32}\.mp4)"', o3)
if not mp4_names:
    mp4_names = re.findall(r'"name"\s*:\s*"([^"]+\.mp4)"', o3)
print("MP4 filenames:", mp4_names)

if mp4_names:
    fname = mp4_names[0]
    # L'URL publique est construite comme:
    pub_url = f"{SB}/storage/v1/object/public/whiteboard-renders/renders/{render_id}/{fname}"
    print(f"PUBLIC URL: {pub_url}")
else:
    # Essayer avec la construction depuis upload renderer
    # upload_mp4_to_storage crée: f"renders/{render_id}/{uuid4_hex}.mp4"
    # On liste directement dans le storage
    pub_url = f"{SB}/storage/v1/object/public/whiteboard-renders/renders/{render_id}/"
    print(f"Cannot determine exact filename, using base: {pub_url}")

results["pub_url"] = pub_url

# 3. Télécharger + ffprobe complet
if mp4_names:
    print("\n>>> DOWNLOAD + FULL FFPROBE")
    cmd_d = (
        f"URL=\"{pub_url}\"\n"
        "MP4=/tmp/d26_final.mp4\n"
        "curl -sL -o \"$MP4\" \"$URL\"\n"
        "FS=$(stat -c%s \"$MP4\" 2>/dev/null || echo 0)\n"
        "echo \"SIZE: $FS bytes\"\n"
        "md5sum \"$MP4\" 2>/dev/null\n"
        "\n"
        "if [ \"$FS\" -gt 10000 ]; then\n"
        "echo '=== STREAMS ==='\n"
        "ffprobe -v quiet -print_format json -show_streams \"$MP4\" 2>&1\n"
        "echo '=== FORMAT ==='\n"
        "ffprobe -v quiet -print_format json -show_format \"$MP4\" 2>&1\n"
        "echo '=== VERBOSE VUI ==='\n"
        "ffprobe -v verbose \"$MP4\" 2>&1 | head -60\n"
        "echo '=== DECODE CHECK ==='\n"
        "ffmpeg -v error -i \"$MP4\" -f null - 2>&1; echo \"EXIT=$?\"\n"
        "echo '=== ATOMS ==='\n"
        "python3 -c \"\n"
        "data=open('/tmp/d26_final.mp4','rb').read()\n"
        "off=0\n"
        "while off<len(data)-8:\n"
        "    sz=int.from_bytes(data[off:off+4],'big')\n"
        "    nm=data[off+4:off+8].decode('ascii',errors='?')\n"
        "    print(f'  [{nm}] off={off} sz={sz}')\n"
        "    if sz<8 or off+sz>len(data): break\n"
        "    off+=sz\n"
        "\"\n"
        "echo '=== VIDEO PACKETS ==='\n"
        "ffprobe -v quiet -print_format json -show_packets -select_streams v -read_intervals '%+#80' \"$MP4\" 2>&1 | python3 -c \"\n"
        "import sys,json\n"
        "d=json.load(sys.stdin)\n"
        "pkts=d.get('packets',[])\n"
        "print(f'Video pkts: {len(pkts)}')\n"
        "if pkts:\n"
        "    t=[float(p.get('pts_time',0)) for p in pkts]\n"
        "    ok=all(t[i]>=t[i-1] for i in range(1,len(t)))\n"
        "    print(f'PTS mono: {ok}')\n"
        "    kf=[p for p in pkts if 'K' in p.get('flags','')]\n"
        "    print(f'Keyframes: {len(kf)}/{len(pkts)}')\n"
        "    if len(kf)>1:\n"
        "        kt=[float(p.get('pts_time',0)) for p in kf]\n"
        "        g=[kt[i]-kt[i-1] for i in range(1,len(kt))]\n"
        "        print(f'GOP avg={sum(g)/len(g):.3f}s')\n"
        "    for p in pkts[:8]:\n"
        "        print(f\\\"  pts={p.get('pts_time','?'):8} flags={p.get('flags','?')}\\\")\n"
        "\"\n"
        "echo '=== AUDIO PACKETS ==='\n"
        "ffprobe -v quiet -print_format json -show_packets -select_streams a -read_intervals '%+#30' \"$MP4\" 2>&1 | python3 -c \"\n"
        "import sys,json\n"
        "d=json.load(sys.stdin)\n"
        "pkts=d.get('packets',[])\n"
        "print(f'Audio pkts: {len(pkts)}')\n"
        "for p in pkts[:8]:\n"
        "    print(f\\\"  pts={p.get('pts_time','?'):8} dur={p.get('duration_time','?'):6} sz={p.get('size','?')}\\\")\n"
        "\"\n"
        "fi\n"
    )
    o4, e4 = run(cmd_d, 120)
    print(o4[:8000])
    results["d_ffprobe_full"] = o4

# Save
out_path = r"C:\Users\fasop\AndroidStudioProjects\academia\.windsurf\d26_final.json"
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False, default=str)
print(f"\nSaved: {out_path}")
