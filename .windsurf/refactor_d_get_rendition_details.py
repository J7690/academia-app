import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== DÉTAILS RENDITIONS ===\n")

# 1. Structure de la table video_renditions
sql1 = """
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_schema = 'app' 
AND table_name = 'video_renditions'
ORDER BY ordinal_position
"""
resp1 = requests.post(url, headers=headers, json={"p_sql": sql1}, timeout=30)
data1 = resp1.json()
if data1.get("ok") and data1.get("rows"):
    print('Structure video_renditions:')
    for row in data1["rows"]:
        print(f"  {row['column_name']}: {row['data_type']} (nullable: {row['is_nullable']})")
    print()
else:
    print('Structure video_renditions: NOT FOUND')
    print()

# 2. Statistiques des renditions
sql2 = """
SELECT rendition_key, status, COUNT(*) as count
FROM app.video_renditions
GROUP BY rendition_key, status
ORDER BY rendition_key, status
"""
resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
data2 = resp2.json()
if data2.get("ok") and data2.get("rows"):
    print('Statistiques renditions:')
    for row in data2["rows"]:
        print(f"  {row['rendition_key']}: {row['status']} = {row['count']}")
    print()
else:
    print('Statistiques renditions: NOT FOUND')
    print()

# 3. Renditions récentes (dernières 10)
sql3 = """
SELECT video_asset_id, rendition_key, kind, status, storage_bucket, storage_path, public_url_hint, width, height, bitrate_kbps, created_at
FROM app.video_renditions
ORDER BY created_at DESC
LIMIT 10
"""
resp3 = requests.post(url, headers=headers, json={"p_sql": sql3}, timeout=30)
data3 = resp3.json()
if data3.get("ok") and data3.get("rows"):
    print('Renditions récentes (dernières 10):')
    for row in data3["rows"]:
        print(f"  Asset: {row['video_asset_id']}, Key: {row['rendition_key']}, Status: {row['status']}, Created: {row['created_at']}")
    print()
else:
    print('Renditions récentes: NOT FOUND')
    print()
