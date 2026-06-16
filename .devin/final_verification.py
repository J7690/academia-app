"""Final verification of all fixes."""
import requests
SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}", "Content-Type": "application/json"}

def sql(q, label=""):
    if label: print(f"\n  {label}")
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_sql", headers=H, json={"sql_query": q})
    if r.status_code == 200:
        data = r.json()
        if isinstance(data, list):
            for row in data[:10]: print(f"    {row}")
        else: print(f"    {str(data)[:300]}")
    else: print(f"    ❌ {r.status_code}: {r.text[:200]}")

print("=" * 60)
print("FINAL VERIFICATION")
print("=" * 60)

sql("SELECT status, COUNT(*) FROM app.video_processing_jobs GROUP BY status ORDER BY status", "Job status counts")
sql("SELECT status, COUNT(*) FROM app.video_renditions GROUP BY status ORDER BY status", "Rendition status counts")

# Check no queued transcode_resolution jobs remain (they'd be processed by worker)
sql("""
SELECT id, job_type, status, payload::text 
FROM app.video_processing_jobs 
WHERE status = 'queued' AND job_type = 'transcode_resolution'
LIMIT 5
""", "Queued transcode_resolution jobs (should be empty)")

# Verify all video tables accessible from app schema
print("\n  Schema access check:")
for t in ['video_assets', 'video_sources', 'video_renditions', 'video_processing_jobs']:
    r = requests.get(f"{SUPABASE_URL}/rest/v1/{t}?select=id&limit=1", headers={**H, "Accept-Profile": "app"})
    print(f"    {'✅' if r.status_code == 200 else '❌'} app.{t}: HTTP {r.status_code}")

# Verify Edge Functions respond
print("\n  Edge Function health:")
for fn in ['transcode-video', 'transcode-multi-resolution', 'livekit-token', 'livekit-recording']:
    try:
        r = requests.post(f"{SUPABASE_URL}/functions/v1/{fn}", headers=H, json={}, timeout=10)
        print(f"    {'✅' if r.status_code in (400,401,404) else '❌'} {fn}: HTTP {r.status_code}")
    except: print(f"    ❌ {fn}: unreachable")

# Verify LiveKit server
print("\n  LiveKit server:")
try:
    r = requests.get("http://185.167.96.214:7880", timeout=5)
    print(f"    {'✅' if r.text.strip()=='OK' else '❌'} HTTP {r.status_code}: {r.text.strip()}")
except Exception as e: print(f"    ❌ {e}")

print("\n🏁 All checks complete.")
