import paramiko

host = '185.167.97.144'
user = 'root'
pwd = 'Nexiomgroup@Academia0'

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(host, username=user, password=pwd, timeout=15)

# Logs du worker
cmds = [
    'journalctl -u whiteboard-worker --no-pager -n 50 2>/dev/null || cat /var/log/whiteboard-worker.log 2>/dev/null | tail -50',
    'ls /opt/whiteboard-worker/ 2>/dev/null || ls /root/ 2>/dev/null',
    'ps aux | grep -i worker | grep -v grep',
    'find /tmp -name "*.mp4" -newer /tmp 2>/dev/null | head -10',
    'cat /root/whiteboard_worker.py 2>/dev/null | head -80 || cat /opt/whiteboard-worker/worker.py 2>/dev/null | head -80',
]

for cmd in cmds:
    print(f'\n=== CMD: {cmd[:60]} ===')
    _, stdout, stderr = client.exec_command(cmd)
    out = stdout.read().decode(errors='replace')
    err = stderr.read().decode(errors='replace')
    print(out[:2000] if out else '(vide)')
    if err.strip():
        print('ERR:', err[:200])

client.close()
