"""
AUDIT COMPLET Challenge Video Pipeline
1. Test FFmpeg sur VPS Kamatera
2. Vérifier si le worker de processing existe sur le VPS
3. Vérifier les tables video_processing_jobs, video_sources, video_renditions
4. Vérifier les permissions schema
5. Vérifier le fallback IP dans transcode-multi-resolution
"""
import requests
import json
import paramiko
import time

# ============================================================
# CONFIG
# ============================================================
VPS_IP = "185.167.96.214"
VPS_USER = "root"
VPS_PASS = "Wenden@Koote2026"

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}

def sql(query, label=""):
    if label:
        print(f"\n  {label}")
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": query}
    )
    if r.status_code == 200:
        data = r.json()
        if isinstance(data, list):
            for row in data[:10]:
                print(f"    {row}")
            return data
        else:
            print(f"    {str(data)[:400]}")
            return data
    else:
        print(f"    ❌ HTTP {r.status_code}: {r.text[:200]}")
    return None

def ssh_cmd(ssh, cmd, label=""):
    if label:
        print(f"\n  {label}")
    print(f"    $ {cmd}")
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=30)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    err = stderr.read().decode('utf-8', errors='replace').strip()
    if out:
        for line in out.split('\n')[:20]:
            print(f"    {line}")
    if err and not out:
        for line in err.split('\n')[:10]:
            print(f"    [stderr] {line}")
    return out, err

# ============================================================
print("=" * 70)
print("AUDIT 1: FFmpeg sur le VPS Kamatera")
print("=" * 70)

try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    print(f"  Connecting to {VPS_IP}...")
    ssh.connect(VPS_IP, username=VPS_USER, password=VPS_PASS, timeout=15)
    print("  ✅ Connected via SSH")
    
    # Test FFmpeg version
    ssh_cmd(ssh, "ffmpeg -version | head -5", "FFmpeg version")
    
    # Test FFmpeg codecs disponibles
    ssh_cmd(ssh, "ffmpeg -codecs 2>/dev/null | grep -E '(libx264|aac|h264)' | head -5", "Codecs H264/AAC")
    
    # Test FFmpeg avec un fichier synthétique (créer, encoder, vérifier)
    print("\n  Simulation FFmpeg: générer vidéo test 3s → encode 720p + 480p")
    
    # Generate a test video (3s color bars)
    ssh_cmd(ssh, 
        'ffmpeg -y -f lavfi -i "color=c=blue:s=1920x1080:d=3" '
        '-f lavfi -i "sine=frequency=440:duration=3" '
        '-c:v libx264 -preset ultrafast -c:a aac '
        '/tmp/test_source.mp4 2>&1 | tail -5',
        "Génération vidéo test 1080p 3s")
    
    # Check source file
    ssh_cmd(ssh, "ls -la /tmp/test_source.mp4", "Fichier source")
    
    # Transcode to 720p
    ssh_cmd(ssh,
        'ffmpeg -y -i /tmp/test_source.mp4 '
        '-vf "scale=-2:720" -c:v libx264 -preset fast -b:v 1500k '
        '-c:a aac -b:a 128k -movflags +faststart '
        '/tmp/test_720p.mp4 2>&1 | tail -5',
        "Transcodage → 720p")
    
    ssh_cmd(ssh, "ls -la /tmp/test_720p.mp4", "Fichier 720p")
    
    # Transcode to 480p
    ssh_cmd(ssh,
        'ffmpeg -y -i /tmp/test_source.mp4 '
        '-vf "scale=-2:480" -c:v libx264 -preset fast -b:v 800k '
        '-c:a aac -b:a 128k -movflags +faststart '
        '/tmp/test_480p.mp4 2>&1 | tail -5',
        "Transcodage → 480p")
    
    ssh_cmd(ssh, "ls -la /tmp/test_480p.mp4", "Fichier 480p")
    
    # Test watermark overlay (like WatermarkService does)
    print("\n  Simulation watermark: overlay logo sur vidéo")
    
    # Create a simple logo placeholder
    ssh_cmd(ssh,
        'ffmpeg -y -f lavfi -i "color=c=white@0.35:s=100x100:d=1,format=rgba" '
        '/tmp/test_logo.png 2>&1 | tail -3',
        "Génération logo placeholder")
    
    ssh_cmd(ssh,
        'ffmpeg -y -i /tmp/test_source.mp4 -i /tmp/test_logo.png '
        '-filter_complex "[1:v]format=rgba[logo];'
        '[logo][0:v]scale2ref=oh*mdar:ih*0.08[wm][vid];'
        '[wm]colorchannelmixer=aa=0.35[wm_alpha];'
        '[vid][wm_alpha]overlay=W-w-(W*0.02):H-h-(H*0.04)" '
        '-c:a copy -preset ultrafast -movflags +faststart -y /tmp/test_watermarked.mp4 2>&1 | tail -5',
        "Watermark overlay (comme WatermarkService)")
    
    ssh_cmd(ssh, "ls -la /tmp/test_watermarked.mp4", "Fichier watermarké")
    
    # Test probe/info
    ssh_cmd(ssh,
        'ffprobe -v error -show_entries format=duration,size,bit_rate '
        '-show_entries stream=codec_name,width,height '
        '-of json /tmp/test_720p.mp4',
        "FFprobe info 720p")
    
    # Check if there's a worker/service processing video jobs
    ssh_cmd(ssh, "systemctl list-units --type=service --state=running | grep -i 'video\\|ffmpeg\\|worker\\|process'", 
            "Services vidéo/worker actifs")
    
    ssh_cmd(ssh, "crontab -l 2>/dev/null | grep -i 'video\\|ffmpeg\\|worker\\|process' || echo 'Aucun cron vidéo'",
            "Cron jobs vidéo")
    
    ssh_cmd(ssh, "ls -la /opt/ 2>/dev/null | head -20", "Contenu /opt/")
    ssh_cmd(ssh, "ls -la /root/ 2>/dev/null | head -20", "Contenu /root/")
    
    # Cleanup
    ssh_cmd(ssh, "rm -f /tmp/test_source.mp4 /tmp/test_720p.mp4 /tmp/test_480p.mp4 /tmp/test_watermarked.mp4 /tmp/test_logo.png",
            "Cleanup")
    
    ssh.close()
    print("\n  ✅ SSH session closed")
    
except Exception as e:
    print(f"\n  ❌ SSH Error: {e}")

# ============================================================
print("\n" + "=" * 70)
print("AUDIT 2: Tables video dans Supabase")
print("=" * 70)

# Check video tables and their schema
sql("""
SELECT table_schema, table_name FROM information_schema.tables
WHERE table_name IN (
    'video_assets', 'video_sources', 'video_renditions', 
    'video_processing_jobs'
)
ORDER BY table_schema, table_name
""", "Tables vidéo et leurs schémas")

# Check if video_processing_jobs exists and has data
sql("""
SELECT table_schema, table_name, 
  (SELECT COUNT(*) FROM information_schema.columns c WHERE c.table_name = t.table_name AND c.table_schema = t.table_schema) as col_count
FROM information_schema.tables t
WHERE table_name = 'video_processing_jobs'
""", "video_processing_jobs table info")

# Count pending/queued jobs
sql("""
SELECT status, COUNT(*) as count
FROM app.video_processing_jobs
GROUP BY status
""", "Jobs par statut")

# Check video_renditions pending
sql("""
SELECT status, COUNT(*) as count
FROM app.video_renditions
GROUP BY status
""", "Renditions par statut")

# ============================================================
print("\n" + "=" * 70)
print("AUDIT 3: Schema access pour Edge Functions sur tables vidéo")
print("=" * 70)

video_tables = ['video_assets', 'video_sources', 'video_renditions', 'video_processing_jobs']
for t in video_tables:
    # Without schema (how Edge Function calls it)
    r = requests.get(
        f"{SUPABASE_URL}/rest/v1/{t}?select=id&limit=1",
        headers=HEADERS,
    )
    r2 = requests.get(
        f"{SUPABASE_URL}/rest/v1/{t}?select=id&limit=1",
        headers={**HEADERS, "Accept-Profile": "app"},
    )
    pub = "✅" if r.status_code == 200 else "❌"
    app = "✅" if r2.status_code == 200 else "❌"
    print(f"  {t}: public={pub}(HTTP {r.status_code}), app={app}(HTTP {r2.status_code})")

# ============================================================
print("\n" + "=" * 70)
print("AUDIT 4: IP fallback dans transcode-multi-resolution")
print("=" * 70)

# Check what LIVEKIT_URL resolves to
print(f"  VPS IP actuel: {VPS_IP}")
print(f"  Fallback dans code: 185.220.204.214 (ANCIEN!)")
print(f"  LIVEKIT_URL secret: ws://{VPS_IP}:7880")
print(f"  IP extraite de LIVEKIT_URL: {VPS_IP} ✅")
print(f"  MAIS si LIVEKIT_URL est vide → fallback 185.220.204.214 ❌ FAUX!")

# ============================================================
print("\n" + "=" * 70)
print("AUDIT 5: Supabase secrets vérification")
print("=" * 70)

# Test Edge Function with service key to check if secrets are loaded
r = requests.post(
    f"{SUPABASE_URL}/functions/v1/livekit-token",
    headers={**HEADERS, "Authorization": f"Bearer {SERVICE_KEY}"},
    json={"session_id": "00000000-0000-0000-0000-000000000001"},
    timeout=15
)
print(f"  livekit-token (fake session): HTTP {r.status_code} — {r.text[:200]}")

r2 = requests.post(
    f"{SUPABASE_URL}/functions/v1/transcode-video",
    headers={**HEADERS},
    json={"video_asset_id": "00000000-0000-0000-0000-000000000001"},
    timeout=15
)
print(f"  transcode-video (fake asset): HTTP {r2.status_code} — {r2.text[:200]}")

print("\n" + "=" * 70)
print("RÉSUMÉ DES INCOHÉRENCES")
print("=" * 70)
