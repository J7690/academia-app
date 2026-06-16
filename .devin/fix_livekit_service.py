import paramiko
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('185.167.96.214', username='root', password='Wenden@Koote2026', timeout=15)

cmds = [
    ("systemctl list-units --type=service --state=running | grep -i live", "Running services with 'live'"),
    ("ss -tlnp | grep 7880", "Process listening on port 7880"),
    ("ps aux | grep -i livekit | grep -v grep", "LiveKit processes"),
    ("snap list 2>/dev/null | grep -i live", "Snap packages"),
    ("ls /etc/systemd/system/*livekit* 2>/dev/null || echo 'no systemd unit'", "Systemd units"),
    ("ls /root/livekit* 2>/dev/null /opt/livekit* 2>/dev/null || echo 'no livekit binary found'", "LiveKit binaries"),
]

for cmd, label in cmds:
    print(f"\n  {label}:")
    _, stdout, stderr = ssh.exec_command(cmd, timeout=10)
    out = stdout.read().decode().strip()
    err = stderr.read().decode().strip()
    if out:
        for line in out.split('\n')[:5]:
            print(f"    {line}")
    elif err:
        print(f"    [stderr] {err[:200]}")
    else:
        print(f"    (empty)")

ssh.close()
