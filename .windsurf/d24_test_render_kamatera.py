import paramiko, json

host = '185.167.97.144'
user = 'root'
pwd = 'Nexiomgroup@Academia0'

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(host, username=user, password=pwd, timeout=30)

# 1. Lire le png_renderer complet
print('=== whiteboard_png_renderer.py ===')
_, stdout, _ = client.exec_command('cat /opt/whiteboard-worker/whiteboard_png_renderer.py')
print(stdout.read().decode(errors='replace'))

# 2. Vérifier ffmpeg version et capabilities
print('\n=== FFmpeg version ===')
_, stdout, _ = client.exec_command('ffmpeg -version 2>&1 | head -5')
print(stdout.read().decode(errors='replace'))

# 3. Tester un rendu manuel avec le dernier storyboard
print('\n=== Test render script ===')
test_script = '''
cd /opt/whiteboard-worker
python3 -c "
import json, tempfile
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

with tempfile.TemporaryDirectory() as tmp:
    p = Path(tmp)
    pngs = render_storyboard_to_pngs(storyboard, p)
    print('PNGs generated:', len(pngs))
    for pp in pngs:
        print('  PNG:', pp, 'size:', pp.stat().st_size if pp.exists() else 'MISSING')
    mp4 = assemble_pngs_to_mp4(pngs, p)
    print('MP4:', mp4, 'size:', mp4.stat().st_size)
" 2>&1
'''
_, stdout, stderr = client.exec_command(test_script)
out = stdout.read().decode(errors='replace')
err = stderr.read().decode(errors='replace')
print(out)
if err.strip():
    print('STDERR:', err[:1000])

client.close()
