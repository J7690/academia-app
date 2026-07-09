import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}

def sql(label, q):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q}, timeout=20)
    print(f"\n=== {label} ===")
    print(json.dumps(r.json(), ensure_ascii=False)[:3000])

# Renders récents avec URL
sql("renders récents",
    "SELECT id, status, progress, video_url, error_message, created_at, completed_at FROM app.whiteboard_renders ORDER BY created_at DESC LIMIT 5")

# Vérifier le bucket
sql("fichiers bucket whiteboard-renders",
    "SELECT name, metadata FROM storage.objects WHERE bucket_id = 'whiteboard-renders' ORDER BY created_at DESC LIMIT 5")

# Kamatera RPC
sql("whiteboard_fetch_queued_jobs def",
    "SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'whiteboard_fetch_queued_jobs'")
