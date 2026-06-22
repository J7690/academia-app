import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== RECHERCHE RPCs VIDÉO ===\n")

# 1. Chercher toutes les RPCs avec "videoasset" dans le nom
sql1 = """
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name LIKE '%videoasset%'
ORDER BY routine_name
"""
resp1 = requests.post(url, headers=headers, json={"p_sql": sql1}, timeout=30)
print('RPCs VIDEOASSET:')
print(resp1.text)
print()

# 2. Chercher toutes les RPCs avec "video" dans le nom
sql2 = """
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name LIKE '%video%'
ORDER BY routine_name
"""
resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
print('RPCs VIDEO:')
print(resp2.text)
print()

# 3. Chercher les définitions des RPCs spécifiques
sql3 = """
SELECT pg_get_functiondef(oid) as definition
FROM pg_proc 
WHERE proname = 'app_videoasset_create_upload_intent'
   OR proname = 'app_videoasset_register_uploaded_source'
"""
resp3 = requests.post(url, headers=headers, json={"p_sql": sql3}, timeout=30)
print('DÉFINITIONS RPCs:')
print(resp3.text)
print()
