import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== VÉRIFICATION TABLES VIDÉO ===\n")

# 1. Lister toutes les tables dans le schéma app
sql1 = """
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'app' 
AND table_name LIKE '%video%'
ORDER BY table_name
"""
resp1 = requests.post(url, headers=headers, json={"p_sql": sql1}, timeout=30)
data1 = resp1.json()
if data1.get("ok") and data1.get("rows"):
    print('Tables vidéo dans schéma app:')
    for row in data1["rows"]:
        print(f"  {row['table_name']}")
    print()
else:
    print('Tables vidéo dans schéma app: NOT FOUND')
    print()

# 2. Lister toutes les tables dans le schéma public
sql2 = """
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name LIKE '%video%'
ORDER BY table_name
"""
resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
data2 = resp2.json()
if data2.get("ok") and data2.get("rows"):
    print('Tables vidéo dans schéma public:')
    for row in data2["rows"]:
        print(f"  {row['table_name']}")
    print()
else:
    print('Tables vidéo dans schéma public: NOT FOUND')
    print()

# 3. Compter les renditions
sql3 = """
SELECT COUNT(*) as total FROM app.video_renditions
"""
resp3 = requests.post(url, headers=headers, json={"p_sql": sql3}, timeout=30)
print('Total renditions:')
print(resp3.text)
print()
