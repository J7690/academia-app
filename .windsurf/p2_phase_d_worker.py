#!/usr/bin/env python3
import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== PHASE D: VALIDATION DU WORKER ===\n")

# 1. Vérifier si le conteneur worker existe
stdin, stdout, stderr = client.exec_command('docker ps -a | grep videoasset-worker')
worker_container = stdout.read().decode().strip()
print('DOCKER CONTAINER WORKER:')
print(worker_container if worker_container else 'CONTENEUR NON TROUVÉ')
print()

# 2. Vérifier les processus Python actifs
stdin, stdout, stderr = client.exec_command('ps aux | grep python | grep -v grep')
python_processes = stdout.read().decode().strip()
print('PROCESSUS PYTHON ACTIFS:')
print(python_processes if python_processes else 'AUCUN PROCESSUS PYTHON')
print()

# 3. Vérifier les services systemd liés au worker
stdin, stdout, stderr = client.exec_command('systemctl list-units --type=service --state=running | grep -i video')
video_services = stdout.read().decode().strip()
print('SERVICES SYSTEMD VIDEO:')
print(video_services if video_services else 'AUCUN SERVICE VIDEO')
print()

# 4. Vérifier les cron jobs
stdin, stdout, stderr = client.exec_command('crontab -l 2>/dev/null || echo NO_CRON')
cron_jobs = stdout.read().decode().strip()
print('CRON JOBS:')
print(cron_jobs)
print()

# 5. Vérifier les logs Docker si le conteneur existe
if 'videoasset-worker' in worker_container.lower():
    stdin, stdout, stderr = client.exec_command('docker logs --tail 50 videoasset-worker 2>/dev/null || echo NO_LOGS')
    docker_logs = stdout.read().decode().strip()
    print('DOCKER LOGS WORKER:')
    print(docker_logs[:2000])
    print()

client.close()
