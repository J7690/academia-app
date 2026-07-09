"""
Audit du système de référenciation dans le schéma public
"""

import requests
import json

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== AUDIT SYSTÈME RÉFÉRENCIATION (schéma public) ===\n")

# ÉTAPE 1: Chercher les tables avec "referral" ou "commission" dans public
print("ÉTAPE 1: Tables avec 'referral' ou 'commission' dans public")
sql = """
SELECT relname as table_name
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
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
        print("✅ Aucune table trouvée")
else:
    print(f"❌ Erreur: {resp.text}")

print("\n" + "="*80 + "\n")

# ÉTAPE 2: Vérifier si referral_commissions existe dans public
print("ÉTAPE 2: Colonnes de referral_commissions (si existe)")
sql = """
SELECT a.attname as column_name, t.typname as data_type
FROM pg_attribute a
JOIN pg_type t ON t.oid = a.atttypid
JOIN pg_class c ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
AND c.relname = 'referral_commissions'
AND a.attnum > 0
AND NOT a.attisdropped
ORDER BY a.attnum;
"""

resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        print(f"\nColonnes de referral_commissions ({len(data['rows'])}):\n")
        for row in data["rows"]:
            print(f"  - {row['column_name']}: {row['data_type']}")
    else:
        print("❌ Table non trouvée")
else:
    print(f"❌ Erreur: {resp.text}")

print("\n" + "="*80 + "\n")

# ÉTAPE 3: Compter les enregistrements dans referral_commissions
print("ÉTAPE 3: Compter les enregistrements dans referral_commissions")
sql = """
SELECT COUNT(*) as total
FROM public.referral_commissions;
"""

resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    print(f"Response: {resp.text}")
    if data.get("ok") and data.get("rows"):
        print(f"Total enregistrements: {data['rows'][0]['total']}")
    else:
        print("❌ Erreur ou table vide")
else:
    print(f"❌ Erreur: {resp.text}")

print("\n" + "="*80 + "\n")

# ÉTAPE 4: Vérifier la structure de commission_rules
print("ÉTAPE 4: Colonnes de commission_rules")
sql = """
SELECT a.attname as column_name, t.typname as data_type
FROM pg_attribute a
JOIN pg_type t ON t.oid = a.atttypid
JOIN pg_class c ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'app'
AND c.relname = 'commission_rules'
AND a.attnum > 0
AND NOT a.attisdropped
ORDER BY a.attnum;
"""

resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        print(f"\nColonnes de commission_rules ({len(data['rows'])}):\n")
        for row in data["rows"]:
            print(f"  - {row['column_name']}: {row['data_type']}")
    else:
        print("❌ Table non trouvée")
else:
    print(f"❌ Erreur: {resp.text}")

print("\n" + "="*80 + "\n")
print("=== AUDIT TERMINÉ ===")
