import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

video_asset_id = "10f674b9-d337-47b5-ae77-6cbbabc5b97b"

print("=== PHASE G: CORRÉLATION TEMPORELLE (MANUEL) ===\n")

# Timeline manuelle - chaque requête séparée
queries = [
    ("video_source", f"SELECT 'video_source' as source, 'DB' as type, created_at FROM app.video_sources WHERE video_asset_id = '{video_asset_id}'"),
    ("job_extract_metadata", f"SELECT 'job_extract_metadata' as source, 'DB' as type, created_at FROM app.video_processing_jobs WHERE video_asset_id = '{video_asset_id}' AND job_type = 'extract_metadata'"),
    ("job_generate_mp4", f"SELECT 'job_generate_mp4' as source, 'DB' as type, created_at FROM app.video_processing_jobs WHERE video_asset_id = '{video_asset_id}' AND job_type = 'generate_mp4'"),
    ("job_generate_thumbs", f"SELECT 'job_generate_thumbs' as source, 'DB' as type, created_at FROM app.video_processing_jobs WHERE video_asset_id = '{video_asset_id}' AND job_type = 'generate_thumbs'"),
    ("storage_raw", f"SELECT 'storage_raw' as source, 'Storage' as type, created_at FROM storage.objects WHERE name LIKE '%{video_asset_id}%' AND name LIKE '%raw%'"),
    ("storage_mp4_main", f"SELECT 'storage_mp4_main' as source, 'Storage' as type, created_at FROM storage.objects WHERE name LIKE '%{video_asset_id}%' AND name LIKE '%mp4_main%'"),
    ("storage_mp4_480p", f"SELECT 'storage_mp4_480p' as source, 'Storage' as type, created_at FROM storage.objects WHERE name LIKE '%{video_asset_id}%' AND name LIKE '%mp4_480p%'"),
    ("storage_mp4_360p", f"SELECT 'storage_mp4_360p' as source, 'Storage' as type, created_at FROM storage.objects WHERE name LIKE '%{video_asset_id}%' AND name LIKE '%mp4_360p%'"),
    ("storage_mp4_240p", f"SELECT 'storage_mp4_240p' as source, 'Storage' as type, created_at FROM storage.objects WHERE name LIKE '%{video_asset_id}%' AND name LIKE '%mp4_240p%'"),
    ("rendition_mp4_main", f"SELECT 'rendition_mp4_main' as source, 'DB' as type, created_at FROM app.video_renditions WHERE video_asset_id = '{video_asset_id}' AND rendition_key = 'mp4_main'"),
    ("rendition_mp4_480p", f"SELECT 'rendition_mp4_480p' as source, 'DB' as type, created_at FROM app.video_renditions WHERE video_asset_id = '{video_asset_id}' AND rendition_key = 'mp4_480p'"),
    ("rendition_mp4_360p", f"SELECT 'rendition_mp4_360p' as source, 'DB' as type, created_at FROM app.video_renditions WHERE video_asset_id = '{video_asset_id}' AND rendition_key = 'mp4_360p'"),
    ("rendition_mp4_240p", f"SELECT 'rendition_mp4_240p' as source, 'DB' as type, created_at FROM app.video_renditions WHERE video_asset_id = '{video_asset_id}' AND rendition_key = 'mp4_240p'"),
]

timeline = []
for name, sql in queries:
    resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        for row in data["rows"]:
            timeline.append(row)

# Trier par created_at
timeline.sort(key=lambda x: x["created_at"])

print('TIMELINE TRIÉE:')
for event in timeline:
    print(f"{event['created_at']} - {event['source']} ({event['type']})")
print()
