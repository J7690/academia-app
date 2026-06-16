"""
AUDIT: Video download watermark pipeline
- Vérifie les RPCs d'export watermarked
- Vérifie le worker Kamatera
- Teste le flux complet
"""
import requests
import paramiko
import json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}", "Content-Type": "application/json"}
VPS_IP = "185.167.96.214"

def sql(q):
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_sql", headers=H, json={"sql_query": q})
    return r.json() if r.status_code == 200 else f"ERR {r.status_code}: {r.text[:200]}"

print("=" * 70)
print("AUDIT: Pipeline téléchargement vidéo avec watermark")
print("=" * 70)

# 1. Vérifier si les RPCs existent
print("\n── 1. RPCs D'EXPORT WATERMARK ──")
for rpc in [
    'app_student_request_video_export_watermarked',
    'app_student_get_video_export_watermarked_status',
]:
    data = sql(f"SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = '{rpc}'")
    exists = data and isinstance(data, list) and data[0].get('count', 0) > 0
    print(f"  {'✅' if exists else '❌'} {rpc}: {'existe' if exists else 'MANQUANTE'}")

# 2. Voir le source code des RPCs
print("\n── 2. SOURCE DES RPCs ──")
for rpc in [
    'app_student_request_video_export_watermarked',
    'app_student_get_video_export_watermarked_status',
]:
    src = sql(f"SELECT prosrc FROM pg_proc WHERE proname = '{rpc}'")
    if isinstance(src, list) and src:
        print(f"\n  === {rpc} ===")
        print(f"  {src[0].get('prosrc', 'N/A')[:800]}")
    else:
        print(f"\n  === {rpc} === NOT FOUND: {src}")

# 3. Vérifier la table video_processing_jobs
print("\n── 3. TABLE video_processing_jobs ──")
data = sql("SELECT job_type, status, COUNT(*) FROM app.video_processing_jobs GROUP BY job_type, status ORDER BY job_type, status")
if isinstance(data, list):
    for row in data:
        print(f"  {row.get('job_type','?'):30s} | {row.get('status','?'):15s} | {row.get('count','?')}")
else:
    print(f"  ERR: {data}")

# 4. Vérifier les jobs watermark récents
print("\n── 4. JOBS WATERMARK RÉCENTS ──")
data = sql("""
    SELECT id, video_asset_id, job_type, status, error_message, 
           created_at, updated_at 
    FROM app.video_processing_jobs 
    WHERE job_type ILIKE '%watermark%' OR job_type ILIKE '%export%'
    ORDER BY created_at DESC LIMIT 10
""")
if isinstance(data, list):
    if not data:
        print("  ⚠️ AUCUN job watermark/export trouvé!")
    for row in data:
        print(f"  [{row.get('status','?'):10s}] {row.get('job_type','?')} | asset={row.get('video_asset_id','?')[:8]}... | err={row.get('error_message','none')} | {row.get('created_at','?')}")
else:
    print(f"  ERR: {data}")

# 5. Vérifier les renditions (export_watermarked)
print("\n── 5. RENDITIONS export_watermarked ──")
data = sql("""
    SELECT COUNT(*) as total,
           COUNT(*) FILTER (WHERE rendition_type = 'export_watermarked') as watermarked_count
    FROM app.video_renditions
""")
if isinstance(data, list) and data:
    print(f"  Total renditions: {data[0].get('total','?')}")
    print(f"  Watermarked renditions: {data[0].get('watermarked_count','?')}")
else:
    print(f"  ERR: {data}")

# 6. Vérifier le worker Kamatera
print("\n── 6. VPS KAMATERA — WORKER STATUS ──")
try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(VPS_IP, username='root', password='Wenden@Koote2026', timeout=15)
    
    for cmd, label in [
        ("systemctl is-active academia-video-worker", "Worker service"),
        ("tail -20 /var/log/academia-video-worker.log 2>/dev/null || echo 'NO LOG'", "Worker logs (last 20)"),
        ("cat /opt/academia-worker/worker.js 2>/dev/null | head -5 || echo 'NO WORKER SCRIPT'", "Worker script"),
        ("cat /opt/academia-worker/config.json 2>/dev/null | head -10 || echo 'NO CONFIG'", "Worker config"),
    ]:
        _, stdout, stderr = ssh.exec_command(cmd, timeout=10)
        out = stdout.read().decode().strip()
        err = stderr.read().decode().strip()
        print(f"\n  === {label} ===")
        print(f"  {out[:500]}")
        if err:
            print(f"  STDERR: {err[:200]}")
    
    # Check if worker polls for jobs
    _, stdout, _ = ssh.exec_command("grep -i 'watermark\\|export\\|poll\\|process' /opt/academia-worker/worker.js 2>/dev/null | head -20", timeout=10)
    out = stdout.read().decode().strip()
    print(f"\n  === Worker watermark/export references ===")
    print(f"  {out[:500] if out else 'NONE FOUND'}")
    
    ssh.close()
except Exception as e:
    print(f"  SSH ERROR: {e}")

# 7. Tester la RPC avec un faux asset ID pour voir la réponse
print("\n── 7. TEST RPC request_video_export_watermarked ──")
r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/app_student_request_video_export_watermarked",
    headers=H, json={"p_video_asset_id": "00000000-0000-0000-0000-000000000000"})
print(f"  HTTP {r.status_code}: {r.text[:300]}")

# 8. Tester la RPC status
print("\n── 8. TEST RPC get_video_export_watermarked_status ──")
r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/app_student_get_video_export_watermarked_status",
    headers=H, json={"p_video_asset_id": "00000000-0000-0000-0000-000000000000"})
print(f"  HTTP {r.status_code}: {r.text[:300]}")

# 9. Tester avec un vrai video_asset_id
print("\n── 9. TEST AVEC UN VRAI VIDEO ASSET ──")
data = sql("SELECT id FROM app.video_assets ORDER BY created_at DESC LIMIT 1")
if isinstance(data, list) and data:
    real_id = data[0]['id']
    print(f"  Dernier video_asset: {real_id}")
    
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/app_student_request_video_export_watermarked",
        headers=H, json={"p_video_asset_id": real_id})
    print(f"  request: HTTP {r.status_code}: {r.text[:300]}")
    
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/app_student_get_video_export_watermarked_status",
        headers=H, json={"p_video_asset_id": real_id})
    print(f"  status:  HTTP {r.status_code}: {r.text[:300]}")

print("\n" + "=" * 70)
print("FIN AUDIT")
print("=" * 70)
