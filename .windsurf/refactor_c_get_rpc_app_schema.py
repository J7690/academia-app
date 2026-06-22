import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== RECHERCHE RPCs DANS TOUS LES SCHÉMAS ===\n")

# Chercher dans tous les schémas
sql = """
SELECT routine_schema, routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_name LIKE '%videoasset%'
ORDER BY routine_schema, routine_name
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print('RPCs VIDEOASSET (tous schémas):')
print(resp.text)
print()

# Chercher les RPCs avec "upload" dans le nom
sql2 = """
SELECT routine_schema, routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_name LIKE '%upload%'
ORDER BY routine_schema, routine_name
"""
resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
print('RPCs UPLOAD (tous schémas):')
print(resp2.text)
print()
