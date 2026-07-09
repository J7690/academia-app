#!/usr/bin/env python3
"""D22 - Kamatera runtime state proof"""
import paramiko
from datetime import datetime

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect("185.167.97.144", username="root", password="Nexiomgroup@Academia0", timeout=20)

def run(label, cmd):
    _, out, _ = ssh.exec_command(cmd, timeout=20)
    o = out.read().decode("utf-8", errors="replace").strip()
    print(f"=== {label} ===")
    print(o[:2000])
    print()

run("1. worker service status", "systemctl is-active whiteboard-worker && systemctl status whiteboard-worker --no-pager -l | head -12")
run("2. PID réel", "cat /run/whiteboard-worker.pid 2>/dev/null || systemctl show whiteboard-worker --property=MainPID")
run("3. journald last 20 lines (runtime actual)", "journalctl -u whiteboard-worker -n 20 --no-pager 2>&1")
run("4. whiteboard_fetch_queued_jobs last result", "journalctl -u whiteboard-worker --no-pager 2>&1 | grep 'fetch_queued' | tail -5")
run("5. jobs found count", "journalctl -u whiteboard-worker --no-pager 2>&1 | grep 'Found' | tail -5")
run("6. mark_processing ever called", "journalctl -u whiteboard-worker --no-pager 2>&1 | grep 'mark_processing' | tail -5")
run("7. mark_done ever called", "journalctl -u whiteboard-worker --no-pager 2>&1 | grep 'mark_done' | tail -5")
run("8. storage upload ever done", "journalctl -u whiteboard-worker --no-pager 2>&1 | grep 'storage/v1/object' | tail -5")
run("9. any errors in last 50 lines", "journalctl -u whiteboard-worker -n 50 --no-pager 2>&1 | grep -i 'error\\|traceback\\|exception' | tail -10")

ssh.close()
print(f"\nTimestamp: {datetime.now().isoformat()}")
