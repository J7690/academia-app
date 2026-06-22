import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== PHASE B: TRAÇAGE SQL COMPLET ===\n")

# 1. Identifier une vidéo récente dans video_assets
sql1 = "SELECT id, created_at, updated_at, status, owner_id FROM app.video_assets ORDER BY created_at DESC LIMIT 5"
resp1 = requests.post(url, headers=headers, json={"p_sql": sql1}, timeout=30)
print('VIDEO_ASSETS (5 plus récentes):')
print(resp1.text)
print()

# 2. Pour la vidéo la plus récente, chercher dans video_sources
sql2 = "SELECT id, video_asset_id, storage_bucket, storage_path, created_at FROM app.video_sources ORDER BY created_at DESC LIMIT 5"
resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
print('VIDEO_SOURCES (5 plus récentes):')
print(resp2.text)
print()

# 3. Chercher dans video_renditions
sql3 = "SELECT id, video_asset_id, rendition_key, kind, status, storage_path, width, height, created_at FROM app.video_renditions ORDER BY created_at DESC LIMIT 10"
resp3 = requests.post(url, headers=headers, json={"p_sql": sql3}, timeout=30)
print('VIDEO_RENDITIONS (10 plus récentes):')
print(resp3.text)
print()

# 4. Chercher dans video_processing_jobs
sql4 = "SELECT id, video_asset_id, job_type, status, created_at, updated_at, error FROM app.video_processing_jobs ORDER BY created_at DESC LIMIT 10"
resp4 = requests.post(url, headers=headers, json={"p_sql": sql4}, timeout=30)
print('VIDEO_PROCESSING_JOBS (10 plus récents):')
print(resp4.text)
print()

# 5. Chercher dans challenge_videos
sql5 = "SELECT id, challenge_id, video_asset_id, created_at FROM app.challenge_videos ORDER BY created_at DESC LIMIT 5"
resp5 = requests.post(url, headers=headers, json={"p_sql": sql5}, timeout=30)
print('CHALLENGE_VIDEOS (5 plus récents):')
print(resp5.text)
print()

# 6. Chercher dans student_videos
sql6 = "SELECT id, student_id, video_asset_id, created_at FROM app.student_videos ORDER BY created_at DESC LIMIT 5"
resp6 = requests.post(url, headers=headers, json={"p_sql": sql6}, timeout=30)
print('STUDENT_VIDEOS (5 plus récents):')
print(resp6.text)
print()
