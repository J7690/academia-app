import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== AUDIT EDGE FUNCTIONS SUPABASE ===\n")

# 1. Lister toutes les Edge Functions déployées
sql1 = "SELECT name, version, status FROM supabase_migrations.schema_migrations WHERE name LIKE '%function%' ORDER BY name"
resp1 = requests.post(url, headers=headers, json={"p_sql": sql1}, timeout=30)
print("=== EDGE FUNCTIONS (via schema_migrations) ===")
print("STATUS:", resp1.status_code)
print("BODY:", resp1.text)
print()

# 2. Chercher les fonctions contenant "compress", "watermark", "video", "transcode"
sql2 = "SELECT name FROM supabase_migrations.schema_migrations WHERE name ILIKE '%compress%' OR name ILIKE '%watermark%' OR name ILIKE '%video%' OR name ILIKE '%transcode%' ORDER BY name"
resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
print("=== EDGE FUNCTIONS CONTENANT compress/watermark/video/transcode ===")
print("STATUS:", resp2.status_code)
print("BODY:", resp2.text)
print()

# 3. Lister les fonctions dans pg_proc (PostgreSQL functions)
sql3 = "SELECT proname, prosrc FROM pg_proc WHERE proname ILIKE '%compress%' OR proname ILIKE '%watermark%' OR proname ILIKE '%video%' OR proname ILIKE '%transcode%' ORDER BY proname"
resp3 = requests.post(url, headers=headers, json={"p_sql": sql3}, timeout=30)
print("=== POSTGRESQL FUNCTIONS CONTENANT compress/watermark/video/transcode ===")
print("STATUS:", resp3.status_code)
print("BODY:", resp3.text)
print()

# 4. Vérifier la table edge_functions si elle existe
sql4 = "SELECT table_name FROM information_schema.tables WHERE table_name = 'edge_functions'"
resp4 = requests.post(url, headers=headers, json={"p_sql": sql4}, timeout=30)
print("=== TABLE edge_functions EXISTE? ===")
print("STATUS:", resp4.status_code)
print("BODY:", resp4.text)
print()

# 5. Si la table existe, lister les edge functions
if resp4.status_code == 200 and resp4.text.strip() != "[]":
    sql5 = "SELECT * FROM edge_functions ORDER BY name"
    resp5 = requests.post(url, headers=headers, json={"p_sql": sql5}, timeout=30)
    print("=== CONTENU TABLE edge_functions ===")
    print("STATUS:", resp5.status_code)
    print("BODY:", resp5.text)
    print()
else:
    print("=== TABLE edge_functions N'EXISTE PAS ===\n")
