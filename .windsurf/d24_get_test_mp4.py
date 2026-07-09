import paramiko

host = '185.167.97.144'
user = 'root'
pwd = 'Nexiomgroup@Academia0'

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(host, username=user, password=pwd, timeout=30)

_, stdout, stderr = client.exec_command('''
cd /opt/whiteboard-worker
python3 << 'EOF'
import tempfile, struct
from pathlib import Path
from whiteboard_png_renderer import render_storyboard_to_pngs
from whiteboard_ffmpeg_assembler import assemble_pngs_to_mp4

storyboard = {
  "scenes": [
    {"id": "sc1", "title": "Test", "order": 0, "duration_ms": 5000,
     "blocks": [{"id": "b1", "type": "paragraph", "content": "Bonjour monde", "order": 0, "visible": True}]}
  ],
  "renderer": "notebook", "theme": "notebook"
}

p = Path("/tmp/d24test")
p.mkdir(exist_ok=True)
pngs = render_storyboard_to_pngs(storyboard, p)
mp4 = assemble_pngs_to_mp4(pngs, p)
size = mp4.stat().st_size
data = mp4.read_bytes()

# Atoms
offset = 0
atoms = []
while offset < len(data) - 8:
    sz = struct.unpack(">I", data[offset:offset+4])[0]
    nm = data[offset+4:offset+8].decode("ascii", errors="?")
    atoms.append(f"{nm}:{sz}")
    if sz == 0 or sz < 8: break
    offset += sz
    if offset > 500000: break

print(f"SIZE={size}")
print(f"ATOMS={','.join(atoms)}")
print(f"MOOV_FIRST={atoms[0].startswith('moov') if atoms else False}")
EOF
''')
out = stdout.read().decode(errors='replace')
err = stderr.read().decode(errors='replace')
print("OUT:", out)
if err.strip():
    print("ERR:", err[:500])

# Télécharger
try:
    sftp = client.open_sftp()
    sftp.get('/tmp/d24test/output.mp4', 'C:/Users/fasop/AndroidStudioProjects/academia/.windsurf/test_new.mp4')
    import os
    print("Downloaded:", os.path.getsize('C:/Users/fasop/AndroidStudioProjects/academia/.windsurf/test_new.mp4'), "bytes")
    sftp.close()
except Exception as e:
    print("DL error:", e)

client.close()
