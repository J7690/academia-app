import requests
import paramiko
import time

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_sql", headers=H, json={"sql_query": q})
    return r.json() if r.status_code == 200 else f"ERR {r.status_code}: {r.text[:300]}"

print("── VÉRIFICATION POST-FIX ──\n")

# 1. Job status summary
print("1. Jobs export_watermarked:")
data = sql("SELECT status, COUNT(*) FROM app.video_processing_jobs WHERE job_type='export_watermarked' GROUP BY status")
if isinstance(data, list):
    for r in data:
        print(f"   {r['status']:10s}: {r['count']}")

# 2. Renditions export_watermarked
print("\n2. Renditions export_watermarked:")
data = sql("SELECT COUNT(*) as c FROM app.video_renditions WHERE rendition_key='export_watermarked' AND status='ready'")
if isinstance(data, list) and data:
    print(f"   Ready: {data[0]['c']}")

# 3. Check one watermarked URL
data = sql("SELECT public_url_hint FROM app.video_renditions WHERE rendition_key='export_watermarked' AND status='ready' ORDER BY created_at DESC LIMIT 1")
if isinstance(data, list) and data:
    url = data[0].get('public_url_hint', '')
    print(f"   URL: {url[:100]}")
    if url:
        r = requests.head(url, timeout=10)
        print(f"   HTTP HEAD: {r.status_code} ({r.headers.get('content-length', '?')} bytes)")

# 4. Worker logs
print("\n3. Worker logs (last 15):")
try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect("185.167.96.214", username='root', password='Wenden@Koote2026', timeout=15)
    _, stdout, _ = ssh.exec_command("tail -15 /var/log/academia-video-worker.log", timeout=10)
    print(stdout.read().decode())
    ssh.close()
except Exception as e:
    print(f"   SSH: {e}")

# 5. Remaining queued jobs
print("4. Remaining queued jobs (all types):")
data = sql("SELECT job_type, COUNT(*) FROM app.video_processing_jobs WHERE status='queued' GROUP BY job_type")
if isinstance(data, list):
    if not data:
        print("   None! All jobs processed.")
    for r in data:
        print(f"   {r['job_type']:30s}: {r['count']}")

print("\n── FIN ──")
