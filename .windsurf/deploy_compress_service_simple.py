#!/usr/bin/env python3
import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== DÉPLOIEMENT SERVICE COMPRESSION SIMPLE (SANS FLASK) ===\n")

# 1. Arrêter l'ancien service
stdin, stdout, stderr = client.exec_command('systemctl stop academia-compress')
stdout.read()
print("✓ Ancien service arrêté")

# 2. Créer un service HTTP simple avec http.server (builtin)
service_code = '''#!/usr/bin/env python3
import http.server
import socketserver
import json
import subprocess
import os
import tempfile
import shutil
import urllib.request
from urllib.parse import urlparse

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

class CompressHandler(http.server.BaseHTTPRequestHandler):
    def _set_cors_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')

    def do_OPTIONS(self):
        self.send_response(200)
        self._set_cors_headers()
        self.end_headers()

    def do_POST(self):
        if self.path == '/compress':
            try:
                content_length = int(self.headers['Content-Length'])
                post_data = self.rfile.read(content_length)
                data = json.loads(post_data.decode('utf-8'))
                
                source_url = data.get('source_url')
                output_bucket = data.get('output_bucket')
                output_path = data.get('output_path')
                quality = data.get('quality', 'medium')
                watermark = data.get('watermark', True)
                
                if not source_url or not output_bucket or not output_path:
                    self.send_error(400, "Missing required parameters")
                    return
                
                print(f"[COMPRESS] Processing: {source_url}")
                
                # Create temp directory
                temp_dir = tempfile.mkdtemp()
                input_path = os.path.join(temp_dir, 'input.mp4')
                output_path_local = os.path.join(temp_dir, 'output.mp4')
                
                try:
                    # Download
                    print("[COMPRESS] Downloading...")
                    urllib.request.urlretrieve(source_url, input_path)
                    original_size = os.path.getsize(input_path)
                    print(f"[COMPRESS] Original size: {original_size} bytes")
                    
                    # Compress
                    print("[COMPRESS] Compressing...")
                    import time
                    start_time = time.time()
                    
                    # Quality settings
                    quality_settings = {
                        'low': {'crf': 28, 'preset': 'fast', 'scale': '1280:720'},
                        'medium': {'crf': 23, 'preset': 'medium', 'scale': '1920:1080'},
                        'high': {'crf': 18, 'preset': 'slow', 'scale': '1920:1080'}
                    }
                    
                    settings = quality_settings.get(quality, quality_settings['medium'])
                    
                    # Build FFmpeg command
                    if watermark:
                        vf = f"scale={settings['scale']},drawtext=text='Academia':fontcolor=white:fontsize=48:x=10:y=H-th-10:box=1:boxcolor=black@0.5"
                    else:
                        vf = f"scale={settings['scale']}"
                    
                    cmd = [
                        'ffmpeg', '-i', input_path,
                        '-vf', vf,
                        '-c:v', 'libx264',
                        '-preset', settings['preset'],
                        '-crf', str(settings['crf']),
                        '-c:a', 'aac',
                        '-b:a', '128k',
                        '-movflags', '+faststart',
                        '-y',
                        output_path_local
                    ]
                    
                    result = subprocess.run(cmd, capture_output=True, text=True, timeout=1800)
                    if result.returncode != 0:
                        raise Exception(f"FFmpeg error: {result.stderr}")
                    
                    compressed_size = os.path.getsize(output_path_local)
                    processing_time = time.time() - start_time
                    print(f"[COMPRESS] Compressed size: {compressed_size} bytes")
                    print(f"[COMPRESS] Processing time: {processing_time:.2f}s")
                    
                    # Upload
                    print("[COMPRESS] Uploading...")
                    url = f"{SUPABASE_URL}/storage/v1/object/{output_bucket}/{output_path}"
                    headers = {
                        "apikey": SUPABASE_KEY,
                        "Authorization": f"Bearer {SUPABASE_KEY}",
                        "Content-Type": "video/mp4"
                    }
                    
                    req = urllib.request.Request(url, data=open(output_path_local, 'rb').read(), headers=headers)
                    urllib.request.urlopen(req)
                    print("[COMPRESS] Upload complete")
                    
                    compression_ratio = (1 - compressed_size / original_size) * 100 if original_size > 0 else 0
                    
                    response = {
                        'success': True,
                        'output_path': output_path,
                        'original_size': original_size,
                        'compressed_size': compressed_size,
                        'compression_ratio': round(compression_ratio, 2),
                        'processing_time': round(processing_time, 2)
                    }
                    
                    self.send_response(200)
                    self._set_cors_headers()
                    self.send_header('Content-type', 'application/json')
                    self.end_headers()
                    self.wfile.write(json.dumps(response).encode())
                    
                finally:
                    # Cleanup
                    shutil.rmtree(temp_dir, ignore_errors=True)
                    
            except Exception as e:
                print(f"[COMPRESS] Error: {str(e)}")
                self.send_error(500, str(e))
        else:
            self.send_error(404, "Not found")

if __name__ == '__main__':
    PORT = 8001
    with socketserver.TCPServer(("", PORT), CompressHandler) as httpd:
        print(f"Server running on port {PORT}")
        httpd.serve_forever()
'''

sftp = client.open_sftp()
with sftp.file('/root/compress-service/app.py', 'w') as f:
    f.write(service_code)
sftp.close()

print("✓ Service Python créé (sans Flask)")

# 3. Modifier le service systemd pour utiliser le nouveau port
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

print("✓ Service systemd mis à jour")

# 4. Redémarrer le service
stdin, stdout, stderr = client.exec_command('systemctl daemon-reload')
stdout.read()

stdin, stdout, stderr = client.exec_command('systemctl enable academia-compress')
stdout.read()

stdin, stdout, stderr = client.exec_command('systemctl restart academia-compress')
stdout.read()

print("✓ Service academia-compress redémarré")

# 5. Vérifier le statut
import time
time.sleep(3)

stdin, stdout, stderr = client.exec_command('systemctl status academia-compress')
status = stdout.read().decode()
print("\n=== STATUT SERVICE ===")
print(status[:500])

client.close()
print("\n=== DÉPLOIEMENT TERMINÉ ===")
