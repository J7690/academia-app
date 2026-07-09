"""
Audit du système de référenciation avec pg_class
"""

import requests
import json

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== AUDIT SYSTÈME RÉFÉRENCIATION (pg_class) ===\n")

# ÉTAPE 1: Lister toutes les tables du schéma app
print("ÉTAPE 1: Toutes les tables du schéma app")
sql = """
SELECT relname as table_name
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'app'
AND c.relkind = 'r'
ORDER BY relname;
"""

resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    print(f"Response: {resp.text}")
    if data.get("ok") and data.get("rows"):
        print(f"\nTotal tables: {len(data['rows'])}\n")
        for i, row in enumerate(data["rows"], 1):
            table_name = row['table_name']
            print(f"{i:3}. {table_name}")
            # Chercher les tables liées aux références
            if 'referral' in table_name.lower() or 'ref' in table_name.lower() or 'commission' in table_name.lower():
                print(f"     ⚠️  TABLE LIÉE AUX RÉFÉRENCES!")
    else:
        print("❌ Pas de données")
else:
    print(f"❌ Erreur: {resp.text}")

print("\n" + "="*80 + "\n")

# ÉTAPE 2: Chercher spécifiquement les tables avec "referral" ou "commission"
print("ÉTAPE 2: Tables avec 'referral' ou 'commission'")
sql = """
SELECT relname as table_name
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'app'
AND c.relkind = 'r'
AND (relname ILIKE '%referral%' OR relname ILIKE '%commission%')
ORDER BY relname;
"""

resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    print(f"Response: {resp.text}")
    if data.get("ok") and data.get("rows"):
        print(f"\nTables trouvées: {len(data['rows'])}\n")
        for row in data["rows"]:
            print(f"  - {row['table_name']}")
    else:
        print("✅ Aucune table trouvée (normal si le système n'est pas déployé)")
else:
    print(f"❌ Erreur: {resp.text}")

print("\n" + "="*80 + "\n")

# ÉTAPE 3: Vérifier les colonnes de students
print("ÉTAPE 3: Colonnes de la table students")
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
        print("❌ Pas de données")
else:
    print(f"❌ Erreur: {resp.text}")

print("\n" + "="*80 + "\n")

# ÉTAPE 4: Vérifier la table commercial_profiles
print("ÉTAPE 4: Colonnes de la table commercial_profiles")
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
        print("❌ Table non trouvée ou pas de colonnes")
else:
    print(f"❌ Erreur: {resp.text}")

print("\n" + "="*80 + "\n")
print("=== AUDIT TERMINÉ ===")
