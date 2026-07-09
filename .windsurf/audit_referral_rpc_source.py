"""
Obtenir le code source de l'RPC de référenciation
"""

import requests
import json

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== OBTENIR CODE SOURCE RPC RÉFÉRENCIATION ===\n")

# Test 1: Obtenir le code source de app_register_referral_for_current_user
print("Test 1: Code source de app_register_referral_for_current_user")
sql = """
SELECT pg_get_functiondef(oid)
FROM pg_proc 
WHERE proname = 'app_register_referral_for_current_user';
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    print(f"Response: {resp.text}")
    if data.get("ok") and data.get("rows"):
        print("✅ Code source trouvé:")
        for row in data["rows"]:
            print(row['pg_get_functiondef'])
    else:
        print("❌ RPC non trouvée")
else:
    print(f"❌ Erreur: {resp.text}")
print()

# Test 2: Lister toutes les RPCs avec "referral" dans le nom
print("Test 2: Lister toutes les RPCs avec 'referral' dans le nom")
sql = """
SELECT n.nspname as schema_name, p.proname as function_name
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname ILIKE '%referral%'
ORDER BY n.nspname, p.proname;
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    print(f"Response: {resp.text}")
    if data.get("ok") and data.get("rows"):
        print(f"✅ {len(data['rows'])} RPCs trouvées:")
        for row in data["rows"]:
            print(f"  - {row['schema_name']}.{row['function_name']}")
    else:
        print("❌ Aucune RPC trouvée")
else:
    print(f"❌ Erreur: {resp.text}")
print()

# Test 3: Lister toutes les RPCs avec "commission" dans le nom
print("Test 3: Lister toutes les RPCs avec 'commission' dans le nom")
sql = """
SELECT n.nspname as schema_name, p.proname as function_name
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname ILIKE '%commission%'
ORDER BY n.nspname, p.proname;
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    print(f"Response: {resp.text}")
    if data.get("ok") and data.get("rows"):
        print(f"✅ {len(data['rows'])} RPCs trouvées:")
        for row in data["rows"]:
            print(f"  - {row['schema_name']}.{row['function_name']}")
    else:
        print("❌ Aucune RPC trouvée")
else:
    print(f"❌ Erreur: {resp.text}")
print()

print("=== AUDIT TERMINÉ ===")
