"""Check video_processing_jobs columns and fix the worker accordingly."""
import requests
import json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}", "Content-Type": "application/json"}

def sql(q, label=""):
    if label: print(f"\n  {label}")
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_sql", headers=H, json={"sql_query": q})
    if r.status_code == 200:
        data = r.json()
        if isinstance(data, list):
            for row in data[:20]: print(f"    {row}")
            return data
        else: print(f"    {str(data)[:300]}")
    else: print(f"    ❌ {r.status_code}: {r.text[:200]}")
    return None

# 1. Get exact columns of video_processing_jobs
sql("""
SELECT column_name, data_type, column_default, is_nullable 
FROM information_schema.columns 
WHERE table_schema='app' AND table_name='video_processing_jobs' 
ORDER BY ordinal_position
""", "video_processing_jobs columns")

# 2. Get a sample row to understand payload structure
sql("""
SELECT id, job_type, status, payload::text as payload_text
FROM app.video_processing_jobs
WHERE status = 'queued'
ORDER BY created_at ASC
LIMIT 2
""", "Sample queued jobs")

# 3. Get a sample row of failed jobs
sql("""
SELECT id, job_type, status, payload::text as payload_text, error
FROM app.video_processing_jobs
WHERE status = 'failed'
ORDER BY created_at DESC
LIMIT 2
""", "Sample failed jobs")

# 4. Check video_renditions columns too
sql("""
SELECT column_name, data_type
FROM information_schema.columns 
WHERE table_schema='app' AND table_name='video_renditions' 
ORDER BY ordinal_position
""", "video_renditions columns")
