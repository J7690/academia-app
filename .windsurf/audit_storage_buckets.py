import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

# 1. Vérifier tous les buckets storage
sql1 = 'SELECT id, name, public, file_size_limit, allowed_mime_types FROM storage.buckets ORDER BY id'
resp1 = requests.post(url, headers=headers, json={"p_sql": sql1}, timeout=30)
print("=== ALL STORAGE BUCKETS ===")
print("STATUS:", resp1.status_code)
print("BODY:", resp1.text)

# 2. Vérifier spécifiquement challenge-media et video-assets
sql2 = '''SELECT id, name, public, file_size_limit, allowed_mime_types FROM storage.buckets WHERE id IN ('challenge-media', 'video-assets', 'community-media') ORDER BY id'''
resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
print("\n=== TARGET BUCKETS (challenge-media, video-assets, community-media) ===")
print("STATUS:", resp2.status_code)
print("BODY:", resp2.text)

# 3. Vérifier les fichiers récents dans challenge-media
sql3 = '''SELECT bucket_id, name, metadata, created_at FROM storage.objects WHERE bucket_id = 'challenge-media' ORDER BY created_at DESC LIMIT 10'''
resp3 = requests.post(url, headers=headers, json={"p_sql": sql3}, timeout=30)
print("\n=== RECENT FILES IN challenge-media ===")
print("STATUS:", resp3.status_code)
print("BODY:", resp3.text)

# 4. Vérifier les fichiers récents dans video-assets
sql4 = '''SELECT bucket_id, name, metadata, created_at FROM storage.objects WHERE bucket_id = 'video-assets' ORDER BY created_at DESC LIMIT 10'''
resp4 = requests.post(url, headers=headers, json={"p_sql": sql4}, timeout=30)
print("\n=== RECENT FILES IN video-assets ===")
print("STATUS:", resp4.status_code)
print("BODY:", resp4.text)
