#!/usr/bin/env python3
import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== PHASE A: FFMPEG KAMATERA ===\n")

# 1. Version installée
stdin, stdout, stderr = client.exec_command('ffmpeg -version')
ffmpeg_version = stdout.read().decode().strip()
print('FFMPEG VERSION:')
print(ffmpeg_version[:500])
print()

# 2. Codecs disponibles (encoders)
stdin, stdout, stderr = client.exec_command('ffmpeg -encoders')
encoders = stdout.read().decode().strip()
print('FFMPEG ENCODERS (H264/AAC):')
for line in encoders.split('\n'):
    if 'h264' in line.lower() or 'aac' in line.lower():
        print(line)
print()

# 3. Codecs disponibles (decoders)
stdin, stdout, stderr = client.exec_command('ffmpeg -decoders')
decoders = stdout.read().decode().strip()
print('FFMPEG DECODERS (H264/AAC):')
for line in decoders.split('\n'):
    if 'h264' in line.lower() or 'aac' in line.lower():
        print(line)
print()

# 4. Accélération matérielle
stdin, stdout, stderr = client.exec_command('ffmpeg -hwaccels')
hwaccels = stdout.read().decode().strip()
print('FFMPEG HW ACCELS:')
print(hwaccels)
print()

# 5. Filtres disponibles
stdin, stdout, stderr = client.exec_command('ffmpeg -filters 2>/dev/null | head -50')
filters = stdout.read().decode().strip()
print('FFMPEG FILTERS (first 50):')
print(filters)
print()

# 6. Formats supportés
stdin, stdout, stderr = client.exec_command('ffmpeg -formats 2>/dev/null | grep -E "(mp4|h264)" | head -20')
formats = stdout.read().decode().strip()
print('FFMPEG FORMATS (MP4/H264):')
print(formats)
print()

# 7. Protocoles supportés
stdin, stdout, stderr = client.exec_command('ffmpeg -protocols 2>/dev/null | head -20')
protocols = stdout.read().decode().strip()
print('FFMPEG PROTOCOLS (first 20):')
print(protocols)
print()

client.close()
