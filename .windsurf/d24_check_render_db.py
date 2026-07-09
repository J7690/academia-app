import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}

def sql(label, q):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q}, timeout=20)
    print(f"\n=== {label} ===")
    print(json.dumps(r.json(), ensure_ascii=False)[:3000])

# 1. Le render job a37fc250
sql("render job a37fc250",
    "SELECT id, project_id, status, progress, created_at FROM app.whiteboard_renders WHERE id = 'a37fc250-2255-4b11-824c-efc56b5df93c'")

# 2. Tous les renders créés depuis 11h
sql("renders depuis 11h",
    "SELECT id, status, progress, created_at FROM app.whiteboard_renders WHERE created_at > '2026-06-28 11:00:00' ORDER BY created_at DESC LIMIT 5")

# 3. Ce que fetch_queued_jobs retourne
sql("whiteboard_fetch_queued_jobs direct",
    "SELECT * FROM app.whiteboard_renders WHERE status = 'queued' ORDER BY created_at ASC LIMIT 5")
