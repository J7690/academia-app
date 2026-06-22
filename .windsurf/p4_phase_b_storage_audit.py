import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== PHASE B: AUDIT STORAGE FORENSIQUE ===\n")

# 1. Vérifier les colonnes de storage.objects
sql1 = "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'storage' AND table_name = 'objects' ORDER BY ordinal_position"
resp1 = requests.post(url, headers=headers, json={"p_sql": sql1}, timeout=30)
print('COLONNES STORAGE.OBJECTS:')
print(resp1.text)
print()

# 2. Chercher les fichiers de la vidéo test dans storage.objects
video_asset_id = "10f674b9-d337-47b5-ae77-6cbbabc5b97b"
sql2 = f"SELECT * FROM storage.objects WHERE name LIKE '%{video_asset_id}%' ORDER BY created_at DESC LIMIT 10"
resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
print(f'STORAGE.OBJECTS (pour {video_asset_id}):')
print(resp2.text)
print()
