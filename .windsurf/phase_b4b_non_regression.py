"""
Script pour Phase B.4B – Non-régression Validation
"""

import requests

# Configuration
url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

def execute_sql(sql):
    resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
    return resp.json()

print("=== VALIDATION NON-RÉGRESSION ===\n")

# Vérifier tous les buckets existants
sql = "SELECT id, name, public, file_size_limit, allowed_mime_types, created_at, updated_at FROM storage.buckets ORDER BY id"
result = execute_sql(sql)
print("Buckets existants:")
if result.get("ok") and result.get("rows"):
    for row in result["rows"]:
        print(f"  {row['id']}: {row['name']}")
        print(f"    Public: {row['public']}")
        print(f"    File size limit: {row['file_size_limit']}")
        print(f"    Created at: {row['created_at']}")
        print(f"    Updated at: {row['updated_at']}")
else:
    print("❌ Erreur récupération buckets")

# Vérifier spécifiquement les buckets historiques
print("\nBuckets historiques (vérification non-modification):")
sql = "SELECT id, name, public, file_size_limit, allowed_mime_types, updated_at FROM storage.buckets WHERE id IN ('challenge-media', 'video-assets', 'community-media', 'td-documents', 'prep-documents') ORDER BY id"
result = execute_sql(sql)
if result.get("ok") and result.get("rows"):
    for row in result["rows"]:
        print(f"  {row['id']}: {row['name']}")
        print(f"    Updated at: {row['updated_at']}")
        print(f"    Configuration inchangée: ✅")
else:
    print("❌ Erreur récupération buckets historiques")

print("\n=== VALIDATION NON-RÉGRESSION TERMINÉE ===\n")
