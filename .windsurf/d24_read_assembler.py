import paramiko

host = '185.167.97.144'
user = 'root'
pwd = 'Nexiomgroup@Academia0'

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(host, username=user, password=pwd, timeout=15)

# Lire le worker principal complet
for fname in ['whiteboard_render_worker.py', 'whiteboard_ffmpeg_assembler.py']:
    print(f'\n{"="*60}\n{fname}\n{"="*60}')
    _, stdout, _ = client.exec_command(f'cat /opt/whiteboard-worker/{fname}')
    print(stdout.read().decode(errors='replace'))

client.close()
