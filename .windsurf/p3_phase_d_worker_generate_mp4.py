#!/usr/bin/env python3
import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== PHASE D: AUDIT WORKER - JOBS GENERATE_MP4 ===\n")

# 1. Logs avec filtre "generate_mp4" pour voir les jobs réellement traités
stdin, stdout, stderr = client.exec_command('journalctl -u video-worker.service --since "24 hours ago" --no-pager | grep -i generate_mp4')
logs_generate_mp4 = stdout.read().decode().strip()
print('LOGS AVEC FILTRE "GENERATE_MP4":')
print(logs_generate_mp4[:5000])
print()

# 2. Logs avec filtre "generate_hls" pour voir les jobs HLS
stdin, stdout, stderr = client.exec_command('journalctl -u video-worker.service --since "24 hours ago" --no-pager | grep -i generate_hls')
logs_generate_hls = stdout.read().decode().strip()
print('LOGS AVEC FILTRE "GENERATE_HLS":')
print(logs_generate_hls[:5000])
print()

# 3. Logs avec filtre "VideoAsset" pour voir les traitements réels
stdin, stdout, stderr = client.exec_command('journalctl -u video-worker.service --since "24 hours ago" --no-pager | grep -i VideoAsset')
logs_videoasset = stdout.read().decode().strip()
print('LOGS AVEC FILTRE "VIDEOASSET":')
print(logs_videoasset[:5000])
print()

client.close()
