import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== PHASE B: TRAÇAGE SQL DÉTAILLÉ - VIDÉO TEST ===\n")

# Utiliser la vidéo la plus récente: 10f674b9-d337-47b5-ae77-6cbbabc5b97b
video_asset_id = "10f674b9-d337-47b5-ae77-6cbbabc5b97b"

# 1. Détails video_asset
sql1 = f"SELECT id, created_at, updated_at, status, owner_id FROM app.video_assets WHERE id = '{video_asset_id}'"
resp1 = requests.post(url, headers=headers, json={"p_sql": sql1}, timeout=30)
print(f'VIDEO_ASSET ({video_asset_id}):')
print(resp1.text)
print()

# 2. Détails video_source
sql2 = f"SELECT id, video_asset_id, storage_bucket, storage_path, created_at FROM app.video_sources WHERE video_asset_id = '{video_asset_id}'"
resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
print(f'VIDEO_SOURCE (pour {video_asset_id}):')
print(resp2.text)
print()

# 3. Détails video_renditions
sql3 = f"SELECT id, video_asset_id, rendition_key, kind, status, storage_path, width, height, created_at FROM app.video_renditions WHERE video_asset_id = '{video_asset_id}'"
resp3 = requests.post(url, headers=headers, json={"p_sql": sql3}, timeout=30)
print(f'VIDEO_RENDITIONS (pour {video_asset_id}):')
print(resp3.text)
print()

# 4. Détails video_processing_jobs
sql4 = f"SELECT id, video_asset_id, job_type, status, created_at, updated_at, error FROM app.video_processing_jobs WHERE video_asset_id = '{video_asset_id}'"
resp4 = requests.post(url, headers=headers, json={"p_sql": sql4}, timeout=30)
print(f'VIDEO_PROCESSING_JOBS (pour {video_asset_id}):')
print(resp4.text)
print()

# 5. Vérifier si cette vidéo est liée à un challenge
sql5 = f"SELECT id, challenge_id, video_asset_id, created_at FROM app.challenge_participation_videos WHERE video_asset_id = '{video_asset_id}'"
resp5 = requests.post(url, headers=headers, json={"p_sql": sql5}, timeout=30)
print(f'CHALLENGE_PARTICIPATION_VIDEOS (pour {video_asset_id}):')
print(resp5.text)
print()
