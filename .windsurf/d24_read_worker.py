import paramiko

host = '185.167.97.144'
user = 'root'
pwd = 'Nexiomgroup@Academia0'

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(host, username=user, password=pwd, timeout=15)

files = [
    '/opt/whiteboard-worker/whiteboard_render_worker.py',
    '/opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py',
    '/opt/whiteboard-worker/whiteboard_png_renderer.py',
    '/opt/whiteboard-worker/worker.log',
]

for f in files:
    print(f'\n{"="*60}\n FILE: {f}\n{"="*60}')
    _, stdout, _ = client.exec_command(f'cat "{f}" 2>/dev/null')
    out = stdout.read().decode(errors='replace')
    print(out[:4000] if out else '(vide ou introuvable)')

client.close()
