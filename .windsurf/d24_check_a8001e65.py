import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}

def sql(label, q):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q}, timeout=20)
    print(f"\n=== {label} ===")
    print(json.dumps(r.json(), ensure_ascii=False)[:2000])

sql("render a8001e65",
    "SELECT id, status, progress, video_url, error_message, created_at, completed_at FROM app.whiteboard_renders WHERE id = 'a8001e65-55ec-4a43-90eb-320026a9747d'")

# Tester l'URL signée via service role
import urllib.parse
sql("signed url test",
    """SELECT storage.create_signed_url('whiteboard-renders', 'renders/a8001e65-55ec-4a43-90eb-320026a9747d/', 3600)""")
