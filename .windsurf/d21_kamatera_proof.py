#!/usr/bin/env python3
"""D21 - Kamatera ground truth via SSH"""
import paramiko
from datetime import datetime

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS, timeout=20)

results = []
def log(msg): results.append(msg); print(msg)

def run(label, cmd):
    _, out, err = ssh.exec_command(cmd, timeout=30)
    o = out.read().decode("utf-8", errors="replace").strip()
    e = err.read().decode("utf-8", errors="replace").strip()
    log(f"\n=== {label} ===")
    log(f"CMD: {cmd}")
    if o: log(o[:1500])
    if e: log(f"STDERR: {e[:300]}")

log("="*70)
log(f"D21 - KAMATERA GROUND TRUTH")
log(f"Timestamp: {datetime.now().isoformat()}")
log("="*70)

run("1. whiteboard-worker systemd status", "systemctl status whiteboard-worker --no-pager -l 2>&1")
run("2. whiteboard-worker process", "ps aux | grep whiteboard | grep -v grep")
run("3. whiteboard_render_worker.py RPC calls", "grep -n 'rpc\\|whiteboard_' /opt/whiteboard-worker/whiteboard_render_worker.py")
run("4. whiteboard_render_worker.py table writes", "grep -n 'whiteboard_renders\\|whiteboard_table\\|WHITEBOARD_TABLE' /opt/whiteboard-worker/whiteboard_render_worker.py")
run("5. whiteboard_upload_renderer.py bucket", "grep -n 'WHITEBOARD_BUCKET\\|bucket\\|storage' /opt/whiteboard-worker/whiteboard_upload_renderer.py")
run("6. .env variables", "cat /opt/whiteboard-worker/.env | sed 's/=.*/=***MASKED***/'")
run("7. worker logs last 50 lines", "journalctl -u whiteboard-worker -n 50 --no-pager 2>&1")
run("8. worker.log tail 30", "tail -30 /opt/whiteboard-worker/worker.log 2>&1 || echo NO_LOG_FILE")
run("9. whiteboard_png_renderer key imports", "head -40 /opt/whiteboard-worker/whiteboard_png_renderer.py")
run("10. whiteboard_ffmpeg_assembler full", "cat /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py")
run("11. whiteboard_render_worker full", "cat /opt/whiteboard-worker/whiteboard_render_worker.py")
run("12. ffmpeg version", "ffmpeg -version 2>&1 | head -2")
run("13. python3 packages", "pip3 list 2>/dev/null | grep -i 'httpx\\|pillow\\|dotenv\\|requests'")
run("14. storage/bucket confirmed in upload", "grep -n 'whiteboard-renders\\|storage/v1' /opt/whiteboard-worker/whiteboard_upload_renderer.py")
run("15. kamatera external calls check", "grep -rn 'kamatera\\|185.167\\|external' /opt/whiteboard-worker/ 2>/dev/null || echo NONE")

ssh.close()

outfile = "c:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\d21_kamatera_proof_output.txt"
with open(outfile, "w", encoding="utf-8") as f:
    f.write("\n".join(results))
log(f"\nSaved to: {outfile}")
