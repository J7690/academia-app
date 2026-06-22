#!/usr/bin/env python3
import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== PHASE A: RESSOURCES VPS KAMATERA ===\n")

# 1. CPU disponibles
stdin, stdout, stderr = client.exec_command('nproc')
cpu_cores = stdout.read().decode().strip()
print('CPU CORES:', cpu_cores)

# 2. CPU modèle
stdin, stdout, stderr = client.exec_command('lscpu | grep "Model name"')
cpu_model = stdout.read().decode().strip()
print('CPU MODEL:', cpu_model)

# 3. Charge CPU moyenne (1, 5, 15 min)
stdin, stdout, stderr = client.exec_command('cat /proc/loadavg')
loadavg = stdout.read().decode().strip()
print('LOAD AVG:', loadavg)

# 4. RAM totale
stdin, stdout, stderr = client.exec_command('free -m | grep Mem')
ram = stdout.read().decode().strip()
print('RAM TOTAL:', ram)

# 5. RAM disponible
stdin, stdout, stderr = client.exec_command('free -m | grep Mem')
ram_available = stdout.read().decode().strip()
print('RAM AVAILABLE:', ram_available)

# 6. Charge mémoire moyenne
stdin, stdout, stderr = client.exec_command('free -m')
mem_usage = stdout.read().decode().strip()
print('MEM USAGE:', mem_usage)

# 7. Espace disque total
stdin, stdout, stderr = client.exec_command('df -h / | tail -1')
disk_total = stdout.read().decode().strip()
print('DISK TOTAL:', disk_total)

# 8. Espace disque disponible
stdin, stdout, stderr = client.exec_command('df -h / | tail -1')
disk_available = stdout.read().decode().strip()
print('DISK AVAILABLE:', disk_available)

# 9. Charge disque moyenne (I/O)
stdin, stdout, stderr = client.exec_command('iostat -x 1 1 2>/dev/null || echo IOSTAT_NOT_INSTALLED')
iostat = stdout.read().decode().strip()
print('IOSTAT:', iostat[:1000] if iostat != 'IOSTAT_NOT_INSTALLED' else iostat)

# 10. Utilisation disque actuelle
stdin, stdout, stderr = client.exec_command('df -h')
disk_usage = stdout.read().decode().strip()
print('DISK USAGE:', disk_usage)

client.close()
