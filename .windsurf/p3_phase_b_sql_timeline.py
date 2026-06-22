import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

video_asset_id = "10f674b9-d337-47b5-ae77-6cbbabc5b97b"

print("=== PHASE B: TIMELINE COMPLÈTE VIDÉO TEST ===\n")

# Timeline complète pour la vidéo test
sql = f"""
SELECT 
  'video_source' as step, 
  created_at, 
  updated_at 
FROM app.video_sources 
WHERE video_asset_id = '{video_asset_id}'

UNION ALL

SELECT 
  'video_processing_job_extract_metadata' as step, 
  created_at, 
  updated_at 
FROM app.video_processing_jobs 
WHERE video_asset_id = '{video_asset_id}' AND job_type = 'extract_metadata'

UNION ALL

SELECT 
  'video_processing_job_generate_mp4' as step, 
  created_at, 
  updated_at 
FROM app.video_processing_jobs 
WHERE video_asset_id = '{video_asset_id}' AND job_type = 'generate_mp4'

UNION ALL

SELECT 
  'video_processing_job_generate_thumbs' as step, 
  created_at, 
  updated_at 
FROM app.video_processing_jobs 
WHERE video_asset_id = '{video_asset_id}' AND job_type = 'generate_thumbs'

UNION ALL

SELECT 
  'video_rendition_mp4_main' as step, 
  created_at, 
  updated_at 
FROM app.video_renditions 
WHERE video_asset_id = '{video_asset_id}' AND rendition_key = 'mp4_main'

UNION ALL

SELECT 
  'video_rendition_mp4_480p' as step, 
  created_at, 
  updated_at 
FROM app.video_renditions 
WHERE video_asset_id = '{video_asset_id}' AND rendition_key = 'mp4_480p'

UNION ALL

SELECT 
  'video_rendition_mp4_360p' as step, 
  created_at, 
  updated_at 
FROM app.video_renditions 
WHERE video_asset_id = '{video_asset_id}' AND rendition_key = 'mp4_360p'

UNION ALL

SELECT 
  'video_rendition_mp4_240p' as step, 
  created_at, 
  updated_at 
FROM app.video_renditions 
WHERE video_asset_id = '{video_asset_id}' AND rendition_key = 'mp4_240p'

ORDER BY created_at ASC
"""

resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print('TIMELINE COMPLÈTE:')
print(resp.text)
print()
