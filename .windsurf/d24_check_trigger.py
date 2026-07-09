import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}

def sql(label, q):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q}, timeout=20)
    print(f"\n=== {label} ===")
    print(json.dumps(r.json(), ensure_ascii=False)[:4000])

# 1. Triggers sur whiteboard_renders
sql("triggers sur whiteboard_renders",
    "SELECT trigger_name, event_manipulation, action_statement FROM information_schema.triggers WHERE event_object_table = 'whiteboard_renders' ORDER BY trigger_name")

# 2. Functions liées aux renders
sql("fonctions whiteboard_render",
    "SELECT proname, left(pg_get_functiondef(oid),500) FROM pg_proc WHERE proname LIKE '%whiteboard%render%' OR proname LIKE '%render%whiteboard%'")

# 3. Log détaillé du job - voir video_url
sql("detail render a37fc250",
    "SELECT id, status, progress, video_url, error_message, created_at, completed_at FROM app.whiteboard_renders WHERE id = 'a37fc250-2255-4b11-824c-efc56b5df93c'")
