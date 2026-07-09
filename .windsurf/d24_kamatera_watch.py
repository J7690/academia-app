#!/usr/bin/env python3
"""D24 - Kamatera runtime watch : vérifier nouveaux jobs depuis le test D24"""
import paramiko
from datetime import datetime

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect("185.167.97.144", username="root", password="Nexiomgroup@Academia0", timeout=20)

def run(label, cmd):
    _, out, _ = ssh.exec_command(cmd, timeout=25)
    o = out.read().decode("utf-8", errors="replace").strip()
    print(f"\n=== {label} ===")
    print(o[:3000])

run("1. Service status", "systemctl is-active whiteboard-worker && systemctl status whiteboard-worker --no-pager | head -5")
run("2. Journald dernières 30 lignes (depuis 10:10 UTC)", "journalctl -u whiteboard-worker --since '2026-06-28 10:10:00' --no-pager 2>&1 | tail -50")
run("3. fetch_queued_jobs récents", "journalctl -u whiteboard-worker --since '2026-06-28 10:10:00' --no-pager 2>&1 | grep 'fetch_queued\\|Found\\|job' | tail -20")
run("4. mark_processing depuis 10h10", "journalctl -u whiteboard-worker --since '2026-06-28 10:10:00' --no-pager 2>&1 | grep 'mark_processing\\|Processing job' | tail -10")
run("5. FFmpeg depuis 10h10", "journalctl -u whiteboard-worker --since '2026-06-28 10:10:00' --no-pager 2>&1 | grep -i 'ffmpeg\\|render\\|mp4' | tail -10")
run("6. Storage upload depuis 10h10", "journalctl -u whiteboard-worker --since '2026-06-28 10:10:00' --no-pager 2>&1 | grep 'storage\\|upload\\|mark_done' | tail -10")
run("7. Erreurs depuis 10h10", "journalctl -u whiteboard-worker --since '2026-06-28 10:10:00' --no-pager 2>&1 | grep -i 'error\\|exception\\|traceback' | tail -10")

ssh.close()
print(f"\nTimestamp: {datetime.now().isoformat()}")
