#!/usr/bin/env python3
import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

# Vérifier si piper est installé
stdin, stdout, stderr = client.exec_command('which piper || which piper-tts || echo NOT_FOUND')
print('Piper:', stdout.read().decode().strip())

# Vérifier les fichiers serveur
stdin, stdout, stderr = client.exec_command('ls -la /root/voice_server/ 2>/dev/null || echo DIR_NOT_FOUND')
print('Server dir:', stdout.read().decode().strip())

# Vérifier Python + websockets
stdin, stdout, stderr = client.exec_command('python3 -c "import websockets; print(\'websockets OK\')" 2>/dev/null || echo WEBSOCKETS_MISSING')
print('Websockets:', stdout.read().decode().strip())

client.close()
