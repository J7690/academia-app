import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== VÉRIFICATION ASSEMBLE-VIDEO-CHUNKS ===\n")

# Vérifier si l'Edge Function est déployée (via logs ou metadata)
# Note: Supabase n'expose pas directement la liste des Edge Functions déployées via SQL
# On peut vérifier les logs d'invocation récents si une table de logs existe

# Vérifier les fichiers récents dans video-assets (qui contient les chunks)
sql1 = '''SELECT bucket_id, name, metadata, created_at 
FROM storage.objects 
WHERE bucket_id = 'video-assets' 
AND name LIKE '%_chunks/%' 
ORDER BY created_at DESC 
LIMIT 5'''
resp1 = requests.post(url, headers=headers, json={"p_sql": sql1}, timeout=30)
print("=== CHUNKS RÉCENTS DANS video-assets ===")
print("STATUS:", resp1.status_code)
print("BODY:", resp1.text[:1000])

# Vérifier les fichiers récents dans challenge-media
sql2 = '''SELECT bucket_id, name, metadata, created_at 
FROM storage.objects 
WHERE bucket_id = 'challenge-media' 
ORDER BY created_at DESC 
LIMIT 5'''
resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
print("\n=== FICHIERS RÉCENTS DANS challenge-media ===")
print("STATUS:", resp2.status_code)
print("BODY:", resp2.text[:1000])
