import httpx

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": KEY, "Authorization": "Bearer "+KEY, "Content-Type": "application/json"}

queries = [
    "SELECT proname FROM pg_proc WHERE pronamespace::regnamespace = 'public' AND proname = 'whiteboard_fetch_queued_jobs'",
    "SELECT proname, pronamespace::regnamespace::text as schema FROM pg_proc WHERE proname = 'whiteboard_fetch_queued_jobs'",
    "SELECT n.nspname as schema, p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE p.proname = 'whiteboard_fetch_queued_jobs'",
]

for q in queries:
    with httpx.Client(timeout=60) as c:
        r = c.post(URL, headers=HEADERS, json={"p_sql": q})
        print(r.status_code)
        print(r.json())
