import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== RPCs DANS SCHÉMA APP ===\n")

# Chercher toutes les RPCs dans le schéma app
sql = """
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_schema = 'app'
ORDER BY routine_name
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
if data.get("ok") and data.get("rows"):
    print(f'Total RPCs in app schema: {len(data["rows"])}')
    print('RPCs avec "video" dans le nom:')
    for row in data["rows"]:
        if 'video' in row['routine_name'].lower():
            print(f"  {row['routine_name']}")
    print()
    print('RPCs avec "upload" dans le nom:')
    for row in data["rows"]:
        if 'upload' in row['routine_name'].lower():
            print(f"  {row['routine_name']}")
    print()
else:
    print('RPCs APP: NOT FOUND')
    print()
