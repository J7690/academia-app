"""
AUDIT PART 2: Diagnostiquer le worker et la table video_processing_jobs
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
    return r.json() if r.status_code == 200 else f"ERR {r.status_code}: {r.text[:300]}"

print("=" * 70)

# 1. Schema exacte de video_processing_jobs
print("\n── 1. COLONNES de video_processing_jobs ──")
data = sql("""
    SELECT column_name, data_type, is_nullable 
    FROM information_schema.columns 
    WHERE table_schema = 'app' AND table_name = 'video_processing_jobs'
    ORDER BY ordinal_position
""")
if isinstance(data, list):
    for row in data:
        print(f"  {row['column_name']:30s} {row['data_type']:20s} {row['is_nullable']}")
else:
    print(f"  ERR: {data}")

# 2. Schema de video_renditions
print("\n── 2. COLONNES de video_renditions ──")
data = sql("""
    SELECT column_name, data_type, is_nullable 
    FROM information_schema.columns 
    WHERE table_schema = 'app' AND table_name = 'video_renditions'
    ORDER BY ordinal_position
""")
if isinstance(data, list):
    for row in data:
        print(f"  {row['column_name']:30s} {row['data_type']:20s} {row['is_nullable']}")
else:
    print(f"  ERR: {data}")

# 3. Source complète de la RPC request (troncated last time)
print("\n── 3. SOURCE COMPLÈTE: request_video_export_watermarked ──")
data = sql("SELECT prosrc FROM pg_proc WHERE proname = 'app_student_request_video_export_watermarked'")
if isinstance(data, list) and data:
    print(data[0].get('prosrc', 'N/A'))
else:
    print(f"  ERR: {data}")

# 4. Source complète de la RPC status
print("\n── 4. SOURCE COMPLÈTE: get_video_export_watermarked_status ──")
data = sql("SELECT prosrc FROM pg_proc WHERE proname = 'app_student_get_video_export_watermarked_status'")
if isinstance(data, list) and data:
    print(data[0].get('prosrc', 'N/A'))
else:
    print(f"  ERR: {data}")

# 5. Jobs export_watermarked détails
print("\n── 5. JOBS export_watermarked DÉTAILS ──")
data = sql("""
    SELECT id, video_asset_id, job_type, status, error, result,
           created_at, updated_at 
    FROM app.video_processing_jobs 
    WHERE job_type = 'export_watermarked'
    ORDER BY created_at DESC LIMIT 10
""")
if isinstance(data, list):
    for row in data:
        print(f"  [{row.get('status','?'):10s}] id={str(row.get('id','?'))[:8]}... asset={str(row.get('video_asset_id','?'))[:8]}...")
        print(f"    error={row.get('error','none')}")
        print(f"    result={str(row.get('result','none'))[:200]}")
        print(f"    created={row.get('created_at','?')} updated={row.get('updated_at','?')}")
else:
    print(f"  ERR: {data}")

# 6. Worker script complet
print("\n── 6. WORKER SCRIPT COMPLET ──")
try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(VPS_IP, username='root', password='Wenden@Koote2026', timeout=15)
    
    # Find the actual worker script
    _, stdout, _ = ssh.exec_command("find /opt/academia-worker -name '*.js' -o -name '*.py' -o -name '*.sh' 2>/dev/null", timeout=10)
    files = stdout.read().decode().strip()
    print(f"  Worker files: {files}")
    
    # Read main worker
    for ext in ['worker.py', 'worker.js', 'main.py', 'main.js', 'index.js', 'process.py']:
        _, stdout, _ = ssh.exec_command(f"cat /opt/academia-worker/{ext} 2>/dev/null | head -5", timeout=10)
        out = stdout.read().decode().strip()
        if out:
            print(f"\n  === /opt/academia-worker/{ext} (first 5 lines) ===")
            print(f"  {out}")
    
    # Check systemd service file
    _, stdout, _ = ssh.exec_command("cat /etc/systemd/system/academia-video-worker.service 2>/dev/null", timeout=10)
    out = stdout.read().decode().strip()
    print(f"\n  === systemd service ===")
    print(f"  {out[:500]}")
    
    # Last 50 lines of log
    _, stdout, _ = ssh.exec_command("tail -50 /var/log/academia-video-worker.log 2>/dev/null", timeout=10)
    out = stdout.read().decode().strip()
    print(f"\n  === Last 50 log lines ===")
    print(out[-1500:] if len(out) > 1500 else out)
    
    ssh.close()
except Exception as e:
    print(f"  SSH ERROR: {e}")

print("\n" + "=" * 70)
