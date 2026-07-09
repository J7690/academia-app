#!/usr/bin/env python3
"""D20 - Audit Kamatera whiteboard worker complet"""
import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS, timeout=20)

results = []

def run(label, cmd):
    _, out, _ = ssh.exec_command(cmd, timeout=30)
    o = out.read().decode("utf-8", errors="replace").strip()
    results.append(f"\n=== {label} ===")
    results.append(o[:1000] if o else "(empty)")

run("whiteboard-worker systemd service", "cat /etc/systemd/system/whiteboard-worker.service")
run("whiteboard-worker status", "systemctl status whiteboard-worker --no-pager")
run("whiteboard-worker process", "ps aux | grep whiteboard_render_worker | grep -v grep")
run("whiteboard-worker logs (last 30)", "journalctl -u whiteboard-worker -n 30 --no-pager 2>&1")
run("/opt/whiteboard-worker files", "ls -la /opt/whiteboard-worker/")
run("whiteboard_render_worker.py content", "cat /opt/whiteboard-worker/whiteboard_render_worker.py")
run("whiteboard_ffmpeg_assembler.py content", "cat /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py")
run("whiteboard_upload_renderer.py content", "cat /opt/whiteboard-worker/whiteboard_upload_renderer.py")
run(".env file (masked)", "cat /opt/whiteboard-worker/.env | sed 's/=.*/=***/'")
run("ffmpeg version", "ffmpeg -version 2>&1 | head -3 || echo FFMPEG_NOT_FOUND")
run("python3 packages in venv", "pip3 list 2>/dev/null | grep -i 'httpx\\|pillow\\|requests\\|supabase' || echo NONE")
run("all systemd services running", "systemctl list-units --type=service --state=running --no-pager")

ssh.close()

output = "\n".join(results)
print(output)
outfile = "c:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\d20_kamatera_whiteboard_audit_output.txt"
with open(outfile, "w", encoding="utf-8") as f:
    f.write(output)
print(f"\nSaved to: {outfile}")
