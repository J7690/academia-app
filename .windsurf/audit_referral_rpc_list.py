"""
Lister les RPCs de référenciation avec une approche différente
"""

import requests
import json

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== LISTE RPCS RÉFÉRENCIATION ===\n")

# Test 1: Utiliser une fonction wrapper pour retourner JSON
print("Test 1: Lister RPCs avec json_agg")
sql = """
SELECT json_agg(json_build_object(
    'schema', n.nspname,
    'function', p.proname
))
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname ILIKE '%referral%';
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status: {resp.status_code}")
print(f"Response: {resp.text}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        print("✅ Résultat:")
        for row in data["rows"]:
            print(json.dumps(row, indent=2, default=str))
print()

# Test 2: Lister les RPCs commission
print("Test 2: Lister RPCs commission avec json_agg")
sql = """
SELECT json_agg(json_build_object(
    'schema', n.nspname,
    'function', p.proname
))
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname ILIKE '%commission%';
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status: {resp.status_code}")
print(f"Response: {resp.text}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        print("✅ Résultat:")
        for row in data["rows"]:
            print(json.dumps(row, indent=2, default=str))
print()

# Test 3: Lister toutes les RPCs du schéma app
print("Test 3: Lister toutes les RPCs du schéma app")
sql = """
SELECT json_agg(json_build_object(
    'function', p.proname
))
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'app'
AND p.prokind = 'f'
LIMIT 20;
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status: {resp.status_code}")
print(f"Response: {resp.text}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        print("✅ Résultat:")
        for row in data["rows"]:
            print(json.dumps(row, indent=2, default=str))
print()

print("=== AUDIT TERMINÉ ===")
