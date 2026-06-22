#!/usr/bin/env python3
import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== PHASE A: DOCKER KAMATERA ===\n")

# 1. Conteneurs actifs
stdin, stdout, stderr = client.exec_command('docker ps')
containers_active = stdout.read().decode().strip()
print('CONTAINERS ACTIVE:')
print(containers_active)
print()

# 2. Tous les conteneurs (y compris arrêtés)
stdin, stdout, stderr = client.exec_command('docker ps -a')
containers_all = stdout.read().decode().strip()
print('CONTAINERS ALL:')
print(containers_all)
print()

# 3. Images présentes
stdin, stdout, stderr = client.exec_command('docker images')
images = stdout.read().decode().strip()
print('DOCKER IMAGES:')
print(images)
print()

# 4. Réseaux Docker
stdin, stdout, stderr = client.exec_command('docker network ls')
networks = stdout.read().decode().strip()
print('DOCKER NETWORKS:')
print(networks)
print()

# 5. Volumes Docker
stdin, stdout, stderr = client.exec_command('docker volume ls')
volumes = stdout.read().decode().strip()
print('DOCKER VOLUMES:')
print(volumes)
print()

# 6. Espace occupé par Docker
stdin, stdout, stderr = client.exec_command('docker system df')
docker_df = stdout.read().decode().strip()
print('DOCKER DISK USAGE:')
print(docker_df)
print()

# 7. Stats conteneurs actifs
stdin, stdout, stderr = client.exec_command('docker stats --no-stream')
stats = stdout.read().decode().strip()
print('DOCKER STATS:')
print(stats)
print()

client.close()
