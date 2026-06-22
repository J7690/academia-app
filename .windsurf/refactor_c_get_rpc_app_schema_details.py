import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== DÉTAILS RPCs VIDEOASSET ===\n")

# Chercher les détails des RPCs videoasset
sql = """
SELECT routine_schema, routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_name LIKE '%videoasset%'
ORDER BY routine_schema, routine_name
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
if data.get("ok") and data.get("rows"):
    print('RPCs VIDEOASSET:')
    for row in data["rows"]:
        print(f"  Schema: {row['routine_schema']}, Name: {row['routine_name']}, Type: {row['routine_type']}")
    print()
else:
    print('RPCs VIDEOASSET: NOT FOUND')
    print()

# Chercher les détails des RPCs upload
sql2 = """
SELECT routine_schema, routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_name LIKE '%upload%'
ORDER BY routine_schema, routine_name
"""
resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
data2 = resp2.json()
if data2.get("ok") and data2.get("rows"):
    print('RPCs UPLOAD:')
    for row in data2["rows"]:
        print(f"  Schema: {row['routine_schema']}, Name: {row['routine_name']}, Type: {row['routine_type']}")
    print()
else:
    print('RPCs UPLOAD: NOT FOUND')
    print()

# Maintenant essayer de récupérer les définitions depuis le schéma app
sql3 = """
SELECT pg_get_functiondef(oid) as definition
FROM app.pg_proc 
WHERE proname = 'app_videoasset_create_upload_intent'
   OR proname = 'app_videoasset_register_uploaded_source'
"""
resp3 = requests.post(url, headers=headers, json={"p_sql": sql3}, timeout=30)
print('DÉFINITIONS APP:')
print(resp3.text)
print()
