import urllib.request, json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

url = f"{SUPABASE_URL}/rest/v1/video_processing_jobs?order=updated_at.desc&limit=10&select=id,status,job_type,created_at,updated_at"
headers = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Accept-Profile": "app"}
req = urllib.request.Request(url, headers=headers)
data = json.loads(urllib.request.urlopen(req).read())

print(f"{'STATUS':<12} {'JOB_TYPE':<18} {'UPDATED_AT'}")
print("-" * 60)
for j in data:
    print(f"{j['status']:<12} {j['job_type']:<18} {j['updated_at']}")

# Count by status
print("\n--- SUMMARY ---")
url2 = f"{SUPABASE_URL}/rest/v1/video_processing_jobs?select=status"
headers2 = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Accept-Profile": "app"}
req2 = urllib.request.Request(url2, headers=headers2)
all_jobs = json.loads(urllib.request.urlopen(req2).read())
from collections import Counter
counts = Counter(j["status"] for j in all_jobs)
for s, c in counts.most_common():
    print(f"  {s}: {c}")
