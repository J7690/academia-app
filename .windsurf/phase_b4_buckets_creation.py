"""
Script RPC administrateur pour Phase B.4 – Storage Buckets
"""

import requests
import json

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

print("=== ÉTAPE 1 : CRÉATION BUCKETS STORAGE ===\n")

# Note : Supabase Storage utilise une API REST séparée, pas SQL
# Les buckets ne peuvent pas être créés via admin_execute_sql
# Je vais vérifier si les buckets existent déjà

print("Vérification des buckets existants\n")

sql = "SELECT * FROM storage.buckets"
result = execute_sql(sql)
print(f"Buckets existants: {result}")

if result.get("ok") and result.get("rows"):
    print("Buckets trouvés:")
    for row in result["rows"]:
        print(f"  {row['id']}")
else:
    print("❌ Impossible de lister les buckets")

print("\n=== NOTE IMPORTANTE ===\n")
print("Supabase Storage utilise une API REST séparée, pas SQL.")
print("Les buckets ne peuvent pas être créés via admin_execute_sql.")
print("Les buckets doivent être créés via :")
print("  1. Supabase CLI : supabase storage create buckets")
print("  2. Dashboard Supabase")
print("  3. API Storage directe (POST /storage/buckets)")
print("\n=== FIN DU SCRIPT ===\n")
