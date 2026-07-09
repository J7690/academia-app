import httpx, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": KEY, "Authorization": "Bearer "+KEY, "Content-Type": "application/json"}

queries = [
    "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'app';",
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'whiteboard_projects';",
    "SELECT proname FROM pg_proc WHERE pronamespace::regnamespace = 'public' AND proname = 'whiteboard_fetch_queued_jobs';",
]

for q in queries:
    with httpx.Client(timeout=60) as c:
        r = c.post(URL, headers=HEADERS, json={"p_sql": q})
        print(r.status_code)
        try:
            print(r.json())
        except Exception as e:
            print(e, r.text[:200])
