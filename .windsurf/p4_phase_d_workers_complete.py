#!/usr/bin/env python3
import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== PHASE D: AUDIT COMPLET DES WORKERS ===\n")

# 1. ps aux
stdin, stdout, stderr = client.exec_command('ps aux | head -50')
ps_aux = stdout.read().decode().strip()
print('PS AUX (head 50):')
print(ps_aux)
print()

# 2. docker ps -a
stdin, stdout, stderr = client.exec_command('docker ps -a')
docker_ps = stdout.read().decode().strip()
print('DOCKER PS -A:')
print(docker_ps)
print()

# 3. docker images
stdin, stdout, stderr = client.exec_command('docker images')
docker_images = stdout.read().decode().strip()
print('DOCKER IMAGES:')
print(docker_images)
print()

# 4. systemctl list-units --type=service
stdin, stdout, stderr = client.exec_command('systemctl list-units --type=service --state=running | head -30')
systemctl_services = stdout.read().decode().strip()
print('SYSTEMCTL SERVICES (running, head 30):')
print(systemctl_services)
print()

# 5. crontab -l
stdin, stdout, stderr = client.exec_command('crontab -l 2>/dev/null || echo NO_CRON')
crontab = stdout.read().decode().strip()
print('CRONTAB (root):')
print(crontab)
print()

# 6. find /etc/systemd -name "*.service" | grep -i video
stdin, stdout, stderr = client.exec_command('find /etc/systemd -name "*.service" 2>/dev/null | grep -i video')
systemd_video = stdout.read().decode().strip()
print('SYSTEMD VIDEO SERVICES:')
print(systemd_video)
print()

client.close()
