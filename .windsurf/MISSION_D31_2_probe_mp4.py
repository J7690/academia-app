#!/usr/bin/env python3
import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"
VIDEO_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/whiteboard-renders/renders/2becbe08-1d7b-427d-b7a8-f7660ba2256c/7eb641458ee940bc81dfff3591fc8f48.mp4"

def ssh_command(cmd):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS, timeout=20)
    stdin, stdout, stderr = ssh.exec_command(cmd)
    out = stdout.read().decode(errors='ignore')
    err = stderr.read().decode(errors='ignore')
    ssh.close()
    return out, err

# Download and probe
out, err = ssh_command(f"curl -L -o /tmp/d31_2_probe.mp4 '{VIDEO_URL}' && ffprobe -v error -show_entries stream=codec_type,duration,nb_frames -of csv=p=0 /tmp/d31_2_probe.mp4 && echo '---FORMAT---' && ffprobe -v error -show_entries format=duration,bit_rate -of csv=p=0 /tmp/d31_2_probe.mp4")
print(out)
print("ERR:", err)
