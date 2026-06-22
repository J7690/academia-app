import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== DÉFINITIONS COMPLÈTES RPCs VIDÉO ===\n")

# 1. Définition app_videoasset_create_upload_intent
sql1 = """
SELECT pg_get_functiondef(oid) as definition
FROM pg_proc 
WHERE proname = 'app_videoasset_create_upload_intent'
"""
resp1 = requests.post(url, headers=headers, json={"p_sql": sql1}, timeout=30)
print('app_videoasset_create_upload_intent:')
print(resp1.text)
print()

# 2. Définition app_videoasset_register_uploaded_source
sql2 = """
SELECT pg_get_functiondef(oid) as definition
FROM pg_proc 
WHERE proname = 'app_videoasset_register_uploaded_source'
"""
resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
print('app_videoasset_register_uploaded_source:')
print(resp2.text)
print()
