import paramiko

host = '185.167.97.144'
user = 'root'
pwd = 'Nexiomgroup@Academia0'

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(host, username=user, password=pwd, timeout=30)

_, stdout, _ = client.exec_command('''
cd /opt/whiteboard-worker && python3 << 'PYEOF'
import tempfile
from pathlib import Path
from whiteboard_png_renderer import render_storyboard_to_pngs
from whiteboard_ffmpeg_assembler import assemble_pngs_to_mp4
import subprocess

storyboard = {
  "scenes": [
    {"id": "sc1", "title": "Introduction", "order": 0, "duration_ms": 5000,
     "blocks": [{"id": "b1", "type": "paragraph", "content": "Les derivees d une fonction", "order": 0, "visible": True}]},
    {"id": "sc2", "title": "Definition", "order": 1, "duration_ms": 5000,
     "blocks": [{"id": "b2", "type": "definition", "content": "f prime x = lim f(x+h)-f(x) / h", "order": 0, "visible": True}]}
  ],
  "renderer": "notebook", "theme": "notebook"
}

p = Path("/tmp/d24ffprobe")
p.mkdir(exist_ok=True)
pngs = render_storyboard_to_pngs(storyboard, p)
mp4 = assemble_pngs_to_mp4(pngs, p)
print(f"MP4 size: {mp4.stat().st_size} bytes")

# ffprobe
r = subprocess.run(
    ["ffprobe", "-v", "quiet", "-print_format", "json", "-show_streams", "-show_format", str(mp4)],
    capture_output=True, text=True
)
import json
info = json.loads(r.stdout)
fmt = info.get("format", {})
streams = info.get("streams", [])
print(f"duration: {fmt.get('duration')}s")
print(f"size: {fmt.get('size')} bytes")
for s in streams:
    print(f"stream: codec={s.get('codec_name')} profile={s.get('profile')} level={s.get('level')} size={s.get('width')}x{s.get('height')} dur={s.get('duration')}")
PYEOF
''')
out = stdout.read().decode(errors='replace')
print(out)
client.close()
