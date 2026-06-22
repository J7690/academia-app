#!/usr/bin/env python3
import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== CARACTÉRISTIQUES KAMATERA ===\n")

# 1. Vérifier les services système (LiveKit, Redis, Nginx)
stdin, stdout, stderr = client.exec_command('systemctl list-units --type=service --state=running | grep -E "(livekit|redis|nginx)" || echo NO_SERVICES_FOUND')
services = stdout.read().decode().strip()
print('SERVICES RUNNING:')
print(services)
print()

# 2. Vérifier LiveKit spécifiquement
stdin, stdout, stderr = client.exec_command('systemctl status livekit-server 2>/dev/null || echo LIVEKIT_NOT_FOUND')
livekit_status = stdout.read().decode().strip()
print('LIVEKIT STATUS:')
print(livekit_status[:1000])
print()

# 3. Vérifier Redis
stdin, stdout, stderr = client.exec_command('systemctl status redis 2>/dev/null || systemctl status redis-server 2>/dev/null || echo REDIS_NOT_FOUND')
redis_status = stdout.read().decode().strip()
print('REDIS STATUS:')
print(redis_status[:1000])
print()

# 4. Vérifier Nginx
stdin, stdout, stderr = client.exec_command('systemctl status nginx 2>/dev/null || echo NGINX_NOT_FOUND')
nginx_status = stdout.read().decode().strip()
print('NGINX STATUS:')
print(nginx_status[:1000])
print()

# 5. Vérifier les ports ouverts
stdin, stdout, stderr = client.exec_command('netstat -tlnp 2>/dev/null | grep -E "(7880|6379|80)" || ss -tlnp 2>/dev/null | grep -E "(7880|6379|80)" || echo PORTS_NOT_FOUND')
ports = stdout.read().decode().strip()
print('OPEN PORTS:')
print(ports)
print()

# 6. Vérifier FFmpeg
stdin, stdout, stderr = client.exec_command('which ffmpeg && ffmpeg -version | head -1 || echo FFMPEG_NOT_FOUND')
ffmpeg = stdout.read().decode().strip()
print('FFMPEG:')
print(ffmpeg)
print()

# 7. Vérifier Docker
stdin, stdout, stderr = client.exec_command('which docker && docker --version || echo DOCKER_NOT_FOUND')
docker = stdout.read().decode().strip()
print('DOCKER:')
print(docker)
print()

# 8. Vérifier les conteneurs Docker
stdin, stdout, stderr = client.exec_command('docker ps -a 2>/dev/null || echo NO_DOCKER_CONTAINERS')
containers = stdout.read().decode().strip()
print('DOCKER CONTAINERS:')
print(containers[:2000])
print()

# 9. Vérifier l'espace disque
stdin, stdout, stderr = client.exec_command('df -h')
disk = stdout.read().decode().strip()
print('DISK SPACE:')
print(disk)
print()

# 10. Vérifier la RAM
stdin, stdout, stderr = client.exec_command('free -h')
ram = stdout.read().decode().strip()
print('RAM:')
print(ram)
print()

# 11. Vérifier le CPU
stdin, stdout, stderr = client.exec_command('nproc')
cpu = stdout.read().decode().strip()
print('CPU CORES:')
print(cpu)
print()

# 12. Vérifier l'OS
stdin, stdout, stderr = client.exec_command('cat /etc/os-release | grep PRETTY_NAME')
os_info = stdout.read().decode().strip()
print('OS:')
print(os_info)
print()

client.close()
