import httpx, time, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

for i in range(3):
    try:
        r = httpx.post(URL, headers={"apikey": KEY, "Authorization": "Bearer "+KEY, "Content-Type": "application/json"}, json={"p_sql": "SELECT 1 as n"}, timeout=60)
        print(i, r.status_code, r.json())
        break
    except Exception as e:
        print(i, "ERR", e)
        time.sleep(3)
