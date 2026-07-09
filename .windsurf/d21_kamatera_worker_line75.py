#!/usr/bin/env python3
"""D21 - Lire précisément autour de la ligne 75 du worker"""
import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect("185.167.97.144", username="root", password="Nexiomgroup@Academia0", timeout=20)

def run(label, cmd):
    _, out, _ = ssh.exec_command(cmd, timeout=20)
    o = out.read().decode("utf-8", errors="replace").strip()
    print(f"=== {label} ===")
    print(o[:3000])
    print()

run("worker lines 60-90 (around line 75)", "sed -n '60,95p' /opt/whiteboard-worker/whiteboard_render_worker.py")
run("worker lines 1-60", "sed -n '1,60p' /opt/whiteboard-worker/whiteboard_render_worker.py")
run("worker.log - first 10 lines only", "head -10 /opt/whiteboard-worker/worker.log")
run("worker.log - last 10 lines", "tail -10 /opt/whiteboard-worker/worker.log")
run("journald last 20 (current process)", "journalctl -u whiteboard-worker -n 20 --no-pager 2>&1")
run("worker.log - wc lines", "wc -l /opt/whiteboard-worker/worker.log")
run("worker.log - grep fetch_queued_jobs RPC", "grep 'fetch_queued_jobs' /opt/whiteboard-worker/worker.log | tail -5")
run("worker.log - date of first line", "head -1 /opt/whiteboard-worker/worker.log")
run("worker.log - date of last line", "tail -1 /opt/whiteboard-worker/worker.log")

ssh.close()
