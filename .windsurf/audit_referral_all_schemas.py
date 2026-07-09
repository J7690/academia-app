"""
Audit du système de référenciation dans tous les schémas
"""

import requests
import json

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== AUDIT SYSTÈME RÉFÉRENCIATION (tous schémas) ===\n")

# ÉTAPE 1: Chercher toutes les tables avec "referral" ou "commission" dans tous les schémas
print("ÉTAPE 1: Tables avec 'referral' ou 'commission' (tous schémas)")
sql = """
SELECT n.nspname as schema_name, c.relname as table_name
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r'
AND (c.relname ILIKE '%referral%' OR c.relname ILIKE '%commission%')
AND n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY n.nspname, c.relname;
"""

resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    print(f"Response: {resp.text}")
    if data.get("ok") and data.get("rows"):
        print(f"\nTables trouvées: {len(data['rows'])}\n")
        for row in data["rows"]:
            print(f"  - {row['schema_name']}.{row['table_name']}")
    else:
        print("✅ Aucune table trouvée")
else:
    print(f"❌ Erreur: {resp.text}")

print("\n" + "="*80 + "\n")

# ÉTAPE 2: Vérifier la table students dans app
print("ÉTAPE 2: Colonnes de students (schéma app)")
sql = """
SELECT a.attname as column_name, t.typname as data_type
FROM pg_attribute a
JOIN pg_type t ON t.oid = a.atttypid
JOIN pg_class c ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'app'
AND c.relname = 'students'
AND a.attnum > 0
AND NOT a.attisdropped
ORDER BY a.attnum;
"""

resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        print(f"\nColonnes de students ({len(data['rows'])}):\n")
        for row in data["rows"]:
            col_name = row['column_name']
            print(f"  - {col_name}: {row['data_type']}")
            if 'ref' in col_name.lower() or 'commercial' in col_name.lower():
                print(f"     ⚠️  COLONNE LIÉE AUX RÉFÉRENCES!")
    else:
        print("❌ Table non trouvée")
else:
    print(f"❌ Erreur: {resp.text}")

print("\n" + "="*80 + "\n")

# ÉTAPE 3: Vérifier la table commercial_profiles dans app
print("ÉTAPE 3: Colonnes de commercial_profiles (schéma app)")
sql = """
SELECT a.attname as column_name, t.typname as data_type
FROM pg_attribute a
JOIN pg_type t ON t.oid = a.atttypid
JOIN pg_class c ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'app'
AND c.relname = 'commercial_profiles'
AND a.attnum > 0
AND NOT a.attisdropped
ORDER BY a.attnum;
"""

resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        print(f"\nColonnes de commercial_profiles ({len(data['rows'])}):\n")
        for row in data["rows"]:
            print(f"  - {row['column_name']}: {row['data_type']}")
    else:
        print("❌ Table non trouvée")
else:
    print(f"❌ Erreur: {resp.text}")

print("\n" + "="*80 + "\n")

# ÉTAPE 4: Lister 50 tables du schéma app pour voir ce qui existe
print("ÉTAPE 4: 50 premières tables du schéma app")
sql = """
SELECT c.relname as table_name
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'app'
AND c.relkind = 'r'
ORDER BY c.relname
LIMIT 50;
"""

resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        print(f"\n50 premières tables du schéma app:\n")
        for i, row in enumerate(data["rows"], 1):
            print(f"{i:3}. {row['table_name']}")
    else:
        print("❌ Pas de données")
else:
    print(f"❌ Erreur: {resp.text}")

print("\n" + "="*80 + "\n")
print("=== AUDIT TERMINÉ ===")
