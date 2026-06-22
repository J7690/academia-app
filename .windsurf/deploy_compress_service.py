#!/usr/bin/env python3
import paramiko
import os

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== DÉPLOIEMENT SERVICE COMPRESSION KAMATERA ===\n")

# 1. Créer le répertoire du service
stdin, stdout, stderr = client.exec_command('mkdir -p /root/compress-service')
stdout.read()

# 2. Créer le fichier de service Python
service_code = '''#!/usr/bin/env python3
from flask import Flask, request, jsonify
import requests
import subprocess
import os
import tempfile
import shutil
from urllib.parse import urlparse

app = Flask(__name__)

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

def download_file(url, dest_path):
    """Download file from URL to dest_path"""
    response = requests.get(url, stream=True, timeout=300)
    response.raise_for_status()
    with open(dest_path, 'wb') as f:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)
    return os.path.getsize(dest_path)

def upload_to_supabase(file_path, bucket, storage_path):
    """Upload file to Supabase Storage"""
    url = f"{SUPABASE_URL}/storage/v1/object/{bucket}/{storage_path}"
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "video/mp4"
    }
    
    with open(file_path, 'rb') as f:
        response = requests.put(url, headers=headers, data=f, timeout=300)
    response.raise_for_status()
    return True

def compress_video(input_path, output_path, quality='medium', watermark=True):
    """Compress video with FFmpeg and add watermark"""
    # Quality settings
    quality_settings = {
        'low': {'crf': 28, 'preset': 'fast', 'scale': '1280:720'},
        'medium': {'crf': 23, 'preset': 'medium', 'scale': '1920:1080'},
        'high': {'crf': 18, 'preset': 'slow', 'scale': '1920:1080'}
    }
    
    settings = quality_settings.get(quality, quality_settings['medium'])
    
    # Build FFmpeg command
    cmd = [
        'ffmpeg', '-i', input_path,
        '-vf', f"scale={settings['scale']},drawtext=text='Academia':fontcolor=white:fontsize=48:x=10:y=H-th-10:box=1:boxcolor=black@0.5" if watermark else f"scale={settings['scale']}",
        '-c:v', 'libx264',
        '-preset', settings['preset'],
        '-crf', str(settings['crf']),
        '-c:a', 'aac',
        '-b:a', '128k',
        '-movflags', '+faststart',
        '-y',
        output_path
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=1800)
    if result.returncode != 0:
        raise Exception(f"FFmpeg error: {result.stderr}")
    
    return os.path.getsize(output_path)

@app.route('/compress', methods=['POST'])
def compress():
    try:
        data = request.json
        source_url = data.get('source_url')
        output_bucket = data.get('output_bucket')
        output_path = data.get('output_path')
        quality = data.get('quality', 'medium')
        watermark = data.get('watermark', True)
        
        if not source_url or not output_bucket or not output_path:
            return jsonify({'success': False, 'error': 'Missing required parameters'}), 400
        
        print(f"[COMPRESS] Processing: {source_url}")
        
        # Create temp directory
        temp_dir = tempfile.mkdtemp()
        input_path = os.path.join(temp_dir, 'input.mp4')
        output_path_local = os.path.join(temp_dir, 'output.mp4')
        
        try:
            # Download
            print("[COMPRESS] Downloading...")
            original_size = download_file(source_url, input_path)
            print(f"[COMPRESS] Original size: {original_size} bytes")
            
            # Compress
            print("[COMPRESS] Compressing...")
            import time
            start_time = time.time()
            compressed_size = compress_video(input_path, output_path_local, quality, watermark)
            processing_time = time.time() - start_time
            print(f"[COMPRESS] Compressed size: {compressed_size} bytes")
            print(f"[COMPRESS] Processing time: {processing_time:.2f}s")
            
            # Upload
            print("[COMPRESS] Uploading...")
            upload_to_supabase(output_path_local, output_bucket, output_path)
            print("[COMPRESS] Upload complete")
            
            compression_ratio = (1 - compressed_size / original_size) * 100 if original_size > 0 else 0
            
            return jsonify({
                'success': True,
                'output_path': output_path,
                'original_size': original_size,
                'compressed_size': compressed_size,
                'compression_ratio': round(compression_ratio, 2),
                'processing_time': round(processing_time, 2)
            })
            
        finally:
            # Cleanup
            shutil.rmtree(temp_dir, ignore_errors=True)
            
    except Exception as e:
        print(f"[COMPRESS] Error: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)
'''

sftp = client.open_sftp()
with sftp.file('/root/compress-service/app.py', 'w') as f:
    f.write(service_code)
sftp.close()

print("✓ Service Python créé: /root/compress-service/app.py")

# 3. Créer le fichier requirements.txt
requirements = '''flask==3.0.0
requests==2.31.0
'''

sftp = client.open_sftp()
with sftp.file('/root/compress-service/requirements.txt', 'w') as f:
    f.write(requirements)
sftp.close()

print("✓ Requirements.txt créé")

# 4. Installer les dépendances
stdin, stdout, stderr = client.exec_command('cd /root/compress-service && pip3 install -r requirements.txt')
stdout.read()
print("✓ Dépendances installées")

# 5. Créer le service systemd
service_file = '''[Unit]
Description=Academia Compress Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/compress-service
ExecStart=/usr/bin/python3 /root/compress-service/app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
'''

sftp = client.open_sftp()
with sftp.file('/etc/systemd/system/academia-compress.service', 'w') as f:
    f.write(service_file)
sftp.close()

print("✓ Service systemd créé")

# 6. Activer et démarrer le service
stdin, stdout, stderr = client.exec_command('systemctl daemon-reload')
stdout.read()

stdin, stdout, stderr = client.exec_command('systemctl enable academia-compress')
stdout.read()

stdin, stdout, stderr = client.exec_command('systemctl restart academia-compress')
stdout.read()

print("✓ Service academia-compress démarré")

# 7. Vérifier le statut
stdin, stdout, stderr = client.exec_command('systemctl status academia-compress')
status = stdout.read().decode()
print("\n=== STATUT SERVICE ===")
print(status[:500])

client.close()
print("\n=== DÉPLOIEMENT TERMINÉ ===")
