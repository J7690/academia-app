#!/usr/bin/env python3
import paramiko

HOST = "185.167.97.144"
USER = "root"
PASSWORD = "Nexiomgroup@Academia0"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, username=USER, password=PASSWORD, timeout=20, banner_timeout=15, auth_timeout=15)

cmds = [
    ("STATUS_SERVICE", "systemctl status bobodo-vocal.service --no-pager"),
    ("FILES_OPT", "ls -la /opt/bobodo-vocal/"),
    ("FILES_ROOT", "ls -la /root/bobodo-vocal/ 2>&1 || echo 'DIR_NOT_FOUND'"),
    ("HEALTH", "curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:8000/health 2>&1 || echo 'FAIL'"),
    ("WS_STATUS", "curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:8000/ws 2>&1 || echo 'FAIL'"),
    ("WHISPER_SIZE", "du -sh /root/.cache/huggingface/hub/models--Systran--faster-whisper-medium/ 2>&1 || echo 'NO_WHISPER'"),
    ("PIPER_SIZE", "du -sh /opt/bobodo-vocal/models/ 2>&1 || echo 'NO_PIPER_MODELS'"),
    ("SERVICE_LOGS", "journalctl -u bobodo-vocal.service --no-pager -n 20 2>&1 || echo 'NO_LOGS'"),
    ("PS_PYTHON", "ps aux | grep -i python | grep -v grep"),
    ("NGINX_CONFIG", "ls -la /etc/nginx/sites-enabled/ 2>&1 || echo 'NO_NGINX_SITES'"),
]

results = []
for name, cmd in cmds:
    results.append(f"\n=== {name} ===")
    results.append(f"CMD: {cmd}")
    try:
        stdin, stdout, stderr = client.exec_command(cmd, timeout=30)
        exit_code = stdout.channel.recv_exit_status()
        out = stdout.read().decode('utf-8', errors='replace').strip()
        err = stderr.read().decode('utf-8', errors='replace').strip()
        results.append(f"EXIT: {exit_code}")
        if out:
            results.append("STDOUT:")
            results.append(out)
        if err:
            results.append("STDERR:")
            results.append(err)
    except Exception as e:
        results.append(f"ERROR: {e}")
    results.append("-" * 50)

client.close()

output = "\n".join(results)
with open("c:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\BOBODO_AUDIT_PHASE2.txt", "w", encoding="utf-8") as f:
    f.write(output)
print(output)
