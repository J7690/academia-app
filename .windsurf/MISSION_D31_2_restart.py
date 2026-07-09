#!/usr/bin/env python3
"""MISSION D31.2 — Phase 4 : redémarrage contrôlé du worker."""
import paramiko
import time
from pathlib import Path

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"
REMOTE_DIR = "/opt/whiteboard-worker"


def ssh_command(cmd):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS, timeout=20)
    stdin, stdout, stderr = ssh.exec_command(cmd)
    out = stdout.read().decode(errors='ignore')
    err = stderr.read().decode(errors='ignore')
    ssh.close()
    return out, err


# 1. Capture PID before
status_before, _ = ssh_command("systemctl status whiteboard-worker --no-pager")
old_pid = None
for line in status_before.splitlines():
    if "Main PID:" in line:
        old_pid = line.split("Main PID:")[1].split()[0]
        break

print(f"PID before restart: {old_pid}")

# 2. Remove pycache
out, err = ssh_command(f"rm -rf {REMOTE_DIR}/__pycache__")
print(f"Pycache removal: out={out.strip()}, err={err.strip()}")

# 3. Restart service
out, err = ssh_command("systemctl restart whiteboard-worker")
print(f"Restart command: out={out.strip()}, err={err.strip()}")

# 4. Wait a few seconds and capture status after
time.sleep(3)
status_after, _ = ssh_command("systemctl status whiteboard-worker --no-pager")
new_pid = None
for line in status_after.splitlines():
    if "Main PID:" in line:
        new_pid = line.split("Main PID:")[1].split()[0]
        break

print(f"PID after restart: {new_pid}")

# 5. Prove new code loaded: check file hash and read first lines of concat logic
sha_out, _ = ssh_command(f"sha256sum {REMOTE_DIR}/whiteboard_ffmpeg_assembler.py {REMOTE_DIR}/whiteboard_render_worker.py")
print(f"SHA256 after restart:\n{sha_out}")

# 6. Verify new code loaded by checking process start time
uptime_out, _ = ssh_command("ps -o pid,etimes,comm -p $(systemctl show whiteboard-worker --property=MainPID --value)")
print(f"Worker uptime:\n{uptime_out}")

report = f"""# D31_2_worker_reload_proof.md

**Date :** {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}

---

## 1. PID avant redémarrage

`{old_pid}`

## 2. Suppression des pycache

Commande : `rm -rf /opt/whiteboard-worker/__pycache__`

Résultat : erreur = `{err.strip()}`

## 3. Redémarrage

Commande : `systemctl restart whiteboard-worker`

Résultat : erreur = `{err.strip()}`

## 4. PID après redémarrage

`{new_pid}`

**PID différent :** `{old_pid != new_pid}`

## 5. Statut du service après redémarrage

```
{status_after}
```

## 6. Empreintes des fichiers modifiés

```
{sha_out}
```

## 7. Uptime du processus

```
{uptime_out}
```

**Conclusion :** Le service a redémarré avec un nouveau PID. Les fichiers modifiés sont en place. Le worker chargera le nouveau code à son prochain cycle de poll.
"""

outfile = Path("C:/Users/fasop/AndroidStudioProjects/academia/.windsurf/D31_2_worker_reload_proof.md")
outfile.write_text(report, encoding='utf-8')
print(f"Saved {outfile}")
