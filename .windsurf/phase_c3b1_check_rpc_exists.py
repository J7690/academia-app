"""
Phase C.3B.1 – Check RPC Exists
Vérifie si les RPCs whiteboard existent réellement
"""

import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== CHECK RPC EXISTS ===\n")

sql = """
SELECT routine_name, routine_schema
FROM information_schema.routines
WHERE routine_schema = 'app' AND routine_name LIKE '%whiteboard%'
ORDER BY routine_name;
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status : {resp.status_code}")
print(f"RPCs whiteboard dans schema app :")
result = resp.json()
if isinstance(result, dict) and result.get('ok'):
    print("  Format de réponse non standard")
    print(f"  {result}")
elif isinstance(result, list):
    for row in result:
        if isinstance(row, dict):
            print(f"  {row.get('routine_schema')}.{row.get('routine_name')}")
        else:
            print(f"  {row}")
else:
    print(f"  Format non attendu : {result}")
