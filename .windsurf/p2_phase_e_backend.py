#!/usr/bin/env python3
import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== PHASE E: VALIDATION BACKEND PYTHON ===\n")

# 1. Vérifier les processus Python bobodo
stdin, stdout, stderr = client.exec_command('ps aux | grep bobodo | grep -v grep')
bobodo_processes = stdout.read().decode().strip()
print('PROCESSUS BOBODO:')
print(bobodo_processes)
print()

# 2. Vérifier le service bobodo
stdin, stdout, stderr = client.exec_command('systemctl status bobodo-vocal.service 2>/dev/null || systemctl status academia-backend.service 2>/dev/null || echo NO_BOBODO_SERVICE')
bobodo_service = stdout.read().decode().strip()
print('SERVICE BOBODO:')
print(bobodo_service[:2000])
print()

# 3. Vérifier les logs du backend
stdin, stdout, stderr = client.exec_command('journalctl -u bobodo-vocal.service --since "1 hour ago" --no-pager 2>/dev/null | tail -50 || journalctl -u academia-backend.service --since "1 hour ago" --no-pager 2>/dev/null | tail -50 || echo NO_LOGS')
backend_logs = stdout.read().decode().strip()
print('BACKEND LOGS (1 heure, tail 50):')
print(backend_logs[:3000])
print()

# 4. Vérifier le port 8000 (backend)
stdin, stdout, stderr = client.exec_command('netstat -tlnp 2>/dev/null | grep 8000 || ss -tlnp 2>/dev/null | grep 8000 || echo PORT_8000_NOT_FOUND')
port_8000 = stdout.read().decode().strip()
print('PORT 8000:')
print(port_8000)
print()

client.close()
