import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== VÉRIFICATION RENDITIONS ===\n")

# 1. Structure de la table video_renditions
sql1 = """
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_schema = 'app' 
AND table_name = 'video_renditions'
ORDER BY ordinal_position
"""
resp1 = requests.post(url, headers=headers, json={"p_sql": sql1}, timeout=30)
print('Structure video_renditions:')
print(resp1.text)
print()

# 2. Renditions pour le test video asset (e1a2b3c4-d5e6-f7a8-b9c0-d1e2f3a4b5c6)
sql2 = """
SELECT video_asset_id, rendition_key, kind, status, storage_bucket, storage_path, public_url_hint, width, height, bitrate_kbps, created_at
FROM app.video_renditions
WHERE video_asset_id = 'e1a2b3c4-d5e6-f7a8-b9c0-d1e2f3a4b5c6'
ORDER BY created_at
"""
resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
print('Renditions pour test video asset:')
print(resp2.text)
print()

# 3. Statistiques des renditions
sql3 = """
SELECT rendition_key, status, COUNT(*) as count
FROM app.video_renditions
GROUP BY rendition_key, status
ORDER BY rendition_key, status
"""
resp3 = requests.post(url, headers=headers, json={"p_sql": sql3}, timeout=30)
print('Statistiques renditions:')
print(resp3.text)
print()
