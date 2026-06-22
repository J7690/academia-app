import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== Vérification des tables vidéo dans Supabase ===\n")

# 1. Vérifier si les tables vidéo existent
sql1 = "SELECT tablename FROM pg_tables WHERE schemaname = 'app' AND tablename IN ('video_assets', 'video_sources', 'video_renditions', 'video_processing_jobs')"
resp1 = requests.post(url, headers=headers, json={"p_sql": sql1}, timeout=30)
print("TABLES VIDEO STATUS:", resp1.status_code)
print("TABLES VIDEO BODY:", resp1.text)

# 2. Vérifier les colonnes de video_assets
sql2 = "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'app' AND table_name = 'video_assets' ORDER BY ordinal_position"
resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
print("\nVIDEO_ASSETS COLUMNS STATUS:", resp2.status_code)
print("VIDEO_ASSETS COLUMNS BODY:", resp2.text)

# 3. Vérifier les colonnes de video_sources
sql3 = "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'app' AND table_name = 'video_sources' ORDER BY ordinal_position"
resp3 = requests.post(url, headers=headers, json={"p_sql": sql3}, timeout=30)
print("\nVIDEO_SOURCES COLUMNS STATUS:", resp3.status_code)
print("VIDEO_SOURCES COLUMNS BODY:", resp3.text)

# 4. Vérifier les colonnes de video_renditions
sql4 = "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'app' AND table_name = 'video_renditions' ORDER BY ordinal_position"
resp4 = requests.post(url, headers=headers, json={"p_sql": sql4}, timeout=30)
print("\nVIDEO_RENDITIONS COLUMNS STATUS:", resp4.status_code)
print("VIDEO_RENDITIONS COLUMNS BODY:", resp4.text)

# 5. Vérifier les colonnes de video_processing_jobs
sql5 = "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'app' AND table_name = 'video_processing_jobs' ORDER BY ordinal_position"
resp5 = requests.post(url, headers=headers, json={"p_sql": sql5}, timeout=30)
print("\nVIDEO_PROCESSING_JOBS COLUMNS STATUS:", resp5.status_code)
print("VIDEO_PROCESSING_JOBS COLUMNS BODY:", resp5.text)

# 6. Compter les enregistrements dans chaque table
sql6 = "SELECT (SELECT COUNT(*) FROM app.video_assets) as video_assets_count, (SELECT COUNT(*) FROM app.video_sources) as video_sources_count, (SELECT COUNT(*) FROM app.video_renditions) as video_renditions_count, (SELECT COUNT(*) FROM app.video_processing_jobs) as video_processing_jobs_count"
resp6 = requests.post(url, headers=headers, json={"p_sql": sql6}, timeout=30)
print("\nCOUNTS STATUS:", resp6.status_code)
print("COUNTS BODY:", resp6.text)
