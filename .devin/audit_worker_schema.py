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

# 1. Colonnes
print("── video_processing_jobs columns ──")
data = sql("""
    SELECT column_name, data_type 
    FROM information_schema.columns 
    WHERE table_schema = 'app' AND table_name = 'video_processing_jobs'
    ORDER BY ordinal_position
""")
if isinstance(data, list):
    for r in data:
        print(f"  {r['column_name']:30s} {r['data_type']}")

# 2. video_renditions columns
print("\n── video_renditions columns ──")
data = sql("""
    SELECT column_name, data_type 
    FROM information_schema.columns 
    WHERE table_schema = 'app' AND table_name = 'video_renditions'
    ORDER BY ordinal_position
""")
if isinstance(data, list):
    for r in data:
        print(f"  {r['column_name']:30s} {r['data_type']}")

# 3. Get video_sources for a real asset
print("\n── video_sources columns ──")
data = sql("""
    SELECT column_name, data_type 
    FROM information_schema.columns 
    WHERE table_schema = 'app' AND table_name = 'video_sources'
    ORDER BY ordinal_position
""")
if isinstance(data, list):
    for r in data:
        print(f"  {r['column_name']:30s} {r['data_type']}")

# 4. Sample source for a real asset
print("\n── Sample video_source ──")
data = sql("""
    SELECT vs.id, vs.video_asset_id, vs.storage_bucket, vs.storage_path, vs.public_url_hint, vs.status
    FROM app.video_sources vs
    ORDER BY vs.created_at DESC LIMIT 3
""")
if isinstance(data, list):
    for r in data:
        print(f"  asset={str(r.get('video_asset_id',''))[:8]}... bucket={r.get('storage_bucket','')} path={r.get('storage_path','')[:50]} status={r.get('status','')}")
        print(f"    url={r.get('public_url_hint','')[:100]}")

# 5. Read the full RPC source for request_video_export_watermarked
print("\n── RPC request_video_export_watermarked (full) ──")
data = sql("SELECT prosrc FROM pg_proc WHERE proname = 'app_student_request_video_export_watermarked'")
if isinstance(data, list) and data:
    print(data[0].get('prosrc', 'N/A'))

# 6. Check what the worker actually queries
print("\n── Worker REST API test: queued export_watermarked jobs ──")
r = requests.get(
    f"{SUPABASE_URL}/rest/v1/video_processing_jobs?status=eq.queued&job_type=eq.export_watermarked&order=created_at.asc&limit=3",
    headers=H
)
print(f"  HTTP {r.status_code}: {r.text[:500]}")
