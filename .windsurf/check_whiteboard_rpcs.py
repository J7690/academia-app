import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("Checking for whiteboard RPCs...")

# Check for whiteboard_* RPCs
sql = """
SELECT 
  routine_name,
  routine_type
FROM information_schema.routines
WHERE routine_schema = 'app'
AND routine_name LIKE 'whiteboard_%'
ORDER BY routine_name;
"""

resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print("STATUS:", resp.status_code)

if resp.status_code == 200:
    data = resp.json()
    rpcs = data.get('data', [])
    print(f"Found {len(rpcs)} whiteboard RPCs:")
    for rpc in rpcs:
        print(f"  - {rpc['routine_name']} ({rpc['routine_type']})")
else:
    print("Error:", resp.text)
