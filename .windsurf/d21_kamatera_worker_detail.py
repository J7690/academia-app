#!/usr/bin/env python3
"""D21 - Lire les détails critiques du worker"""
import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect("185.167.97.144", username="root", password="Nexiomgroup@Academia0", timeout=20)

def run(label, cmd):
    _, out, _ = ssh.exec_command(cmd, timeout=20)
    o = out.read().decode("utf-8", errors="replace").strip()
    print(f"=== {label} ===")
    print(o[:2000])
    print()

run("worker lines 50-130", "sed -n '50,130p' /opt/whiteboard-worker/whiteboard_render_worker.py")
run("worker lines 130-200", "sed -n '130,200p' /opt/whiteboard-worker/whiteboard_render_worker.py")
run("worker.log first 60 lines", "head -60 /opt/whiteboard-worker/worker.log")
run("worker.log grep 404", "grep '404' /opt/whiteboard-worker/worker.log | tail -10")
run("worker.log grep fetch_queued", "grep 'fetch_queued' /opt/whiteboard-worker/worker.log | tail -10")
run("worker.log grep 'whiteboard_renders'", "grep 'whiteboard_renders' /opt/whiteboard-worker/worker.log | tail -10")
run("whiteboard_renders 404 count", "grep -c '404' /opt/whiteboard-worker/worker.log || echo 0")

ssh.close()
