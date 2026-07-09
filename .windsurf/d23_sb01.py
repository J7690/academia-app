import requests, json, time
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}
sess = requests.Session()
sess.mount("https://", HTTPAdapter(max_retries=Retry(total=3, backoff_factor=1)))
ADMIN = URL + "/rest/v1/rpc/admin_execute_sql"

def q(label, sql):
    time.sleep(0.5)
    r = sess.post(ADMIN, headers=H, json={"p_sql": sql.strip().rstrip(";")}, timeout=30)
    b = r.json()
    print(f"### {label}")
    print(json.dumps(b, ensure_ascii=False)[:5000])
    print()

q("SB-01 RETURN+ARGS create_project",
  "SELECT proname, pg_get_function_result(oid) AS return_type, pg_get_function_arguments(oid) AS arguments FROM pg_proc WHERE proname = 'whiteboard_create_project'")

q("SB-02 PROSRC create_project",
  "SELECT proname, left(prosrc,4000) AS prosrc FROM pg_proc WHERE proname = 'whiteboard_create_project'")

q("SB-03 FULLDEF create_project",
  "SELECT left(pg_get_functiondef(oid),4000) AS fulldef FROM pg_proc WHERE proname = 'whiteboard_create_project'")
