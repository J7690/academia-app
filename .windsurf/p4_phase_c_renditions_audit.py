import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

video_asset_id = "10f674b9-d337-47b5-ae77-6cbbabc5b97b"

print("=== PHASE C: AUDIT VIDEO_RENDITIONS - CREATED_BY/UPDATED_BY ===\n")

# 1. Vérifier les colonnes de la table video_renditions
sql1 = "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'app' AND table_name = 'video_renditions' ORDER BY ordinal_position"
resp1 = requests.post(url, headers=headers, json={"p_sql": sql1}, timeout=30)
print('COLONNES VIDEO_RENDITIONS:')
print(resp1.text)
print()

# 2. Extraire toutes les données pour la vidéo test
sql2 = f"SELECT * FROM app.video_renditions WHERE video_asset_id = '{video_asset_id}'"
resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
print(f'VIDEO_RENDITIONS COMPLET (pour {video_asset_id}):')
print(resp2.text)
print()
