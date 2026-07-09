import paramiko, requests, struct

host = '185.167.97.144'
user = 'root'
pwd = 'Nexiomgroup@Academia0'

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(host, username=user, password=pwd, timeout=30)

# Générer un MP4 de test et le récupérer
test_script = '''
cd /opt/whiteboard-worker
python3 -c "
import json, tempfile, base64
from pathlib import Path
from whiteboard_png_renderer import render_storyboard_to_pngs
from whiteboard_ffmpeg_assembler import assemble_pngs_to_mp4

storyboard = {
  'scenes': [
    {'id': 'sc1', 'title': 'Test', 'order': 0, 'duration_ms': 5000,
     'blocks': [{'id': 'b1', 'type': 'paragraph', 'content': 'Bonjour', 'order': 0, 'visible': True}]}
  ],
  'renderer': 'notebook', 'theme': 'notebook'
}

import os, shutil
p = Path('/tmp/test_render_d24')
p.mkdir(exist_ok=True)
pngs = render_storyboard_to_pngs(storyboard, p)
mp4 = assemble_pngs_to_mp4(pngs, p)
print('SIZE:', mp4.stat().st_size)

# Afficher les atoms
import struct
data = mp4.read_bytes()
offset = 0
while offset < len(data) - 8:
    sz = struct.unpack('>I', data[offset:offset+4])[0]
    nm = data[offset+4:offset+8].decode('ascii', errors='?')
    print(f'ATOM offset={offset} size={sz} name={nm}')
    if sz == 0 or sz < 8: break
    offset += sz
    if offset > 200000: break
" 2>&1
'''
_, stdout, _ = client.exec_command(test_script)
print(stdout.read().decode(errors='replace'))

# Télécharger le fichier test
sftp = client.open_sftp()
try:
    sftp.get('/tmp/test_render_d24/output.mp4', 'C:/Users/fasop/AndroidStudioProjects/academia/.windsurf/test_render_new.mp4')
    print("Fichier téléchargé")
    import os
    size = os.path.getsize('C:/Users/fasop/AndroidStudioProjects/academia/.windsurf/test_render_new.mp4')
    print(f"Taille locale: {size} bytes")
except Exception as e:
    print("Erreur téléchargement:", e)
sftp.close()
client.close()
