import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

# Get RPC arguments
sql = "SELECT pg_get_function_arguments(oid) as args FROM pg_proc WHERE proname = 'app_append_bobodo_message'"
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print("RPC ARGS:", resp.status_code, resp.text)

# Try calling RPC directly with test params
rpc_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/app_append_bobodo_message"
test_payload = {
    "p_session_id": "00000000-0000-0000-0000-000000000000",
    "p_sender": "student",
    "p_content": "test",
    "p_safety_flag": None
}
resp2 = requests.post(rpc_url, headers=headers, json=test_payload, timeout=30)
print("\nRPC CALL STATUS:", resp2.status_code)
print("RPC CALL BODY:", resp2.text[:500])
