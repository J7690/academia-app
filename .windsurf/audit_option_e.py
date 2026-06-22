import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== AUDIT OPTION E - VALIDATION SUPABASE ===\n")

# 1. Vérifier chunks récents dans video-assets (preuve assemble-video-chunks utilisée)
sql1 = '''SELECT bucket_id, name, metadata, created_at 
FROM storage.objects 
WHERE bucket_id = 'video-assets' 
AND name LIKE '%_chunks/%' 
ORDER BY created_at DESC 
LIMIT 3'''
resp1 = requests.post(url, headers=headers, json={"p_sql": sql1}, timeout=30)
print("=== CHUNKS RÉCENTS video-assets ===")
print("STATUS:", resp1.status_code)
print("BODY:", resp1.text[:800])

# 2. Vérifier chunks récents dans challenge-media
sql2 = '''SELECT bucket_id, name, metadata, created_at 
FROM storage.objects 
WHERE bucket_id = 'challenge-media' 
AND name LIKE '%_chunks/%' 
ORDER BY created_at DESC 
LIMIT 3'''
resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
print("\n=== CHUNKS RÉCENTS challenge-media ===")
print("STATUS:", resp2.status_code)
print("BODY:", resp2.text[:800])

# 3. Vérifier policies challenge-media
sql3 = '''SELECT policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename = 'objects' 
AND schemaname = 'storage' 
AND policyname LIKE '%challenge%' 
ORDER BY policyname'''
resp3 = requests.post(url, headers=headers, json={"p_sql": sql3}, timeout=30)
print("\n=== POLICIES challenge-media ===")
print("STATUS:", resp3.status_code)
print("BODY:", resp3.text[:1000])

# 4. Vérifier bucket challenge-media
sql4 = '''SELECT id, name, public, file_size_limit, allowed_mime_types 
FROM storage.buckets 
WHERE id = 'challenge-media' '''
resp4 = requests.post(url, headers=headers, json={"p_sql": sql4}, timeout=30)
print("\n=== BUCKET challenge-media ===")
print("STATUS:", resp4.status_code)
print("BODY:", resp4.text)

# 5. Vérifier fichiers récents challenge-media (hors chunks)
sql5 = '''SELECT bucket_id, name, metadata, created_at 
FROM storage.objects 
WHERE bucket_id = 'challenge-media' 
AND name NOT LIKE '%_chunks/%' 
ORDER BY created_at DESC 
LIMIT 5'''
resp5 = requests.post(url, headers=headers, json={"p_sql": sql5}, timeout=30)
print("\n=== FICHIERS RÉCENTS challenge-media (hors chunks) ===")
print("STATUS:", resp5.status_code)
print("BODY:", resp5.text[:1000])
