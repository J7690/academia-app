"""
Audit du système de référenciation via API REST avec schéma app
"""

import requests
import json

# Configuration API REST
base_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
}

print("=== AUDIT SYSTÈME RÉFÉRENCIATION (API REST + schéma) ===\n")

# Test 1: Essayer avec schéma app dans l'URL
print("Test 1: GET /rest/v1/app/commission_rules")
try:
    resp = requests.get(f"{base_url}/app_commission_rules", headers=headers, timeout=30)
    print(f"Status: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        print(f"✅ Table accessible - {len(data)} enregistrements")
    elif resp.status_code == 404:
        print("❌ Table non trouvée (404)")
    else:
        print(f"❌ Erreur: {resp.text}")
except Exception as e:
    print(f"❌ Exception: {e}")
print()

# Test 2: Essayer avec header Prefer pour le schéma
print("Test 2: GET /rest/v1/commission_rules avec header schema=app")
headers_with_schema = headers.copy()
headers_with_schema["Prefer"] = "schema=app"
try:
    resp = requests.get(f"{base_url}/commission_rules", headers=headers_with_schema, timeout=30)
    print(f"Status: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        print(f"✅ Table accessible - {len(data)} enregistrements")
    elif resp.status_code == 404:
        print("❌ Table non trouvée (404)")
    else:
        print(f"❌ Erreur: {resp.text}")
except Exception as e:
    print(f"❌ Exception: {e}")
print()

# Test 3: Lister les tables disponibles via pg_tables (via RPC)
print("Test 3: Lister les tables via RPC admin_execute_sql")
rpc_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
sql = """
SELECT tablename 
FROM pg_tables 
WHERE schemaname = 'app' 
ORDER BY tablename;
"""
try:
    resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
    print(f"Status: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        print(f"Response: {resp.text}")
        if data.get("ok") and data.get("rows"):
            print(f"✅ {len(data['rows'])} tables trouvées dans schéma app")
            for i, row in enumerate(data["rows"][:20], 1):
                print(f"   {i}. {row['tablename']}")
        else:
            print("❌ Pas de données")
    else:
        print(f"❌ Erreur: {resp.text}")
except Exception as e:
    print(f"❌ Exception: {e}")
print()

print("=== AUDIT TERMINÉ ===")
